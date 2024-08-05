/*
 * main.c - essentially a port of BZ Accelerometer_demo
 * 
 */

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <avr/io.h>
#include <util/delay.h>
#include "uart.h"
#include "i2c.h"

#include "imu.h"
#include "imu_const.h"

// create a file pointer for read/write to USART0
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);

int main (void)
{
  uint8_t loop_cnt = 0;
  int16_t acc_res[7];
  int res;
  bool acc_connected = false;

  USART0Init();
  stdout = &usart0_str;		/* connect UART to stdout */
  stdin = &usart0_str;		/* connect UART to stdin */

  i2c_init( BDIV);		/* initialize I2C */

  puts("IMU test");

  while (true) {
    // Accelerometer init
    while (!acc_connected){
      res = init_acc();
      //      if (res==PICO_ERROR_GENERIC){
      if (res){      
	printf("Accelerometer not connected or not replying.\n");
	//	sleep_ms(250);
	_delay_ms(250);
      } else {
	acc_connected = true;
      }
    }

    // every few loops print column headers
    if (loop_cnt>=9){
      printf("Temp C   Gyro X   Gyro Y   Gyro Z  Accel X Accel Y Accel Z  \n");
      loop_cnt = 0;
    } else {
      loop_cnt++;
    }

    res = read_acc(acc_res);
    //    if (res==PICO_ERROR_GENERIC){
    if (res){    
      printf("Warning: Accelerometer not replying. Data not valid!\n");
      acc_connected = false;
    }

    // skip the floats on AVR
    for( int ii=0; ii<7; ii++)
      printf("%7d ", acc_res[ii]);
        
//    printf("%5.1fC ",acc_res[0]*ACC_TEMP_SCF+ACC_TEMP_OFFSET);
//    for (int ii = 0; ii < 3; ii++)
//      {
//	printf("%6.1fdps ", acc_res[ii+1]*ACC_GYRO_SCF);
//      }
//    printf("  ");
//    for (int ii = 0; ii < 3; ii++)
//      {
//	printf("%6.3fg  ", acc_res[ii+4]*ACC_ACCEL_SCF);
//      }
    printf("\n");

    _delay_ms(300);
  }

}


