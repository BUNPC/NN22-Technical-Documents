#include <stdint.h>
#include <avr/io.h>

void blink_binary( uint8_t v);
void blink_led( int count, int ms);

#ifdef AVR_TARGET

#define LED_DDR DDRC
#define LED_BIT 3
#define LED_PORT PORTC

#else

// Arduino LED is on PB5
#define LED_DDR DDRB
#define LED_BIT 5
#define LED_PORT PORTB
#endif

