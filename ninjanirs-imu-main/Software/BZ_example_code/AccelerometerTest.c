// Supporting RP2040 firmware for NinjaNIRS2022 Control Board

// Initial version: 2023-3-2
// Bernhard Zimmermann - bzim@bu.edu
// Boston University Neurophotonics Center

// This firmware will display the output of an ISM330DHCX 6DOF IMU connected
// to a QWIIC port on the Control Board.
// To see the output, connect a terminal to the virtual COM port of the Pico USB.

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/i2c.h"

//#define PICO_FLASH_SIZE_BYTES (16 * 1024 * 1024)

const uint LED_R_PIN = 5;
const uint LED_G_PIN = 4;

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
const uint8_t ACC_CTRL1_XL_VAL = 0b00011000; //accel ODR (12.5Hz) and FS (+-4g)
const uint8_t ACC_CTRL2_G_VAL = 0b00010000; //gyro ODR (12.5Hz) and FS (+-250dps)
const uint8_t ACC_OUT_TEMP_L_ADDR = 0x20; //start of output registers
const uint8_t ACC_CTRL5_C_ADDR = 0x14;

// scaling factors and offsets
const float ACC_ACCEL_SCF = 4.0/(2<<14);
const float ACC_GYRO_SCF = 250.0/(2<<14);
const float ACC_TEMP_SCF = 1.0/256;
const float ACC_TEMP_OFFSET = 25.0;

// function declarations
int acc_set_self_test(int8_t st_val);
int read_acc_raw(uint8_t res_buf[14]);
int read_acc(int16_t res_buf[7]);
int init_acc();

int main()
{
    uint8_t loop_cnt = 0;
    int16_t acc_res[7];
    int res;
    bool acc_connected = false;

    stdio_init_all();
    
    // I2C Initialisation. Using it at 200Khz.
    i2c_init(ACC_I2C, 200*1000);
    gpio_set_function(I2C1_SDA_PIN, GPIO_FUNC_I2C);
    gpio_set_function(I2C1_SCL_PIN, GPIO_FUNC_I2C);
    gpio_pull_up(I2C1_SDA_PIN);
    gpio_pull_up(I2C1_SCL_PIN);

    // Init LED pins
    gpio_init(LED_R_PIN);
    gpio_set_dir(LED_R_PIN, GPIO_OUT);
    gpio_init(LED_G_PIN);
    gpio_set_dir(LED_G_PIN, GPIO_OUT);

    while (true) {
        gpio_put(LED_R_PIN, 1);
        gpio_put(LED_G_PIN, 0);

        // Accelerometer init
        while (!acc_connected){
            res = init_acc();
            if (res==PICO_ERROR_GENERIC){
                printf("Accelerometer not connected or not replying.\n");
                sleep_ms(250);
            } else {
                acc_connected = true;
            }
        }

        // every few loops print column headers
        if (loop_cnt>=9){
            printf("Temp C    Gyro X    Gyro Y    Gyro Z   Accel X  Accel Y  Accel Z  \n");
            loop_cnt = 0;
        } else {
            loop_cnt++;
        }

        res = read_acc(acc_res);
        if (res==PICO_ERROR_GENERIC){
            printf("Warning: Accelerometer not replying. Data not valid!\n");
            acc_connected = false;
        }
        
        printf("%5.1fC ",acc_res[0]*ACC_TEMP_SCF+ACC_TEMP_OFFSET);
        for (int ii = 0; ii < 3; ii++)
        {
            printf("%6.1fdps ", acc_res[ii+1]*ACC_GYRO_SCF);
        }
        printf("  ");
        for (int ii = 0; ii < 3; ii++)
        {
            printf("%6.3fg  ", acc_res[ii+4]*ACC_ACCEL_SCF);
        }
        printf("\n");

        sleep_ms(20);
        gpio_put(LED_R_PIN, 0);
        gpio_put(LED_G_PIN, 1);       
        sleep_ms(300);
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

int read_acc(int16_t res_buf[7]){
    // this function reads temperature, accelerometer, and gyro data into res_buf
    uint8_t buf[14];
    int res;
    res = read_acc_raw(buf);
    for (int ii=0; ii<7; ii++){
        res_buf[ii] = (buf[ii * 2] | buf[(ii * 2) + 1]<<8 );
    }
    return res;
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
