library IEEE;
use IEEE.STD_LOGIC_1164.ALL;																						
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity scaler is
	generic ( 
			NCh : integer;
			NBit : integer
			);  
		port (
			CLKL : in STD_LOGIC;
			CLKH : in STD_LOGIC;
			scal_in : STD_LOGIC_VECTOR ( (NCh-1) downto 0);				
			--............ vme interface ....................
			u_ad_reg :in std_logic_vector(11 downto 2);
			u_dat_in :in std_logic_vector(31 downto 0);
			u_data_o :out std_logic_vector(31 downto 0);
			oecsr, ckcsr:in std_logic
			);
end scaler;

architecture RTL of scaler is

	signal in_f1,in_f2 : std_logic_vector ( (NCh-1) downto 0);
	signal count : std_logic_vector (NCh*NBit-1 downto 0);
	signal count_fix : std_logic_vector (NCh*NBit-1 downto 0);
	signal sc_clr : std_logic;
	signal sc_fix : std_logic;

	constant BASE_SCAL_REG : std_logic_vector(11 downto 2) := b"0000000000"; -- 0x000 - 0x1FF r

	constant BASE_SCAL_CLR : std_logic_vector(11 downto 2) := b"1000000000"; -- 0x800 w
	constant BASE_SCAL_STOP : std_logic_vector(11 downto 2) := b"1000000001"; -- 0x804 w for sc_fix = '1'

	constant BASE_SCAL_FIX : std_logic_vector(11 downto 2) := b"1111000000"; -- 0xF00 r
	constant BASE_SCAL_NCH : std_logic_vector(11 downto 2) := b"1111000001"; -- 0xF04 r
	constant BASE_SCAL_NBIT :std_logic_vector(11 downto 2) := b"1111000010"; -- 0xF08 r





------------------------------------------------------------------------------------------
begin ---- BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN 
------------------------------------------------------------------------------------------
	
	process (CLKH)
	begin
		if (CLKH'event and CLKH ='1') then
			in_f1<=scal_in;
			in_f2<=in_f1;

		end if;
	end process;
	
	process (CLKH, in_f1, in_f2)
	begin
		if(CLKH'event and CLKH='1') then
			for i in 0 to (NCh-1) loop
				if(sc_clr='1') then
					count(NBit*(i+1)-1 downto NBit*i)<=(others => '0');
				elsif(in_f1(i)='1' and in_f2(i)='0') then
					count(NBit*(i+1)-1 downto NBit*i)<=count(NBit*(i+1)-1 downto NBit*i)+1;
				end if;
			end loop;

			if(sc_clr='1' or sc_fix='1' ) then
				count_fix <= count;
			end if;

		end if;
	end process;
--	count_fix <= (others => '0');

----VME access ----------------------------------------------------------------------------------------- .................... decoder for data registers ................................
		process(CLKL, ckcsr, u_ad_reg)
		begin

			-- CLEAR --

			if (CLKL'event and CLKL ='1') then
--				if (ckcsr='1' and  u_ad_reg(15 downto 12)= x"1" and 
--					u_ad_reg(11 downto 2)= b"0100000001"  ) then -- 0x1404 
--					vme_ovf <= u_dat_in(TDCCH-1 downto 0);
--				elsif (vme_ovf = CONV_STD_LOGIC_VECTOR(0,TDCCH)) then
--					vme_ovf <= TDCOVF;
--				end if;

				if (ckcsr='1' and 
					u_ad_reg(11 downto 2)= BASE_SCAL_CLR  ) then -- 0x800
					sc_clr <= u_dat_in(0);
				else sc_clr <='0';
				end if;

				if (ckcsr='1' and 
					u_ad_reg(11 downto 2)= BASE_SCAL_STOP  ) then -- 0x804 
					sc_fix <= u_dat_in(0);
				else sc_fix <='0';
				end if;

			end if;

		end process;
		

	-------- vme read cycle -------------------------------------------------------
	process(CLKL, oecsr, u_ad_reg)
	begin
		if (CLKL'event and CLKL ='1' and oecsr ='1') then
			-- Scaler readout -- 0x000  
			for I in 0 to NCh-1 loop -- 0x000 ->0x1fc
				if ( u_ad_reg(11 downto 10)=BASE_SCAL_REG(11 downto 10) ) then
					if ( u_ad_reg(9 downto 2)=CONV_STD_LOGIC_VECTOR( I, 8) ) then 
						u_data_o(31 downto 0) <= count_fix( NBit*(I+1)-1 downto NBit*I );

--						u_data_o(31 downto 24) <= CONV_STD_LOGIC_VECTOR(I,8);
--						u_data_o(23 downto 0) <= count_fix( NBit*(I+1)-1 downto NBit*I );

--						u_data_o(23 downto 0) <= b"0000" & count_fix( NBit*(I+1)-1 downto NBit*I );
					end if;
				end if;
			end loop;
			-- STATUS -- 0x400 
			if ( 
				u_ad_reg(11 downto 2)= BASE_SCAL_NCH  ) then -- 
					u_data_o(7 downto 0) <= CONV_STD_LOGIC_VECTOR(NCh, 8);
					u_data_o(31 downto 8) <= x"000000";
			end if;			
			if ( 
				u_ad_reg(11 downto 2)= BASE_SCAL_NBIT  ) then -- 
					u_data_o(31 downto 0) <= CONV_STD_LOGIC_VECTOR(NBit,32);
			end if;	

				if (  
					u_ad_reg(11 downto 2)= BASE_SCAL_FIX ) then -- 
						u_data_o(31 downto 0) <= x"87654321";
				end if;	
		
		

			end if;
		end process;
		


end RTL;