----------------------------------------------------------------------------------
-- Peter-Bernd Otte
-- 5.4.2012
--   Delay = DELAY times clock cycle
--   Delay = 3 means delays by 2*clock lengths + 0..1*clock length
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity delay_by_shiftregister is
	Generic (
		DELAY : integer
	);
    Port ( CLK : in  STD_LOGIC;
           SIG_IN : in  STD_LOGIC;
           DELAY_OUT : out  STD_LOGIC);
end delay_by_shiftregister;

architecture Behavioral of delay_by_shiftregister is

signal sr : std_logic_vector ( (DELAY-1) downto 0);

begin

	process (CLK, SIG_IN)
	begin
		if(rising_edge(CLK)) then
			sr(0) <= SIG_IN;
			for i in 1 to (DELAY-1) loop
				sr(i)<=sr(i-1);				
			end loop;	
		end if;
	end process;
	
	DELAY_OUT <= sr(DELAY-1);
	
end Behavioral;

