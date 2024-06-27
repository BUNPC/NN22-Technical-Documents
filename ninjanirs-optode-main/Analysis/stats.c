#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include "fft.h"
#include "stats.h"
#include "goertzel_mag.h"

static int debug = 0;
  
char *format_process_csv( process_stats_t *ps) {
  static char f[255];
  snprintf( f, sizeof(f), "%g,%g,%g", ps->mean, ps->sdev, ps->smax);
  return f;
}

void print_process_stats( process_stats_t *ps) {
  char *f = format_process_stats( ps);
  printf("%s",f);
}

char *format_process_stats( process_stats_t *ps) {
  static char f[20000];
  static char s[100];
  *f = '\0';
  sprintf( s, "Stats:\n   Mean=%g SD=%g AC Max=%g\n", ps->mean, ps->sdev, ps->smax);
  strcat( f, s);
  sprintf( s, "FFT:\n   %d Peaks\n", ps->npeaks);
  strcat( f, s);
  if( ps->npeaks) {
    for( int i=0; i<ps->npeaks; i++) {
      sprintf( s, "     %d  mag=%8.3g freq=%8.2fMHz\n", i, ps->peak_mag[i], ps->peak_freq[i]/1e6);
      strcat( f, s);
    }
  }
  sprintf( s, "   median power=%g\n", ps->median_power);
  strcat( f, s);
  if( ps->ngoert) {
    strcat( f, "-- Goertzel sweep 1-500MHz --\n");
    strcat( f, "   Freq     G_Mag      Real   Imag \n");
    for( int i=0; i<ps->ngoert; i++) {
      strcat( f, format_goert_t( &ps->g[i]));
    }
  }

  return f;
}

//
// clear struct
//
#define free_if_stat(s) if(s){free(s);}

void free_process_stats( process_stats_t* ps) {
  free_if_stat( ps->power_spectrum);
  free_if_stat( ps->power_frequency);
  free_if_stat( ps->g);
  memset( ps, 0, sizeof( process_stats_t));
}

//
// calculate statistics on a waveform
//
int process_data( int nPoints, double *dat, process_stats_t *ps) {

  int peaks = MAX_PEAKS;	/* hardwired peak count */
  ps->peak_ratio = 1000.0;	/* hardwired peak ratio */

  if( debug) {
    printf("Process data: %d points ", nPoints);
    for( int i=0; i<10; i++)
      printf(" %f", dat[i]);
    printf("\n");
  }

  if( debug) printf("Process WF segment with %d points\n", nPoints);

  double *in = dat;

  if( debug)  printf("Run DFT\n");
  ps->nspect = real_dft( nPoints, in, NULL, NULL);
  if( debug)  printf("Allocating %d points", ps->nspect);
  if( ps->nspect == 0)
    return -1;

  ps->power_spectrum = calloc( ps->nspect, sizeof(double));
  ps->power_frequency = calloc( ps->nspect, sizeof(double));

  ps->nspect = real_dft( nPoints, in, ps->power_spectrum, ps->power_frequency);
  if( ps->nspect < 0) {
    fprintf( stderr, "Error in DFT!\n");
    exit(-1);
  }

  if( debug)  printf("Find peaks\n");
  ps->npeaks = find_peaks( ps->nspect, ps->power_spectrum, ps->power_frequency, 
			   peaks, ps->peak_mag, ps->peak_freq,
			   ps->peak_ratio, &ps->median_power);

  // run Goertzel algo and a range of freqs
  // allocate default count
  ps->g = calloc( GOERT_NUM_PEAKS, sizeof(process_goert_t));
  ps->ngoert = 0;
  ps->agoert = GOERT_NUM_PEAKS;
  for( int ifreq=1; ifreq<500; ifreq++) {
    double gfreq = 1e6*ifreq;
    double gmag = goertzel_mag( nPoints, gfreq, 250e6, in);
    if( debug)  printf("Run goertzel with freq=%f... mag=%f %s\n", gfreq, gmag,
		       (gmag > GMAG_THRESH) ? "Save" : "");
    if( gmag > GMAG_THRESH) {
      if( ps->ngoert+1 == ps->agoert) { /* out of space? */
	if( debug) printf("Too many Goertzel peaks!\n");
      } else {
	ps->g[ps->ngoert].goert_freq = gfreq;
	ps->g[ps->ngoert].goert_mag = gmag;
	ps->g[ps->ngoert].goert_real = goertzel_real();
	ps->g[ps->ngoert].goert_imag = goertzel_imag();
	if( debug) {
	  printf("%d: ", ps->ngoert);
	  print_goert_t( &ps->g[ps->ngoert]);
	}
	++ps->ngoert;
      }
      
    }
  }
  // simple statistics
  if( debug)  printf("Do stats\n");
  double sum = 0;
  double sdev = 0;
  double smax = 0;
  for( int i=0; i<nPoints; i++) {
    sum += in[i];
    if( fabs( in[i]) > smax)
      smax = fabs( in[i]);
  }
  if( debug)  printf("Summing...\n");
  sum /= nPoints;
  for( int i=0; i<nPoints; i++)
    sdev += (in[i]-sum)*(in[i]-sum);
  sdev = sqrt( sdev/nPoints);
  ps->mean = sum;
  ps->sdev = sdev;
  ps->smax = smax;

  if( debug)  printf("return\n");
  return 0;
}


// round to next lower power of 2
int round_to_pow2( int v) {
  if( v == 0)
    return 0;
  for( int b = 30; b>0; b--)
    if( v > (1<<b))
      return 1<<b;
}


//
// convert binary data to 
//
void binary_stats( uint32_t *data_ptr, int npt, process_stats_t *ps0, process_stats_t *ps1)
{
  double y0[npt], y1[npt];

  for( int i=0; i<npt; i++) {
    y0[i] = (int16_t)(data_ptr[i] & 0xffff);
    y1[i] = (int16_t)((data_ptr[i] >> 16) & 0xffff);
    if( debug) printf("%d %08x %f %f\n", i, data_ptr[i], y0[i], y1[i]);
  }
		      
  process_data( npt, y0, ps0);
  process_data( npt, y1, ps1);
}


char *format_goert_t( process_goert_t* g) {
  static char buff[80];
  snprintf( buff, sizeof(buff), "%6.1fMHz  %8.2f  %6.2f %6.1f\n",
	    g->goert_freq/1e6, g->goert_mag, g->goert_real, g->goert_imag);
  return buff;
}


void print_goert_t( process_goert_t* g) {
  printf("%s", format_goert_t( g));
}
		   
