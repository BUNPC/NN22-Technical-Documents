-- Firmware for NN22_ControlBoard00
-- Auxillary ADC readout
-- This component reads the ADS7886 analog to digital converters used
-- for auxillary analog inputs. It also samples the aux digital inputs
-- from the remote trigger receiver and MMCX digital input.

-- Initial version: 2023-3-7
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
--library MACHXO2;
--use MACHXO2.components.all;

entity aux_adc_rx is
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
end aux_adc_rx;

architecture aux_adc_rx_behavior of aux_adc_rx is
	constant CLK_PERIODS_PER_SCK : integer := 8; -- 96/8 = 12 MHz; ADC max: 20 MHz
	constant N_ADC : integer := 2;
	constant N_BYTES_PER_SAMPLE : integer := 3;
	constant PACKET_HEADER : std_logic_vector(DataxDO'range) := std_logic_vector(to_unsigned(250, 8));
	
	signal AcqTrgLastxSP, AcqTrgLastxSN : std_logic;
	signal TxTrgLastxSP, TxTrgLastxSN : std_logic;
	
	signal ClkCntxDP, ClkCntxDN: integer range 0 to (CLK_PERIODS_PER_SCK/2)-1;
	signal BitCntxDP, BitCntxDN: integer range 0 to maximum(15,N_BYTES_PER_SAMPLE*N_ADC-1);
	
	type fsmstatetype is (sIdle, sAcqCSlow, sAcqCSlow2, sAcqSCKlow, sAcqShiftIn, sAcqSCKhigh, sAcqComplete, 
						sTxHeader, sTxDigitalInputs, sTxData, sTxShiftOut);
	signal StatexDP, StatexDN : fsmstatetype;	
	
	type AUX_ADC_SReg_Array_Type is array (0 to N_ADC-1) of unsigned(11 downto 0);
	signal ADCSregxDP, ADCSregxDN : AUX_ADC_SReg_Array_Type;
	type AUX_ADC_Acc_Array_Type is array (0 to N_ADC-1) of unsigned((N_BYTES_PER_SAMPLE*8 -1) downto 0);
	signal ADCAccxDP, ADCAccxDN : AUX_ADC_Acc_Array_Type;
	
	signal DigAuxxDP, DigAuxxDN : std_logic_vector(7 downto 0);
	
begin

	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StatexDP <= sIdle;
			AcqTrgLastxSP <= '0';
			TxTrgLastxSP <= '0';
			ClkCntxDP <= 0;
			BitCntxDP <= 0;
			ADCSregxDP <= (others => (others => '0'));
			ADCAccxDP <= (others => (others => '0'));
			DigAuxxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			AcqTrgLastxSP <= AcqTrgLastxSN;
			TxTrgLastxSP <= TxTrgLastxSN;
			ClkCntxDP <= ClkCntxDN;
			BitCntxDP <= BitCntxDN;
			ADCSregxDP <= ADCSregxDN;
			ADCAccxDP <= ADCAccxDN;
			DigAuxxDP <= DigAuxxDN;
		end if;
	end process;
	
	p_cfg_memless : process(StatexDP, ClkCntxDP, BitCntxDP, ADCSregxDP, ADCAccxDP, TxTrgxSI, TxTrgLastxSP, 
							DigAuxxDP, DataAckxSI, AcqTrgxSI, AcqTrgLastxSP, SDOxDI)
	begin
		CSnxSO <= '1';
		SCKxSO <= '1';
		ClkCntxDN <= ClkCntxDP;
		BitCntxDN <= BitCntxDP;
		ADCSregxDN <= ADCSregxDP;
		ADCAccxDN <= ADCAccxDP;
		DataxDO <= std_logic_vector(ADCAccxDP(0)(7 downto 0));
		DataRdyxSO <= '0';
		StatexDN <= StatexDP;
		case StatexDP is
			when sIdle =>
				ClkCntxDN <= 0;
				BitCntxDN <= 0;
				if TxTrgxSI = '1' and TxTrgLastxSP = '0' then
					StatexDN <= sTxHeader;
				elsif AcqTrgxSI = '1' and AcqTrgLastxSP = '0' then
					StatexDN <= sAcqCSlow;
				end if;
				
			-- States related to acquisition of samples from ADC
			when sAcqCSlow =>
				CSnxSO <= '0';
				BitCntxDN <= 0;
				StatexDN <= sAcqCSlow2;
			when sAcqCSlow2 =>
				CSnxSO <= '0';
				BitCntxDN <= 0;
				StatexDN <= sAcqSCKlow;
			when sAcqSCKlow =>
				CSnxSO <= '0';
				SCKxSO <= '0';
				ClkCntxDN <= ClkCntxDP +1;
				if ClkCntxDP >= (CLK_PERIODS_PER_SCK/2)-2 then
					StatexDN <= sAcqShiftIn;
				end if;
			when sAcqShiftIn =>
				CSnxSO <= '0';
				SCKxSO <= '0';
				if BitCntxDP <= 14 then -- last SCK rise not valid
					for I in 0 to N_ADC-1 loop
						ADCSregxDN(I) <= shift_left(ADCSregxDP(I),1);
						ADCSregxDN(I)(0) <= SDOxDI(I);
					end loop;
				end if;
				ClkCntxDN <= 0;
				StatexDN <= sAcqSCKhigh;
			when sAcqSCKhigh =>
				CSnxSO <= '0';
				SCKxSO <= '1';
				if BitCntxDP >= 15 then
					StatexDN <= sAcqComplete;
				elsif ClkCntxDP >= (CLK_PERIODS_PER_SCK/2)-1 then
					ClkCntxDN <= 0;
					BitCntxDN <= BitCntxDP +1;
					StatexDN <= sAcqSCKlow;
				else
					ClkCntxDN <= ClkCntxDP +1;
				end if;
			when sAcqComplete =>
				CSnxSO <= '1';
				SCKxSO <= '1';
				for I in 0 to N_ADC-1 loop
					ADCAccxDN(I) <= ADCAccxDP(I) + resize(ADCSregxDP(I),ADCAccxDP(I)'length);
				end loop;
				StatexDN <= sIdle;
			
			-- States related to transmission of results to higher level unit
			when sTxHeader =>
				DataxDO <= PACKET_HEADER;
				DataRdyxSO <= '1';
				BitCntxDN <= 0;
				if DataAckxSI = '1' then
					StatexDN <= sTxDigitalInputs;
				end if;
			when sTxDigitalInputs =>
				DataxDO <= DigAuxxDP;
				DataRdyxSO <= '1';
				BitCntxDN <= 0;
				if DataAckxSI = '1' then
					StatexDN <= sTxData;
				end if;
			when sTxData =>
				DataRdyxSO <= '1';
				if DataAckxSI = '1' then
					StatexDN <= sTxShiftOut;
				end if;
			when sTxShiftOut =>
				for I in 0 to N_ADC-2 loop
					ADCAccxDN(I) <= shift_right(ADCAccxDP(I),8);
					ADCAccxDN(I)((N_BYTES_PER_SAMPLE*8 -1) downto (N_BYTES_PER_SAMPLE-1)*8) 
						<= ADCAccxDP(I+1)(7 downto 0);
				end loop;
				ADCAccxDN(N_ADC-1) <= shift_right(ADCAccxDP(N_ADC-1),8);
				BitCntxDN <= BitCntxDP +1;
				if BitCntxDP >= N_ADC*N_BYTES_PER_SAMPLE -1 then
					StatexDN <= sIdle;
				else
					StatexDN <= sTxData;
				end if;
								
			when others =>
				StatexDN <= sIdle;
		end case;
	end process;
	
	AcqTrgLastxSN <= AcqTrgxSI;
	TxTrgLastxSN <= TxTrgxSI;
	DigAuxxDN <= DigAuxxDI;


end aux_adc_rx_behavior;