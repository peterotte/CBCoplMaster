----------------------------------------------------------------------------------
-- Engineer: Peter-Bernd Otte, KPH
-- 
-- Create Date:    12:45:09 27.08.2012 
--
-- Don't for get the following commands for *.ucf file:
--
-- # needed for OsziHisto START
-- # if no functionality like ClockSpeedSelected
-- # is needed, then this can be taken out
-- NET "OsziHisto_1/ClockSpeedSelected*" TIG;
-- NET "OsziHisto_1/SignalInShapeMode*" TIG;
-- NET "OsziHisto_1/TriggerSelection*" TIG;
-- NET "OsziHisto_1/VMEAddrIn*" TIG;
-- NET "OsziHisto_1/VMEDataOut*" TIG;
-- NET "OsziHisto_1/DisarmTrigger" TIG;
-- INST "OsziHisto_1/Inter_OsziAcquisionRunning" TNM = test1;
-- INST "OsziHisto_1/u_data_o_0" TNM = test2;
-- TIMESPEC TS_teste3 = FROM "test1" TO "test2" TIG;
-- #needed for OsziHisto END
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity OsziHisto is
    Port ( SignalsIN : in  STD_LOGIC_VECTOR (255 downto 0);
           OsziAcquisionRunning : out  STD_LOGIC; --'1' while acquiring
			  clock200 : in STD_LOGIC;
			  clock50 : in STD_LOGIC;
			  Debug_Out : out std_logic_vector(31 downto 0);
	--............................. vme interface ....................
		u_ad_reg :in std_logic_vector(11 downto 2);
		u_dat_in :in std_logic_vector(31 downto 0);
		u_data_o :out std_logic_vector(31 downto 0);
		oecsr, ckcsr:in std_logic
	);
end OsziHisto;

architecture Behavioral of OsziHisto is
	subtype sub_Address is std_logic_vector(11 downto 4);
	constant BASE_TRIG_DisarmTrigger : sub_Address 					:= x"01" ; -- r/w
	constant BASE_TRIG_VMERAMBAddr : sub_Address 					:= x"02" ; -- r/w
	constant BASE_TRIG_VMERAMBOut_0 : sub_Address 					:= x"03" ; -- r
	constant BASE_TRIG_VMERAMBOut_1 : sub_Address 					:= x"04" ; -- r
	constant BASE_TRIG_VMERAMBOut_2 : sub_Address 					:= x"05" ; -- r
	constant BASE_TRIG_VMERAMBOut_3 : sub_Address 					:= x"06" ; -- r
	constant BASE_TRIG_TriggerSelection : sub_Address 				:= x"12" ; -- r/w
	constant BASE_TRIG_SignalInShapeMode : sub_Address 			:= x"13" ; -- r/w
	constant BASE_TRIG_OsziAcquisionRunning : sub_Address 		:= x"14" ; -- r

	constant BASE_TRIG_DebugSignalsSelectionCh0 : sub_Address 		:= x"e1" ; -- r/w
	constant BASE_TRIG_DebugSignalsSelectionCh1 : sub_Address 		:= x"e2" ; -- r/w
	constant BASE_TRIG_DebugSignalsSelectionCh2 : sub_Address 		:= x"e3" ; -- r/w
	constant BASE_TRIG_DebugSignalsSelectionCh3 : sub_Address 		:= x"e4" ; -- r/w
	
	constant BASE_TRIG_VMERAMClearStart : sub_Address 				:= x"b1" ; -- w
	constant BASE_TRIG_ClockSpeedSelected : sub_Address 			:= x"b2" ; -- r/w
	
	constant BASE_TRIG_FIXED : sub_Address 							:= x"f0" ; -- r
	constant TRIG_FIXED_Master : std_logic_vector(31 downto 0)  := x"120827af"; -- 27.08.2012 V9

	constant ChCntWidth : integer := 32;
	constant AddrWidth : integer := 9;

	signal TriggerSelection : std_logic_vector(2 downto 0);
	signal DisarmTrigger : std_logic := '1';
	signal VMEAddrIn : std_logic_vector(AddrWidth-1 downto 0);
	signal SignalInShapeMode : std_logic_vector(1 downto 0);
	signal VMEDataOut : std_logic_vector(127 downto 0);
	signal ClockSpeedSelected : std_logic_vector(3 downto 0);
	signal clockOsziCounter : std_logic_vector(15 downto 0);
	signal clockOszi : std_logic;


	COMPONENT delay_by_shiftregister
		Generic (
			DELAY : integer
		);
	PORT(
		CLK : IN std_logic;
		SIG_IN : IN std_logic;          
		DELAY_OUT : OUT std_logic
		);
	END COMPONENT;
	
	component OsziRAM
		port (
		clka: IN std_logic;
		wea: IN std_logic_VECTOR(0 downto 0);
		addra: IN std_logic_VECTOR(AddrWidth-1 downto 0);
		dina: IN std_logic_VECTOR(ChCntWidth*4-1 downto 0);
		douta: OUT std_logic_VECTOR(ChCntWidth*4-1 downto 0);
		clkb: IN std_logic;
		web: IN std_logic_VECTOR(0 downto 0);
		addrb: IN std_logic_VECTOR(AddrWidth-1 downto 0);
		dinb: IN std_logic_VECTOR(ChCntWidth*4-1 downto 0);
		doutb: OUT std_logic_VECTOR(ChCntWidth*4-1 downto 0));
	end component;
	-- Synplicity black box declaration
	attribute syn_black_box : boolean;
	attribute syn_black_box of OsziRAM: component is true;

	constant NumberOfSignalsIn : integer := 4;
	signal SelectedSignals, SelectedSignals_0, SelectedSignals_1,
		PreSelectedSignals_LeadingEdge, PreSelectedSignals_FallingEdge,
		PreSelectedSignals, PreSelectedSignals_Delayed : std_logic_vector(NumberOfSignalsIn-1 downto 0);
	--
	signal SelectedTriggerIn, SelectedTriggerIn_0, SelectedTriggerIn_1 : std_logic;
	--
	signal Counter : std_logic_vector(AddrWidth downto 0);
	signal Counter_Clear, 
		SRCounter_0, SRCounter_1, SRCounter_2, SRCounter_3 : std_logic_vector(AddrWidth-1 downto 0);
	signal ResetOszi : std_logic;
	
	signal RAMDataOutA, RAMDataOutAAfterRAM, RAMDataOutA_AfterAddP0, RAMDataOutA_AfterAddP1, RAMDataOutA_AfterSelec : std_logic_vector(ChCntWidth*4-1 downto 0);
	
	signal RAMWEB : std_logic_vector(0 downto 0);
	signal RAMBAddr : std_logic_vector(AddrWidth-1 downto 0);
	signal RAMBData : std_logic_vector(ChCntWidth*4-1 downto 0);
	signal Inter_OsziAcquisionRunning : std_logic;


	--for clearance of ram
	component PreciseGateByCounter
		GENERIC (
			WIDTH : integer --in numbers of clock, max 2^22-1 (because of counter signal)
								-- total length: 5 = 8*clock
								-- total length: 3 = 6*clock
		);
    Port ( Input : in  STD_LOGIC;
           Output : out  STD_LOGIC; -- 20ns deadtime after pulse
			  DeadOut : out  STD_LOGIC; --during reset (20ns) is this signal = '1'
			  Inhibit : in std_logic; -- normal operation = '0'. Not sensitive to input edge if = '1' (inhibit)
           clock : in  STD_LOGIC);
	end component;
	signal VMERAMClearStart : std_logic;
	signal VMERAMClear : std_logic_vector(0 downto 0);
	
	
	-------------------------------------------------------
	signal DebugSignalsSelectionCh : std_logic_vector(8*NumberOfSignalsIn-1 downto 0);
	component DebugChSelector
    Port ( DebugSignalsIn : in  STD_LOGIC_VECTOR (255 downto 0);
           SelectedInput : in  STD_LOGIC_VECTOR (7 downto 0);
           SelectedOutput : out  STD_LOGIC);
	end component;


begin
	-- without Channel Selector
	--SelectedSignals <= SignalsIN;
	
	Inst_DebugChSelectors: for i in 0 to NumberOfSignalsIn-1 generate 
		Inst_DebugChSelector: DebugChSelector PORT MAP(
			DebugSignalsIn => SignalsIN,
			SelectedInput => DebugSignalsSelectionCh(i*8+7 downto i*8),
			SelectedOutput => SelectedSignals(i)
		);
	end generate;

	
	OsziAcquisionRunning <= Inter_OsziAcquisionRunning;
	
	------------------------------------------------
	--Delete RAM
	MyPreciseGateByCounter: PreciseGateByCounter	GENERIC MAP (WIDTH => 512*2 ) -- = 2^AddrWidth
    Port MAP ( Input => VMERAMClearStart,
           Output => VMERAMClear(0),
			  DeadOut => open,
			  Inhibit => '0',
           clock => clockOszi);
			  
	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			if VMERAMClear(0) = '0' then
				Counter_Clear <= (others => '0');
			else
				Counter_Clear <= Counter_Clear +1;
			end if;
		end if;
	end process;
	

	------------------------------------------------
	--Signal Shaping
	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			SelectedSignals_0 <= SelectedSignals;
			SelectedSignals_1 <= SelectedSignals_0;
		end if;
	end process;
	
	PreSignalShaper: for i in 0 to NumberOfSignalsIn-1 generate 
		PreSelectedSignals_LeadingEdge(i) <= '1' when (SelectedSignals_1(i)&SelectedSignals_0(i) = "01") else '0';
		PreSelectedSignals_FallingEdge(i) <= '1' when (SelectedSignals_1(i)&SelectedSignals_0(i) = "10") else '0';
	end generate;
	
	PreSelectedSignals <= PreSelectedSignals_LeadingEdge when SignalInShapeMode = "01" else
		PreSelectedSignals_FallingEdge when SignalInShapeMode = "10" else
		SelectedSignals_1;
	
	Delays: for i in 0 to NumberOfSignalsIn-1 generate 
		Inst_delay_by_shiftregister: delay_by_shiftregister GENERIC MAP ( DELAY => 100) --this delay defines the time period before the trigger
		PORT MAP(CLK => clockOszi, SIG_IN => PreSelectedSignals(i), DELAY_OUT => PreSelectedSignals_Delayed(i));
	end generate;
	
	Debug_Out(3 downto 0) <= PreSelectedSignals;
	
	-----------------------------------------------
	-- Trigger Selection
	SelectedTriggerIn <= SelectedSignals(0) when TriggerSelection = "000" else
		SelectedSignals(1) when TriggerSelection = "001" else
		SelectedSignals(2) when TriggerSelection = "010" else
		SelectedSignals(3) when TriggerSelection = "011" else
		not SelectedSignals(0) when TriggerSelection = "100" else
		not SelectedSignals(1) when TriggerSelection = "101" else
		not SelectedSignals(2) when TriggerSelection = "110" else
		not SelectedSignals(3) when TriggerSelection = "111";
	
	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			SelectedTriggerIn_0 <= SelectedTriggerIn;
			SelectedTriggerIn_1 <= SelectedTriggerIn_0;
		end if;
	end process;

	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			if (ResetOszi = '1') or (VMERAMClear(0) = '1') then
				Inter_OsziAcquisionRunning <= '0';
			elsif (DisarmTrigger = '0') and (SelectedTriggerIn_1&SelectedTriggerIn_0 = "01") then
				Inter_OsziAcquisionRunning <= '1';
			else
				Inter_OsziAcquisionRunning <= Inter_OsziAcquisionRunning;
			end if;
		end if;
	end process;
	Debug_Out(4) <= Inter_OsziAcquisionRunning;
	Debug_Out(5) <= ResetOszi;
	Debug_Out(6) <= VMERAMClear(0);
	Debug_Out(7) <= VMERAMClearStart;
	-----------------------------------------------

	-----------------------------------------------
	--Counter for Addr into RAM
	process (clockOszi)
	begin
		if rising_Edge(clockOszi) then
			if (Inter_OsziAcquisionRunning = '1') then
				Counter <= Counter +1;
			else
				Counter <= (others => '0');
			end if;
		end if;
	end process;
	
	ResetOszi <= Counter(AddrWidth);
	
	--Store the RAM addr for later after calculation
	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			SRCounter_0 <= Counter(AddrWidth-1 downto 0);
			SRCounter_1 <= SRCounter_0;
			SRCounter_2 <= SRCounter_1;
			SRCounter_3 <= SRCounter_2;
		end if;
	end process;
	
	My_OsziRAM : OsziRAM
		port map (
			clka => clockOszi,
			wea => "0",
			addra => Counter(AddrWidth-1 downto 0),
			dina => (others => '0'),
			douta => RAMDataOutA,
			clkb => clockOszi,
			web => RAMWEB,
			addrb => RAMBAddr,
			dinb => RAMBData,
			doutb => VMEDataOut);
			
	RAMWEB <= "1" when (Inter_OsziAcquisionRunning = '1') or (VMERAMClear(0) = '1') else "0";
	RAMBAddr <= Counter_Clear when (VMERAMClear(0) = '1') else
		SRCounter_3 when (Inter_OsziAcquisionRunning = '1') else 
		VMEAddrIn;
	RAMBData <= (others => '0') when VMERAMClear(0) = '1' else RAMDataOutA_AfterSelec;

	process(clockOszi)
	begin
		if rising_edge(clockOszi) then
			RAMDataOutAAfterRAM <= RAMDataOutA;
		end if;
	end process;
	
	--Add +1
	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			RAMDataOutA_AfterAddP0(ChCntWidth*1-1 downto ChCntWidth*0) <= RAMDataOutAAfterRAM(ChCntWidth*1-1 downto ChCntWidth*0);
			RAMDataOutA_AfterAddP1(ChCntWidth*1-1 downto ChCntWidth*0) <= RAMDataOutAAfterRAM(ChCntWidth*1-1 downto ChCntWidth*0) +1;

			RAMDataOutA_AfterAddP0(ChCntWidth*2-1 downto ChCntWidth*1) <= RAMDataOutAAfterRAM(ChCntWidth*2-1 downto ChCntWidth*1);
			RAMDataOutA_AfterAddP1(ChCntWidth*2-1 downto ChCntWidth*1) <= RAMDataOutAAfterRAM(ChCntWidth*2-1 downto ChCntWidth*1) +1;

			RAMDataOutA_AfterAddP0(ChCntWidth*3-1 downto ChCntWidth*2) <= RAMDataOutAAfterRAM(ChCntWidth*3-1 downto ChCntWidth*2);
			RAMDataOutA_AfterAddP1(ChCntWidth*3-1 downto ChCntWidth*2) <= RAMDataOutAAfterRAM(ChCntWidth*3-1 downto ChCntWidth*2) +1;

			RAMDataOutA_AfterAddP0(ChCntWidth*4-1 downto ChCntWidth*3) <= RAMDataOutAAfterRAM(ChCntWidth*4-1 downto ChCntWidth*3);
			RAMDataOutA_AfterAddP1(ChCntWidth*4-1 downto ChCntWidth*3) <= RAMDataOutAAfterRAM(ChCntWidth*4-1 downto ChCntWidth*3) +1;
		end if;
	end process;
	
	--look into delayed selected signals and contruct new data which goes into RAM
	process (clockOszi)
	begin
		if rising_edge(clockOszi) then
			if PreSelectedSignals_Delayed(0) = '1' then
				RAMDataOutA_AfterSelec(ChCntWidth*1-1 downto ChCntWidth*0) <= RAMDataOutA_AfterAddP1(ChCntWidth*1-1 downto ChCntWidth*0);
			else
				RAMDataOutA_AfterSelec(ChCntWidth*1-1 downto ChCntWidth*0) <= RAMDataOutA_AfterAddP0(ChCntWidth*1-1 downto ChCntWidth*0);
			end if;
			if PreSelectedSignals_Delayed(1) = '1' then
				RAMDataOutA_AfterSelec(ChCntWidth*2-1 downto ChCntWidth*1) <= RAMDataOutA_AfterAddP1(ChCntWidth*2-1 downto ChCntWidth*1);
			else
				RAMDataOutA_AfterSelec(ChCntWidth*2-1 downto ChCntWidth*1) <= RAMDataOutA_AfterAddP0(ChCntWidth*2-1 downto ChCntWidth*1);
			end if;
			if PreSelectedSignals_Delayed(2) = '1' then
				RAMDataOutA_AfterSelec(ChCntWidth*3-1 downto ChCntWidth*2) <= RAMDataOutA_AfterAddP1(ChCntWidth*3-1 downto ChCntWidth*2);
			else
				RAMDataOutA_AfterSelec(ChCntWidth*3-1 downto ChCntWidth*2) <= RAMDataOutA_AfterAddP0(ChCntWidth*3-1 downto ChCntWidth*2);
			end if;
			if PreSelectedSignals_Delayed(3) = '1' then
				RAMDataOutA_AfterSelec(ChCntWidth*4-1 downto ChCntWidth*3) <= RAMDataOutA_AfterAddP1(ChCntWidth*4-1 downto ChCntWidth*3);
			else
				RAMDataOutA_AfterSelec(ChCntWidth*4-1 downto ChCntWidth*3) <= RAMDataOutA_AfterAddP0(ChCntWidth*4-1 downto ChCntWidth*3);
			end if;
		end if;
	end process;
	
	
	---------------------------------------------------------------------------------------------------------	
	-- Select Clockspeed
	process (clock200)
	begin
		if rising_edge(clock200) then
			clockOsziCounter <= clockOsziCounter+1;
		end if;
	end process;
	clockOszi <= clock200 when ClockSpeedSelected = x"0" else
		clockOsziCounter(0) when ClockSpeedSelected = x"1" else
		clockOsziCounter(1) when ClockSpeedSelected = x"2" else
		clockOsziCounter(2) when ClockSpeedSelected = x"3" else
		clockOsziCounter(3) when ClockSpeedSelected = x"4" else
		clockOsziCounter(4) when ClockSpeedSelected = x"5" else
		clockOsziCounter(5) when ClockSpeedSelected = x"6" else
		clockOsziCounter(6) when ClockSpeedSelected = x"7" else
		clockOsziCounter(7) when ClockSpeedSelected = x"8" else
		clockOsziCounter(8) when ClockSpeedSelected = x"9" else
		clockOsziCounter(9) when ClockSpeedSelected = x"a" else
		clockOsziCounter(10) when ClockSpeedSelected = x"b" else
		clockOsziCounter(11) when ClockSpeedSelected = x"c" else
		clockOsziCounter(12) when ClockSpeedSelected = x"d" else
		clockOsziCounter(13) when ClockSpeedSelected = x"e" else
		clockOsziCounter(14) when ClockSpeedSelected = x"f";
	---------------------------------------------------------------------------------------------------------	
	
	---------------------------------------------------------------------------------------------------------	
	-- Code for VME handling / access
	-- handle read commands from vmebus
	---------------------------------------------------------------------------------------------------------	
	process(clock50, oecsr, u_ad_reg)
	begin
		if (clock50'event and clock50 = '1' and oecsr = '1') then
			u_data_o <= (others => '0');
				
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_DisarmTrigger) then u_data_o(0) <= DisarmTrigger; end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMBAddr) then u_data_o(AddrWidth-1 downto 0) <= VMEAddrIn; end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMBOut_0) then u_data_o(31 downto 0) <= VMEDataOut(32*1-1 downto 32*0); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMBOut_1) then u_data_o(31 downto 0) <= VMEDataOut(32*2-1 downto 32*1); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMBOut_2) then u_data_o(31 downto 0) <= VMEDataOut(32*3-1 downto 32*2); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMBOut_3) then u_data_o(31 downto 0) <= VMEDataOut(32*4-1 downto 32*3); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_TriggerSelection) then u_data_o(2 downto 0) <= TriggerSelection; end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_SignalInShapeMode) then u_data_o(1 downto 0) <= SignalInShapeMode; end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_OsziAcquisionRunning) then u_data_o(0) <= Inter_OsziAcquisionRunning; end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_ClockSpeedSelected) then u_data_o(3 downto 0) <= ClockSpeedSelected; end if;
			
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh0) then u_data_o(7 downto 0) <= DebugSignalsSelectionCh(7+8*0 downto 0+8*0); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh1) then u_data_o(7 downto 0) <= DebugSignalsSelectionCh(7+8*1 downto 0+8*1); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh2) then u_data_o(7 downto 0) <= DebugSignalsSelectionCh(7+8*2 downto 0+8*2); end if;
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh3) then u_data_o(7 downto 0) <= DebugSignalsSelectionCh(7+8*3 downto 0+8*3); end if;
			
			if (u_ad_reg(11 downto 4) =  BASE_TRIG_FIXED) then u_data_o(31 downto 0) <= TRIG_FIXED_Master; end if;
		end if;
	end process;

	---------------------------------------------------------------------------------------------------------	
	-- Code for VME handling / access
	-- decoder for data registers
	-- handle write commands from vmebus
	---------------------------------------------------------------------------------------------------------	
	process(clock50, ckcsr, u_ad_reg)
	begin
		if (clock50'event and clock50 = '1') then
			VMERAMClearStart <= '0';
			DisarmTrigger <= DisarmTrigger;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_DisarmTrigger) ) then DisarmTrigger <= u_dat_in(0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMBAddr) ) then VMEAddrIn <= u_dat_in(AddrWidth-1 downto 0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_TriggerSelection) ) then TriggerSelection <= u_dat_in(2 downto 0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_SignalInShapeMode) ) then SignalInShapeMode <= u_dat_in(1 downto 0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_VMERAMClearStart) ) then VMERAMClearStart <= u_dat_in(0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_ClockSpeedSelected) ) then ClockSpeedSelected <= u_dat_in(3 downto 0); end if;
			
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh0) ) then DebugSignalsSelectionCh(7+8*0 downto 0+8*0) <= u_dat_in(7 downto 0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh1) ) then DebugSignalsSelectionCh(7+8*1 downto 0+8*1) <= u_dat_in(7 downto 0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh2) ) then DebugSignalsSelectionCh(7+8*2 downto 0+8*2) <= u_dat_in(7 downto 0); end if;
			if ( (ckcsr = '1') and (u_ad_reg(11 downto 4) =  BASE_TRIG_DebugSignalsSelectionCh3) ) then DebugSignalsSelectionCh(7+8*3 downto 0+8*3) <= u_dat_in(7 downto 0); end if;

		end if;
	end process;

end Behavioral;

