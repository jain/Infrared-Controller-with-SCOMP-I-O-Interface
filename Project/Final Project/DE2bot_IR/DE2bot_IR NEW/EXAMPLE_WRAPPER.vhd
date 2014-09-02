LIBRARY IEEE;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY EXAMPLE_WRAPPER IS
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
END EXAMPLE_WRAPPER;


ARCHITECTURE a OF EXAMPLE_WRAPPER IS
	-- Create some signals that we can use internally
	SIGNAL PACKET_INT : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL IDLE_INT   : STD_LOGIC;
	-- Declare the IR_RCVR device
	COMPONENT IR_RCVR IS
		PORT (
			RAW_IR, SAMPLE_CLOCK : IN STD_LOGIC;
			PACKET : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			IDLE : OUT STD_LOGIC
		);
	END COMPONENT;
	
	TYPE STATE_TYPE IS(
		
	
	BEGIN
	-- Create an instance of IR_RCVR and connect it
	-- to the appropriate signals
	MY_DECODER: IR_RCVR
	PORT MAP(
		RAW_IR, SAMPLE_CLK,
		PACKET_INT, IDLE_INT
	);
	
	-- Now, we can do whatever we want with the signals.
	-- Here I'm just going to connect some of PACKET straight to the output
	-- so that this file will compile.  This is of course a terrible idea.
	
	
	
	IO_DATA <= PACKET_INT(15 DOWNTO 0);
	
	
	
	
END a;