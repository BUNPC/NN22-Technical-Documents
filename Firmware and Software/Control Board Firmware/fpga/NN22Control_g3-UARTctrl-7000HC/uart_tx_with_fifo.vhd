-- Firmware for NN22_ControlBoard00
-- UART transmitter with FIFO

-- Initial version: 2022-12-27
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx_with_fifo is
	generic (
		TX_CLK_DIV : integer := 16 -- 96/16 = 6 MBPS
	);
	port (
		ClkxCI 	 	: in std_logic;
		ResetxRI 	: in std_logic;
		CTSnxSI		: in std_logic;
		SerDatxDO 	: out std_logic;
		BuffFullxSO	: out std_logic;
		BuffEmptyxSO: out std_logic;
		ParDatRdyxSI : in std_logic;
		ParDatxDI 	: in std_logic_vector(7 downto 0)
	);
end uart_tx_with_fifo;

architecture behavioral of uart_tx_with_fifo is
	type fsmstatetype is (sIdle, sLoad, sRead, sTxBits, sTxStop);
	signal StatexDP, StatexDN : fsmstatetype;
	
	signal FIFORdEnxS, FIFOEmptyxS : std_logic;
	signal FIFODataxD : std_logic_vector(7 downto 0);
	signal SRegxDP, SRegxDN  : std_logic_vector(8 downto 0);
	signal SerDatxDP, SerDatxDN : std_logic;
	
	signal ClkCntxDP, ClkCntxDN : integer range 0 to TX_CLK_DIV-1;
	signal BitCntxDP, BitCntxDN: integer range 0 to 8;
	
	signal CTSnSRegxDP, CTSnSRegxDN : std_logic_vector(2 downto 0);
	
	component uart_fifo
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
	
	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then 
			StatexDP <= sIdle;
			ClkCntxDP <= 0;
			BitCntxDP <= 0;
			SRegxDP <= (others => '0');
			SerDatxDP <= '0';
			CTSnSRegxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			ClkCntxDP <= ClkCntxDN;
			BitCntxDP <= BitCntxDN;
			SRegxDP <= SRegxDN;
			SerDatxDP <= SerDatxDN;
			CTSnSRegxDP <= CTSnSRegxDN;
		end if;  
	end process;
	
	CTSnSRegxDN <= CTSnxSI & CTSnSRegxDP(CTSnSRegxDP'high downto 1);
	SerDatxDO <= SerDatxDP;
	
	p_memless : process(StatexDP, ClkCntxDP, BitCntxDP, SRegxDP, FIFODataxD, FIFOEmptyxS, CTSnSRegxDP)
	begin
		StatexDN <= StatexDP;
		ClkCntxDN <= ClkCntxDP +1;
		BitCntxDN <= BitCntxDP;
		SerDatxDN <= '1';
		FIFORdEnxS <= '0';
		SRegxDN <= SRegxDP;
		case StatexDP is
			when sIdle =>
				if FIFOEmptyxS = '0' and CTSnSRegxDP(0) = '0' then
					StatexDN <= sLoad;
				end if;
			when sLoad =>
				FIFORdEnxS <= '1';
				StatexDN <= sRead;
			when sRead => 
				ClkCntxDN <= 0;
				BitCntxDN <= 0;
				SRegxDN <= FIFODataxD & '0';
				StatexDN <= sTxBits;
			when sTxBits =>
				SerDatxDN <= SRegxDP(0);
				if ClkCntxDP = TX_CLK_DIV-1 then
					ClkCntxDN <= 0;
					BitCntxDN <= BitCntxDP +1;
					SRegxDN <= SRegxDP(8) & SRegxDP(8 downto 1); -- right shift
					if BitCntxDP = 8 then
						StatexDN <= sTxStop;
					end if;
				end if;
			when sTxStop =>
				if ClkCntxDP = TX_CLK_DIV-1 then
					StatexDN <= sIdle;
				end if;
			when others =>
				StatexDN <= sIdle;
		end case;
   end process;
   

	uart_fifo_inst : uart_fifo
    port map (
		Data(7 downto 0)=> ParDatxDI, 
		WrClock=> ClkxCI, 
		RdClock=> ClkxCI, 
		WrEn=> ParDatRdyxSI, 
        RdEn=> FIFORdEnxS, 
		Reset=> ResetxRI, 
		RPReset=> ResetxRI, 
		Q(7 downto 0)=> FIFODataxD, 
		Empty=> FIFOEmptyxS, 
        Full=> BuffFullxSO, 
		AlmostEmpty=> BuffEmptyxSO, 
		AlmostFull=> open
	);
	
end behavioral;