// pins
#define LED1_PIN 4
#define LED2_PIN 5
#define LED3_PIN 6
#define LED4_PIN 7
#define MOTOR_PIN 3
#define SENS_LED_PIN 2
#define SENS_INPUT_PIN A0
#define SERVO1_PIN 9
#define SERVO2_PIN 10
#define SPKR_PIN 16
#define BUTTON_PIN A1

#define ON_TIME 1250
#define OFF_TIME 1250

void setup() {
  pinMode(SENS_LED_PIN, OUTPUT);
}


void loop() {
  digitalWrite( SENS_LED_PIN, 1);
  delayMicroseconds(ON_TIME);
  digitalWrite( SENS_LED_PIN, 0);  
  delayMicroseconds(OFF_TIME);
}
