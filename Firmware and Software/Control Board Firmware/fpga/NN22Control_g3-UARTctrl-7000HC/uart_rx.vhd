-- Firmware for NN22_ControlBoard00
-- UART receiver

-- Initial version: 2022-12-27
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
	generic (
		RX_CLK_DIV : integer := 16  -- 96/16 = 6 MBPS
	);
	port (
		ClkxCI		: in std_logic;
		ResetxRI 	: in std_logic;
		SerDatxDI	: in std_logic;
		ParDatxDO	: out std_logic_vector(7 downto 0);
		ParDatRdyxSO : out std_logic;
		DebugxSO	: out std_logic
	);
end uart_rx;

architecture behavioral of uart_rx is
	constant START_BIT_CLKS : integer := (RX_CLK_DIV * 3/2) +1;

	type fsmstatetype is (sIdle, sStart, sRead, sPDRdy, sStop);
	signal StatexDP, StatexDN : fsmstatetype;

	signal InSRegxDP, InSRegxDN : std_logic_vector(2 downto 0);
	signal ParDatSRegxDP, ParDatSRegxDN : std_logic_vector(7 downto 0);
	
	signal ClkCntxDP, ClkCntxDN : integer range 0 to START_BIT_CLKS-1;
	signal BitCntxDP, BitCntxDN: integer range 0 to 7;
begin
	ParDatxDO <= ParDatSRegxDP;

	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StatexDP <= sIdle;
			ClkCntxDP <= 0;
			BitCntxDP <= 0;
			--		 ParDatORegxDP <= ParDatORegxDN;
			ParDatSRegxDP <= (others => '0');
			InSRegxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			ClkCntxDP <= ClkCntxDN;
			BitCntxDP <= BitCntxDN;
			--	ParDatORegxDP <= ParDatORegxDN;
			ParDatSRegxDP <= ParDatSRegxDN;
			InSRegxDP <= InSRegxDN;
		end if;
	end process;
	
	-- synchronizer registers
	InSRegxDN <= SerDatxDI & InSRegxDP(InSRegxDP'high downto 1);

	p_memless : process(StatexDP, ClkCntxDP, BitCntxDP, ParDatSRegxDP, InSRegxDP)
	begin
		ClkCntxDN <= ClkCntxDP -1;
		BitCntxDN <= BitCntxDP;
		ParDatSRegxDN <= ParDatSRegxDP;
		ParDatRdyxSO <= '0';
		DebugxSO <= '0';
		StatexDN <= StatexDP;
		case StatexDP is
			when sIdle =>
				DebugxSO <= '1';
				if InSRegxDP(0) = '0' then 
					StatexDN <= sStart;
				end if;
			when sStart =>
				ClkCntxDN <= START_BIT_CLKS-1;
				BitCntxDN <= 7;
				StatexDN <= sRead;
			when sRead =>
				if ClkCntxDP = 0 then
					ClkCntxDN <= RX_CLK_DIV -1;
					BitCntxDN <= BitCntxDP -1;
					ParDatSRegxDN <= InSRegxDP(0) & ParDatSRegxDP(7 downto 1);
					DebugxSO <= '1';
					if BitCntxDP = 0 then
						StatexDN <= sPDRdy;
					end if;
				end if;
			when sPDRdy =>
				ParDatRdyxSO <= '1';
				StatexDN <= sStop;
			when sStop =>
				--DebugxSO <= '1';
				if ClkCntxDP = 0 then
					StatexDN <= sIdle;
				end if;
			when others =>
		end case;
   end process;

end behavioral;