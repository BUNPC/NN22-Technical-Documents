-- Firmware for NN22_ControlBoard00
-- FIFO buffer using the external pseudo SRAM (PSRAM APS6404L).

-- Assuming clock speed of 96 MHz, though 168 MHz should be possible. Main limit is the 84 MHz SPI speed for fast reads and writes 
-- in linear burst operation, but also check timing of CSn etc.

-- Initial version: 2023-08-03
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ext_fifo is
	port (
		ClkxCI 	 	: in std_logic;
		ResetxRI 	: in std_logic;
		
		ResetRamxSI	: in std_logic;
		
		-- SPI for APS6404L PSRAM
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
end ext_fifo;

architecture behavioral of ext_fifo is
	constant MAX_BYTES_PER_XFER : integer := 16; -- limited by max CSn low pulse width of ~4us
	type fsmstatetype is (sIdle, sReadCmd, sReadAddr3, sReadAddr2, sReadAddr1, sReadWait, sReadData, sReadDone, 
		sNewCmd, sNewCmd2, sWriteCmd, sWriteAddr3, sWriteAddr2, sWriteAddr1, sWriteData, sWriteDone, sPreIdle,
		sResetEnCmd, sResetEnDone1, sResetEnDone2, sResetEnDone3, sResetCmd, sResetDone);
	signal StatexDP, StatexDN : fsmstatetype;
	
	type spifsmstatetype is (sIdle, sClkLow, sClkHigh, sDone);
	signal SpiStatexDP, SpiStatexDN : spifsmstatetype;
	
	signal IntFIFORdEnxS, IntFIFOEmptyxS : std_logic;
	signal IntFIFODataOutxD : std_logic_vector(7 downto 0);
	
	signal BitCntxDP, BitCntxDN: integer range 0 to 7;
	signal ByteCntxDP, ByteCntxDN: integer range 0 to 1023;
	
	signal ExtFIFOWrAddrxDP, ExtFIFOWrAddrxDN : unsigned(22 downto 0);
	signal ExtFIFORdAddrxDP, ExtFIFORdAddrxDN : unsigned(22 downto 0);
	signal NextAddrxDP, NextAddrxDN : unsigned(23 downto 0); -- registering because mux into SpiSReg was getting too large/slow
	signal ExtFIFOFullxSP, ExtFIFOFullxSN : std_logic; 
	signal ExtFIFOEmptyxS : std_logic;
	
	
	signal SpiIdlexS : std_logic;
	signal SpiDonexS : std_logic;
	signal SpiStartxS : std_logic;
	signal SpiSRegxDP, SpiSRegxDN : std_logic_vector(7 downto 0);
	signal SpiOutDatxD : std_logic_vector(7 downto 0);
	
	-- registering to prevent glitches at output
	signal RamCSnxSP, RamCSnxSN : std_logic;
	signal RamSCKxSP, RamSCKxSN : std_logic;
	
	component ext_fifo_int_fifo
    port (
		Data: in  std_logic_vector(7 downto 0); 
		WrClock: in  std_logic; 
        RdClock: in  std_logic; 
		WrEn: in  std_logic; 
		RdEn: in  std_logic; 
        Reset: in  std_logic; 
		RPReset: in  std_logic; 
        Q: out  std_logic_vector(7 downto 0); 
		Empty: out  std_logic; 
        Full: out  std_logic; 
		AlmostEmpty: out  std_logic; 
        AlmostFull: out  std_logic
	);
	end component;
	
begin

	ExtFIFOEmptyxS <= '1' when ExtFIFORdAddrxDP = ExtFIFOWrAddrxDP else '0';
	ExtFIFOFullxSN <= '1' when (ExtFIFOWrAddrxDP+2) = ExtFIFORdAddrxDP else '0'; -- not using last mem loc to simplify
	ParDatOutxDO <= SpiSRegxDP;
	RamCSnxSO <= RamCSnxSP;
	RamSCKxSO <= RamSCKxSP;
	
	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then 
			StatexDP <= sIdle;
			ByteCntxDP <= 0;
			BitCntxDP <= 0;
			ExtFIFOWrAddrxDP <= (others => '0');
			ExtFIFORdAddrxDP <= (others => '0');
			NextAddrxDP <= (others => '0');
			ExtFIFOFullxSP <= '0';
			RamCSnxSP <= '0';
			RamSCKxSP <= '0';
			
			SpiStatexDP <= sIdle;
			SpiSRegxDP <= (others => '0');

		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			ByteCntxDP <= ByteCntxDN;
			BitCntxDP <= BitCntxDN;
			ExtFIFOWrAddrxDP <= ExtFIFOWrAddrxDN;
			ExtFIFORdAddrxDP <= ExtFIFORdAddrxDN;
			NextAddrxDP <= NextAddrxDN;
			ExtFIFOFullxSP <= ExtFIFOFullxSN;
			RamCSnxSP <= RamCSnxSN;
			RamSCKxSP <= RamSCKxSN;
			 
			SpiStatexDP <= SpiStatexDN;
			SpiSRegxDP <= SpiSRegxDN;

		end if;  
	end process;
	
	p_memless_main : process(StatexDP, ByteCntxDP, ExtFIFOWrAddrxDP, ExtFIFORdAddrxDP, ParDatReqxSI, ExtFIFOEmptyxS,
		IntFIFOEmptyxS, IntFIFODataOutxD, ExtFIFOFullxSP, ParDatStopxSI, SpiDonexS, ResetRamxSI)
	begin
		StatexDN <= StatexDP;
		ByteCntxDN <= ByteCntxDP;
		
		ExtFIFOWrAddrxDN <= ExtFIFOWrAddrxDP;
		ExtFIFORdAddrxDN <= ExtFIFORdAddrxDP;
		NextAddrxDN <= NextAddrxDP;
		
		IntFIFORdEnxS <= '0';
		
		RamCSnxSN <= '1';
		
		SpiStartxS <= '0';
		SpiOutDatxD <= x"00";
		
		ParDatOutRdyxSO <= '0';

		case StatexDP is
			when sIdle =>
				if ResetRamxSI = '1' then
					RamCSnxSN <= '0';
					StatexDN <= sResetEnCmd;
				elsif ParDatReqxSI = '1' and ExtFIFOEmptyxS = '0' then
					RamCSnxSN <= '0';
					StatexDN <= sReadCmd;
				elsif IntFIFOEmptyxS = '0' and ExtFIFOFullxSP = '0' then
					RamCSnxSN <= '0';
					StatexDN <= sWriteCmd;
				end if;

			-- *** Read from external PSRAM ***
			when sReadCmd => 
				RamCSnxSN <= '0';
				ByteCntxDN <= 0;
				SpiOutDatxD <= x"0B"; -- fast read command
				NextAddrxDN <= '0' & ExtFIFORdAddrxDP;
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					StatexDN <= sReadAddr3;
				end if;
				
			when sReadAddr3 => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= std_logic_vector(NextAddrxDP(23 downto 16));
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					NextAddrxDN <= shift_left(NextAddrxDP, 8);
					StatexDN <= sReadAddr2;
				end if;
				
			when sReadAddr2 => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= std_logic_vector(NextAddrxDP(23 downto 16));
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					NextAddrxDN <= shift_left(NextAddrxDP, 8);
					StatexDN <= sReadAddr1;
				end if;
				
			when sReadAddr1 => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= std_logic_vector(NextAddrxDP(23 downto 16));
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					StatexDN <= sReadWait;
				end if;
				
			when sReadWait => -- wait cycle
				RamCSnxSN <= '0';
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					StatexDN <= sReadData;
				end if;
				
			when sReadData =>
				RamCSnxSN <= '0';
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					ExtFIFORdAddrxDN <= ExtFIFORdAddrxDP +1;
					ByteCntxDN <= ByteCntxDP +1;
					StatexDN <= sReadDone;
				end if;
			
			when sReadDone =>
				ParDatOutRdyxSO <= '1';
				if ParDatStopxSI = '0' and ExtFIFOEmptyxS = '0' and ByteCntxDP < MAX_BYTES_PER_XFER then
					RamCSnxSN <= '0';
					StatexDN <= sReadData;
				elsif IntFIFOEmptyxS = '0' and ExtFIFOFullxSP = '0' then
					StatexDN <= sNewCmd;
				else
					StatexDN <= sPreIdle;
				end if;
				
			when sNewCmd =>
				-- need to raise chip select before starting a new command
				StatexDN <= sNewCmd2;
			
			when sNewCmd2 =>
				-- need at least 2 clock cycles of CSn high (min 18 ns)
				RamCSnxSN <= '0';
				StatexDN <= sWriteCmd;
			
			-- *** Write to external PSRAM ***
			when sWriteCmd => 
				RamCSnxSN <= '0';
				ByteCntxDN <= 0;
				SpiOutDatxD <= x"02"; -- simple write command
				NextAddrxDN <= '0' & ExtFIFOWrAddrxDP;
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					StatexDN <= sWriteAddr3;
				end if;
				
			when sWriteAddr3 => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= std_logic_vector(NextAddrxDP(23 downto 16));
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					NextAddrxDN <= shift_left(NextAddrxDP, 8);
					StatexDN <= sWriteAddr2;
				end if;
				
			when sWriteAddr2 => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= std_logic_vector(NextAddrxDP(23 downto 16));
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					NextAddrxDN <= shift_left(NextAddrxDP, 8);
					StatexDN <= sWriteAddr1;
				end if;
				
			when sWriteAddr1 => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= std_logic_vector(NextAddrxDP(23 downto 16));
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					IntFIFORdEnxS <= '1';
					StatexDN <= sWriteData;
				end if;
				
			when sWriteData =>
				RamCSnxSN <= '0';
				SpiOutDatxD <= IntFIFODataOutxD;
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					ByteCntxDN <= ByteCntxDP +1;
					ExtFIFOWrAddrxDN <= ExtFIFOWrAddrxDP +1;
					StatexDN <= sWriteDone;
				end if;
			
			when sWriteDone =>
				if ExtFIFOFullxSP = '0' and IntFIFOEmptyxS = '0' and ByteCntxDP < MAX_BYTES_PER_XFER then
					IntFIFORdEnxS <= '1';
					RamCSnxSN <= '0';
					StatexDN <= sWriteData;
				else
					StatexDN <= sPreIdle;
				end if;	
				
			-- *** Software Reset ***
			when sResetEnCmd => 
				RamCSnxSN <= '0';
				SpiOutDatxD <= x"66"; -- reset enable command
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					StatexDN <= sResetEnDone1;
				end if;
			
			when sResetEnDone1 =>
				-- need at least 2 clock cycles of CSn high (min 18 ns)
				StatexDN <= sResetEnDone2;
				
			when sResetEnDone2 =>
				-- need at least 2 clock cycles of CSn high (min 18 ns)
				StatexDN <= sResetEnDone3;
				
			when sResetEnDone3 =>
				RamCSnxSN <= '0';
				StatexDN <= sResetCmd;
				
			when sResetCmd =>
				RamCSnxSN <= '0';
				SpiOutDatxD <= x"99"; -- reset command
				ByteCntxDN <= 0;
				SpiStartxS <= '1';
				if SpiDonexS = '1' then
					StatexDN <= sResetDone;
				end if;
				
			when sResetDone =>
				ExtFIFOWrAddrxDN <= (others => '0');
				ExtFIFORdAddrxDN <= (others => '0');
				-- need to wait 50 ns minimum, using ByteCnt to count clock ticks
				if ByteCntxDP < 5 then
					ByteCntxDN <= ByteCntxDP +1;
				elsif ResetRamxSI = '0' then
					StatexDN <= sPreIdle;
				end if;
				
				
			when sPreIdle =>
				-- need at least 2 clock cycles of CSn high (min 18 ns)
				StatexDN <= sIdle;

			when others =>
				StatexDN <= sIdle;
		end case;
	end process;
   
	p_memless_spi : process(SpiStatexDP, BitCntxDP, SpiSRegxDP, SpiStartxS, RamMISOxDI, SpiOutDatxD)
	begin
		SpiStatexDN <= SpiStatexDP;
		BitCntxDN <= BitCntxDP;
		SpiSRegxDN <= SpiSRegxDP;
		
		RamMOSIxDO <= SpiSRegxDP(7);
		RamSCKxSN <= '0';
		SpiIdlexS <= '0';
		SpiDonexS <= '0';

		case SpiStatexDP is
			when sIdle =>
				BitCntxDN <= 0;
				SpiIdlexS <= '1';
				SpiSRegxDN <= SpiOutDatxD;
				if SpiStartxS = '1' then
					SpiStatexDN <= sClkLow;
				end if;

			when sClkLow => 
				RamSCKxSN <= '1';
				SpiStatexDN <= sClkHigh;
				
			when sClkHigh =>
				-- left shift
				SpiSRegxDN(7 downto 1) <= SpiSRegxDP(6 downto 0);
				SpiSRegxDN(0) <= RamMISOxDI;
				BitCntxDN <= BitCntxDP +1;
				if BitCntxDP = 7 then
					SpiDonexS <= '1';
					SpiStatexDN <= sIdle;
				else
					SpiStatexDN <= sClkLow;
				end if;
			
			--when sDone =>
				--SpiDonexS <= '1';
				--SpiStatexDN <= sIdle;

			when others =>
				SpiStatexDN <= sIdle;
		end case;
	end process;
   

	int_fifo_inst : ext_fifo_int_fifo
	port map (
		Data(7 downto 0)=> ParDatInxDI, 
		WrClock=> ClkxCI, 
		RdClock=> ClkxCI, 
		WrEn=> ParDatInRdyxSI, 
		RdEn=> IntFIFORdEnxS, 
		Reset=> ResetxRI, 
		RPReset=> ResetxRI, 
		Q(7 downto 0)=> IntFIFODataOutxD, 
		Empty=> IntFIFOEmptyxS, 
		Full=> open, 
		AlmostEmpty=> open, 
		AlmostFull=> BuffFullxSO
	);
	
end behavioral;