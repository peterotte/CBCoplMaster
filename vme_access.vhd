
----------------------------------------------------------------------------------
-- Company:     GSI
-- Engineer:    S.Minami and Peter-Bernd Otte
-- 
-- Create Date:    10:47:22 06/03/2008 
-- Design Name: vme_access.vhd
-- Last Update:    22.8.2012
-- Description:  a module for vme access control
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vme_access is
  generic (
    BASE_AD : std_logic_vector( 23 downto 20) := b"0000"
                                        -- VME base address D23 to D 20
    );
    
  Port ( AD : inout  STD_LOGIC_VECTOR (31 downto 0);
		VME_Reset : in std_logic;
           ASI : in  STD_LOGIC;
           WRI : in  STD_LOGIC;
           DS0I : in  STD_LOGIC;
           DS1I : in  STD_LOGIC;
           CON : inout  STD_LOGIC_VECTOR (15 downto 0);
			  VN2andVN1 : out std_logic_vector(7 downto 0);
			  CKADDR : out STD_LOGIC;
			  WS : out STD_LOGIC;
           CKCSR : out  STD_LOGIC;
           OECSR : out  STD_LOGIC;
			  U_AD_REG : out STD_LOGIC_VECTOR ( 31 downto 2);
			  U_DAT_IN : in STD_LOGIC_VECTOR ( 31 downto 0);
			  U_DAT_OUT : out STD_LOGIC_VECTOR ( 31 downto 0);
 
			  CLK : in  STD_LOGIC);
end vme_access;

architecture Behavioral of vme_access is


------------------------------- vme signals -----------------------------------------------
signal asis	: std_logic;		-- synchronized  VME !AS
signal dsr	: std_logic;		-- synchronized  VME (!DS0 and !DS1)
signal ad_reg		: std_logic_vector (31 downto 0);	 -- internal address register for VME address
--signal u_ad_reg 	:std_logic_vector(19 downto 2);	
--signal u_dat_in 	:std_logic_vector(31 downto 0);	


--type vme_adr_typ is (va00,va01,va02,va03,va04,va05,va0b, vaRecovery);	-- va06,va07,va08,va09,va0a,
--signal vme_adr, vme_anx : vme_adr_typ;
	subtype vme_adr_typ is std_logic_vector(3 downto 0);
	constant va00 : vme_adr_typ 			:= "0000";
	constant va01 : vme_adr_typ 			:= "0001";
	constant va02 : vme_adr_typ 			:= "0011";
	constant va03 : vme_adr_typ 			:= "0010";
	constant va03a : vme_adr_typ 			:= "0110";
	constant va04 : vme_adr_typ 			:= "0111";
	constant va05 : vme_adr_typ 			:= "0101";
	constant va0b : vme_adr_typ 			:= "0100";
	constant vaRecovery : vme_adr_typ 	:= "1100";
	signal vme_adr, vme_adr_Next : vme_adr_typ;

	--Always use gray code for FSM!! http://en.wikipedia.org/wiki/Gray_code
	attribute safe_recovery_state: string;
	attribute safe_recovery_state of vme_adr: signal is "1100"; -- always use some separate Recovery State
	attribute safe_implementation: string;
	attribute safe_implementation of vme_adr: signal is "yes";
	attribute fsm_encoding: string;
	attribute fsm_encoding of vme_adr: signal is "user"; -- "{auto | one-hot | compact | sequential | gray | johnson | speed1 | user}";
	attribute fsm_extract: string;
	attribute fsm_extract of vme_adr: signal is "yes";
	attribute register_powerup : string;
	attribute register_powerup of vme_adr : signal is "0000"; -- if the FSm has no reset option, then thhis attribute has to be set. Otherwise it wont be recognised as a FSM.



	--type vmdacs_typ is (vc00,vc01,vc02,vc03,vc04,vc05,vc06,vc08,vc09,vc0a,vc0b,vc0c,vc0d,vc0e);
	subtype vmdacs_typ is std_logic_vector(4 downto 0);
	constant vc00 : vmdacs_typ 			:= "00000";
	constant vc01 : vmdacs_typ 			:= "00001";
	constant vc02 : vmdacs_typ 			:= "00011";
	constant vc03 : vmdacs_typ 			:= "00010";
	constant vc04a : vmdacs_typ 			:= "00110";
	constant vc04aa : vmdacs_typ 			:= "00111";
	constant vc04b : vmdacs_typ 			:= "00101";
	constant vc04c: vmdacs_typ 			:= "00100";
	constant vc05 : vmdacs_typ 			:= "01100";
	constant vc06 : vmdacs_typ 			:= "01101";
	constant vc08 : vmdacs_typ 			:= "01111";
	constant vc09 : vmdacs_typ 			:= "01110";
	constant vc0a : vmdacs_typ 			:= "01010";
	constant vc0b : vmdacs_typ 			:= "01011";
	constant vc0c : vmdacs_typ 			:= "01001";
	constant vc0ca : vmdacs_typ 			:= "01000";
	constant vc0caa : vmdacs_typ 			:= "11000";
	constant vc0caaa : vmdacs_typ 		:= "11001";
	constant vc0d : vmdacs_typ 			:= "11011";
	constant vc0e : vmdacs_typ 			:= "11010";
	constant vcRecovery : vmdacs_typ 	:= "11111";
	signal vmdacs, vmdacs_nx : vmdacs_typ;
	attribute safe_recovery_state of vmdacs: signal is "11111";--"11111"; -- always use some separate Recovery State
	attribute safe_implementation of vmdacs: signal is "yes";
	attribute fsm_encoding of vmdacs: signal is "user"; -- "{auto | one-hot | compact | sequential | gray | johnson | speed1 | user}";
	attribute fsm_extract of vmdacs: signal is "yes";
	attribute register_powerup of vmdacs : signal is "00000"; -- if the FSM has no reset option, then this attribute has to be set. Otherwise it won't be recognised as a FSM.


	signal st_csr_drd		: std_logic;	 -- start state machine for CSR read
	signal st_csr_dwr		: std_logic;	 -- start state machine for CSR write   
	signal selcsr		: std_logic;	 -- CSR selected

	signal int_res		: std_logic_vector (23 downto 20);	 -- internal address register for VME address
	signal sel_rnd		: std_logic;	 -- FLASH, CSR, HPI, DPRAM random access

	signal ckad		: std_logic;				-- clock for internal address register
	signal stda		: std_logic;				-- start data phase	state machine
	signal wrs		: std_logic;				-- synchronized VME WRITE
	signal readacc,writeacc	: std_logic;
	signal regsel	:std_logic;
	signal csr_o	: std_logic_vector (1 downto 0);  	-- vme data phase outputs for csr 
	signal vdcsr	: std_logic_vector (3 downto 0);  	-- vme data phase outputs for external vme buffer register 
	signal enable		: std_logic;				-- enable internal data bus to outside of fpga
	signal ack_csr		: std_logic;				-- internal acknowledge csr

begin
	------------------------------------------------------------------------
	-- Reading VN1 and VN2
	------------------------------------------------------------------------
	process (clk)
	begin
		if rising_edge(clk) then
			con(13 downto 12) <= con(13 downto 12)+1;
			case con(13 downto 12) is
				when "00" => VN2andVN1(7 downto 6) <= con(15 downto 14);
				when "01" => VN2andVN1(5 downto 4) <= con(15 downto 14);
				when "10" => VN2andVN1(3 downto 2) <= con(15 downto 14);
				when "11" => VN2andVN1(1 downto 0) <= con(15 downto 14);
				when others => null;    -- null = no operation
			end case;
		end if;
	end process;
	------------------------------------------------------------------------



----* ADPH @@@@@@@@@@@@@@@@ VME ADDRESS PHASE @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--...................... synchronize and invert address strobe .......................
	process(clk) begin
		if (rising_edge(clk)) then 
		    asis <= not ASI;
		    dsr  <= not DS0I and not DS1I;      -- synchronized DS input from VME
		end if;
	end process;
--

	  U_AD_REG 	<=	 ad_reg(31 downto 2);
	  U_DAT_OUT 	<=	 AD;    -- VME address/data bus (31 downto 0)
	
	
--...................... VME address phase state machine .......................
	
	process (clk)
	begin
		if (rising_edge(clk)) then
			if VME_Reset = '1' then
				vme_adr <= va00;
			else
				vme_adr <= vme_adr_Next;
			end if;
		end if;
	end process;
	
	process (clk,vme_adr,asis) 	-- states are - va00,va01,va02,va03,va04,va05,va0b
	begin
		if (vme_adr = vaRecovery) then
			vme_adr_Next <= va00;
		elsif (vme_adr = va00) and (asis = '1') then	
			vme_adr_Next <= va01;
		elsif (vme_adr = va00) then
			vme_adr_Next <= va00;
		elsif (vme_adr = va01) and (asis = '1') then
			vme_adr_Next <= va02;
		elsif (vme_adr = va01) then
			vme_adr_Next <= va00;
		elsif (vme_adr = va02) then
			vme_adr_Next <= va03;
		elsif (vme_adr = va03) then
			vme_adr_Next <= va03a;
		elsif (vme_adr = va03a) then
			vme_adr_Next <= va04;
		elsif (vme_adr = va04) then
			vme_adr_Next <= va05;
		elsif (vme_adr = va05) then
			vme_adr_Next <= va0b;
		elsif (vme_adr = va0b) and (asis = '1') then
			vme_adr_Next <= va0b;
		elsif (vme_adr = va0b) then
			vme_adr_Next <= va00;				
		else 
			vme_adr_Next <= va00;
		end if;
   end process;
-- .............................. synchronize outputs ..................................
	process(vme_adr) 
	begin
		if ( (vme_adr=va03) or (vme_adr=va03a) ) then
		  ckad <= '1';
		else
		  ckad <= '0';
		end if;
		if ( (vme_adr = va04) or (vme_adr = va05) or (vme_adr = va0b) ) then
			stda <= '1';
		else
			stda <='0';
		end if;
	end process;
	CKADDR <= ckad;
	
----................... end of VME address phase state machine ...................
--
---................... save VME address into FPGA internal address register ...................
	process(clk, ckad)
	begin
          if (rising_edge(clk)) then
                  if  ckad = '1' then
							ad_reg <= AD;
                     wrs <= WRI;  
                  end if;
          end if;
	end process;
	WS <= not wrs;
	int_res	<= ad_reg(23 downto 20);  -- internal resources 
--..................  transfer mode decoded by CPLD
	process(clk)								  
	begin
		if (rising_edge(clk)) then   
			sel_rnd <= CON(7);   -- CSR random access
		end if;
	end process;


-- * CSR0 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ DATA PHASE for CSR @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--................................  comparator for CSR  and  DSP CSR  .......................................

	process(clk)
	begin
		if(rising_edge(clk)) then
			if (dsr='1' and stda='1' and wrs='1' and sel_rnd='1') then 
				readacc <= '1'; -- CSR sta-ma
			else 
				readacc <= '0';
			end if;    
			if (dsr='1' and stda='1' and wrs='0' and sel_rnd='1') then 
				writeacc <= '1'; -- CSR sta-ma
			else 
				writeacc <= '0';
			end if;   
		end if;
	end process;

	process(clk) begin
	--	if(rising_edge(clk)) then
	--		if(int_res = BASE_AD) then  -- csr_ad is constant
	--			regsel <= '1';
	--		else
	--			regsel <= '0';
	--		end if;
	--	end if;
		regsel<='1';
   end process;
		  
	process(clk)			-- address selection for internal csr and dsp csr registers
	begin
		if (rising_edge(clk)) then   
			if (readacc = '1' and regsel = '1') then 
				st_csr_drd <= '1'; -- CSR sta-ma
			else 
				st_csr_drd <= '0';
			end if;    
		end if;
	end process;
	
	process(clk) begin
		if(rising_edge(clk)) then
			if (writeacc = '1' and regsel = '1' ) then 
				st_csr_dwr <= '1'; -- CSR sta-ma
			else 
				st_csr_dwr <= '0';
			end if; 
		end if;
	end process;
	
	process (clk)
	begin
		if (rising_edge(clk)) then   
			if (int_res=BASE_AD and sel_rnd='1') then 
				selcsr <= '1'; -- CSR selected
			else 
				selcsr <= '0';
			end if;  
		end if;
	end process;

-- ............................ clock for vmedacs state machine ................................
	process(clk) 
	begin
		if (rising_edge(clk)) then 
			if VME_Reset = '1' then
				vmdacs <= vc00;
			else
				vmdacs <= vmdacs_nx;
			end if;
		end if;
	end process;

	process (vmdacs, dsr, st_csr_dwr, st_csr_drd) 	-- states are - vc00,vc01,vc02,vc03,vc04,vc05,vc06,vc07,vc08 
		begin
			csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1';
			if (vmdacs = vc00) and (st_csr_drd ='1') then
				csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; --1011
				vmdacs_nx <= vc01;						
			elsif (vmdacs = vc00) and (st_csr_dwr ='1') then
				csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; 
				vmdacs_nx <= vc08;		
			elsif (vmdacs = vc00) then
				csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; 
				vmdacs_nx <= vc00;
--............................. read csr ................................
			elsif (vmdacs = vc01) then
				vmdacs_nx <= vc02;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; 
			elsif (vmdacs = vc02) then
				vmdacs_nx <= vc03;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; 
			elsif (vmdacs = vc03) then
				vmdacs_nx <= vc04a;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; 
			elsif (vmdacs = vc04a) then
				vmdacs_nx <= vc04aa;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; 
			elsif (vmdacs = vc04aa) then
				vmdacs_nx <= vc04b;	csr_o <= b"01"; vdcsr <= b"1000"; ack_csr	<='1'; 
			elsif (vmdacs = vc04b) then
				vmdacs_nx <= vc04c;	csr_o <= b"01"; vdcsr <= b"1001"; ack_csr	<='1'; 
			elsif (vmdacs = vc04c) then
				vmdacs_nx <= vc05;	csr_o <= b"01"; vdcsr <= b"1001"; ack_csr	<='1'; 
			elsif (vmdacs = vc05) and (dsr ='1') then
				csr_o <= b"01"; vdcsr <= b"1001"; ack_csr	<='0'; 	
				vmdacs_nx <= vc05;						
			elsif (vmdacs = vc05) then
				csr_o <= b"01"; vdcsr <= b"1001"; ack_csr	<='0'; 
				vmdacs_nx <= vc06;						
			elsif (vmdacs = vc06) then
				vmdacs_nx <= vc00;	csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; 
--............................. write csr ................................
			elsif (vmdacs = vc08) then
				vmdacs_nx <= vc09;	csr_o <= b"10"; vdcsr <= b"0011"; ack_csr	<='1'; 
			elsif (vmdacs = vc09) then
				vmdacs_nx <= vc0a;	csr_o <= b"10"; vdcsr <= b"0011"; ack_csr	<='1'; 
			elsif (vmdacs = vc0a) then
				vmdacs_nx <= vc0b;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; 
			elsif (vmdacs = vc0b) then
				vmdacs_nx <= vc0c;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; 
			elsif (vmdacs = vc0c) then
				vmdacs_nx <= vc0ca;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; 
			elsif (vmdacs = vc0ca) then
				vmdacs_nx <= vc0caa;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; 
			elsif (vmdacs = vc0caa) then
				vmdacs_nx <= vc0caaa;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; 
			elsif (vmdacs = vc0caaa) then
				vmdacs_nx <= vc0d;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; 
			elsif (vmdacs = vc0d) and (dsr ='1') then
				csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='0'; 	
				vmdacs_nx <= vc0d;
			elsif (vmdacs = vc0d) then
				csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='0'; 
				vmdacs_nx <= vc0e;	
			elsif (vmdacs = vc0e) then
				vmdacs_nx <= vc00;	csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; 
			elsif (vmdacs = vcRecovery) then
				vmdacs_nx <= vc00;
			else
				vmdacs_nx <= vc00;
			end if;

	end process;
-- ...................................................................................
	
	
-- .............................. synchronize outputs ..................................
	process(clk) begin
		if (rising_edge(clk)) then 
			if(selcsr = '1') then
				ckcsr	<= csr_o(1);	-- clock data into csr
				oecsr	<= csr_o(0);	-- output data from csr to VME
			else
				ckcsr <= '0';
                                oecsr <= '0';
			end if;
		end if;
	end process ;
	
	

--------------------------- Multiplexer	for VME buffer and VME control signals -------------------------------
--			vdbuf = odvi,cdvi,odiv,cdiv
		process(clk)
		begin
   			if (rising_edge(clk)) then   
    				if ( selcsr='1' ) then 
					CON(4)	<=	vdcsr(3);	-- odvi = OE for data register VME<-internal
					CON(3)	<=	vdcsr(2);	-- cdvi = clock for data register VME<-internal
					CON(2)	<=	vdcsr(1);	-- odiv = OE for data register internal<-VME  
					CON(1)	<=	vdcsr(0);	-- cdiv = clock for data register internal<-VME
					CON(0)	<=	ack_csr;		-- acknowledge from csr
   				else 
					CON(4) <= '1';
                                        CON(3) <= '1';
                                        CON(2) <= '1';
                                        CON(1) <= '1';
                                        CON(0) <= '1';	-- inactive
    				end if;    
    			end if;
		end process; 
		
	enable	<=	csr_o(0);	-- address and data bus output
	AD <= U_DAT_IN when enable ='1' else (others => 'Z');		  
	
	
end Behavioral;
