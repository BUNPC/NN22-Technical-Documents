#include <avr/io.h>

#define USART_BAUDRATE 9600
// #define USART_BAUDRATE 57600
// #define UBRR_VALUE (((F_CPU / (USART_BAUDRATE * 16UL))) - 1)

//
// calculation above is wrong for some values
//
// use this table for 8MHz clock
// 9600     = 51
// 19200    = 25
// 57600    = 8
// 125000   = 3    (OK for 115.2k with 8.5% err)
// 250000   = 1

#define UBRR_VALUE 1

void USART0Init(void);
int USART0SendByte(char u8Data, FILE *stream);
int USART0CharacterAvailable();
int USART0ReceiveByte( FILE *stream);
#ifdef UART_GET_STRING_USED
void USART0GetString( char *buffer, int max);
#endif
