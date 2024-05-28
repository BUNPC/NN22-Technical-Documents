//
// read input from serial port with some editing
//    ^H or DEL = backspace
//    ^U        = delete line
// All other control characters ignored
// 
// buff - character array to store data up to nchar bytes
// always returns pointer to buff
//
char *my_gets( char *buff, int nchar) {
  char *p = buff;
  int n = 0;
  char ch[1];
  while( 1) {
    if( Serial.available()) {
      Serial.readBytes( ch, 1);
      char c = ch[0];
      if( isprint(c)) {
        if( n < nchar) {
          *p++ = c;
          ++n;
          Serial.write( c);
        }
      }
      if( c == '\b' || c == '\177') {
        if( p > buff) {    // backspace?
          --p;
          --n;
          Serial.write( '\b');
          Serial.write( ' ');
          Serial.write( '\b');
        } else {
          Serial.write( '\a');
        }
      }
      if( c == '\r' || c == '\n') {
        *p = '\0';
        Serial.write( '\r');
        Serial.write( '\n');
        return buff;
      }
    }
  }
}


