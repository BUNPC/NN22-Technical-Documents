//
// test bed for NN IMU - run on Arduino Pro Micro or Leonardo (32U4)
// Connect TxRx pins 0/1 to IMU
// monitor through computer USB serial port at 9600 baud
//
// user types in a 

#include <stdint.h>

// maximum number of command arguments to parse                                                                                  
#define MAXARG 5

// these are global so they are included in the report of variable size use                                                      
static char buff[80];
static char* argv[MAXARG];
static int iargv[MAXARG];

// IMU Rx timeout in ms
#define RX_TIMEOUT 100

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);       // USB port to computer
  Serial1.begin(250000);    // pins 0/1 port
  Serial.println("Enter a numeric byte to send to IMU");
}

void loop() {
  // put your main code here, to run repeatedly:
  Serial.write( ">");
  Serial.flush();

  my_gets( buff, sizeof(buff));
  int n = parse( buff, argv, iargv, MAXARG);
  Serial.print("Send: ");
  Serial.println( iargv[0]);
  Serial1.write( iargv[0]);

  // receive bytes from Serial1 for a while and display
  unsigned long ms = millis();
  char *p = buff;
  
  do {
    if( Serial1.available()) {
      Serial1.readBytes( p, 1);
      ++p;
    } 
  } while( (millis()-ms) < RX_TIMEOUT && (p-buff) < sizeof(buff));

  int nb = p-buff;
  Serial.print("Count: ");
  if( nb == 17 && buff[1] == 14) {
    uint8_t sum = buff[1];
    Serial.println("IMU data:");
    int16_t* imu = (int16_t *)&buff[2];
    for( int i=0; i<14; i++)
      sum += buff[2+i];
    for( int i=0; i<7; i++) {
      Serial.print( imu[i]);
      Serial.print( " ");
    }
    Serial.println("");
    Serial.print("Sum rx calc: ");
    Serial.print( (uint8_t)buff[16]);
    Serial.print(" ");
    Serial.println( sum);

    Serial.println("raw dump:");
      Serial.println( nb);
    for( int i=0; i<nb; i++) {
      Serial.print(i);
      Serial.print(": ");
      Serial.println( (int)buff[i]);
    }
  }

}
