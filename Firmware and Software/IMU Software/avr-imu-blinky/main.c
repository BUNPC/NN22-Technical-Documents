/*
 * blinky example
 */

#include <stdio.h>
#include <avr/io.h>
#include <util/delay.h>

// Arduino LED is on PB5

#define LED_DDR DDRC
#define LED_BIT 3
#define LED_PORT PORTC

int main (void)
{

  LED_DDR |= (1 << LED_BIT);

  while( 1) {
    LED_PORT |= (1 << LED_BIT);
    _delay_ms( 500);
    LED_PORT &= ~(1 << LED_BIT);
    _delay_ms( 500);
  }
}


