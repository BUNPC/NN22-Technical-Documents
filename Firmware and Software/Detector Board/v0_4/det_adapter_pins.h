// ---  NinjaNIRS 2022  ---
// Pin constants for NN22_RPi_DetAdapter00_s02_R66R67 board
//
// Initial version: 2022-12-12
// Major revision: 2024-04-14 (2 wire ADC read)
// Bernhard Zimmermann - bzim@bu.edu
// Boston University Neurophotonics Center
//


// Backplane pins: GPIO00 - GPIO06
const uint UART_TX_PIN = 0;
const uint UART_RX_PIN = 1;
const uint BOARD_SELECT_PIN = 2;
//const uint TRG_PIN = 3; // check also adcacq_msin.pio
const uint END_CYC_PIN = 4;
const uint STATUS_SELECT_PIN = 5;
const uint RESERVED_PIN = 6;

// Misc Pins
const uint LED_PIN = 7;
const uint OPT_EN_VP_PIN = 8;
const uint OPT_EN_VN_PIN = 9;

// ADC pins
// 4 ADCs with dual-data SPI interface
const uint CSN_A3_PIN = 12;
const uint SCLK_A3_PIN = 13;
const uint MOSI_A3_PIN = 14;
const uint MISO_A3_PIN = 15;
const uint MISOB_A3_PIN = 11;
 
const uint CSN_A1_PIN = 16;
const uint SCLK_A1_PIN = 17;
const uint MOSI_A1_PIN = 18;
const uint MISO_A1_PIN = 20;
const uint MISOB_A1_PIN = 19;

const uint CSN_A4_PIN = 21;
const uint SCLK_A4_PIN = 22;
const uint MOSI_A4_PIN = 23;
const uint MISO_A4_PIN = 24;
const uint MISOB_A4_PIN = 10;

const uint CSN_A2_PIN = 25;
const uint SCLK_A2_PIN = 26;
const uint MOSI_A2_PIN = 27;
const uint MISO_A2_PIN = 29;
const uint MISOB_A2_PIN = 28;

// Map adc results to detectors
const uint DET_ADC_MAP[] = {1, 0, 4, 5, 3, 2, 6, 7};
