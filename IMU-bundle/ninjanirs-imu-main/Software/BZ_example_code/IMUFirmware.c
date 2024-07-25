// Supporting RP2040 firmware for NinjaNIRS2022 Control Board

// Initial version: 2023-3-3
// Bernhard Zimmermann - bzim@bu.edu
// Boston University Neurophotonics Center

// This firmware will read the output of an ISM330DHCX 6DOF IMU connected
// to a QWIIC port on the Control Board, and will then forward it to the FPGA.
// It behaves similar to a NN22 detector adapter card.

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/i2c.h"
#include "hardware/pll.h"
#include "hardware/clocks.h"
#include "hardware/watchdog.h"


const uint LED_R_PIN = 5;
const uint LED_G_PIN = 4;

const uint FAN_PWR_PIN = 3;

// FPGA interface pins
const uint UART_TX_PIN = 12;
const uint UART_RX_PIN = 13;
const uint BOARD_SELECT_PIN = 14;  //CTS flow control
const uint END_CYC_PIN = 15;
//const uint TRG_STATUS_PIN = 16;

// Qwiic RPiP1 port
const uint I2C1_SDA_PIN = 10;
const uint I2C1_SCL_PIN = 11;
#define ACC_I2C i2c1

// Address of ISM330DHCX 6DOF IMU
// 0x6A if SA0 = low, 0x6B if SA0 = high
// (SA0 pin on sparkfun board is pulled high by default)
const uint8_t ACC_ADDR= 0x6B;
const uint8_t ACC_WHO_AM_I_ADDR = 0x0F;
const uint8_t ACC_WHO_AM_I_VAL = 0x6B;
const uint8_t ACC_CTRL3_C_ADDR = 0x12; 
const uint8_t ACC_CTRL3_C_VAL = 0x03; // software reset
const uint8_t ACC_CTRL1_XL_ADDR = 0x10;
const uint8_t ACC_CTRL1_XL_VAL = 0b01111000; //accel ODR (833Hz) and FS (+-4g)
const uint8_t ACC_CTRL2_G_VAL = 0b01110000; //gyro ODR (833Hz) and FS (+-250dps)
const uint8_t ACC_OUT_TEMP_L_ADDR = 0x20; //start of output registers
const uint8_t ACC_CTRL5_C_ADDR = 0x14;

// scaling factors and offsets
// const float ACC_ACCEL_SCF = 4.0/(2<<14);
// const float ACC_GYRO_SCF = 250.0/(2<<14);
// const float ACC_TEMP_SCF = 1.0/256;
// const float ACC_TEMP_OFFSET = 25.0;

// function declarations
int acc_set_self_test(int8_t st_val);
int read_acc_raw(uint8_t res_buf[14]);
int read_acc(int16_t res_buf[7]);
int init_acc();

int main()
{
    uint8_t loop_cnt = 0;
    uint8_t acc_res[14];
    int res;
    bool acc_connected = false;

    bool end_cyc_last = false;
	bool end_cyc_curr;
    bool startup_phase = true;
	uint8_t cyc_cnt = 0;
	const uint8_t PKT_HEADER[] = {249, 248};

    // Change system clock to 96 MHz to run at the same frequency as the FPGA and 
    // other RP2040s in the system.
    // 96 MHz allows us to get an exact baud rate of 6MBPS.
    /*
	$ python pll_divs.py 96
	Requested: 96.0 MHz
	Achieved: 96.0 MHz
	FBDIV: 128 (VCO = 1536 MHz)
	PD1: 4
	PD2: 4
	*/
	clock_stop(clk_peri);
	clock_configure(clk_sys,
					CLOCKS_CLK_SYS_CTRL_SRC_VALUE_CLK_REF,
					0,
					12 * MHZ,
					12 * MHZ);
	pll_deinit(pll_sys);
	pll_init(pll_sys, 1, 1536 * MHZ, 4, 4);
	clock_configure(clk_sys,
					CLOCKS_CLK_SYS_CTRL_SRC_VALUE_CLKSRC_CLK_SYS_AUX,
					CLOCKS_CLK_SYS_CTRL_AUXSRC_VALUE_CLKSRC_PLL_SYS,
					96 * MHZ,
					96 * MHZ);
	clock_configure(clk_peri,
					0,
					CLOCKS_CLK_PERI_CTRL_AUXSRC_VALUE_CLKSRC_PLL_SYS,
					96 * MHZ,
					96 * MHZ);

    stdio_init_all();

    // Init LED pins
    gpio_init(LED_R_PIN);
    gpio_set_dir(LED_R_PIN, GPIO_OUT);
    gpio_init(LED_G_PIN);
    gpio_set_dir(LED_G_PIN, GPIO_OUT);

    gpio_init(END_CYC_PIN); //input

    gpio_put(LED_R_PIN, 1);
    sleep_ms(250);
    gpio_put(LED_R_PIN, 0);

    // Turn Fan on
    gpio_init(FAN_PWR_PIN);
    gpio_set_dir(FAN_PWR_PIN, GPIO_OUT);
    gpio_put(FAN_PWR_PIN, 1);

    // Enable watchdog timer
    //watchdog_enable(500, true); //500 ms
    
    // UART initialisation
	uart_init(uart0, 6000000);
	uart_set_hw_flow(uart0, true, false); // enable CTS (tx flow control)
	gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
	gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
	gpio_set_function(BOARD_SELECT_PIN, GPIO_FUNC_UART);

    // I2C initialisation. Using it at 200Khz.
    i2c_init(ACC_I2C, 200*1000);
    gpio_set_function(I2C1_SDA_PIN, GPIO_FUNC_I2C);
    gpio_set_function(I2C1_SCL_PIN, GPIO_FUNC_I2C);
    gpio_pull_up(I2C1_SDA_PIN);
    gpio_pull_up(I2C1_SCL_PIN);

    // Main Loop
    while (true) {
        // Accelerometer init or reconnect
        if (!acc_connected){
            res = init_acc();
            if (res==PICO_ERROR_GENERIC){ // Accelerometer not connected or not replying.
                gpio_put(LED_R_PIN, 1);
                sleep_us(100);
            } else {
                gpio_put(LED_R_PIN, 0);
                acc_connected = true;
            }
        }

        end_cyc_curr = gpio_get(END_CYC_PIN);
        if (end_cyc_curr == 1 && end_cyc_last == 0) { // FPGA requesting result
            if (acc_connected){
                // write results into uart fifo
                uart_write_blocking(uart0, PKT_HEADER, 2);
                uart_putc_raw(uart0, (char)cyc_cnt);
                uart_write_blocking(uart0, acc_res, 14);
                uart_putc_raw(uart0, 0); //possibly tx crc in future
                gpio_put(LED_G_PIN, 1);
            }
			
            gpio_put(LED_R_PIN, 0);
            
            // get new result from IMU
            res = read_acc_raw(acc_res);
            if (res==PICO_ERROR_GENERIC){ // Accelerometer not replying
                acc_connected = false;
                for (int ii=0; ii<14; ii++){
                    acc_res[ii] = 0;
                }
                gpio_put(LED_R_PIN, 1);
            }

            // use first few samples after reboot to test the accelerometer
            if (startup_phase){
                if (cyc_cnt==10){
                    acc_set_self_test(-1);
                } else if (cyc_cnt==20){
                    acc_set_self_test(1);
                } else if (cyc_cnt>=30) {
                    acc_set_self_test(0);
                    startup_phase = false;
                }
            }
            gpio_put(LED_G_PIN, 0);
			cyc_cnt += 1;
		}
		end_cyc_last = end_cyc_curr;
        //watchdog_update();
    }

    return 0;
}

int acc_set_self_test(int8_t st_val)
{
    // this function enables the accelerometer and gyro self test
    // st_val = -1: negative self test
    // st_val = 0: self_test off
    // st_val = 1: positive self test

    uint8_t buf[2];

    buf[0] = ACC_CTRL5_C_ADDR;
    if (st_val==-1) { // negative self-test
        buf[1] = 0b00001110;
    } else if (st_val==1) { // positive self-test
        buf[1] = 0b00000101;
    } else { // normal mode (self-test off)
        buf[1] = 0;
    }
    i2c_write_blocking(ACC_I2C, ACC_ADDR, buf, 2, false);
    return 0;
}

int read_acc_raw(uint8_t res_buf[14])
{
    // this function reads temperature, accelerometer, and gyro data into res_buf
    i2c_write_blocking(ACC_I2C, ACC_ADDR, &ACC_OUT_TEMP_L_ADDR, 1, true);
    return i2c_read_blocking(ACC_I2C, ACC_ADDR, res_buf, 14, false);
}

int init_acc()
{
    // this fuction resets and initializes the ISM330DHCX IMU

    int res = 0;
    uint8_t buf[3];

    // check whether "who am i" register is ok
    res = i2c_write_blocking(ACC_I2C, ACC_ADDR, &ACC_WHO_AM_I_ADDR, 1, true);
    if (res==PICO_ERROR_GENERIC) { // acc not replying to I2C address/command
        return PICO_ERROR_GENERIC;
    } else {
        i2c_read_blocking(ACC_I2C, ACC_ADDR, buf, 1, false);
        if (buf[0]!=ACC_WHO_AM_I_VAL){ // not the correct model connected
            return PICO_ERROR_GENERIC;
        }
    }  

    // reset the acc
    buf[0] = ACC_CTRL3_C_ADDR;
    buf[1] = ACC_CTRL3_C_VAL;
    i2c_write_blocking(ACC_I2C, ACC_ADDR, buf, 2, false);
    sleep_us(200);

    // config acc
    buf[0] = ACC_CTRL1_XL_ADDR;
    buf[1] = ACC_CTRL1_XL_VAL;
    buf[2] = ACC_CTRL2_G_VAL;
    i2c_write_blocking(ACC_I2C, ACC_ADDR, buf, 3, false);

    //read back and verify
    buf[0]=0;
    buf[1]=0;
    i2c_write_blocking(ACC_I2C, ACC_ADDR, &ACC_CTRL1_XL_ADDR, 1, true);
    i2c_read_blocking(ACC_I2C, ACC_ADDR, buf, 2, false);
    if (buf[0]!=ACC_CTRL1_XL_VAL || buf[1]!=ACC_CTRL2_G_VAL){
        return PICO_ERROR_GENERIC;
    }

    return 0;
}
