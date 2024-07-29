// i2c.h - header for i2c functions
// TWI bit rate defined here too

#include <stdint.h>

#define BDIV (F_CPU / 100000 - 16) / 2 + 1    // Puts I2C rate just below 100kHz
// above doesn't work for 1MHz clock!

// #define BDIV (F_CPU / 10000 - 16) / 2 + 1    // Puts I2C rate just below 10kHz


void i2c_init(uint8_t adr);
uint8_t i2c_io(uint8_t adr, uint8_t *wp, uint16_t wn, uint8_t *rp, uint16_t rn);
