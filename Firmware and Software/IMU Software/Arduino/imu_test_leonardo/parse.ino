//
// parse string s into space-separated tokens
// convert as decimal or hex (0x prefix) integers
// (use strtok)
//
// int parse( char *s, char *argv[], int *iargv, int max)
//

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// in AVR-land, strtoul() and sscanf() are big

int htoi( char *s) {
  int n = 0;
  while( *s) {
    n *= 16;
    char c = *s;
    if( isxdigit( c)) {
      if( isdigit(c))
	      n += c - '0';
      else
	      n += 10 + (toupper(c) - 'A');
    }
    ++s;
  }
  return n;
}

int my_atoi( char *s) {
  if( strlen(s) > 2 && !strncasecmp( s, "0x", 2))
    return( htoi( s+2));
  else
    return( atoi( s));
}

int parse( char *s, char *argv[], int *iargv, int max) {
  int n = 0;
  char *p = strtok( s, " ");
  if( p == NULL)
    return 0;
  // handle first token
  argv[n] = p;
  //  iargv[n] = strtoul( p, NULL, 0);
  iargv[n] = my_atoi( p);
  ++n;
  // handle subsequent tokens
  while( (p = strtok( NULL, " ")) && (n < max) ) {
    argv[n] = p;
    // iargv[n] = strtoul( p, NULL, 0);
    iargv[n] = my_atoi( p);
    ++n;
  }
  return n;
}
