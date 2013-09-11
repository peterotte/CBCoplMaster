library IEEE;
use IEEE.STD_LOGIC_1164.ALL;																						
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;



entity vuprom_coplanarity_master is
	Port (
--............................. VME Signals ............................................
		AD				: inout std_logic_vector(31 downto 0);	--VME Address-Data bus
		ASI	  			: in std_logic;			     -- Address strobe
		WRI	  			: in std_logic;			     -- Write
		BERRO	  			: out std_logic;		  -- bus error for chain block transfer
		DS0I, DS1I	  		: in std_logic;			  -- data strobe
		DACKP				: in std_logic;			-- acknowledge over CPLD (CON(0))
		IACKII, IACK			: in std_logic;			  -- interrupt acknowledge	chain
		IRBLO, IACKOU			: out std_logic;		  -- interrupt acknowledge	chain
--............................. DSP control signals ............................................
		AHOLD, ARDY	 	: out std_logic;	-- 	
		AHOLDA, AECKO           : in std_logic;		-- 	
		AOE, ARE, AWE		: in std_logic; --		
		AS	 		: in std_logic_vector(19 downto 0); -- address bus of EMIFA 
		DS			: inout std_logic_vector(31 downto 0); -- data bus
		DSPRS, NMI		: inout std_logic; --
		INT	 		: inout std_logic_vector(7 downto 4); --
		TINP	 		: out std_logic_vector(2 downto 0); -- 
		TOUT	 		: in std_logic_vector(2 downto 0); --
		AECKO1			: in std_logic; -- clock from DSP 100MHz for SDRAM
		CEL			: in std_logic_vector(3 downto 0); --
		BCLK, BHOLD, BRDY	: out std_logic;  -- EMIF_B, not used
		CLKR0, CLKS0, CLKX0, DX, FSR0, FSX0, DR0, DX0		: in std_logic; -- serial links
                AX                  : in std_logic_vector(19 downto 16);
		CKFPH				: in std_logic;			-- Clock from DSP 100 MHz 
--............................... HPI ..........................................................DSP
		 HCS, HRW		: inout std_logic; --
		 HD	  	  	: inout std_logic_vector(31 downto 0);	-- hpi data
		 HIA		  	: inout std_logic_vector(2 downto 0);	-- hpi address
		 HRDY			: in std_logic; --			
--............................. Buffer/Register Control Signals ............................................
		CAIV				: out std_logic;		-- 	Address buffer clock signal Int->VME
		CAVI, CDIV, CDVI		: in std_logic;			-- 	not used yet
		OAIV				: out std_logic;			-- 	Address  buffer OE   Int->VME
		OAVI, ODIV, ODVI  : in std_logic;			-- 	not used yet
--............................. Front panel Control Signals ............................................
		IN1X, IN2X, IN3X	  	:in std_logic_vector(32 downto 1);-- 	signals from LVDS inputs ch4
		OU1X				:inout std_logic_vector(32 downto 1);--
		PGIO1X, PGIO2X, PGIO3X, PGIO4X  :inout std_logic_vector(32 downto 1);-- 1:in, 2:i/o 3:i/o 4:o
		LED, PGXLED	  			: out std_logic_vector(8 downto 1);	-- Front panel LED on board, piggy back
                COD                             :in std_logic_vector(2 downto 1); -- piggy board 1I3O=b"00 3I1O=b"11"
		LEMIN1 				:in std_logic;	-- 	signal from LEMO NIM or TTL	
		LEMOE	  				:out std_logic;		-- 	/OE for LEMLEMOTTL output		
		LEMOTTL	  			:out std_logic;-- 	TTL output to LEMO, if JU1 is selected.		
		LEMONIM				:out std_logic;-- 	NIM output to LEMO, if JU2 is selected.				

--............................. SRAM Control Signals ............................................
		SAD	  					: inout std_logic_vector(17 downto 0);	-- address 
		SDA	  					: inout std_logic_vector(15 downto 0);	-- data 
		SCS	  					: inout std_logic;
		SOE	 					: inout std_logic;
		SWE	  					: inout std_logic;
--............................. DISPLAY
		AI	  				: inout std_logic_vector(1 downto 0);	-- display address ( use 1 and 2 only, 0 and 3 can't be seen)
		DI	  				: inout std_logic_vector(6 downto 0);	-- display data 
		WRDIS	  				: inout std_logic;	-- display write
		DOUTLCD					: out std_logic;
--............................. System  Signals ............................................
		PRES, SRESI	  			: in std_logic;	-- reset positive from reset IC	
		RES	  					: in std_logic_vector(2 downto 1);	-- reset from CPLD
		CKFNL, CKFPL	  		: in std_logic;			-- Clock from buffer 100 MHz 
		CON	  					: inout std_logic_vector(15 downto 0);		-- 	Connection between PROG and vupm_1
		HPV, HPW	  				: out std_logic_vector(15 downto 0)	  	-- 	Logic analyzer signals 
		);
end vuprom_coplanarity_master;

architecture rtl of vuprom_coplanarity_master is


	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     VME access 
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	-- TOP level design                     --
	constant YEAR: integer :=9;
	constant MONTH: integer :=4;
	constant DATE: integer :=2;
	constant TRIAL: integer :=2;
	constant version: std_logic_vector ( 31 downto 0):=x"00030508";  -- v0003.00.10
	signal ymdt: std_logic_vector (31 downto 0);
	--signal tdcsetting : std_logic_vector (31 downto 0);
	constant vmead_clkstatus: std_logic_vector ( 11 downto 2) :=b"0000000000";
	constant vmead_ymdt: std_logic_vector ( 11 downto 2) :=b"0000000001";
	constant vmead_version: std_logic_vector ( 11 downto 2) :=b"0000000010";
	signal vme_clkrst : std_logic_vector ( 1 downto 0);
	signal vme_clkstatus: std_logic_vector(1 downto 0);
	signal top_data_o: std_logic_vector(31 downto 0);
	signal top_oecsr : std_logic;
	signal top_ckcsr : std_logic;

	------------------ VME address modifier ------------------------------
	-- CON(8) = am_b = Extended non-privileged  block transfer    
	-- CON(7) = am_9 = Extended non-privileged data access    
	------------------ VME addresses --------------------------------------
	--- address bus (23 downto 20)
	---  address bit 23 = 1 : access to CPLD
	---  XXC0 0000 0000 for Flash Memory Access from CPLD
	---  XX80 0000 0000 for Configure FPGA from Flash Memory
	constant csr_ad	:std_logic_vector(3 downto 0)    := b"0000"; -- vmeaddr=XX00 0000 - XX00 000C  a23-20
	-- constant dspcsr_ad :std_logic_vector(3 downto 0) := b"0100"; -- DSP CSR register  
	-- constant hpi_ad	: std_logic_vector(3 downto 0)   := b"0110"; -- DSP HPI access
	-- constant vmeram_ad : std_logic_vector(3 downto 0):= b"0001"; -- dual ported VME RAM in FPGA
	-- constant sram_ad: std_logic_vector(3 downto 0)   := b"0010"; -- SRAM memory
	-- constant sram_ad	:std_logic_vector(3 downto 2)  := x"01";----vmeaddr=XX40 0000 - XX40 FFFC    

	----- address sharing for vmecsr address bus (19 downto 12)
	constant scal_base :std_logic_vector(7 downto 0) :=x"01";
	constant trig_base :std_logic_vector(7 downto 0) :=x"02";
	-- constant pw_base : std_logic_vector(7 downto 0)  :=x"03";
	constant top_base : std_logic_vector(7 downto 0) :=x"04"; 
	constant disp_base : std_logic_vector(7 downto 0) :=x"05"; 
	constant oszihisto_base : std_logic_vector(7 downto 0) :=x"0a";	

	-- vme bus control signals
	signal ckcsr		: std_logic;	 -- internal CSR
	signal oecsr		: std_logic;	 -- internal CSR
	signal din		: std_logic_vector (31 downto 0);	 -- internal data bus, CSR
	signal u_ad_reg 		:std_logic_vector(31 downto 2);
	signal u_dat_in 		:std_logic_vector(31 downto 0);	
	signal u_data_o 		:std_logic_vector(31 downto 0);	
	signal ckaddr, ws		: std_logic;
	
	signal VN2andVN1 : std_logic_vector(7 downto 0); -- setting of VN1 and VN2 wheels for VMEbus address
	signal VMEAccess_Reset : std_logic;

	COMPONENT vme_access
	  generic (
		 BASE_AD : std_logic_vector( 23 downto 20) := csr_ad
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
				  CLK : in  STD_LOGIC
		);
	END COMPONENT;

	-------------------------------------------
	type TypeGlobal_Module_Step is (PreInit, Init, PostInit, Working);
	signal Global_Module_Step : TypeGlobal_Module_Step;
	signal Global_Reset_After_Power_Up_Delay_1msec : std_logic;

	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     CLOCK 
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	signal clk50, clk100, clk200, clk300, clk400: std_logic;
	signal clk_rst, clk_locked: std_logic_vector ( 1 downto 0);
	 
	COMPONENT clock_boost
	PORT(
		CLKIN_N_IN : IN std_logic;
		CLKIN_P_IN : IN std_logic;
		CLK_RST_IN : IN std_logic_vector(1 downto 0);          
		CLK_LOCKED_OUT : OUT std_logic_vector(1 downto 0);
		CLK50MHz_OUT : OUT std_logic;
		CLK100MHz_OUT : OUT std_logic;
		CLK200MHz_OUT : OUT std_logic;
		CLK300MHz_OUT : OUT std_logic;
		CLK400MHz_OUT : OUT std_logic
		);
	END COMPONENT;
 


	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     Display
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

	signal dispmem_in, dispmem_out	:std_logic_vector(7 downto 0);
	signal disp_data_o : std_logic_vector(31 downto 0);
	signal disp_oecsr : std_logic;
	signal disp_ckcsr : std_logic;
	signal disp_in : std_logic_vector(3 downto 0);

	component display_matrix is
		 Port (  
				VN2andVN1 : in std_logic_vector(7 downto 0);
				reset : in std_logic_vector(1 downto 0);
				  LCD_DIN : inout  STD_LOGIC;
				  LCD_LP : inout  STD_LOGIC;
				  LCD_FLM : inout  STD_LOGIC;
				  LCD_SCP : inout STD_LOGIC;
				  LCD_LED_GRN : inout  STD_LOGIC;
				  LCD_LED_RED : inout  STD_LOGIC;
					--		VME interface -------------------------
					clk50			: in std_logic;
					disp_in : in std_logic_vector(3 downto 0);
					u_ad_reg :in std_logic_vector(11 downto 2);
					u_dat_in :in std_logic_vector(31 downto 0);
					u_data_o :out std_logic_vector(31 downto 0);
					ckaddr, ws, oecsr, ckcsr:in std_logic	
			  );
	end component;

	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     I/O
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--


	signal vhdc_out : std_logic_vector ( 32*1-1 downto 0);
	signal vhdc_in	: std_logic_vector (32*7-1 downto 0);

	signal led_out : std_logic_vector(15 downto 0);

	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     SCALER
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

	signal scal_data_o : std_logic_vector(31 downto 0);
	constant SCCH: integer := 8*32;
	constant SCBit: integer := 32;
	signal scal_in : std_logic_vector(SCCH-1 downto 0);
	signal scal_oecsr : std_logic;
	signal scal_ckcsr : std_logic;
	
	component scaler
		generic ( 
			NCh : integer := SCCH;
			NBit : integer := SCBit
			);  
		port (
			clkl : in STD_LOGIC;
			clkh : in STD_LOGIC;		
			scal_in : STD_LOGIC_VECTOR ( (SCCH-1) downto 0);				
			--............. vme interface .............
			u_ad_reg :in std_logic_vector(11 downto 2);
			u_dat_in :in std_logic_vector(31 downto 0);
			u_data_o :out std_logic_vector(31 downto 0);
			oecsr, ckcsr:in std_logic
		);
	end component;




	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     TRIGGER
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	signal trig_data_o : std_logic_vector(31 downto 0);
	signal trig_in : std_logic_vector( 32*7-1 downto 0);
	signal trig_out : std_logic_vector( 32*1-1 downto 0);
	signal ToOsziAndScaler_out : STD_LOGIC_VECTOR (32*8-1 downto 0);
	signal trig_oecsr : std_logic;
	signal trig_ckcsr : std_logic;

	component trigger
		port (
			clock50 : in STD_LOGIC;
			clock100 : in STD_LOGIC;
			clock200 : in STD_LOGIC;
			clock400 : in STD_LOGIC;
			trig_in : in STD_LOGIC_VECTOR ( 32*7-1 downto 0);	
			trig_out : out STD_LOGIC_VECTOR ( 32*1-1 downto 0);
			ToOsziAndScaler_out : out STD_LOGIC_VECTOR (32*8-1 downto 0);
			nim_in   : in  STD_LOGIC;
			nim_out  : out STD_LOGIC;
			led	     : out STD_LOGIC_VECTOR(8 downto 1); -- 8 LEDs onboard
			pgxled   : out STD_LOGIC_VECTOR(8 downto 1); -- 8 LEDs on PIG board
			Global_Reset_After_Power_Up : in std_logic;
			VN2andVN1 : in std_logic_vector(7 downto 0);
	--............................. vme interface ....................
			u_ad_reg :in std_logic_vector(11 downto 2);
			u_dat_in :in std_logic_vector(31 downto 0);
			u_data_o :out std_logic_vector(31 downto 0);
			oecsr, ckcsr:in std_logic
		);
	end component;

	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     Oszi Histo
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	signal oszihisto_data_o : std_logic_vector(31 downto 0);
	signal oszihisto_in : std_logic_vector( 191 downto 0);
	signal oszihisto_out : std_logic_vector( 63 downto 0);
	signal oszihisto_oecsr : std_logic;
	signal oszihisto_ckcsr : std_logic;
	signal Oszi_SignalsIN: std_logic_vector(255 downto 0);

	COMPONENT OsziHisto
	PORT(
		SignalsIN : IN std_logic_vector(255 downto 0);
		clock200 : IN std_logic;
		clock50 : IN std_logic;
		OsziAcquisionRunning : OUT std_logic;
		Debug_Out : OUT std_logic_vector(31 downto 0);
	--............................. vme interface ....................
		u_ad_reg : IN std_logic_vector(11 downto 2);
		u_dat_in : IN std_logic_vector(31 downto 0);
		u_data_o : OUT std_logic_vector(31 downto 0);
		oecsr : IN std_logic;
		ckcsr : IN std_logic          
		);
	end component;





------------------------------------------------------------------------------------------
begin ---- BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN -----------------
------------------------------------------------------------------------------------------



--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--     CLOCK 
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

	clock_boost_1: clock_boost PORT MAP(
		CLKIN_N_IN => CKFNL,
		CLKIN_P_IN => CKFPL,
		CLK50MHz_OUT => clk50,
		CLK100MHz_OUT => clk100,
		CLK200MHz_OUT => clk200,
		CLK300MHz_OUT => clk300,
		CLK400MHz_OUT => clk400,
		CLK_LOCKED_OUT => clk_locked,
		CLK_RST_IN => clk_rst
	);

	------------------------------------------------------------------------------------------
	-- Reset after Power Up
	-- Needed e.g. for reset of PLL of clock boost 200 -> 200 MHz
	clk_rst(0) <= vme_clkrst(0);
	clk_rst(1) <= vme_clkrst(1) or Global_Reset_After_Power_Up_Delay_1msec;
	


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--     VME access 
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	
	
	vme_access_1: vme_access PORT MAP(
			AD => AD,
			VME_Reset => VMEAccess_Reset,
				ASI => ASI,
           WRI => WRI,
           DS0I => DS0I,
           DS1I => DS1I,
           CON => CON,
			  VN2andVN1 => VN2andVN1,
			 CKADDR => ckaddr,
			 WS => ws,
				CKCSR => ckcsr,
           OECSR => oecsr,
			  U_AD_REG => u_ad_reg,
			  U_DAT_IN => din,
			  U_DAT_OUT => u_dat_in,
           CLK =>clk50
			  );

	--VMEAccess_Reset <= LEMIN1;
	VMEAccess_Reset <= '0';
	BERRO		<= '1';  	-- H means inactive
	IACKOU	<= IACKII; 	-- interrupt acknowledge chain
--		SRESI				-- system reset
	CAIV		<=	'1';	-- clock for address ram0begister internal<-VME, disabled
	OAIV		<=	'1';	-- OE for address register internal<-VME, disabled, '1' means high
	IRBLO	<= '1';

	
---VME access for top level design 

	vme_clkstatus(1 downto 0) <= clk_locked(1 downto 0);
	ymdt(7 downto 0) <=  CONV_STD_LOGIC_VECTOR(TRIAL, 8);
	ymdt(15 downto 8) <=  CONV_STD_LOGIC_VECTOR(DATE, 8);
	ymdt(23 downto 16) <= CONV_STD_LOGIC_VECTOR(MONTH, 8);
	ymdt(31 downto 24) <= CONV_STD_LOGIC_VECTOR(YEAR, 8);
--	tdcsetting(7 downto 0) <=  b"00000001";
--	tdcsetting(15 downto 8) <=  CONV_STD_LOGIC_VECTOR(TDCCH, 8);
--	tdcsetting(23 downto 16) <= CONV_STD_LOGIC_VECTOR(TDCBIT, 8);

	process(clk50, oecsr, ckcsr, u_ad_reg)
	begin
		if (rising_edge(clk50)) then   
			if (oecsr ='1' and u_ad_reg(19 downto 12)=top_base) then 
				top_oecsr <='1';
			else
				top_oecsr <='0';
			end if;
			if (ckcsr ='1' and u_ad_reg(19 downto 12)=top_base) then 
				top_ckcsr <='1';
			else
				top_ckcsr <='0';
			end if;				
		end if;				
	end process;
-- Write cycle --
	process(clk50, top_ckcsr, u_ad_reg)
	begin
		if (clk50'event and clk50 ='1') then
			if (top_ckcsr='1' and u_ad_reg(11 downto 2)=vmead_clkstatus) then
					vme_clkrst(1) <= u_dat_in(1);
			else vme_clkrst(1) <='0';
			end if;
		end if;
		vme_clkrst(0)<='0';
	end process; 

-----Read cycle ----
		process(clk50, top_oecsr, u_ad_reg)
		begin
   		if (clk50'event and clk50 ='1') then
    			if (top_oecsr='1' and u_ad_reg(11 downto 2)=vmead_clkstatus) then 
							top_data_o <= EXT(vme_clkstatus,32); 
	    		elsif (top_oecsr='1' and u_ad_reg(11 downto 2)=vmead_ymdt) then 
							top_data_o <= ymdt;
	    		elsif (top_oecsr='1' and u_ad_reg(11 downto 2)=vmead_version) then 
							top_data_o <= version;
--	    		elsif (oecsr='1' and u_ad_reg(15 downto 4)=x"300" 
--					and u_ad_reg(3 downto 2)=b"10") then 
--							top_data_o <= tdcsetting;
--	    		elsif (oecsr='1' and u_ad_reg(15 downto 4)=x"300" 
--					and u_ad_reg(3 downto 2)=b"11") then 
--							top_data_o <= EXT(TDCOVF, 32);
				else top_data_o <=  (others =>'0');
				end if;    
			end if;
		end process;



----------------------- DATA  for OUTPUT to VME -------------------------------------------

		process(clk50, scal_oecsr, trig_oecsr, top_oecsr)
		begin
   			if (rising_edge(clk50)) then   
					if 	(scal_oecsr ='1' ) then
							din	<=  	scal_data_o;
					elsif 	(trig_oecsr ='1' ) then
							din	<=	trig_data_o; 
					elsif 	(top_oecsr ='1') then
							din	<=	top_data_o; 
					elsif (disp_oecsr ='1') then
							din	<= disp_data_o;
					elsif (oszihisto_oecsr ='1') then
						din	<= oszihisto_data_o;
					else  	
						din	<=  	(others => '0');
					end if;    
    			end if;
		end process;		
	

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--     Display
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
        DOUTLCD <= '0';
--		WRDIS	<= '1';

	disp_matrix1: display_matrix port map (
		VN2andVN1 => VN2andVN1,
		reset => res,
	  lcd_din => DI(0),
	  lcd_lp => DI(1), 
	  lcd_flm => DI(2),
	  lcd_scp => DI(3),
	  lcd_led_grn => DI(4),
	  lcd_led_red => DI(5),
		clk50 => clk50,
		disp_in => disp_in,
		u_ad_reg=>u_ad_reg(11 downto 2), 
		u_dat_in=>u_dat_in, 
		u_data_o=>disp_data_o,
		ckaddr=> ckaddr,
		ws=>ws,
		oecsr=>disp_oecsr, 
		ckcsr=>disp_ckcsr
			);
	-- vme_access --
	process(clk50, oecsr, ckcsr, u_ad_reg)
	begin
			if (rising_edge(clk50)) then   
				if (oecsr ='1' and u_ad_reg(19 downto 12)=disp_base) then 
					disp_oecsr <='1';
				else
					disp_oecsr <='0';
				end if;
				if (ckcsr ='1' and u_ad_reg(19 downto 12)=disp_base) then 
					disp_ckcsr <='1';
				else
					disp_ckcsr <='0';
				end if;				
			end if;				
	end process;

	disp_in(0)<= clk_locked(0) and clk_locked(1);
	disp_in(1)<= COD(1) or COD(2);
	disp_in(2)<= CON(7) or CON(8);
	disp_in(3)<= LEMIN1;
	
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--     I/O
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	vhdc_in( 31 downto 0)  <= IN1X ( 32 downto 1);
	vhdc_in( 63 downto 32) <= IN2X ( 32 downto 1);
	vhdc_in( 95 downto 64) <= IN3X ( 32 downto 1);
	vhdc_in( 127 downto 96) <= PGIO1X ( 32 downto 1);
	vhdc_in( 159 downto 128) <= PGIO2X ( 32 downto 1);
	vhdc_in( 191 downto 160) <= PGIO3X ( 32 downto 1);
	vhdc_in( 223 downto 192) <= PGIO4X ( 32 downto 1);

	OU1X( 32 downto 1)   <= vhdc_out ( 31 downto 0);
--	PGIO4X( 32 downto 1) <= vhdc_out ( 63 downto 32);
--	PGIO2X( 32 downto 1) <= vhdc_out ( 63 downto 32);
--	PGIO3X( 32 downto 1) <= vhdc_out ( 95 downto 64);
--	PGIO4X( 32 downto 1) <= vhdc_out ( 127 downto 96);

--	LEMONIM<= tdc_tst_stop_o or trig_allor;
--	LEMONIM<= tdc_tst_stop_o or LEMIN1;


	vhdc_out <= trig_out;

-- scaler i/o
	scal_in <= ToOsziAndScaler_out;


	
	--Select Signals for Oszi:
	Oszi_SignalsIN <= ToOsziAndScaler_out;
	
-- trigger i/o
	trig_in( 32*7-1 downto 0)  <= vhdc_in( 32*7-1 downto 0);
	LEMOE <='1'; -- LEMTTL set to Z.
	LEMOTTL <='0'; 
	

----- DSP ------
	BCLK	<= clk50;
	BHOLD	<= '0';
	BRDY	<= '1';
	ARDY	<= '1';
	AHOLD	<= '1';
	NMI	<=	'Z';
	TINP	<=	(others => '0');
	DS <= (others =>'Z');
	DSPRS <='Z';

---- SRAM -----
	SCS	<= '1';
	SOE	<= '1';
	SWE	<= '1';
	SAD		<=	(others => 'Z');
	SDA		<=	(others => 'Z'); 
		--was: CON(15 downto 9)		<=	b"0000000";
		CON(11 downto 9)		<=	b"000"; -- because Con 15 downto 12 is used for reading of wheels VN1 and VN2


	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     SCALER
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

	scaler_1: scaler 
		port map (
			clkl=>clk50, clkh => clk100,
			scal_in=>scal_in,
			u_ad_reg=>u_ad_reg(11 downto 2), 
			u_dat_in=>u_dat_in, 
			u_data_o=>scal_data_o,
			oecsr=>scal_oecsr, 
			ckcsr=>scal_ckcsr
		);									

	process(clk50, oecsr, ckcsr, u_ad_reg)
	begin
		if (rising_edge(clk50)) then   
		--scaler--
			if (oecsr ='1' and u_ad_reg(19 downto 12)=scal_base) then 
				scal_oecsr <='1';
			else
				scal_oecsr <='0';
			end if;
			if (ckcsr ='1' and u_ad_reg(19 downto 12)=scal_base) then 
				scal_ckcsr <='1';
			else
				scal_ckcsr <='0';
			end if;	
		end if;				
	end process;
			

	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     TRIGGER
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	trigger_1: trigger port map (
			clock50=>clk50,
			clock100=>clk100,
			clock200=>clk200,
			clock400=>clk400,
			trig_in=>trig_in,
			trig_out=>trig_out,
			ToOsziAndScaler_out => ToOsziAndScaler_out, 
			nim_in => LEMIN1,
			nim_out => LEMONIM,
			led => led,
			pgxled => pgxled,
			Global_Reset_After_Power_Up => Global_Reset_After_Power_Up_Delay_1msec,
			VN2andVN1 => VN2andVN1,
			u_ad_reg=>u_ad_reg(11 downto 2), 
			u_dat_in=>u_dat_in, 
			u_data_o=>trig_data_o,
			oecsr=>trig_oecsr, 
			ckcsr=>trig_ckcsr
		);									
		process(clk50, oecsr, ckcsr, u_ad_reg)
		begin
   			if (rising_edge(clk50)) then   

					if (oecsr ='1' and u_ad_reg(19 downto 12)=trig_base) then 
						trig_oecsr <='1';
					else
						trig_oecsr <='0';
					end if;
					if (ckcsr ='1' and u_ad_reg(19 downto 12)=trig_base) then 
						trig_ckcsr <='1';
					else
						trig_ckcsr <='0';
					end if;						

				end if;				
		end process;
		

	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	--     Oszi Histo
	--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
	
	OsziHisto_1: OsziHisto PORT MAP(
		SignalsIN => Oszi_SignalsIN, --trig_in(3 downto 0),
		OsziAcquisionRunning => open,
		clock200 => clk200,
		clock50 => clk50,
		Debug_Out => open,
		u_ad_reg => u_ad_reg(11 downto 2),
		u_dat_in => u_dat_in,
		u_data_o => oszihisto_data_o,
		oecsr => oszihisto_oecsr,
		ckcsr => oszihisto_ckcsr
	);

	process(clk50, oecsr, ckcsr, u_ad_reg)
	begin
			if (rising_edge(clk50)) then   

				if (oecsr ='1' and u_ad_reg(19 downto 12)=oszihisto_base) then 
					oszihisto_oecsr <='1';
				else
					oszihisto_oecsr <='0';
				end if;
				if (ckcsr ='1' and u_ad_reg(19 downto 12)=oszihisto_base) then 
					oszihisto_ckcsr <='1';
				else
					oszihisto_ckcsr <='0';
				end if;						

			end if;				
	end process;


--======================================================================================================

------------------------------------------------------------------------------
-- * HPLA @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Logic Analyzer @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
------------------------------------
-- 	odvi <= CON(4); 	cdvi	<=	CON(3); 	odiv <= CON(2);	cdiv <= CON(1); 	ack_csr <= CON(0);	-- from fpga to cpld
--		odvi <= '1'; 		cdvi	<=	'0'; 		odiv <= '1';		cdiv <= '1'; 		dack_i <= '1';			-- from fpga to cpld


--		hpv(15 downto 7) <= (others => '0');
	hpw(7 downto 0) <= x"00";
	hpw(8) <= '0' when led_out(15 downto 0)=x"0000" else '1';
	hpw(9) <= LEMIN1;
	hpw(15 downto 10) <= IN1X ( 6 downto 1);



	hpv(0)<=CON(7);
	hpv(1)<=CON(8);
	hpv(6 downto 2)<=CON(4 downto 0);
	hpv(7) <= clk50;
	hpv(15 downto 8 ) <= (others => '0');
	


	------------------------------------------------------------------------------------------

	------------------------------------------------------------------------------------------
	-- Reset after Power Up
	-- Needed e.g. for reset of PLL of clock boost 200 -> 400 MHz
	------------------------------------------------------------------------------------------
	process (clk50)
		variable ZaehlerGlobalModuleStep : integer;
	begin
		if rising_edge(Clk50) then	
			if Global_Module_Step /= Working then
				ZaehlerGlobalModuleStep := ZaehlerGlobalModuleStep + 1;
			end if;
			
			if ZaehlerGlobalModuleStep < 50000*1 then -- before 1 msecond
				Global_Module_Step <= PreInit;
			elsif ZaehlerGlobalModuleStep < 50000*2 then -- before 2 mseconds
				Global_Module_Step <= Init;
			elsif ZaehlerGlobalModuleStep < 50000*3 then -- before 3 mseconds
				Global_Module_Step <= PostInit;
			else
				Global_Module_Step <= Working;
			end if;

		end if;
	end process;


	process (Global_Module_Step)
	begin
		case Global_Module_Step is
			when PreInit => 
				Global_Reset_After_Power_Up_Delay_1msec <= '0';
			when Init =>
				Global_Reset_After_Power_Up_Delay_1msec <= '1';
			when PostInit =>
				Global_Reset_After_Power_Up_Delay_1msec <= '0';
			when Working => 
				Global_Reset_After_Power_Up_Delay_1msec <= '0';
		end case;
	end process;
	
end rtl;
