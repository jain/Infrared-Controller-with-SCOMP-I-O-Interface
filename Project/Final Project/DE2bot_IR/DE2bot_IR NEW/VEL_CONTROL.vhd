-- VEL_CONTROL.VHD
-- 2013-07-12
-- This was the velocity controller for the AmigoBot project. 
-- Team Flying Robots
-- ECE2031 L05  (minor mods by T. Collins, plus major addition of closed-loop control)

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE LPM.LPM_COMPONENTS.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY VEL_CONTROL IS
	PORT(
		PWM_CLK,    -- must be an 400 MHz clock signal to get ~100 kHz PWM frequency
		RESETN,
		CS,       -- chip select, asserted when new speed is input
		IO_WRITE : IN    STD_LOGIC;  -- asserted when being written to
		IO_DATA  : IN    STD_LOGIC_VECTOR(15 DOWNTO 0);  -- commanded speed from SCOMP (only lower 8 bits used)
		VELOCITY : IN    STD_LOGIC_VECTOR(11 DOWNTO 0); -- actual velocity of motor, for closed loop control 
		CTRL_CLK : IN    STD_LOGIC;  -- clock that determines control loop sampling rate (100 Hz)
		NMOTOR_EN, -- turns the motor on/off, this will be a PWM signal
		MOTOR_DIR : OUT  STD_LOGIC; -- direction the wheel will rotate
		WATCHDOG  : OUT  STD_LOGIC;  -- safety feature
		SATURATED : OUT  STD_LOGIC -- indicates that integrator is saturated
	);
END VEL_CONTROL;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

ARCHITECTURE a OF VEL_CONTROL IS
	SIGNAL COUNT  : STD_LOGIC_VECTOR(11 DOWNTO 0); -- counter output
	SIGNAL IO_DATA_INT: STD_LOGIC_VECTOR(7 DOWNTO 0); -- internal speed value
	SIGNAL NMOTOR_EN_INT: STD_LOGIC; --  internal enable signal
	SIGNAL LATCH: STD_LOGIC;
	SIGNAL PWM_CMD: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL WATCHDOG_INT: STD_LOGIC;

	BEGIN 
	-- Use LPM counter megafunction to make a divide by 4096 counter
	counter: LPM_COUNTER
	GENERIC MAP(
		lpm_width => 12,
		lpm_direction => "UP"
	)
	PORT MAP(
		clock => PWM_CLK,
		q => COUNT
	);

	-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
	--  INSTABILITY, AND RUNAWAY ROBOTS!!

	-- Use LPM compare megafunction to produce desired duty cycle
	compare: LPM_COMPARE
	GENERIC MAP(
		lpm_width => 12,
		lpm_representation => "UNSIGNED"
	)
	PORT MAP(
		dataa => COUNT,
		datab =>  PWM_CMD(11 DOWNTO 0),  
		ageb => NMOTOR_EN_INT
	);

	-- the enable and watchdog bits are outputs, but since they are read
	--   internally, they require "shadow" equivalents for read/write.
	-- Here, they are used to drive the actual output pins
	NMOTOR_EN <= NMOTOR_EN_INT;
	WATCHDOG <= WATCHDOG_INT;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

	LATCH <= CS AND IO_WRITE; -- part of IO fix (below) -- TRC

	PROCESS (RESETN, LATCH)
	BEGIN
		-- set speed to 0 after a reset
		IF RESETN = '0' THEN
			IO_DATA_INT <= "00000000";
			WATCHDOG_INT <= '0';
			-- keep the IO command (velocity command) from SCOMP in an internal register IO_DATA_INT
		ELSIF RISING_EDGE(LATCH) THEN   -- fixed unreliable OUT operation - TRC
			-- handle the case of the max negative velocity
			IF IO_DATA(7 DOWNTO 0) = "10000000" THEN
				IO_DATA_INT <= "00000000";  -- req'd behavior for -128 (treat as zero)
			ELSE -- save value
				IO_DATA_INT <= IO_DATA(7 DOWNTO 0);
			END IF;
			WATCHDOG_INT <= NOT WATCHDOG_INT;		-- toggle the watchdog timer any time a command is received
		END IF;
	END PROCESS;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!


	-- added closed loop control so that motor will try to achieve exactly the value commanded - TRC
	PROCESS (CTRL_CLK, RESETN, IO_DATA_INT)
		VARIABLE CMD_VEL, VEL_ERR, CUM_VEL_ERR: INTEGER;
		CONSTANT SATURATION: INTEGER := 10000;  -- Limits effect of integrator "windup"
		VARIABLE D_ERR, LASTVEL: INTEGER := 0;
		CONSTANT LIMIT: SIGNED(19 DOWNTO 0) := x"0F000";
		CONSTANT PLIM: SIGNED(19 DOWNTO 0) := x"01000"; -- cap for P
		CONSTANT KF: INTEGER := 200;
		CONSTANT KP: INTEGER := 50;
		CONSTANT KI: INTEGER := 1;
		CONSTANT KD: INTEGER := 1;  -- Gains 
		VARIABLE MOTOR_CMD: SIGNED(19 DOWNTO 0); 
		VARIABLE PROP_CTRL, INT_CTRL, DERIV_CTRL: SIGNED(19 DOWNTO 0); 
		VARIABLE FF_CTRL: SIGNED(19 DOWNTO 0);

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

	BEGIN 
		PWM_CMD <= STD_LOGIC_VECTOR  (ABS (MOTOR_CMD(19 DOWNTO 4)));
		IF RESETN = '0' OR IO_DATA_INT = "00000000" THEN
			MOTOR_CMD := "00000000000000000000"; -- at startup, motor should be off
			CUM_VEL_ERR := 0;
			LASTVEL := 0;
			D_ERR := 0;
		ELSIF RISING_EDGE(CTRL_CLK) THEN   -- determine a control signal at each control cycle
			CMD_VEL := TO_INTEGER(SIGNED(IO_DATA_INT)); 
			D_ERR := VEL_ERR - LASTVEL;
			LASTVEL := VEL_ERR;
			VEL_ERR := ((CMD_VEL*4) - TO_INTEGER(SIGNED(VELOCITY(11 DOWNTO 0))));  
			CUM_VEL_ERR := CUM_VEL_ERR + VEL_ERR;   -- perform the integration,
			IF (CUM_VEL_ERR > SATURATION) THEN
				CUM_VEL_ERR := SATURATION;
				SATURATED <= '1';
			ELSIF (VEL_ERR < -SATURATION) THEN
				CUM_VEL_ERR := -SATURATION;
				SATURATED <= '1';
			ELSE
				SATURATED <= '0';
			END IF;
			PROP_CTRL := TO_SIGNED( VEL_ERR * KP, 20 );   -- The "P" component of the PID controller
			IF (PROP_CTRL > PLIM) THEN
				PROP_CTRL := PLIM; 
			ELSIF (PROP_CTRL < -PLIM) THEN
				PROP_CTRL := -PLIM;
			END IF;
			INT_CTRL  := TO_SIGNED( CUM_VEL_ERR * KI, 20);   -- The "I" component
			DERIV_CTRL := TO_SIGNED( D_ERR * KD, 20);-- The "D" component 
			FF_CTRL := TO_SIGNED( CMD_VEL * KF, 20);   -- FeedForward component...
-- CLOSED-LOOP CONTROL ENABLED IN THIS VERSION:
--			MOTOR_CMD := (FF_CTRL + PROP_CTRL)/8;
			MOTOR_CMD := FF_CTRL + PROP_CTRL + INT_CTRL + DERIV_CTRL;
			IF (MOTOR_CMD > LIMIT) THEN
				MOTOR_CMD := LIMIT; 
			ELSIF (MOTOR_CMD < -LIMIT) THEN
				MOTOR_CMD := -LIMIT;
			END IF;
			MOTOR_DIR <= NOT(MOTOR_CMD(19)); 
		END IF; 
	END PROCESS;

END a;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

