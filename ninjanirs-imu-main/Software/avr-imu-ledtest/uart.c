//
// very simple UART functions
//

#include <stdio.h>
#include "uart.h"

// initialize the UART.  Baud rate set in uart.h
void USART0Init(void)
{
  // Set baud rate
  UBRR0H = (uint8_t)(UBRR_VALUE>>8);
  UBRR0L = (uint8_t)UBRR_VALUE;
  // Set frame format to 8 data bits, no parity, 1 stop bit
  UCSR0C |= (1<<UCSZ01)|(1<<UCSZ00);
  //enable transmission and reception
  UCSR0B |= (1<<RXEN0)|(1<<TXEN0);
}

// send a byte.  stream is provided for stdio compatibility
// and may be NULL
int USART0SendByte(char u8Data, FILE *stream)
{
#ifdef UART_COOKED
  if(u8Data == '\n')
    {
      USART0SendByte('\r', stream);
    }
#endif
  //wait while previous byte is completed
  while(!(UCSR0A&(1<<UDRE0))){};
  // Transmit data
  UDR0 = u8Data;
  return 0;
}


// return true if a character is available for input
int USART0CharacterAvailable()
{
  return (UCSR0A&(1<<RXC0));
}

// receive a byte, block in none available
// argument is ignored
// echo character
// convert <CR> to <LF>
int USART0ReceiveByte( FILE *stream)
{
  unsigned char c;
  // Wait for byte to be received
  while(!(UCSR0A&(1<<RXC0))){};
  // Return received data
  c = UDR0;
  USART0SendByte( c, NULL);
#ifdef UART_COOKED
  if(c == '\r') {
    c = '\n';
    USART0SendByte( c, NULL);
  }
#endif
  return c;
}



#ifdef UART_GET_STRING_USED
// read a string from the UART
// return the string on newline; replace the newline with \0
// process backspace; no other editing

void USART0GetString( char *buffer, int max)
{
  int n = 0;
  char *p = buffer;
  uint8_t c;

  while( 1) {
    c = USART0ReceiveByte( NULL);
    putchar( c);
    if( c == '\n') {
      *p++ = '\0';
      return;
    }
    if( c == '\b' && p > buffer) {
      putchar('\b');
      --p;
    } else {
      *p++ = c;
    }
    
  }
  
}
#endif
