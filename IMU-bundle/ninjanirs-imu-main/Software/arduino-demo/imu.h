// imu.h - header for ISM330DHCX
// mostly swiped from BZ example code

#include <stdint.h>

extern const uint8_t ACC_ADDR;
extern const uint8_t ACC_WHO_AM_I_ADDR;
extern const uint8_t ACC_WHO_AM_I_VAL;
extern const uint8_t ACC_CTRL3_C_ADDR;
extern const uint8_t ACC_CTRL3_C_VAL;
extern const uint8_t ACC_CTRL1_XL_ADDR;
extern const uint8_t ACC_CTRL1_XL_VAL;
extern const uint8_t ACC_CTRL2_G_VAL;
extern const uint8_t ACC_OUT_TEMP_L_ADDR;
extern const uint8_t ACC_CTRL5_C_ADDR;

// scaling factors and offsets (N/A in AVR)
// extern const float ACC_ACCEL_SCF;
// extern const float ACC_GYRO_SCF;
// extern const float ACC_TEMP_SCF;
// extern const float ACC_TEMP_OFFSET;

// function declarations
int acc_set_self_test(int8_t st_val);
int read_acc_raw(uint8_t res_buf[14]);
int read_acc(int16_t res_buf[7]);
int init_acc();

