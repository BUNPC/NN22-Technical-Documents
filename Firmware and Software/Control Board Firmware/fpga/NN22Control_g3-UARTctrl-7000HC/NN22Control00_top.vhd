-- Firmware for NN22_ControlBoard00
-- Top-level unit

-- Initial version: 2022-12-23
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
--library MACHXO2;
--use MACHXO2.components.all;

entity NN22Control_top is
	port(
		OSC_CLK				: in std_logic;
		
		-- Detector boards
		UART_DETB_TO_FPGA 	: in std_logic_vector(24 downto 0);
		UART_FPGA_TO_DETB 	: out std_logic_vector(4 downto 0);
		DETB_SELECT 		: out std_logic_vector(24 downto 0);
		DETB_RUN 			: out std_logic_vector(3 downto 0);
		DETB_STATUS_SELECT 	: out std_logic_vector(4 downto 0);
		DETB_TRIGGER 		: out std_logic_vector(3 downto 0);
		DETB_END_CYC		: out std_logic_vector(4 downto 0);
		
		-- Source boards
		SRC_COL 			: out std_logic_vector(13 downto 0);
		SRC_ROW 			: out std_logic_vector(2 downto 0);
		SRC_PWR 			: out std_logic_vector(2 downto 0);
		
		-- Auxiliary ADCs
		ADS_CSN				: out std_logic_vector(1 downto 0);
		ADS_SCK				: out std_logic_vector(1 downto 0);
		ADS_SDO				: in std_logic_vector(1 downto 0);
		
		-- RAM
		RAM0_CEN 			: out std_logic;
		RAM0_SCLK			: out std_logic;
		RAM0_SIO			: inout std_logic_vector(3 downto 0);
		RAM1_CEN			: out std_logic;
		RAM1_SCLK			: out std_logic;
		RAM1_SIO			: inout std_logic_vector(3 downto 0);
		
		-- FTDI UART USB interface
		UART_FPGA_TO_FTDI	: out std_logic;
		UART_FTDI_TO_FPGA	: in std_logic;
		UART_CTSN_TO_FTDI	: out std_logic;
		UART_RTSN_TO_FPGA	: in std_logic;
		UART_FTDI_RXLEDN	: in std_logic;
		UART_FTDI_TXLEDN	: in std_logic;
		
		-- Raspberry Pi Zero
		RPI0_CE				: in std_logic;
		RPI0_MISO			: out std_logic;
		RPI0_SCLK			: in std_logic;
	
		-- Misc
		ACC_RUN_IND			: out std_logic;
		EXP_J303_D			: out std_logic_vector(3 downto 0);
		TRG					: in std_logic_vector(3 downto 0);
		AUXIO				: inout std_logic_vector(1 downto 0);
		FP_LED				: out std_logic_vector(3 downto 0);
		V5P1_B01_EN			: out std_logic;
		TP301_NET			: out std_logic; -- V5P1_B23_EN (PCB error)
		V5P1_RPI_EN			: out std_logic;
		V5P1_SRC_EN			: out std_logic;
		V9P0_EN				: out std_logic;
		VN22_EN				: out std_logic;
		VN3P4_EN			: out std_logic;
		VN22_CLKA			: out std_logic;
		VN22_CLKB			: out std_logic
	);
end NN22Control_top;

architecture NN22Control_top_behavior of NN22Control_top is
	signal ResetxR : std_logic;
	signal Clk96xC : std_logic;
	
	signal PllLockxS : std_logic;
	
	signal AuxCSnxS : std_logic;
	signal AuxSCKxS : std_logic;
	
	signal DetBRunxS : std_logic_vector(3 downto 0);
	signal DetBStatusSelectxS  : std_logic;
	signal DetBTriggerxS : std_logic;
	signal DetBEndCycxS : std_logic;
	
	signal RamMOSIxD : std_logic;
	
	component NN22Control_main
	port (
		ClkxCI				: in std_logic;
		ResetxRI			: in std_logic;
		
		-- Detector boards
		UartDetBtoFPGAxDI 	: in std_logic_vector(24 downto 0);
		UartFPGAtoDetBxDO 	: out std_logic_vector(4 downto 0);
		DetBSelectxSO 		: out std_logic_vector(24 downto 0);
		DetBRunxSO 			: out std_logic_vector(3 downto 0);
		DetBStatusSelectxSO : out std_logic;
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
	end component;
	
	component main_pll
    port (
		CLKI: 	in  std_logic; 
		CLKOP: 	out  std_logic; 
        LOCK: 	out  std_logic);
	end component;
	
begin
	ResetxR <= not PllLockxS;
	
	NN22Control_main_inst : NN22Control_main
	port map (
		ClkxCI				=> Clk96xC,
		ResetxRI			=> ResetxR,
		
		-- Detector boards
		UartDetBtoFPGAxDI 	=> UART_DETB_TO_FPGA,
		UartFPGAtoDetBxDO 	=> UART_FPGA_TO_DETB,
		DetBSelectxSO 		=> DETB_SELECT,
		DetBRunxSO 			=> DetBRunxS,
		DetBStatusSelectxSO => DetBStatusSelectxS,
		DetBTriggerxSO 		=> DetBTriggerxS,
		DetBEndCycxSO		=> DetBEndCycxS,
		
		-- Source boards
		SrcColxDO 			=> SRC_COL,
		SrcRowxDO 			=> SRC_ROW,
		SrcPwrxDO			=> SRC_PWR,
		
		-- Auxiliary ADCs
		AuxCSnxSO			=> AuxCSnxS,
		AuxSCKxSO			=> AuxSCKxS,
		AuxSDOxDI			=> ADS_SDO,
				
		-- FTDI UART USB interface
		UartFPGAtoFTDIxDO	=> UART_FPGA_TO_FTDI,
		UartFTDItoFPGAxDI	=> UART_FTDI_TO_FPGA,
		UartCTSntoFTDIxDO	=> UART_CTSN_TO_FTDI,
		UartRTSntoFPGAxDI	=> UART_RTSN_TO_FPGA,
		
		-- SPI Raspberry Pi 0 interface
		SpiRPi0SCKxSI		=> RPI0_SCLK,
		SpiRPi0CSnxSI		=> RPI0_CE,
		SpiRPi0MISOxDO		=> RPI0_MISO,
		
		-- SPI for APS6404L PSRAM
		RamCSnxSO			=> RAM0_CEN,
		RamMISOxDI 			=> RAM0_SIO(1),
		RamMOSIxDO 			=> RamMOSIxD,
		RamSCKxSO			=> RAM0_SCLK,
	
		-- Misc
		AccRunIndxSO		=> ACC_RUN_IND,
		ExpJ303xDO			=> EXP_J303_D,
		TrgxDI				=> TRG,
		AuxIOxSI			=> AUXIO,
		FpLEDxSO			=> FP_LED(1 downto 0),
		V5P1B01enxSO		=> V5P1_B01_EN,
		V5P1B23enxSO		=> TP301_NET,
		V5P1RPienxSO		=> V5P1_RPI_EN,
		V5P1srcenxSO		=> V5P1_SRC_EN,
		V9P0enxSO			=> V9P0_EN,
		VN22enxSO			=> VN22_EN,
		VN3P4enxSO			=> VN3P4_EN,
		VN22_CLKaxSO		=> VN22_CLKA,
		VN22_CLKbxSO		=> VN22_CLKB
	);

	FP_LED(2) <= not UART_FTDI_RXLEDN;
	FP_LED(3) <= not UART_FTDI_TXLEDN;
	
	ADS_CSN <= (others => AuxCSnxS);
	ADS_SCK <= (others => AuxSCKxS);
	
	DETB_RUN <= DetBRunxS;
	DETB_STATUS_SELECT <= (others => DetBStatusSelectxS);
	DETB_TRIGGER <= (others => DetBTriggerxS);
	DETB_END_CYC <= (others => DetBEndCycxS);
	
	-- PSRAM
	RAM0_SIO(0) <= '1' when RamMOSIxD = '1' else '0';
	RAM0_SIO(3 downto 1) <= (others => 'Z');
	RAM1_CEN <= '1';
	RAM1_SCLK <= '0';
	RAM1_SIO <= (others => '0');
	
	main_pll_inst : main_pll
    port map (
		CLKI	=> OSC_CLK, -- 48 MHz in
		CLKOP	=> Clk96xC, -- 96 MHz out
		LOCK	=> PllLockxS
	);

end NN22Control_top_behavior;
