-- Firmware for NN22_ControlBoard00
-- SPI transmitter with FIFO
-- FPGA is the slave device
-- (rx functionality: to-do)

-- Initial version: 2023-3-13
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_rxtx_with_fifo is
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
end spi_rxtx_with_fifo;

architecture behavioral of spi_rxtx_with_fifo is
	
	type fsmstatetype is (sIdle, sTxByteCount, sTxData);
	signal StatexDP, StatexDN : fsmstatetype;
	
	signal FIFOWrAddrxDP, FIFOWrAddrxDN : unsigned(9 downto 0);
	signal FIFORdAddrxDP, FIFORdAddrxDN : unsigned(9 downto 0);
	
	signal FIFOBytesAvailableFullxD : unsigned(FIFORdAddrxDP'range);
	signal FIFOBytesAvailableLtdxD : unsigned(7 downto 0);
	signal FIFOFullxS : std_logic; 
	signal FIFOEmptyxS : std_logic;
	signal FIFOOutDataxD : std_logic_vector(7 downto 0);
	signal TxSRegxDP, TxSRegxDN : std_logic_vector(7 downto 0);
	
	signal BitCntxDP, BitCntxDN: integer range 0 to 7;
	
	-- synchronizer registers
	signal CSnxSP, CSnxSN : std_logic;
	signal SCKSRegxSP, SCKSRegxSN : std_logic_vector(1 downto 0);
	
	signal DUMMY_A : std_logic_vector(7 downto 0);
	
	
	component spi_txrx_ram
    port (
		DataInA	: in  std_logic_vector(7 downto 0); 
        DataInB	: in  std_logic_vector(7 downto 0); 
        AddressA: in  std_logic_vector(9 downto 0); 
        AddressB: in  std_logic_vector(9 downto 0); 
        ClockA	: in  std_logic; ClockB: in  std_logic; 
        ClockEnA: in  std_logic; ClockEnB: in  std_logic; 
        WrA		: in  std_logic; WrB: in  std_logic; ResetA: in  std_logic; 
        ResetB	: in  std_logic; QA: out  std_logic_vector(7 downto 0); 
        QB		: out std_logic_vector(7 downto 0)
	);
	end component;
	
begin
	
	FIFOEmptyxS <= '1' when FIFORdAddrxDP = FIFOWrAddrxDP else '0';
	FIFOFullxS <= '1' when (FIFOWrAddrxDP+1) = FIFORdAddrxDP else '0'; -- not using last mem loc to simplify
	BuffFullxSO <= FIFOFullxS;
	-- no safeguard against overwriting last mem location (if FIFO is allowed to fill up, we'll have discontinuities
	-- in the datastream anyhow)
	FIFOWrAddrxDN <= FIFOWrAddrxDP when (ParDatRdyxSI = '0' or FIFOFullxS = '1') else
					FIFOWrAddrxDP +1;
	FIFOBytesAvailableFullxD <= FIFOWrAddrxDP - FIFORdAddrxDP;
	FIFOBytesAvailableLtdxD <= FIFOBytesAvailableFullxD(7 downto 0) when FIFOBytesAvailableFullxD < 256 else
								(others => '1');
	
	CSnxSN <= CSnxSI;
	SCKSRegxSN(0) <= SCKxSI;
	SCKSRegxSN(1) <= SCKSRegxSP(0);
	
	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StatexDP <= sIdle;
			FIFOWrAddrxDP <= (others => '0');
			FIFORdAddrxDP <= (others => '0');
			TxSRegxDP  <= (others => '0');
			CSnxSP <= '1';
			SCKSRegxSP <= (others => '0');
			BitCntxDP <= 0;
			
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			FIFOWrAddrxDP <= FIFOWrAddrxDN;
			FIFORdAddrxDP <= FIFORdAddrxDN;
			TxSRegxDP <= TxSRegxDN;
			CSnxSP <= CSnxSN;
			SCKSRegxSP <= SCKSRegxSN;
			BitCntxDP <= BitCntxDN;
			
		end if;
	end process;
	
	p_memless : process (StatexDP, CSnxSP, SCKSRegxSP, BitCntxDP, FIFORdAddrxDP, FIFOEmptyxS, 
						FIFOBytesAvailableLtdxD, FIFOOutDataxD, TxSRegxDP)
	begin
		MISOxDO <= 'Z';
		TxSRegxDN <= TxSRegxDP;
		BitCntxDN <= BitCntxDP;
		FIFORdAddrxDN <= FIFORdAddrxDP;
		StatexDN <= StatexDP;
		case StatexDP is 
			when sIdle =>
				TxSRegxDN <= std_logic_vector(FIFOBytesAvailableLtdxD);
				BitCntxDN <= 0;
				if CSnxSP = '0' then
					StatexDN <= sTxByteCount;
				end if;
			when sTxByteCount =>
				MISOxDO <= TxSRegxDP(7);
				if CSnxSP = '1' then
					StatexDN <= sIdle;
				elsif SCKSRegxSP = "10" then -- falling edge
					if BitCntxDP >= 7 then
						TxSRegxDN <= FIFOOutDataxD;
						BitCntxDN <= 0;
						StatexDN <= sTxData;
					else -- shift out
						TxSRegxDN <= std_logic_vector(shift_left(unsigned(TxSRegxDP), 1));
						BitCntxDN <= BitCntxDP +1;
					end if;
				end if;
			when sTxData =>
				MISOxDO <= TxSRegxDP(7);
				if CSnxSP = '1' then
					StatexDN <= sIdle;
				elsif SCKSRegxSP = "10" then -- falling edge
					if BitCntxDP >= 7 then
						TxSRegxDN <= FIFOOutDataxD;
						BitCntxDN <= 0;
					else -- shift out
						TxSRegxDN <= std_logic_vector(shift_left(unsigned(TxSRegxDP), 1));
						BitCntxDN <= BitCntxDP +1;
					end if;
					-- current addr has been loaded in SReg
					-- prepare next data
					if BitCntxDP = 1 and FIFOEmptyxS = '0' then
						FIFORdAddrxDN <= FIFORdAddrxDP +1;
					end if;
				end if;
			when others =>
				StatexDN <= sIdle;
		end case;
	end process;


	-- component instances
	spi_txrx_ram_inst : spi_txrx_ram
    port map (
		DataInA(7 downto 0) => ParDatxDI, 
		DataInB(7 downto 0) => (others => '0'), 
		AddressA(9 downto 0) => std_logic_vector(FIFOWrAddrxDP), 
        AddressB(9 downto 0) => std_logic_vector(FIFORdAddrxDP), 
		ClockA => ClkxCI, 
		ClockB => ClkxCI, 
		ClockEnA => '1', 
        ClockEnB => '1', 
		WrA => ParDatRdyxSI, 
		WrB => '0', 
		ResetA => ResetxRI, 
		ResetB => ResetxRI, 
		QA(7 downto 0) => DUMMY_A, 
        QB(7 downto 0) => FIFOOutDataxD
	);

end behavioral;