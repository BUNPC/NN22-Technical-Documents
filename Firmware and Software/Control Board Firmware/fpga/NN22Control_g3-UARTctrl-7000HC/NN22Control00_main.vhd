-- Firmware for NN22_ControlBoard00
-- Main unit

-- Initial version: 2022-12-23
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
--library MACHXO2;
--use MACHXO2.components.all;

entity NN22Control_main is
	port(
		ClkxCI				: in std_logic;
		ResetxRI			: in std_logic;
		
		-- Detector boards
		UartDetBtoFPGAxDI 	: in std_logic_vector(24 downto 0);
		UartFPGAtoDetBxDO 	: out std_logic_vector(4 downto 0);
		DetBSelectxSO 		: out std_logic_vector(24 downto 0);
		DetBRunxSO 			: out std_logic_vector(3 downto 0);
		DetBStatusSelectxSO	: out std_logic;
		DetBTriggerxSO 		: out std_logic;
		DetBEndCycxSO		: out std_logic;
		
		-- Source boards
		SrcColxDO 			: out std_logic_vector(13 downto 0);
		SrcRowxDO 			: out std_logic_vector(2 downto 0);
		SrcPwrxDO			: out std_logic_vector(2 downto 0);
		
		-- Auxiliary ADCs
		AuxCSnxSO			: out std_logic;
		AuxSCKxSO			: out std_logic;
		AuxSDOxDI			: in std_logic_vector(1 downto 0);
				
		-- FTDI UART USB interface
		UartFPGAtoFTDIxDO	: out std_logic;
		UartFTDItoFPGAxDI	: in std_logic;
		UartCTSntoFTDIxDO	: out std_logic;
		UartRTSntoFPGAxDI	: in std_logic;
		
		-- SPI Raspberry Pi 0 interface
		SpiRPi0SCKxSI		: in std_logic;
		SpiRPi0CSnxSI		: in std_logic;
		SpiRPi0MISOxDO		: out std_logic;
		
		-- SPI for APS6404L PSRAM
		RamCSnxSO			: out std_logic;
		RamMISOxDI 			: in std_logic;
		RamMOSIxDO 			: out std_logic;
		RamSCKxSO			: out std_logic;
	
		-- Misc
		AccRunIndxSO		: out std_logic;
		ExpJ303xDO			: out std_logic_vector(3 downto 0);
		TrgxDI				: in std_logic_vector(3 downto 0);
		AuxIOxSI			: in std_logic_vector(1 downto 0);
		FpLEDxSO			: out std_logic_vector(1 downto 0);
		V5P1B01enxSO		: out std_logic;
		V5P1B23enxSO		: out std_logic;
		V5P1RPienxSO		: out std_logic;
		V5P1srcenxSO		: out std_logic;
		V9P0enxSO			: out std_logic;
		VN22enxSO			: out std_logic;
		VN3P4enxSO			: out std_logic;
		VN22_CLKaxSO		: out std_logic;
		VN22_CLKbxSO		: out std_logic
	);
end NN22Control_main;

architecture NN22Control_main_behavior of NN22Control_main is

	-- config FSM related
	constant N_CMD_BYTES : integer := 6;
	type CfgFSMSReg_type is array (0 to N_CMD_BYTES-1) of std_logic_vector(7 downto 0);
	signal CfgFSMSRegxDP, CfgFSMSRegxDN : CfgFSMSReg_type;
	signal CfgFSMSRegOutxD : std_logic_vector(7 downto 0);
	type cfgfsmstate_type is (sIdle, sRxBytes, sDecodeCmd, sTxHeader, sLoadBytes, sTxBytes);
	signal CfgStatexDP, CfgStatexDN : cfgfsmstate_type;
	signal CfgUartRxDatxD : std_logic_vector(7 downto 0);
	signal CfgUartRxDatRdyxS : std_logic;
	signal CfgByteCntxDP, CfgByteCntxDN : integer range 0 to N_CMD_BYTES-1;
	signal CfgWrEnxS : std_logic;
	signal CfgRamAWrEnxS : std_logic;
	signal CfgRamBWrEnxS : std_logic;
	signal CfgRamAOutxD : std_logic_vector(26 downto 0);
	signal CfgRamBOutxD : std_logic_vector(17 downto 0);
	signal CfgOutRdyxDP, CfgOutRdyxDN : std_logic;
	signal CfgOutRdySetxS, CfgOutRdyClrxS : std_logic;
	
	-- main status register related
	signal MainStatRegxDP, MainStatRegxDN : std_logic_vector(23 downto 0);
	signal MainStatRegWrEnxS : std_logic;
	signal RunxS : std_logic;
	
	-- acquisition FSM / MUX related
	signal ParDatfromMuxxD : std_logic_vector(7 downto 0);
	signal ParDatfromMuxRdyxS : std_logic;
	signal DetBSelectxSP, DetBSelectxSN : std_logic_vector(DetBSelectxSO'range);
	
	signal UartDetBtoFPGAxDP, UartDetBtoFPGAxDN : std_logic_vector(UartDetBtoFPGAxDI'range);
	signal UartDetBtoFPGASelxD : std_logic;
	signal UartDetBRxDatxD : std_logic_vector(7 downto 0);
	signal UartDetBRxDatRdySetxS : std_logic;
	signal UartDetBRxDatRdyClrxS : std_logic;
	signal UartDetBRxDatRdyxSP, UartDetBRxDatRdyxSN : std_logic;
	
	-- PSRAM external buffer / UART to FTDI related
	signal UartTxDatxD : std_logic_vector(7 downto 0);
	signal UartTxDatRdyxS : std_logic;
	signal UartBuffEmptyxS : std_logic;
	signal UartBuffFullxS : std_logic;
	signal ResetExtRamxS : std_logic;
	
	-- auxiliary input related
	signal AuxDataxD : std_logic_vector(7 downto 0); 
	signal AuxDataRdyxS : std_logic; 
	signal AuxDataAckxS : std_logic; 
	signal AuxTxTrgxS : std_logic;
	
	-- program counters related
	signal RamAEndxS : std_logic;
	signal RamBEndxS : std_logic;
	signal SrcPwrPrexD : std_logic_vector(SrcPwrxDO'range);
	
	signal DetBSelectIxD : std_logic_vector(4 downto 0);
	signal DetBRxEnxS : std_logic;
	
	signal PCntAxDP, PCntAxDN : unsigned(9 downto 0);
	signal PCntBxDP, PCntBxDN : unsigned(9 downto 0);
	signal ClkCntxDP, ClkCntxDN : unsigned(10 downto 0);
	
	-- program counter B transmit FSM
	type PcntTxSReg_type is array (0 to 1) of std_logic_vector(7 downto 0);
	signal PcntTxSRegxDP, PcntTxSRegxDN : PcntTxSReg_type;
	type pcnttxfsmstate_type is (sIdle, sTxHeader, sTxB1, sTxB0, sWait);
	signal PcntTxStatexDP, PcntTxStatexDN : pcnttxfsmstate_type;
	
	signal PCntTxTrgxS : std_logic;
	signal PcntTxDatxD : std_logic_vector(7 downto 0);
	signal PCntTxDatRdyxS : std_logic;
	signal PCntTxDatAckxS : std_logic;
	
	-- misc
	signal UartFPGAtoFTDIxD : std_logic;
	signal DUMMY_A : std_logic_vector(4 downto 0);
	signal DUMMY_B : std_logic_vector(6 downto 0);
	
	-- component declarations
	component ext_fifo
	port (
		ClkxCI 	 	: in std_logic;
		ResetxRI 	: in std_logic;
		
		ResetRamxSI	: in std_logic;
		
		-- SPI for APS6404L
		RamCSnxSO	: out std_logic;
		RamMISOxDI 	: in std_logic;
		RamMOSIxDO 	: out std_logic;
		RamSCKxSO	: out std_logic;
		
		-- Input interface
		BuffFullxSO	: out std_logic;
		ParDatInRdyxSI : in std_logic;
		ParDatInxDI : in std_logic_vector(7 downto 0);
		
		-- Output interface
		ParDatReqxSI : in std_logic; -- FIFO almost empty
		ParDatStopxSI: in std_logic; -- FIFO almost full
		ParDatOutRdyxSO : out std_logic;
		ParDatOutxDO : out std_logic_vector(7 downto 0)
	);
	end component;
	
	component uart_rx
	generic (
		RX_CLK_DIV : integer  := 16
	);
	port (
		ClkxCI		: in std_logic;
		ResetxRI 	: in std_logic;
		SerDatxDI		: in std_logic;
		ParDatxDO	: out std_logic_vector(7 downto 0);
		ParDatRdyxSO : out std_logic;
		DebugxSO	: out std_logic
	);
	end component;
	
	component uart_tx_with_fifo
	generic (
		TX_CLK_DIV : integer  := 16
	);
	port (
		ClkxCI 	 	: in std_logic;
		ResetxRI 	: in std_logic;
		CTSnxSI		: in std_logic;
		SerDatxDO 	: out std_logic;
		BuffFullxSO	: out std_logic;
		BuffEmptyxSO: out std_logic;
		ParDatRdyxSI: in std_logic;
		ParDatxDI 	: in std_logic_vector(7 downto 0)
	);
	end component;
	
	component spi_rxtx_with_fifo
	port (
		ClkxCI 	 	: in std_logic;
		ResetxRI 	: in std_logic;
		CSnxSI		: in std_logic;
		MISOxDO 	: out std_logic;
		SCKxSI		: in std_logic;
		BuffFullxSO	: out std_logic;
		ParDatRdyxSI : in std_logic;
		ParDatxDI 	: in std_logic_vector(7 downto 0)
	);
	end component;
	
	component aux_adc_rx
	port(
		ClkxCI		: in std_logic;
		ResetxRI	: in std_logic;
		
		AcqTrgxSI 	: in std_logic;
		TxTrgxSI	: in std_logic;
		
		CSnxSO		: out std_logic;
		SCKxSO		: out std_logic;
		SDOxDI		: in std_logic_vector(1 downto 0);
		
		DigAuxxDI	: in std_logic_vector(7 downto 0);
				
		DataxDO 	: out std_logic_vector(7 downto 0);
		DataRdyxSO 	: out std_logic;
		DataAckxSI 	: in std_logic
		
	);
	end component;
	
	component ram_a
    port (
		DataInA: in  std_logic_vector(26 downto 0); 
        DataInB: in  std_logic_vector(26 downto 0); 
        AddressA: in  std_logic_vector(9 downto 0); 
        AddressB: in  std_logic_vector(9 downto 0); 
        ClockA: in  std_logic; 
		ClockB: in  std_logic; 
        ClockEnA: in  std_logic; 
		ClockEnB: in  std_logic; 
        WrA: in  std_logic; 
		WrB: in  std_logic; 
		ResetA: in  std_logic; 
        ResetB: in  std_logic; 
		QA: out  std_logic_vector(26 downto 0); 
        QB: out  std_logic_vector(26 downto 0));
	end component;
	
	component ram_b
    port (
		DataInA: in  std_logic_vector(17 downto 0); 
        DataInB: in  std_logic_vector(17 downto 0); 
        AddressA: in  std_logic_vector(9 downto 0); 
        AddressB: in  std_logic_vector(9 downto 0); 
        ClockA: in  std_logic; 
		ClockB: in  std_logic; 
        ClockEnA: in  std_logic; 
		ClockEnB: in  std_logic; 
        WrA: in  std_logic; 
		WrB: in  std_logic; 
		ResetA: in  std_logic; 
        ResetB: in  std_logic; 
		QA: out  std_logic_vector(17 downto 0); 
        QB: out  std_logic_vector(17 downto 0));
	end component;
	
begin
	
	-- config FSM
	-- FSM used to write/read RAM A and B, and status registers
	p_cfg_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			CfgStatexDP <= sIdle;
			CfgFSMSRegxDP <= (others => (others => '0'));
			CfgByteCntxDP <= 0;
			CfgOutRdyxDP <= '0';
		elsif (rising_edge(ClkxCI)) then
			CfgStatexDP <= CfgStatexDN;
			CfgFSMSRegxDP <= CfgFSMSRegxDN;
			CfgByteCntxDP <= CfgByteCntxDN;
			CfgOutRdyxDP <= CfgOutRdyxDN;
		end if;
	end process;

	p_cfg_memless : process(CfgStatexDP, CfgUartRxDatRdyxS, CfgUartRxDatxD, CfgFSMSRegxDP, CfgOutRdyxDP, MainStatRegxDP,
							CfgRamAOutxD, CfgRamBOutxD, CfgByteCntxDP)
	begin
		CfgStatexDN <= CfgStatexDP;
		CfgFSMSRegxDN <= CfgFSMSRegxDP;
		CfgFSMSRegOutxD <= CfgFSMSRegxDP(0);
		CfgByteCntxDN <= CfgByteCntxDP;
		CfgWrEnxS <= '0';
		CfgOutRdySetxS <= '0';
		case CfgStatexDP is
			when sIdle =>
				CfgByteCntxDN <= N_CMD_BYTES-1;
				if (CfgUartRxDatRdyxS = '1' and CfgUartRxDatxD = X"FF") then
					CfgStatexDN <= sRxBytes;
				end if;
			when sRxBytes =>
				if CfgUartRxDatRdyxS = '1' then
					CfgByteCntxDN <= CfgByteCntxDP -1;
					CfgFSMSRegxDN <= CfgFSMSRegxDP(1 to N_CMD_BYTES-1) & CfgUartRxDatxD; -- shift in byte
					if CfgByteCntxDP = 0 then
						CfgStatexDN <= sDecodeCmd;
					end if;
				end if;
			when sDecodeCmd =>
				if CfgFSMSRegxDP(1)(7) = '1' then -- write
					CfgStatexDN <= sIdle;
					CfgWrEnxS <= '1';
				else -- read
					CfgOutRdySetxS <= '1';
					CfgStatexDN <= sTxHeader;	
				end if;
				--CfgFSMSRegOutxD <= std_logic_vector(to_unsigned(240, 8));
			when sTxHeader =>
				CfgFSMSRegOutxD <= std_logic_vector(to_unsigned(240, 8));
				if CfgOutRdyxDP = '0' then
					CfgStatexDN <= sLoadBytes;
				end if;
			when sLoadBytes =>
				if CfgFSMSRegxDP(1)(4) = '1' then -- read ram a
					CfgFSMSRegxDN(5)(2 downto 0) <= CfgRamAOutxD(26 downto 24);
					CfgFSMSRegxDN(4) <= CfgRamAOutxD(23 downto 16);
					CfgFSMSRegxDN(3) <= CfgRamAOutxD(15 downto 8);
					CfgFSMSRegxDN(2) <= CfgRamAOutxD(7 downto 0);					
				elsif CfgFSMSRegxDP(1)(5) = '1' then -- read ram b
					CfgFSMSRegxDN(4)(1 downto 0) <= CfgRamBOutxD(17 downto 16);
					CfgFSMSRegxDN(3) <= CfgRamBOutxD(15 downto 8);
					CfgFSMSRegxDN(2) <= CfgRamBOutxD(7 downto 0);
				elsif CfgFSMSRegxDP(1)(6) = '1' and CfgFSMSRegxDP(0)(0) = '1' then -- read main_sreg
					CfgFSMSRegxDN(4) <= MainStatRegxDP(23 downto 16);
					CfgFSMSRegxDN(3) <= MainStatRegxDP(15 downto 8);
					CfgFSMSRegxDN(2) <= MainStatRegxDP(7 downto 0);
				end if;
				CfgByteCntxDN <= N_CMD_BYTES-1;
				CfgOutRdySetxS <= '1';
				CfgStatexDN <= sTxBytes;
			when sTxBytes =>
				if CfgOutRdyxDP = '0' then
					CfgByteCntxDN <= CfgByteCntxDP -1;
					CfgFSMSRegxDN <= CfgFSMSRegxDP(1 to N_CMD_BYTES-1) & CfgUartRxDatxD; -- shift in byte
					if CfgByteCntxDP = 0 then
						CfgStatexDN <= sIdle;
					else
						CfgOutRdySetxS <= '1';
					end if;
				end if;
			when others =>
				CfgStatexDN <= sIdle;
		end case;
	end process;
	
	CfgRamAWrEnxS <= CfgWrEnxS and CfgFSMSRegxDP(1)(4);
	CfgRamBWrEnxS <= CfgWrEnxS and CfgFSMSRegxDP(1)(5);
	MainStatRegWrEnxS <= CfgWrEnxS and CfgFSMSRegxDP(1)(6) and CfgFSMSRegxDP(0)(0);
	CfgOutRdyxDN <= '1' when CfgOutRdySetxS = '1' else
					'0' when CfgOutRdyClrxS = '1' else
					CfgOutRdyxDP;
	
	-- main status register
	p_main_stat_reg_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			MainStatRegxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			MainStatRegxDP <= MainStatRegxDN;
		end if;
	end process;
	
	p_main_stat_reg_memless : process (MainStatRegxDP, MainStatRegWrEnxS, CfgFSMSRegxDP)
	begin
		MainStatRegxDN <= MainStatRegxDP;
		if (MainStatRegWrEnxS = '1') then
			MainStatRegxDN(7 downto 0) <= CfgFSMSRegxDP(2);
			MainStatRegxDN(15 downto 8) <= CfgFSMSRegxDP(3);
			MainStatRegxDN(23 downto 16) <= CfgFSMSRegxDP(4);
		end if;
	end process;
	
	RunxS <= MainStatRegxDP(0);
	DetBRunxSO <= not MainStatRegxDP(4 downto 1);
	ResetExtRamxS <= MainStatRegxDP(6);
	V5P1B01enxSO <= MainStatRegxDP(16);
	V5P1B23enxSO <= MainStatRegxDP(17);
	V5P1RPienxSO <= not MainStatRegxDP(18);
	V5P1srcenxSO <= MainStatRegxDP(19);
	V9P0enxSO <= MainStatRegxDP(20);
	VN22enxSO <= MainStatRegxDP(21);
	VN3P4enxSO <= MainStatRegxDP(22);
	VN22_CLKaxSO <= '0';
	VN22_CLKbxSO <= '0';
	
	-- program counters
	p_pcnt_memzing : process(ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			PCntAxDP <= (others => '0');
			PCntBxDP <= (others => '0');
			ClkCntxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			PCntAxDP <= PCntAxDN;
			PCntBxDP <= PCntBxDN;
			ClkCntxDP <= ClkCntxDN;
		end if;
	end process;
	
	-- LEDs can only turn on while programm is running
	SrcPwrxDO <= SrcPwrPrexD when RunxS = '1' else (others => '0');
	-- TO-DO: Turn off LEDs when PCs are being reset
	
	p_pcnts_memless : process(ClkCntxDP, MainStatRegxDP, RamAEndxS, RamBEndxS, PCntAxDP, PCntBxDP, RunxS)
		variable ClkCntEndxD : unsigned(ClkCntxDP'range);
		variable PCntAAdvancexS : std_logic := '0';
		variable PCntBAdvancexS : std_logic := '0';
	begin
		
		-- clock counter
		ClkCntEndxD := unsigned(MainStatRegxDP(15 downto 8)) & "111" ;
		if PCntBxDP = to_unsigned(0, PCntBxDP'length) and RunxS = '0' then -- idle
			ClkCntxDN <= (others => '0');
			PCntBAdvancexS := '0';
		elsif ClkCntxDP >= ClkCntEndxD then -- end
			ClkCntxDN <= (others => '0');
			PCntBAdvancexS := '1';
		else
			ClkCntxDN <= ClkCntxDP +1;
			PCntBAdvancexS := '0';
		end if;
		
		-- program counter RAM B
		if PCntBAdvancexS = '1' then -- advance
			if RamBEndxS = '1' or PCntBxDP = "1111111111" then -- go to 0
				PCntBxDN <= (others => '0');
				PCntAAdvancexS := '1';
			else
				PCntBxDN <= PCntBxDP +1;
				PCntAAdvancexS := '0';
			end if;
		else
			PCntBxDN <= PCntBxDP;
			PCntAAdvancexS := '0';
		end if;
		
		-- program counter RAM A
		if MainStatRegxDP(5) = '1' then -- reset
			PCntAxDN <= (others => '0');
		elsif PCntAAdvancexS = '1' then -- advance
			if RamAEndxS = '1' then -- go to 0
				PCntAxDN <= (others => '0');
			else
				PCntAxDN <= PCntAxDP +1;
			end if;
		else
			PCntAxDN <= PCntAxDP;
		end if;
		
	end process;
	
	-- program counter B transmit FSM
	p_pcnttx_memzing : process(ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			PcntTxSRegxDP <= (others => (others => '0'));
			PcntTxStatexDP <= sIdle;
		elsif (rising_edge(ClkxCI)) then
			PcntTxSRegxDP <= PcntTxSRegxDN;
			PcntTxStatexDP <= PcntTxStatexDN;
		end if;
	end process;
	
	p_pcnttx_memless : process(PcntTxStatexDP, PCntTxTrgxS, PCntTxDatAckxS, PCntAxDP)
	begin
		PCntTxDatRdyxS <= '0';
		PcntTxDatxD <= PcntTxSRegxDP(0);
		PcntTxSRegxDN <= PcntTxSRegxDP;
		PcntTxStatexDN <= PcntTxStatexDP;
		case PcntTxStatexDP is
			when sIdle =>
				PcntTxSRegxDN(0) <= std_logic_vector(PCntAxDP(7 downto 0));
				PcntTxSRegxDN(1)(1 downto 0) <= std_logic_vector(PCntAxDP(9 downto 8));
				PcntTxSRegxDN(1)(7 downto 2) <= (others => '0');
				if PCntTxTrgxS = '1' then
					PcntTxStatexDN <= sTxHeader;
				end if;
			when sTxHeader =>
				PcntTxDatxD <= std_logic_vector(to_unsigned(254, 8));
				PCntTxDatRdyxS <= '1';
				if PCntTxDatAckxS = '1' then
					PcntTxStatexDN <= sTxB1;
				end if;
			when sTxB1 =>
				--PcntTxDatxD <= PcntTxSRegxDP(0);
				PCntTxDatRdyxS <= '1';
				if PCntTxDatAckxS = '1' then -- shift out
					PcntTxSRegxDN(0) <= PcntTxSRegxDP(1);
					PcntTxStatexDN <= sTxB0;
				end if;
			when sTxB0 =>
				--PcntTxDatxD <= PcntTxSRegxDP(0);
				PCntTxDatRdyxS <= '1';
				if PCntTxDatAckxS = '1' then
					PcntTxStatexDN <= sWait;
				end if;
			when sWait =>
				if PCntTxTrgxS = '0' then
					PcntTxStatexDN <= sIdle;
				end if;
			when others =>
				PcntTxStatexDN <= sIdle;
		end case;
	end process;
	
	-- acquisition FSM / MUX
	p_acq_mux_memzing : process(ResetxRI, ClkxCI, UartDetBtoFPGAxDN)
	begin
		if ResetxRI = '1' then
			UartDetBtoFPGAxDP <= (others => '0');
			UartDetBRxDatRdyxSP <= '0';
			DetBSelectxSP <= (others => '0');
		elsif rising_edge(ClkxCI) then
			UartDetBtoFPGAxDP <= UartDetBtoFPGAxDN;
			UartDetBRxDatRdyxSP <= UartDetBRxDatRdyxSN;
			DetBSelectxSP <= DetBSelectxSN;
		end if;
	end process;
	
	UartDetBtoFPGAxDN <= UartDetBtoFPGAxDI;
	UartDetBtoFPGASelxD <= UartDetBtoFPGAxDP(to_integer(unsigned(DetBSelectIxD)));
	UartDetBRxDatRdyxSN <= '1' when UartDetBRxDatRdySetxS = '1' else
							'0' when UartDetBRxDatRdyClrxS = '1' else
							UartDetBRxDatRdyxSP;
		
	p_acq_mux_memless : process(CfgOutRdyxDP, CfgFSMSRegOutxD, UartDetBRxDatxD, UartDetBRxDatRdyxSP, PcntTxDatxD, 
								PCntTxDatRdyxS, AuxDataRdyxS, DetBRxEnxS, DetBSelectIxD, AuxDataxD)
	begin
		PCntTxDatAckxS <= '0';
		ParDatfromMuxRdyxS <= '0';
		CfgOutRdyClrxS <= '0';
		UartDetBRxDatRdyClrxS <= '0';
		AuxDataAckxS <= '0';
		ParDatfromMuxxD <= CfgFSMSRegOutxD;

		if CfgOutRdyxDP = '1' then
			CfgOutRdyClrxS <= '1';
			ParDatfromMuxRdyxS <= '1';
			ParDatfromMuxxD <= CfgFSMSRegOutxD;
		elsif UartDetBRxDatRdyxSP = '1' then
			UartDetBRxDatRdyClrxS <= '1';
			ParDatfromMuxRdyxS <= '1';
			ParDatfromMuxxD <= UartDetBRxDatxD;
		elsif PCntTxDatRdyxS = '1' then
			PCntTxDatAckxS <= '1';
			ParDatfromMuxRdyxS <= '1';
			ParDatfromMuxxD <= PcntTxDatxD;
		elsif AuxDataRdyxS = '1' then
			AuxDataAckxS <= '1';
			ParDatfromMuxRdyxS <= '1';
			ParDatfromMuxxD <= AuxDataxD;
		end if;
		
		DetBSelectxSN <= (others => '1');
		DetBSelectxSN(to_integer(unsigned(DetBSelectIxD))) <= not DetBRxEnxS;
	end process;
	
	DetBSelectxSO <= DetBSelectxSP;
	
	-- Detector boards
	UartFPGAtoDetBxDO <= (others => '1'); -- Uart FPGA to DetB: to-do.
	
	-- Misc
	FpLEDxSO(0) <= RunxS;
	AccRunIndxSO <= RunxS;
	FpLEDxSO(1) <= '0';
	UartCTSntoFTDIxDO <= '0'; -- FPGA processes commands nearly instantly, no flow control required.
	
	-- debug connections
	ExpJ303xDO(0) <= UartFTDItoFPGAxDI;
	ExpJ303xDO(1) <= UartFPGAtoFTDIxD;
	ExpJ303xDO(2) <= UartRTSntoFPGAxDI;
	ExpJ303xDO(3) <= ResetExtRamxS;
	--ExpJ303xDO(0) <= RamCSnxSO;
	--ExpJ303xDO(1) <= RamMISOxDI;
	--ExpJ303xDO(2) <= RamMOSIxDO;
	--ExpJ303xDO(3) <= RamSCKxSO;
	
	UartFPGAtoFTDIxDO <= UartFPGAtoFTDIxD; -- required to out to 2 pins
		
	-- component instances
	ext_fifo_inst : ext_fifo
	port map (
		ClkxCI 	 	=> ClkxCI,
		ResetxRI 	=> ResetxRI,
		
		ResetRamxSI => ResetExtRamxS,
		
		-- SPI for APS6404L
		RamCSnxSO	=> RamCSnxSO,
		RamMISOxDI 	=> RamMISOxDI,
		RamMOSIxDO 	=> RamMOSIxDO,
		RamSCKxSO	=> RamSCKxSO,
		
		-- Input interface
		BuffFullxSO	=> open,
		ParDatInRdyxSI => ParDatfromMuxRdyxS,
		ParDatInxDI => ParDatfromMuxxD,
		
		-- Output interface
		ParDatReqxSI => UartBuffEmptyxS, -- FIFO almost empty
		ParDatStopxSI => UartBuffFullxS, -- FIFO almost full
		ParDatOutRdyxSO => UartTxDatRdyxS,
		ParDatOutxDO => UartTxDatxD
	);
	
	uart_from_detb_inst : uart_rx
	port map (
		ClkxCI		=> ClkxCI,
		ResetxRI 	=> ResetxRI,
		SerDatxDI	=> UartDetBtoFPGASelxD,
		ParDatxDO	=> UartDetBRxDatxD,
		ParDatRdyxSO => UartDetBRxDatRdySetxS,
		DebugxSO	=> open
	);
	
	uart_to_ftdi_inst : uart_tx_with_fifo
	generic map(
		TX_CLK_DIV => 8 -- 96/8 = 12 MBPS
	)
	port map (
		ClkxCI 	 	=> ClkxCI,
		ResetxRI 	=> ResetxRI,
		CTSnxSI		=> UartRTSntoFPGAxDI,
		SerDatxDO 	=> UartFPGAtoFTDIxD,
		BuffFullxSO	=> UartBuffFullxS,
		BuffEmptyxSO=> UartBuffEmptyxS,
		ParDatRdyxSI => UartTxDatRdyxS,
		ParDatxDI 	=> UartTxDatxD
	);
	
	spi_to_rpi_zero : spi_rxtx_with_fifo
	port map (
		ClkxCI 	 	=> ClkxCI,
		ResetxRI 	=> ResetxRI,
		CSnxSI		=> SpiRPi0CSnxSI,
		MISOxDO 	=> SpiRPi0MISOxDO,
		SCKxSI		=> SpiRPi0SCKxSI,
		BuffFullxSO	=> open,
		ParDatRdyxSI => UartTxDatRdyxS,
		ParDatxDI 	=> UartTxDatxD
	);

	uart_from_ftdi_inst : uart_rx
	generic map(
		RX_CLK_DIV => 8 -- 96/8 = 12 MBPS
	)
	port map (
		ClkxCI		=> ClkxCI,
		ResetxRI 	=> ResetxRI,
		SerDatxDI	=> UartFTDItoFPGAxDI,
		ParDatxDO	=> CfgUartRxDatxD,
		ParDatRdyxSO => CfgUartRxDatRdyxS,
		DebugxSO	=> open
	);
	
	aux_adc_rx_inst : aux_adc_rx
	port map(
		ClkxCI		=> ClkxCI,
		ResetxRI	=> ResetxRI,
		
		AcqTrgxSI 	=> DetBTriggerxSO,
		TxTrgxSI	=> AuxTxTrgxS,
		
		CSnxSO		=> AuxCSnxSO,
		SCKxSO		=> AuxSCKxSO,
		SDOxDI		=> AuxSDOxDI,
		
		DigAuxxDI(3 downto 0) => TrgxDI,
		DigAuxxDI(5 downto 4) => AuxIOxSI,		DigAuxxDI(7 downto 6) => (others => '0'),
		
		DataxDO 	=> AuxDataxD,
		DataRdyxSO 	=> AuxDataRdyxS,
		DataAckxSI 	=> AuxDataAckxS
	);
	
	ram_a_inst : ram_a -- state sequence ram
    port map (
		DataInA( 7 downto  0)=>CfgFSMSRegxDP(2),
		DataInA(15 downto  8)=>CfgFSMSRegxDP(3),
		DataInA(23 downto 16)=>CfgFSMSRegxDP(4),
		DataInA(26 downto 24)=>CfgFSMSRegxDP(5)(2 downto 0),
		DataInB(26 downto 0)=>(others => '0'), 
        AddressA(7 downto 0)=>CfgFSMSRegxDP(0),
		AddressA(9 downto 8)=>CfgFSMSRegxDP(1)(1 downto 0), 		
		AddressB(9 downto 0)=>std_logic_vector(PCntAxDP), 
		ClockA=>ClkxCI, 
        ClockB=>ClkxCI, 
		ClockEnA=>'1', 
		ClockEnB=>'1', 
		WrA=>CfgRamAWrEnxS, 
		WrB=>'0', 
		ResetA=>ResetxRI, 
        ResetB=>ResetxRI, 
		QA(26 downto 0)=>CfgRamAOutxD,
		QB(2 downto 0)=>SrcRowxDO,
		QB(3) => DUMMY_A(0),
		QB(17 downto 4)=>SrcColxDO,
		QB(20 downto 18)=>SrcPwrPrexD,
		QB(21)=>DetBStatusSelectxSO,
		QB(25 downto 22)=>DUMMY_A(4 downto 1),
		QB(26)=>RamAEndxS
	);
	
	ram_b_inst : ram_b -- acquisition sequence ram
    port map (
		DataInA( 7 downto  0)=>CfgFSMSRegxDP(2),
		DataInA(15 downto  8)=>CfgFSMSRegxDP(3),
		DataInA(17 downto 16)=>CfgFSMSRegxDP(4)(1 downto 0),
		DataInB(17 downto 0)=>(others => '0'), 
        AddressA(7 downto 0)=>CfgFSMSRegxDP(0),
		AddressA(9 downto 8)=>CfgFSMSRegxDP(1)(1 downto 0), 
        AddressB(9 downto 0)=>std_logic_vector(PCntBxDP), 
		ClockA=>ClkxCI, 
		ClockB=>ClkxCI, 
		ClockEnA=>'1', 
        ClockEnB=>'1', 
		WrA=>CfgRamBWrEnxS, 
		WrB=>'0', 
		ResetA=>ResetxRI, 
		ResetB=>ResetxRI, 
		QA(17 downto 0)=>CfgRamBOutxD,
		QB(4 downto 0)=> DetBSelectIxD,
		QB(5)=>DetBRxEnxS,
		QB(6)=>AuxTxTrgxS,
		QB(7)=>PCntTxTrgxS,
		QB(8)=>DetBEndCycxSO,
		QB(9)=>DetBTriggerxSO,
		QB(16 downto 10)=>DUMMY_B(6 downto 0),
        QB(17)=>RamBEndxS
	);

end NN22Control_main_behavior;
