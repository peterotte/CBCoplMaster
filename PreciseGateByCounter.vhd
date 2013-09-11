-- Peter-Bernd Otte
-- Created: 24.4.2012
-- Last Update: 30.5.2012

-- precise gat realised by counter
-- only sensitive on edges of input signal

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PreciseGateByCounter is
	GENERIC (
		WIDTH : integer; --in numbers of clock, max 2^22-1 (because of counter signal)
								-- total length: 5 = 8*clock
								-- total length: 3 = 6*clock
		CounterWidth : integer := 22 --to save reseources and make it faster (for 200MHz -> CounterWidth<20 necessary)
	);
    Port ( Input : in  STD_LOGIC;
           Output : out  STD_LOGIC; -- 20ns deadtime after pulse
			  DeadOut : out  STD_LOGIC; --during reset (20ns) is this signal = '1'
			  Inhibit : in std_logic; -- normal operation = '0'. Not sensitive to input edge if = '1' (inhibit)
           clock : in  STD_LOGIC);
end PreciseGateByCounter;

architecture Behavioral of PreciseGateByCounter is
	signal Inter_out, Inter_Comp : std_logic;
	signal counter : std_logic_vector(CounterWidth downto 0);
	
   COMPONENT SingleBitStorage
   PORT( Clear	:	IN	STD_LOGIC; 
          Output	:	OUT	STD_LOGIC; 
          CE	:	IN	STD_LOGIC; 
          Clock	:	IN	STD_LOGIC; 
          Data	:	IN	STD_LOGIC);
   END COMPONENT;

	signal InputCE : std_logic;
begin
	InputCE <= not Inhibit;
	Inst_SingleBitStorage_1: SingleBitStorage PORT MAP(
		Data => '1', 
		Clock => Input,
		CE => InputCE,
		Clear => Inter_Comp, 
		Output => Inter_out
   );
	process (clock)
	begin
		if rising_edge(clock) then
			if (Inter_out = '1') then
				counter <= counter+1;
			else
				counter <= (others => '0');
			end if;
		end if;
	end process;
	process (clock)
	begin
		if rising_edge(clock) then
			if (counter >= WIDTH) then
				Inter_Comp <= '1';
			else
				Inter_Comp <= '0';
			end if;
		end if;
	end process;
	
	Output <= Inter_Comp xor Inter_out;
	DeadOut <= Inter_Comp;
	
end Behavioral;
