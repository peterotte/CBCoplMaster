library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity gate_by_shiftreg is
	Generic (
		WIDTH : integer
	);
    Port ( CLK : in STD_LOGIC;
			  SIG_IN : in  STD_LOGIC;
           GATE_OUT : out  STD_LOGIC);
end gate_by_shiftreg;


architecture Behavioral of gate_by_shiftreg is

	signal shift_reg : std_logic_vector ( (WIDTH-1) downto 0);
	signal gate : std_logic;

begin
	process (CLK, SIG_IN)
	begin
		if (rising_edge(CLK)) then
			shift_reg(0) <= SIG_IN;
			for I in 0 to WIDTH-2 loop
				shift_reg(I+1) <= shift_reg(I);
			end loop;
			
			if (shift_reg(WIDTH-2 downto 0) /= "0" ) then
				gate <='1';
			else 
				gate<='0';
			end if;
	
		end if;
	end process;
	
--	GATE_OUT <= gate when shift_reg(WIDTH-2) = '0' else '0';
	GATE_OUT <= gate when shift_reg(WIDTH-1) = '0' else '0';

end Behavioral;

