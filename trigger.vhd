--changes
-- x1211213a: Ignose User Timing Constants = off
-- x1211213b: Changed Gate Width to GATEWIDTH= 61, 1x Failing Constraint!
-- x1211213c: Changed Gate Width to GATEWIDTH= 35, no Failing Constraints
	

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;																						
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use Package_CB_Configuration.ALL;

entity trigger is
	port (
		clock50 : in STD_LOGIC;
		clock100 : in STD_LOGIC;
		clock200 : in STD_LOGIC;
		clock400 : in STD_LOGIC; 
		trig_in : in STD_LOGIC_VECTOR (32*7-1 downto 0);		
		trig_out : out STD_LOGIC_VECTOR (32*1-1 downto 0);
		ToOsziAndScaler_out : out STD_LOGIC_VECTOR (32*8-1 downto 0);
		nim_in   : in  STD_LOGIC;
		nim_out  : out STD_LOGIC;
		led	     : out STD_LOGIC_VECTOR(8 downto 1); -- 8 LEDs onboard
		pgxled   : out STD_LOGIC_VECTOR(8 downto 1); -- 8 LEDs on PIG board
		Global_Reset_After_Power_Up : in std_logic;
		VN2andVN1 : in std_logic_vector(7 downto 0);
		-- VME interface ------------------------------------------------------
		u_ad_reg :in std_logic_vector(11 downto 2);
		u_dat_in :in std_logic_vector(31 downto 0);
		u_data_o :out std_logic_vector(31 downto 0);
		oecsr, ckcsr:in std_logic
	);
end trigger;


architecture RTL of trigger is


	--------------------------------------------
	-- Address reservation for VME
	--------------------------------------------
	subtype sub_Address is std_logic_vector(11 downto 4);
	
	constant BASE_TRIG_EnableInputs0 : sub_Address					:= x"50"; --r/w
	constant BASE_TRIG_EnableInputs1 : sub_Address					:= x"51"; --r/w
	constant BASE_TRIG_EnableInputs2 : sub_Address					:= x"52"; --r/w
	constant BASE_TRIG_EnableInputs3 : sub_Address					:= x"53"; --r/w
	constant BASE_TRIG_EnableInputs4 : sub_Address					:= x"54"; --r/w
	constant BASE_TRIG_EnableInputs5 : sub_Address					:= x"55"; --r/w
	constant BASE_TRIG_EnableInputs6 : sub_Address					:= x"56"; --r/w
	
	constant BASE_TRIG_FIXED : sub_Address 					:= x"f0" ; -- r
	constant TRIG_FIXED : std_logic_vector(31 downto 0) := x"1211213c"; 


	signal EnableInputs : STD_LOGIC_Vector(32*7-1 downto 0) := (others => '1');
	signal post_trig_in : std_logic_vector(32*7-1 downto 0);


	--------------------------------------------
	-- Components
	--------------------------------------------
	component InputStretcher 
		Generic (
			Duration : integer := 1
			);
		PORT (
			Clock : in STD_LOGIC;
			Input : in STD_LOGIC;
			Output : out STD_LOGIC
		);
	end component;
	
	component delay_by_shiftregister
		Generic (
			DELAY : integer
		);
		Port ( 
			CLK : in  STD_LOGIC;
			SIG_IN : in  STD_LOGIC;
			DELAY_OUT : out  STD_LOGIC
		);
	end component;
	
	component gate_by_shiftreg
		Generic (
			WIDTH : integer
		);
		 Port ( CLK : in STD_LOGIC;
				  SIG_IN : in  STD_LOGIC;
				  GATE_OUT : out  STD_LOGIC
		);
	end component;


	
	--------------------------------------------

	signal CB_AllOR, PID_AllOR, BaF_AllOR, TAPSVeto_AllOR : std_logic;

	--------------------------------------------


   constant NumberOfPhiBins : integer := 48;

	--undelayed (UD)
	signal FreePIDConverterInputs_UD : std_logic_vector(31 downto 24);
	signal PID_ModuleInputs_UD : std_logic_vector(23 downto 0);
	signal CB_ModuleInputs1_UD, CB_ModuleInputs2_UD, CB_ModuleInputs3_UD, CB_ModuleInputs4_UD, CB_ModuleInputs5_UD, CB_ModuleInputs6_UD : std_logic_vector(15 downto 0);
	signal BaF_ModuleInputs1_UD, BaF_ModuleInputs2_UD, BaF_ModuleInputs3_UD, BaF_ModuleInputs4_UD, BaF_ModuleInputs5_UD, BaF_ModuleInputs6_UD : std_logic_vector(7 downto 0);
	signal TAPSVeto_ModuleInputs1_UD, TAPSVeto_ModuleInputs2_UD, TAPSVeto_ModuleInputs3_UD, TAPSVeto_ModuleInputs4_UD, 
		TAPSVeto_ModuleInputs5_UD, TAPSVeto_ModuleInputs6_UD : std_logic_vector(7 downto 0);

	--delayed, so they all arrive at the same time
	signal FreePIDConverterInputs_D : std_logic_vector(31 downto 24);
	signal PID_ModuleInputs_D : std_logic_vector(23 downto 0);
	signal CB_ModuleInputs1_D, CB_ModuleInputs2_D, CB_ModuleInputs3_D, CB_ModuleInputs4_D, CB_ModuleInputs5_D, CB_ModuleInputs6_D : std_logic_vector(15 downto 0);
	signal BaF_ModuleInputs1_D, BaF_ModuleInputs2_D, BaF_ModuleInputs3_D, BaF_ModuleInputs4_D, BaF_ModuleInputs5_D, BaF_ModuleInputs6_D : std_logic_vector(7 downto 0);
	signal TAPSVeto_ModuleInputs1_D, TAPSVeto_ModuleInputs2_D, TAPSVeto_ModuleInputs3_D, TAPSVeto_ModuleInputs4_D, 
		TAPSVeto_ModuleInputs5_D, TAPSVeto_ModuleInputs6_D : std_logic_vector(7 downto 0);

	--delayed and gated
	constant GATEWIDTH : integer := 35; --in 5ns bins
	signal FreePIDConverterInputs_DG : std_logic_vector(31 downto 24);
	signal PID_ModuleInputs_DG : std_logic_vector(23 downto 0);
	signal CB_ModuleInputs1_DG, CB_ModuleInputs2_DG, CB_ModuleInputs3_DG, CB_ModuleInputs4_DG, CB_ModuleInputs5_DG, CB_ModuleInputs6_DG : std_logic_vector(15 downto 0);
	signal BaF_ModuleInputs1_DG, BaF_ModuleInputs2_DG, BaF_ModuleInputs3_DG, BaF_ModuleInputs4_DG, BaF_ModuleInputs5_DG, BaF_ModuleInputs6_DG : std_logic_vector(7 downto 0);
	signal TAPSVeto_ModuleInputs1_DG, TAPSVeto_ModuleInputs2_DG, TAPSVeto_ModuleInputs3_DG, TAPSVeto_ModuleInputs4_DG, 
		TAPSVeto_ModuleInputs5_DG, TAPSVeto_ModuleInputs6_DG : std_logic_vector(7 downto 0);


   signal CB_PhiAngle_Register, PID_PhiAngle_Register, BaF_PhiAngle_Register, TAPSVeto_PhiAngle_Register,
		Particle_PhiAngle_Register, ChargedParticle_PhiAngle_Register : std_logic_vector(NumberOfPhiBins-1 downto 0);
	
	--signals for coplanar trigger output
	signal PhiAngleTriggerOutput, PhiAngleChargeRequiredTriggerOutput : std_logic;
	signal PhiAngleTriggerOutput_Intermediate, PhiAngleChargeRequiredTriggerOutput_Intermediate : std_logic_vector(NumberOfPhiBins/2-1 downto 0);

begin
	------------------------------------------------------------------------------------------
	-- 0. Disable single Inputs
	------------------------------------------------------------------------------------------
	post_trig_in <= trig_in(32*7-1 downto 0) and EnableInputs;
	
	
	------------------------------------------------------------------------------------------------
	--should be PID ch0 = PID_ModuleInputs(0), etc.
	FreePIDConverterInputs_UD <= not (
		post_trig_in(0+32*6)&post_trig_in(2+32*6)&post_trig_in(4+32*6)&post_trig_in(6+32*6)&
		post_trig_in(8+32*6)&post_trig_in(10+32*6)&post_trig_in(12+32*6)&post_trig_in(14+32*6)
		);
		
	--Mixed up due to level converter
	PID_ModuleInputs_UD <= not (
		post_trig_in(30+32*6)&post_trig_in(28+32*6)&post_trig_in(26+32*6)&post_trig_in(24+32*6)& --ch 23,22,21,20
		post_trig_in(22+32*6)&post_trig_in(20+32*6)&post_trig_in(18+32*6)&post_trig_in(16+32*6)& --ch 19,18,17,16
		post_trig_in(31+32*6)&post_trig_in(29+32*6)&post_trig_in(27+32*6)&post_trig_in(25+32*6)& --ch 15,14,13,12
		post_trig_in(23+32*6)&post_trig_in(21+32*6)&post_trig_in(19+32*6)&post_trig_in(17+32*6)& --ch 11,10,9,8
		post_trig_in(15+32*6)&post_trig_in(13+32*6)&post_trig_in(11+32*6)&post_trig_in(9+32*6)& --ch 7,6,5,4
		post_trig_in(7+32*6)&post_trig_in(5+32*6)&post_trig_in(3+32*6)&post_trig_in(1+32*6) --ch 3,2,1,0
		);
	
	CB_ModuleInputs1_UD <= post_trig_in(15+16*0+32*3 downto 0+16*0+32*3); --Oszi Ch 6f..60
	CB_ModuleInputs2_UD <= post_trig_in(15+16*1+32*3 downto 0+16*1+32*3);
	CB_ModuleInputs3_UD <= post_trig_in(15+16*2+32*3 downto 0+16*2+32*3);
	CB_ModuleInputs4_UD <= post_trig_in(15+16*3+32*3 downto 0+16*3+32*3);
	CB_ModuleInputs5_UD <= post_trig_in(15+16*4+32*3 downto 0+16*4+32*3);
	CB_ModuleInputs6_UD <= post_trig_in(15+16*5+32*3 downto 0+16*5+32*3);
	
	BaF_ModuleInputs1_UD <= post_trig_in(7+16*0 downto 0+16*0); --phi bin 27..20
	BaF_ModuleInputs2_UD <= post_trig_in(7+16*1 downto 0+16*1); --phi bin 35..28
	BaF_ModuleInputs3_UD <= post_trig_in(7+16*2 downto 0+16*2); --phi bin 43..36
	BaF_ModuleInputs4_UD <= post_trig_in(7+16*3 downto 0+16*3); --phi bin 47..44 & 3..0
	BaF_ModuleInputs5_UD <= post_trig_in(7+16*4 downto 0+16*4); --phi bin 11..4
	BaF_ModuleInputs6_UD <= post_trig_in(7+16*5 downto 0+16*5); --phi bin 19..12

	TAPSVeto_ModuleInputs1_UD <= post_trig_in(15+16*0 downto 8+16*0); --Phi Alignment for TAPS Vetos identical with BaF2
	TAPSVeto_ModuleInputs2_UD <= post_trig_in(15+16*1 downto 8+16*1);
	TAPSVeto_ModuleInputs3_UD <= post_trig_in(15+16*2 downto 8+16*2);
	TAPSVeto_ModuleInputs4_UD <= post_trig_in(15+16*3 downto 8+16*3);
	TAPSVeto_ModuleInputs5_UD <= post_trig_in(15+16*4 downto 8+16*4);
	TAPSVeto_ModuleInputs6_UD <= post_trig_in(15+16*5 downto 8+16*5);
	
	
	------------------------------------------------------------------------------------------------
	-- Delay signals
	------------------------------------------------------------------------------------------------
	--PID Signals: Delay by 75ns
	Delay_PID_Signals: for i in 0 to 23 generate begin
		Delay_PID_Signal: delay_by_shiftregister 
			GENERIC MAP ( DELAY => 15 	)
			PORT MAP(
				CLK => clock200,
				SIG_IN => PID_ModuleInputs_UD(i),
				DELAY_OUT => PID_ModuleInputs_D(i)
		);
	end generate;

	--CB signals: no delay
	CB_ModuleInputs1_D <= CB_ModuleInputs1_UD;
	CB_ModuleInputs2_D <= CB_ModuleInputs2_UD;
	CB_ModuleInputs3_D <= CB_ModuleInputs3_UD;
	CB_ModuleInputs4_D <= CB_ModuleInputs4_UD;
	CB_ModuleInputs5_D <= CB_ModuleInputs5_UD;
	CB_ModuleInputs6_D <= CB_ModuleInputs6_UD;

	--TAPS BaF2 signals: delay by 148ns
	Delay_BaF_Signals: for i in 0 to 7 generate begin
		Delay_BaF_Signal_SectorA: delay_by_shiftregister GENERIC MAP ( DELAY => 27 )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs1_UD(i), DELAY_OUT => BaF_ModuleInputs1_D(i)  );
		Delay_BaF_Signal_SectorB: delay_by_shiftregister GENERIC MAP ( DELAY => 27 )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs2_UD(i), DELAY_OUT => BaF_ModuleInputs2_D(i)  );
		Delay_BaF_Signal_SectorC: delay_by_shiftregister GENERIC MAP ( DELAY => 27 )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs3_UD(i), DELAY_OUT => BaF_ModuleInputs3_D(i)  );
		Delay_BaF_Signal_SectorD: delay_by_shiftregister GENERIC MAP ( DELAY => 27 )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs4_UD(i), DELAY_OUT => BaF_ModuleInputs4_D(i)  );
		Delay_BaF_Signal_SectorE: delay_by_shiftregister GENERIC MAP ( DELAY => 27 )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs5_UD(i), DELAY_OUT => BaF_ModuleInputs5_D(i)  );
		Delay_BaF_Signal_SectorF: delay_by_shiftregister GENERIC MAP ( DELAY => 27 )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs6_UD(i), DELAY_OUT => BaF_ModuleInputs6_D(i)  );
	end generate;

	--TAPS Veto signals: delay by 136ns
	Delay_TAPSVeto_Signals: for i in 0 to 7 generate begin
		Delay_TAPSVeto_Signal_SectorA: delay_by_shiftregister GENERIC MAP ( DELAY => 30 )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs1_UD(i), DELAY_OUT => TAPSVeto_ModuleInputs1_D(i)  );
		Delay_TAPSVeto_Signal_SectorB: delay_by_shiftregister GENERIC MAP ( DELAY => 30 )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs2_UD(i), DELAY_OUT => TAPSVeto_ModuleInputs2_D(i)  );
		Delay_TAPSVeto_Signal_SectorC: delay_by_shiftregister GENERIC MAP ( DELAY => 30 )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs3_UD(i), DELAY_OUT => TAPSVeto_ModuleInputs3_D(i)  );
		Delay_TAPSVeto_Signal_SectorD: delay_by_shiftregister GENERIC MAP ( DELAY => 30 )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs4_UD(i), DELAY_OUT => TAPSVeto_ModuleInputs4_D(i)  );
		Delay_TAPSVeto_Signal_SectorE: delay_by_shiftregister GENERIC MAP ( DELAY => 30 )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs5_UD(i), DELAY_OUT => TAPSVeto_ModuleInputs5_D(i)  );
		Delay_TAPSVeto_Signal_SectorF: delay_by_shiftregister GENERIC MAP ( DELAY => 30 )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs6_UD(i), DELAY_OUT => TAPSVeto_ModuleInputs6_D(i)  );
	end generate;
	------------------------------------------------------------------------------------------------

	------------------------------------------------------------------------------------------------
	-- GateGen for Signals
	------------------------------------------------------------------------------------------------
	--PID Signals
	GateGen_PID_Signals: for i in 0 to 23 generate begin
		GateGen_PID_Signal: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH 	)
			PORT MAP( CLK => clock200, SIG_IN => PID_ModuleInputs_D(i), GATE_OUT => PID_ModuleInputs_DG(i)   );
	end generate;

	--CB signals
	GateGen_CB_Signals: for i in 0 to 15 generate begin
		GateGen_CB_Signal_SectorA: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => CB_ModuleInputs1_D(i), GATE_OUT => CB_ModuleInputs1_DG(i)  );
		GateGen_CB_Signal_SectorB: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => CB_ModuleInputs2_D(i), GATE_OUT => CB_ModuleInputs2_DG(i)  );
		GateGen_CB_Signal_SectorC: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => CB_ModuleInputs3_D(i), GATE_OUT => CB_ModuleInputs3_DG(i)  );
		GateGen_CB_Signal_SectorD: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => CB_ModuleInputs4_D(i), GATE_OUT => CB_ModuleInputs4_DG(i)  );
		GateGen_CB_Signal_SectorE: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => CB_ModuleInputs5_D(i), GATE_OUT => CB_ModuleInputs5_DG(i)  );
		GateGen_CB_Signal_SectorF: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => CB_ModuleInputs6_D(i), GATE_OUT => CB_ModuleInputs6_DG(i)  );
	end generate;

	--TAPS BaF2 signals
	GateGen_BaF_Signals: for i in 0 to 7 generate begin
		GateGen_BaF_Signal_SectorA: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs1_D(i), GATE_OUT => BaF_ModuleInputs1_DG(i)  );
		GateGen_BaF_Signal_SectorB: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs2_D(i), GATE_OUT => BaF_ModuleInputs2_DG(i)  );
		GateGen_BaF_Signal_SectorC: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs3_D(i), GATE_OUT => BaF_ModuleInputs3_DG(i)  );
		GateGen_BaF_Signal_SectorD: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs4_D(i), GATE_OUT => BaF_ModuleInputs4_DG(i)  );
		GateGen_BaF_Signal_SectorE: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs5_D(i), GATE_OUT => BaF_ModuleInputs5_DG(i)  );
		GateGen_BaF_Signal_SectorF: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => BaF_ModuleInputs6_D(i), GATE_OUT => BaF_ModuleInputs6_DG(i)  );
	end generate;

	--TAPS Veto signals
	GateGen_TAPSVeto_Signals: for i in 0 to 7 generate begin
		GateGen_TAPSVeto_Signal_SectorA: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs1_D(i), GATE_OUT => TAPSVeto_ModuleInputs1_DG(i)  );
		GateGen_TAPSVeto_Signal_SectorB: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs2_D(i), GATE_OUT => TAPSVeto_ModuleInputs2_DG(i)  );
		GateGen_TAPSVeto_Signal_SectorC: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs3_D(i), GATE_OUT => TAPSVeto_ModuleInputs3_DG(i)  );
		GateGen_TAPSVeto_Signal_SectorD: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs4_D(i), GATE_OUT => TAPSVeto_ModuleInputs4_DG(i)  );
		GateGen_TAPSVeto_Signal_SectorE: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs5_D(i), GATE_OUT => TAPSVeto_ModuleInputs5_DG(i)  );
		GateGen_TAPSVeto_Signal_SectorF: gate_by_shiftreg GENERIC MAP ( WIDTH => GATEWIDTH )
			PORT MAP( CLK => clock200, SIG_IN => TAPSVeto_ModuleInputs6_D(i), GATE_OUT => TAPSVeto_ModuleInputs6_DG(i)  );
	end generate;
	------------------------------------------------------------------------------------------------


	
	------------------------------------------------------------------------------------------------
	ToOsziAndScaler_out(8*6-1 downto 0) <= BaF_ModuleInputs6_DG&BaF_ModuleInputs5_DG&BaF_ModuleInputs4_DG&BaF_ModuleInputs3_DG&BaF_ModuleInputs2_DG&BaF_ModuleInputs1_DG;
	ToOsziAndScaler_out(8*12-1 downto 8*6) <= TAPSVeto_ModuleInputs6_DG&TAPSVeto_ModuleInputs5_DG&TAPSVeto_ModuleInputs4_DG&TAPSVeto_ModuleInputs3_DG&TAPSVeto_ModuleInputs2_DG&TAPSVeto_ModuleInputs1_DG;
	ToOsziAndScaler_out(16*6-1+8*12 downto 8*12) <= CB_ModuleInputs6_DG&CB_ModuleInputs5_DG&CB_ModuleInputs4_DG&CB_ModuleInputs3_DG&CB_ModuleInputs2_DG&CB_ModuleInputs1_DG;
	ToOsziAndScaler_out(192+31 downto 192) <= FreePIDConverterInputs_DG&PID_ModuleInputs_DG;
	------------------------------------------------------------------------------------------------
	
	------------------------------------------------------------------------------------------------
	-- All ORs
	------------------------------------------------------------------------------------------------
	CB_AllOR <= '1' when (CB_ModuleInputs1_DG&CB_ModuleInputs2_DG&CB_ModuleInputs3_DG&CB_ModuleInputs4_DG&CB_ModuleInputs5_DG&CB_ModuleInputs6_DG) /= "0" else '0';
	PID_AllOR <= '1' when PID_ModuleInputs_DG /= "0" else '0';
	BaF_AllOR <= '1' when (BaF_ModuleInputs1_DG&BaF_ModuleInputs2_DG&BaF_ModuleInputs3_DG&BaF_ModuleInputs4_DG&BaF_ModuleInputs5_DG&BaF_ModuleInputs6_DG) /= "0" else '0';
	TAPSVeto_AllOR <= '1' when (TAPSVeto_ModuleInputs1_DG&TAPSVeto_ModuleInputs2_DG&TAPSVeto_ModuleInputs3_DG&TAPSVeto_ModuleInputs4_DG&TAPSVeto_ModuleInputs5_DG&TAPSVeto_ModuleInputs6_DG) /= "0" else '0';
	------------------------------------------------------------------------------------------------
	
	------------------------------------------------------------------------------------------------
	-- Lines from input selectors
	------------------------------------------------------------------------------------------------
	   --			Modul 1	Modul 2	Modul 3	Modul 4	Modul 5		Modul 6
		--			47,0-14	6-21		17-32		23-38		0-5 + 38-47	13+32-42
		--		1	13			1			49			77			9				45
		--		2	21			85			57			51			15				5
		--		3	31			37			67			65			23				17
		--		4	3			79			75			87			27				11
		--		5	39			73			81			83			29				35
		--		6	7			55			63			71			33	
		--		7	25			61			69			89			41	
		--		8	19			43			59			53			47	

		--		PhiAngleSectionOut <= 
		--		CrystalsQuantAzimutIfModule1(47)&CrystalsQuantAzimutIfModule1(14 downto 0) when VN2andVN1 = x"e1" else --Module 1
		--	   CrystalsQuantAzimutIfModule2(21 downto 6) when VN2andVN1 = x"e2" else --Module 2
		--	   CrystalsQuantAzimutIfModule3(32 downto 17) when VN2andVN1 = x"e3" else --Module 3
		--	   CrystalsQuantAzimutIfModule4(38 downto 23) when VN2andVN1 = x"e4" else --Module 4
		--	   CrystalsQuantAzimutIfModule5(47 downto 38)&CrystalsQuantAzimutIfModule5(5 downto 0) when VN2andVN1 = x"e5" else --Module 5
		--	   CrystalsQuantAzimutIfModule6(42 downto 32)&CrystalsQuantAzimutIfModule6(13)&"0000" when VN2andVN1 = x"e6" else --Module 6
		--	   (others => '0'); --if wrong VMEAddress
	------------------------------------------------------------------------------------------------

	--Start:  This needs to be checked. Probably the level converter mixed it up.
	PID_PhiAngle_Register <=    --This needs to be checked. Probably the level converter mixed it up.
		(0 => PID_ModuleInputs_DG(0),	1 => PID_ModuleInputs_DG(0), 	2 => PID_ModuleInputs_DG(1),   3 => PID_ModuleInputs_DG(1),  
		4 => PID_ModuleInputs_DG(2),   5 => PID_ModuleInputs_DG(2),  	6 => PID_ModuleInputs_DG(3),   7 => PID_ModuleInputs_DG(3), 
		8 => PID_ModuleInputs_DG(4),   9 => PID_ModuleInputs_DG(4),  	10 => PID_ModuleInputs_DG(5),  11 => PID_ModuleInputs_DG(5), 
		12 => PID_ModuleInputs_DG(6),  13 => PID_ModuleInputs_DG(6), 	14 => PID_ModuleInputs_DG(7),  15 => PID_ModuleInputs_DG(7), 
		16 => PID_ModuleInputs_DG(8),  17 => PID_ModuleInputs_DG(8), 	18 => PID_ModuleInputs_DG(9),  19 => PID_ModuleInputs_DG(9), 
		20 => PID_ModuleInputs_DG(10), 21 => PID_ModuleInputs_DG(10),	22 => PID_ModuleInputs_DG(11), 23 => PID_ModuleInputs_DG(11), 
		24 => PID_ModuleInputs_DG(12), 25 => PID_ModuleInputs_DG(12),	26 => PID_ModuleInputs_DG(13), 27 => PID_ModuleInputs_DG(13), 
		28 => PID_ModuleInputs_DG(14), 29 => PID_ModuleInputs_DG(14),	30 => PID_ModuleInputs_DG(15), 31 => PID_ModuleInputs_DG(15), 
		32 => PID_ModuleInputs_DG(16), 33 => PID_ModuleInputs_DG(16),	34 => PID_ModuleInputs_DG(17), 35 => PID_ModuleInputs_DG(17), 
		36 => PID_ModuleInputs_DG(18), 37 => PID_ModuleInputs_DG(18),	38 => PID_ModuleInputs_DG(19), 39 => PID_ModuleInputs_DG(19), 
		40 => PID_ModuleInputs_DG(20), 41 => PID_ModuleInputs_DG(20),	42 => PID_ModuleInputs_DG(21), 43 => PID_ModuleInputs_DG(21), 
		44 => PID_ModuleInputs_DG(22), 45 => PID_ModuleInputs_DG(22),	46 => PID_ModuleInputs_DG(23), 47 => PID_ModuleInputs_DG(23) ) ;
	--End: This needs to be checked. Probably the level converter mixed it up.

	CB_PhiAngle_Register <= 
		(CB_ModuleInputs1_DG(15) & "00000000000000000000000000000000" & CB_ModuleInputs1_DG(14 downto 0) ) or  --Module 1
		( "00000000000000000000000000" & CB_ModuleInputs2_DG & "000000" ) or --Module 2
		( "000000000000000" & CB_ModuleInputs3_DG & "00000000000000000" ) or --Module 3
		( "000000000" & CB_ModuleInputs4_DG & "00000000000000000000000" ) or --Module 4
		( CB_ModuleInputs5_DG(15 downto 6) & "00000000000000000000000000000000" & CB_ModuleInputs5_DG(5 downto 0) ) or --Module 5
		( "00000" & CB_ModuleInputs6_DG(15 downto 5) & "000000000000000000" & CB_ModuleInputs6_DG(4) & "0000000000000" ); --Module 6
	
	
	------------------------------------------------------------------------------------------------
	-- From TAPS BaF Sector
	------------------------------------------------------------------------------------------------
		--		SB <= LED1_Signals;
		--	--Sector A
		--	LED_Coplanar_Signals_SectorA(0) <= SB(03) or SB(06) or SB(10) or SB(15) or SB(21) or SB(28) or SB(29) or SB(36) or SB(37) or SB(45) or SB(46) or SB(55); --bin 20
		--	LED_Coplanar_Signals_SectorA(1) <= SB(07) or SB(11) or SB(16) or SB(22) or SB(30) or SB(38) or SB(47) or SB(56); --bin 21
		--	LED_Coplanar_Signals_SectorA(2) <= SB(04) or SB(17) or SB(23) or SB(31) or SB(39) or SB(48) or SB(57) or SB(58); --bin 22
		--	LED_Coplanar_Signals_SectorA(3) <= SB(12) or SB(24) or SB(40) or SB(49) or SB(59); --bin 23
		--	LED_Coplanar_Signals_SectorA(4) <= SB(08) or SB(13) or SB(18) or SB(25) or SB(32) or SB(41) or SB(50) or SB(51) or SB(60); --bin 24
		--	LED_Coplanar_Signals_SectorA(5) <= SB(05) or SB(19) or SB(26) or SB(33) or SB(42) or SB(52) or SB(61) or SB(62); --bin 25
		--	LED_Coplanar_Signals_SectorA(6) <= SB(09) or SB(14) or SB(20) or SB(27) or SB(34) or SB(43) or SB(53) or SB(63); --bin 26
		--	LED_Coplanar_Signals_SectorA(7) <= SB(35) or SB(44) or SB(54); --bin 27
	------------------------------------------------------------------------------------------------

	--module 1: phi bin 27..20,        module 2: phi bin 35..28, module 3: phi bin 43..36
	--module 4: phi bin 3..0 & 47..44, module 5: phi bin 11..4,  module 6: phi bin 19..12
	BaF_PhiAngle_Register <= BaF_ModuleInputs4_DG(3 downto 0) & BaF_ModuleInputs3_DG & BaF_ModuleInputs2_DG & 
		BaF_ModuleInputs1_DG & BaF_ModuleInputs6_DG & BaF_ModuleInputs5_DG & BaF_ModuleInputs4_DG(7 downto 4);

		
	TAPSVeto_PhiAngle_Register <= TAPSVeto_ModuleInputs4_DG(3 downto 0) & TAPSVeto_ModuleInputs3_DG & TAPSVeto_ModuleInputs2_DG & 
		TAPSVeto_ModuleInputs1_DG & TAPSVeto_ModuleInputs6_DG & TAPSVeto_ModuleInputs5_DG & TAPSVeto_ModuleInputs4_DG(7 downto 4);
	
	------------------------------------------------------------------------------------------------
	
	
	------------------------------------------------------------------------------------------------
	-- Combine different detectors
	------------------------------------------------------------------------------------------------
	Particle_PhiAngle_Register <= BaF_PhiAngle_Register or CB_PhiAngle_Register;
	ChargedParticle_PhiAngle_Register <= TAPSVeto_PhiAngle_Register or PID_PhiAngle_Register;
	------------------------------------------------------------------------------------------------
	
	
	------------------------------------------------------------------------------------------------
	-- LEDs
	------------------------------------------------------------------------------------------------
	led(1) <= '0';
	led(2) <= '1' when trig_in(31 downto 0) /= "0" else '0';
	led(3) <= '0';
	led(4) <= '1' when trig_in(31+32*1 downto 0+32*1) /= "0" else '0';
	led(5) <= '0';
	led(6) <= '1' when trig_in(31+32*2 downto 0+32*2) /= "0" else '0';
	led(7) <= '0';
	led(8) <= '0';
	pgxled(1) <= '0';
	pgxled(2) <= '1' when trig_in(31+32*3 downto 0+32*3) /= "0" else '0';
	pgxled(3) <= '0';
	pgxled(4) <= '1' when trig_in(31+32*4 downto 0+32*4) /= "0" else '0';
	pgxled(5) <= '0';
	pgxled(6) <= '1' when trig_in(31+32*5 downto 0+32*5) /= "0" else '0';
	pgxled(7) <= '0';
	pgxled(8) <= '1' when trig_in(31+32*6 downto 0+32*6) /= "0" else '0';
	------------------------------------------------------------------------------------------------
	
	
	------------------------------------------------------------------------------------------------
	-- Generate Coplanarity Trigger
	------------------------------------------------------------------------------------------------
	
	-------------------------------------
	-- Step 1: Form individual pairs
	-- look only for particles (CB and BaF)
	CalculatePhiAngleTriggerOutput_Intermediate: for i in 0 to NumberOfPhiBins/2-1 generate begin -- for 0 to 23
			PhiAngleTriggerOutput_Intermediate(i) <= 
				Particle_PhiAngle_Register(i) and 
				(
					Particle_PhiAngle_Register(i+24-1) or 
					Particle_PhiAngle_Register(i+24) or 
					Particle_PhiAngle_Register((i+24+1) mod NumberOfPhiBins) 
				);
		end generate;
		
	-- look for particles from CB and BaF and require min. one charged hit in PID or Veto
	CalculatePhiAngleChargeRequiredTriggerOutput_Intermediate: for i in 0 to NumberOfPhiBins/2-1 generate begin -- for 0 to 23
			PhiAngleChargeRequiredTriggerOutput_Intermediate(i) <= 
				PhiAngleTriggerOutput_Intermediate(i) and 
				( 
					ChargedParticle_PhiAngle_Register(i) or 
					ChargedParticle_PhiAngle_Register(i+24-1) or 
					ChargedParticle_PhiAngle_Register(i+24) or 
					ChargedParticle_PhiAngle_Register((i+24+1) mod NumberOfPhiBins)
				);
		end generate;
	

	-- Step 2 for coplanarity: Make a big OR of all pairs
	-- particles
	PhiAngleTriggerOutput <= '1' when PhiAngleTriggerOutput_Intermediate /= "0" else '0';
	-- with charge
	PhiAngleChargeRequiredTriggerOutput <= '1' when PhiAngleChargeRequiredTriggerOutput_Intermediate /= "0" else '0';
	
	trig_out(0) <= PhiAngleTriggerOutput; --Oszi Ch: 224, 0xe0
	trig_out(1) <= PhiAngleChargeRequiredTriggerOutput; --Oszi Ch: 225, 0xe1
	trig_out(2) <= CB_AllOR; --Oszi Ch: 226, 0xe2
	trig_out(3) <= PID_AllOR; --Oszi Ch: 227, 0xe3
	trig_out(4) <= BaF_AllOR; --Oszi Ch: 228, 0xe4
	trig_out(5) <= TAPSVeto_AllOR; --Oszi Ch: 229, 0xe5
	
	ToOsziAndScaler_out(224+0) <= PhiAngleTriggerOutput; --Oszi Ch: 224, 0xe0
	ToOsziAndScaler_out(224+1) <= PhiAngleChargeRequiredTriggerOutput; --Oszi Ch: 225, 0xe1
	ToOsziAndScaler_out(224+2) <= CB_AllOR; --Oszi Ch: 226, 0xe2
	ToOsziAndScaler_out(224+3) <= PID_AllOR; --Oszi Ch: 227, 0xe3
	ToOsziAndScaler_out(224+4) <= BaF_AllOR; --Oszi Ch: 228, 0xe4
	ToOsziAndScaler_out(224+5) <= TAPSVeto_AllOR; --Oszi Ch: 229, 0xe5
	 

--	------------------------------------------------------------------------------------------------
--	-- Lengthen the selected SimpleLogic Trigger, so it can be used
--	------------------------------------------------------------------------------------------------
--
--	SimpleLogicStretcher: InputStretcher generic map (Duration => 6) --Lengthen signal by 10ns*2^6 = 640ns
--		PORT map(clock100, InterSimpleLogicTrigger, InterSimpleLogicTrigger_Stretched);
--	SimpleLogicStretcher_Short: InputStretcher generic map (Duration => 2) --Lengthen signal by 10ns*2^2 = 40ns
--		PORT map(clock100, InterSimpleLogicTrigger, InterSimpleLogicTrigger_StretchedShort);
--	nim_out <= InterSimpleLogicTrigger_StretchedShort; --signal must be shorter than Sender FSM needs for one complete cycle
--	------------------------------------------------------------------------------------------------
--


	
	---------------------------------------------------------------------------------------------------------	
	-- Code for VME handling / access
	-- decoder for data registers
	-- handle write commands from vmebus
	---------------------------------------------------------------------------------------------------------	
	process(clock50, ckcsr, u_ad_reg)
	begin
		if (clock50'event and clock50 ='1') then
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs0  ) then
				EnableInputs(32*1-1 downto 32*0) <= u_dat_in;
			end if;
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs1  ) then
				EnableInputs(32*2-1 downto 32*1) <= u_dat_in;
			end if;
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs2  ) then
				EnableInputs(32*3-1 downto 32*2) <= u_dat_in;
			end if;
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs3  ) then
				EnableInputs(32*4-1 downto 32*3) <= u_dat_in;
			end if;
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs4  ) then
				EnableInputs(32*5-1 downto 32*4) <= u_dat_in;
			end if;
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs5  ) then
				EnableInputs(32*6-1 downto 32*5) <= u_dat_in;
			end if;
			if (ckcsr='1' and u_ad_reg(11 downto 4)= BASE_TRIG_EnableInputs6  ) then
				EnableInputs(32*7-1 downto 32*6) <= u_dat_in;
			end if;
	
		end if;
	end process;
	

	---------------------------------------------------------------------------------------------------------	
	-- Code for VME handling / access
	-- handle read commands from vmebus
	---------------------------------------------------------------------------------------------------------	
	process(clock50, oecsr, u_ad_reg)
	begin
		if (clock50'event and clock50 ='1') then
			if (oecsr ='1') then
				u_data_o(31 downto 0) <= (others => '0');
				case u_ad_reg(11 downto 4) is
					when BASE_TRIG_FIXED => 
						u_data_o(31 downto 0) <= TRIG_FIXED;
					when BASE_TRIG_EnableInputs0 =>
						u_data_o(31 downto 0) <= EnableInputs(31 downto 0);
					when BASE_TRIG_EnableInputs1 =>
						u_data_o(31 downto 0) <= EnableInputs(31+32*1 downto 0+32*1);
					when BASE_TRIG_EnableInputs2 =>
						u_data_o(31 downto 0) <= EnableInputs(31+32*2 downto 0+32*2);
					when BASE_TRIG_EnableInputs3 =>
						u_data_o(31 downto 0) <= EnableInputs(31+32*3 downto 0+32*3);
					when BASE_TRIG_EnableInputs4 =>
						u_data_o(31 downto 0) <= EnableInputs(31+32*4 downto 0+32*4);
					when BASE_TRIG_EnableInputs5 =>
						u_data_o(31 downto 0) <= EnableInputs(31+32*5 downto 0+32*5);
					when BASE_TRIG_EnableInputs6 =>
						u_data_o(31 downto 0) <= EnableInputs(31+32*6 downto 0+32*6);
					when others => 
						u_data_o(31 downto 0) <= (others => '0');
				end case;
			end if;
		end if;
	end process;

end RTL;