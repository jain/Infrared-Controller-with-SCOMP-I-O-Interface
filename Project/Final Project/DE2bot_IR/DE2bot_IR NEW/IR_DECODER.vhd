LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE LPM.LPM_COMPONENTS.ALL;

ENTITY IR_DECODER IS
	PORT(
		-- This device will take in the two required signals,
		RAW_IR     : IN STD_LOGIC;
		SAMPLE_CLK : IN STD_LOGIC;
		-- as well as a generic "chip select".  Your device
		-- may need more or less control signals...
		CS         : IN STD_LOGIC;
		-- And this device will just have one 16-bit output.
		-- Your device might have more or less.
		IO_DATA    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END IR_DECODER;


ARCHITECTURE a OF IR_DECODER IS
	-- Declare our states
	TYPE STATE_TYPE IS (
		DECODE,
		FORWARD,
		BACK,
		LFT,
		RGHT,
		STOP,
		LWF, -- Left wheel forward
		LWB, -- Left wheel reverse
		RWF, -- Right wheel forward
		RWB, -- Right wheel reverse
		SLOW,
		FAST
	);
	-- Create some signals that we can use internally
	SIGNAL PACKET_INT : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL IDLE_INT   : STD_LOGIC;
	SIGNAL CODE_INT   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL STATE      : STATE_TYPE;
	SIGNAL IO_OUT     : STD_LOGIC;	
	SIGNAL ADDRESS    : STD_LOGIC_VECTOR(15 DOWNTO 0);	
		
	-- Declare the IR_RCVR device
	COMPONENT IR_RCVR IS
		PORT (
			RAW_IR, SAMPLE_CLOCK : IN STD_LOGIC;
			PACKET : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			IDLE : OUT STD_LOGIC
		);
	END COMPONENT;
	
	BEGIN
	-- Create an instance of IR_RCVR and connect it
	-- to the appropriate signals
	MY_DECODER: IR_RCVR
	PORT MAP(
		RAW_IR, SAMPLE_CLK,
		PACKET_INT, IDLE_INT
	);
	-- Tri state driver
	IO_BUS: LPM_BUSTRI
	GENERIC MAP (
		lpm_width => 16
	)
	PORT MAP (
		data     => ADDRESS,
		enabledt => IO_OUT,
		tridata  => IO_DATA
	);
	-- make the input take only the portion of the packet we want
	CODE_INT <= PACKET_INT(15 DOWNTO 8);
	-- determines when to output to IO_DATA 
	IO_OUT <= CS;
  PROCESS (SAMPLE_CLK, IDLE_INT)
  BEGIN
        -- Stops when no signal has been received for 120ms
    IF IDLE_INT = '1' THEN
      state <= STOP;
    ELSIF SAMPLE_CLK'EVENT AND SAMPLE_CLK = '1' THEN
        -- Case statement to determine next state
      CASE state IS
        WHEN DECODE => -- decodes the action to do from the remote
          CASE CODE_INT IS
            WHEN x"05" => state <= FORWARD;
            WHEN x"0F" => state <= BACK;
            WHEN x"07" => state <= LFT;
            WHEN x"0D" => state <= RGHT;
            WHEN x"0C" => state <= STOP;
            WHEN x"03" => state <= LWF;
            WHEN x"04" => state <= LWB;
            WHEN x"01" => state <= RWF;
            WHEN x"02" => state <= RWB;
            WHEN x"0E" => state <= SLOW;
            WHEN x"1C" => state <= FAST;
            WHEN OTHERS => state <= DECODE;
          END CASE;
          
        -- all of the outputs are made with a WITH STATE SELECT statement,
        -- so each state just returns to decode
        WHEN FORWARD =>
			ADDRESS <= x"0100";
			state <= DECODE;
        
        WHEN BACK =>
			ADDRESS <= x"0110";
			state <= DECODE;
        
        WHEN LFT =>
			ADDRESS <= x"0120";
			state <= DECODE;
        
        WHEN RGHT =>
			ADDRESS <= x"0130";
			state <= DECODE;
        
        WHEN STOP =>
			ADDRESS <= x"0180";
			-- stays stopped if no signal has been received
			IF IDLE_INT = '1' THEN
				state <= STOP;
			ELSE
				state <= DECODE;
			END IF;
        
        WHEN LWF =>
			ADDRESS <= x"0150";
			state <= DECODE;
        
        WHEN LWB =>
			ADDRESS <= x"0200";
			state <= DECODE;
        
        WHEN RWF =>
			ADDRESS <= x"0140";
			state <= DECODE;
        
        WHEN RWB =>
			ADDRESS <= x"0190";
			state <= DECODE;
        
        WHEN SLOW =>
			ADDRESS <= x"0160";
			state <= DECODE;
        
        WHEN FAST =>
			ADDRESS <= x"0170";
			state <= DECODE;     

        
      END CASE;
    END IF;
  END PROCESS;
	
	-- outputs the data to be used as an address in assembly
	--WITH state SELECT
		--ADDRESS <= x"0100" WHEN FORWARD,
			--x"0110" WHEN BACK,
			--x"0120" WHEN LFT,
			--x"0130" WHEN RGHT,
			--x"0180" WHEN STOP,
			--x"0160" WHEN SLOW,
			--x"0170" WHEN FAST,
			--x"0140" WHEN RWF,
			--x"0150" WHEN LWF,
			--x"0190" WHEN RWB,
			--x"0200" WHEN LWB,
			--x"0000" WHEN DECODE;
	
END a;