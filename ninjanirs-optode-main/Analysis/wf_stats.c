//
// Read a scope waveform and do some simple statistics (noise)
//
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <math.h>

#define issigned(c) (isdigit((c))||((c)=='-')||((c)=='+'))

typedef struct {
  double mean;			/* mean */
  double sdev;			/* std deviation */
  double smax;			/* absolute value of maximum */
  double samp;			/* sampling interval */
  int num;			/* number of samples */
} stats_t;

void calc_stats( double *in, int nPoints, stats_t* ps);
void print_stats( stats_t* ps);

// #define DEBUG

int main( int argc, char *argv[]) {
  FILE *fp;
  char buff[80];

  int npt = 0;
  double interval = 0.0;
  double *xval = NULL;
  double *yval = NULL;

  stats_t st;

  if( argc < 2) {
    fprintf(stderr, "usage: wf_stats <csv_file>\n");
    exit(1);
  }

  if( (fp = fopen( argv[1], "rb")) == NULL) {
    fprintf(stderr, "Error opening %s for input\n", argv[1]);
    exit(1);
  }

  // count lines
  while( fgets( buff, sizeof(buff), fp) != NULL) {
    if( issigned( *buff))
      ++npt;
  }
  printf("%d points in waveform\n", npt);

  xval = calloc( npt, sizeof( *xval));
  yval = calloc( npt, sizeof( *yval));
  
  // read data
  int n = 0;
  rewind( fp);
  while( fgets( buff, sizeof(buff), fp) != NULL) {
    if( issigned( *buff)) {
      char *px = strtok( buff, ",");
      char *py = strtok( NULL, ",");
      xval[n] = atof( px);
      yval[n] = atof( py);
#ifdef DEBUG
      printf("Parsed: \"%s\" , \"%s\"\n", px, py);
      printf("Data: %e\n", yval[n]);
#endif      
      ++n;
    }
  }

  st.num = npt;
  st.samp = fabs( xval[1] - xval[0]);
  calc_stats( yval, npt, &st);

  print_stats( &st);

}

void print_stats( stats_t* ps) {
  printf("Mean:     %e V\n", ps->mean);
  printf("Std Dev:  %e V\n", ps->sdev);
  printf("Max:      %e V\n", ps->smax);
  printf("Interval: %e S\n", ps->samp);
  printf("(Freq:)   %e Hz\n", 1.0/ps->samp);
  printf("(Len:)    %e S\n", ps->samp * ps->num);
}

void calc_stats( double *in, int nPoints, stats_t* ps) {

  double sum = 0;
  double sdev = 0;
  double smax = 0;
  for( int i=0; i<nPoints; i++) {
    sum += in[i];
    if( fabs( in[i]) > smax)
      smax = fabs( in[i]);
  }
  sum /= nPoints;
  for( int i=0; i<nPoints; i++)
    sdev += (in[i]-sum)*(in[i]-sum);
  sdev = sqrt( sdev/nPoints);
  ps->mean = sum;
  ps->sdev = sdev;
  ps->smax = smax;

}
  
