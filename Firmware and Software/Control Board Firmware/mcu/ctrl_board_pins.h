// ---  NinjaNIRS 2022  ---
// Pin constants for ControlBoard02_v01 board
// This is the new control board with LCMXO2-7000HC FPGA.
//
// Initial version: 2024-04-19
// Bernhard Zimmermann - bzim@bu.edu
// Boston University Neurophotonics Center
//

// FPGA interface pins
const uint UART_TX_PIN = 12;
const uint UART_RX_PIN = 13;
const uint BOARD_SELECT_PIN = 14;  //CTS flow control
const uint END_CYC_PIN = 15;
const uint STATUS_SELECT_PIN = 16;
const uint RUN_IND_PIN = 17; // Run indicator input

// Qwiic RPiP1 port
const uint I2C1_SDA_PIN = 10;
const uint I2C1_SCL_PIN = 11;
#define ACC_I2C i2c1

// Misc Pins
const uint LED_R_PIN = 5;
const uint LED_G_PINS[] = {4, 3};
const uint BUTTON_PIN = 6;
const uint BUZZER_PIN = 7;
const uint FAN_PWR_PIN = 24;
const uint FAN_SENSE_PIN = 25;
const uint V12_CURR_SENSE_PIN = 26;
const uint V12_CURR_SENSE_ACH = 0;
const uint AUXIO_PINS[] = {29, 27};
const uint AUXIO_ACHS[] = {3, 1};
const uint VIN_SENSE_PIN = 28;
const uint VIN_SENSE_ACH = 2;
const uint TEMP_ACH = 4; // Internal temperature sensor virtual pin