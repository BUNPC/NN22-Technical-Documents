//
// try to reset an AtMega32U4
// 

#define DEBUG

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <ctype.h>

#include "sio_cmd.h"

static int fd;

int main( int argc, char*argv[] )
{
  if( argc < 2) {
    printf("usage:  try_reset <port>\n");
    exit(1);
  }

  char *port = argv[1];

  if( (fd = sio_open( port, B1200)) < 0) {
    printf("Error opening serial port %s\n", port);
    exit( 1);
  }

  close( fd);

}
