/*
 * main.c - main program for AVR IMU readout
 * 
 * blink the led with a duty cycle corresponding to IMU data from Z
 */

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <avr/io.h>
#include <util/delay.h>
#include "i2c.h"

#include "imu.h"
#include "imu_const.h"

void blink_led( int count, int ms);
void blink_binary( uint8_t v);

#define LED_DDR DDRC
#define LED_BIT 3
#define LED_PORT PORTC

// dummy data for testing
static int16_t acc_test[] = { 1111, 2222, 3333, 4444, 5555, 6666, 7777 };

int main (void)
{
  uint8_t loop_cnt = 0;
  int16_t acc_res[7];
  int res;
  bool acc_connected = false;

  // activate internal pull-ups on I2C pins
  PORTC |= ((1 << 4) | (1 << 5));

  i2c_init( BDIV);		/* initialize I2C */

  LED_DDR |= (1 << LED_BIT);

  while ( true) {

    blink_led( 1, 100);		/* single blink on start */
    _delay_ms( 500);

    // Accelerometer init
    while (!acc_connected){
      blink_led( 2, 100);	/* two blinks if not connected */
      _delay_ms( 500);
      res = init_acc();
      blink_binary( res);
      _delay_ms( 500);

      if (res) {      		/* error return */
	acc_connected = false;
	blink_led( 5, 100);
      } else {
	acc_connected = true;
	blink_led( 1, 100);
      }
    }
    _delay_ms( 500);

    res = read_acc(acc_res);
    if (res){    		/* error return */
      blink_led( 5, 100);
      _delay_ms( 500);
      blink_binary( res);
      acc_connected = false;
    }

    blink_binary( acc_res[6] >> 8);

    _delay_ms( 1000);
  }

}


void delay_count_ms( int n) {
  for( int i=0; i<n; i++)
    _delay_ms(1);
}

//
// blink the LED count times with delay between in ms
//
void blink_led( int count, int ms) {
  for( int i=0; i<count; i++) {
    LED_PORT |= (1 << LED_BIT);
    delay_count_ms( ms);
    LED_PORT &= ~(1 << LED_BIT);
    delay_count_ms( ms);
  }
}

#define PERI_MS 500
#define LONG_MS 250
#define SHORT_MS 100


void long_flash() {
    LED_PORT |= (1 << LED_BIT);
    delay_count_ms( LONG_MS);
    LED_PORT &= ~(1 << LED_BIT);
    delay_count_ms( PERI_MS-LONG_MS);
}

void short_flash() {
    LED_PORT |= (1 << LED_BIT);
    delay_count_ms( SHORT_MS);
    LED_PORT &= ~(1 << LED_BIT);
    delay_count_ms( PERI_MS-SHORT_MS);
}

//
// blink a long/short binary LED value
// MSB first
//
void blink_binary( uint8_t v) {
  uint8_t bv = 0x80;		/* start with MSB */
  uint8_t bn;

  for( bn=0; bn<8; bn++) {
    if( v & bv)
      long_flash();
    else
      short_flash();
    bv >>= 1;
  }
}
