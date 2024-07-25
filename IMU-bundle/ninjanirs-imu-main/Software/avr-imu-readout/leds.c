//
// some functions to blink an LED
//
// assumes LED_BIT, LED_PORT set
//
// blink_led( count, ms) - blink count times for ms
// blink_binary( v)      - blink in long/short binary code msb first
//
#include "leds.h"
#include <util/delay.h>

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
