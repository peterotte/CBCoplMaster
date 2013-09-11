-- check, whether all PLLs are locked: ./vmeext 0xXX004000 0x0 r
-- should be 0x3
-- To Reset the PLLs: ./vmeext 0xXX004000 0x3 w

----------------------------------------------------------------------------------
-- Company:  GSI
-- Engineer: S.Minami
-- 
-- Create Date:    13:46:21 04/14/2008 
-- Design Name: 
-- Module Name:    clock_boost - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity clock_boost is
    Port ( CLKIN_N_IN : in  STD_LOGIC;
           CLKIN_P_IN : in  STD_LOGIC;
			  CLK_RST_IN : in  STD_LOGIC_VECTOR (1 downto 0);
           CLK_LOCKED_OUT : out  STD_LOGIC_VECTOR (1 downto 0);
			  CLK50MHz_OUT : out  STD_LOGIC;
           CLK100MHz_OUT : out  STD_LOGIC;
           CLK200MHz_OUT : out  STD_LOGIC;
           CLK300MHz_OUT : out  STD_LOGIC;
           CLK400MHz_OUT : out  STD_LOGIC );
 
end clock_boost;

architecture Behavioral of clock_boost is

	COMPONENT clkbst100to200
	PORT(
		CLKIN_N_IN : IN std_logic;
		CLKIN_P_IN : IN std_logic;
		RST_IN : IN std_logic;          
		CLKDV_OUT : OUT std_logic;
		CLKFX_OUT : OUT std_logic;
		CLKIN_IBUFGDS_OUT : OUT std_logic;
		CLK0_OUT : OUT std_logic;
		CLK2X_OUT : OUT std_logic;
		LOCKED_OUT : OUT std_logic
		);
	END COMPONENT;


	COMPONENT clkbst200to400
	PORT(
		CLKIN_IN : IN std_logic;
		RST_IN : IN std_logic;          
		CLK0_OUT : OUT std_logic;
		CLK2X_OUT : OUT std_logic;
		LOCKED_OUT : OUT std_logic
		);
	END COMPONENT;

	signal clk50,clk100,clk200,clk300,clk400: std_logic;
	signal locked, reset : std_logic_vector ( 1 downto 0);
	signal clk100_2, clk200_2: std_logic;
begin

		  CLK50MHz_OUT <= clk50;
		  CLK100MHz_OUT <= clk100;
		  CLK200MHz_OUT <= clk200;
		  CLK300MHz_OUT <= clk300;
		  CLK400MHz_OUT <= clk400;
		  CLK_LOCKED_OUT <= locked;
		  reset <= CLK_RST_IN;

	Inst_clkbst100to200: clkbst100to200 PORT MAP(
		CLKIN_N_IN => CLKIN_N_IN,
		CLKIN_P_IN => CLKIN_P_IN,
		RST_IN => reset(0),
		CLKDV_OUT => clk50,
		CLKFX_OUT => clk300,
		CLKIN_IBUFGDS_OUT => clk100_2,
		CLK0_OUT => clk100,
		CLK2X_OUT => clk200,
		LOCKED_OUT => locked(0)
	);


	Inst_clkbst200to400: clkbst200to400 PORT MAP(
		CLKIN_IN => clk200,
		RST_IN => reset(1),
		CLK0_OUT => clk200_2,
		CLK2X_OUT => clk400,
		LOCKED_OUT =>locked(1) 
	);


--locked(1)<='0';
--clk400<= clk300;


end Behavioral;

