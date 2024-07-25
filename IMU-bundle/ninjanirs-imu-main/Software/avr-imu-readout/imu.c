// imu.c - IMU functions stolen mostly from BZ
//
// re-written a bit to use the unified i2c_io function
// from USC EE459
//

#include "i2c.h"
#include "imu.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <util/delay.h>

#ifdef DEBUG
#include <stdio.h>
#endif

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
  // i2c_write_blocking(ACC_I2C, ACC_ADDR, buf, 2, false);
  i2c_io( ACC_ADDR, buf, 2, NULL, 0);
  return 0;
}

int read_acc_raw(uint8_t res_buf[14])
{
  // this function reads temperature, accelerometer, and gyro data into res_buf
//  i2c_write_blocking(ACC_I2C, ACC_ADDR, &ACC_OUT_TEMP_L_ADDR, 1, true);
//  return i2c_read_blocking(ACC_I2C, ACC_ADDR, res_buf, 14, false);
  int rc = i2c_io( ACC_ADDR, &ACC_OUT_TEMP_L_ADDR, 1, res_buf, 14);
  return rc;
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
//  res = i2c_write_blocking(ACC_I2C, ACC_ADDR, &ACC_WHO_AM_I_ADDR, 1, true);
//  if (res==PICO_ERROR_GENERIC) { // acc not replying to I2C address/command
//    return PICO_ERROR_GENERIC;
//  } else {
//    i2c_read_blocking(ACC_I2C, ACC_ADDR, buf, 1, false);
//    if (buf[0]!=ACC_WHO_AM_I_VAL){ // not the correct model connected
//      return PICO_ERROR_GENERIC;
//    }
//  }  
  res = i2c_io( ACC_ADDR, &ACC_WHO_AM_I_ADDR, 1,
		buf, 1);
#ifdef DEBUG
    printf("init1 res=0x%x\n", res);
#endif    
  if( res) {
    return res;
  }

  // reset the acc
  buf[0] = ACC_CTRL3_C_ADDR;
  buf[1] = ACC_CTRL3_C_VAL;
  //  i2c_write_blocking(ACC_I2C, ACC_ADDR, buf, 2, false);
  res = i2c_io( ACC_ADDR, buf, 2, NULL, 0);
#ifdef DEBUG
  printf("init2 res=0x%x\n", res);
#endif    
  //  sleep_us(200);
  _delay_us(200);

  // config acc
  buf[0] = ACC_CTRL1_XL_ADDR;
  buf[1] = ACC_CTRL1_XL_VAL;
  buf[2] = ACC_CTRL2_G_VAL;
  //  i2c_write_blocking(ACC_I2C, ACC_ADDR, buf, 3, false);
  res = i2c_io( ACC_ADDR, buf, 3, NULL, 0);
#ifdef DEBUG
  printf("init3 res=0x%x\n", res);
#endif    

  //read back and verify
  buf[0]=0;
  buf[1]=0;
  //  i2c_write_blocking(ACC_I2C, ACC_ADDR, &ACC_CTRL1_XL_ADDR, 1, true);
  //  i2c_read_blocking(ACC_I2C, ACC_ADDR, buf, 2, false);
  res=i2c_io( ACC_ADDR, &ACC_CTRL1_XL_ADDR, 1, buf, 2);
#ifdef DEBUG
  printf("init4 res=0x%x\n", res);
#endif    
  if (buf[0]!=ACC_CTRL1_XL_VAL || buf[1]!=ACC_CTRL2_G_VAL){
#ifdef DEBUG
    printf("buf= %x %x expect %x %x\n", buf[0], buf[1], ACC_CTRL1_XL_VAL, ACC_CTRL2_G_VAL);
#endif    
    //    return PICO_ERROR_GENERIC;
    return -1;
  }

  return 0;
}
