#include <stdint.h>

#define MAX_PEAKS 10

//
// process data
// npt is number of points in raw waveform data
// return a negative value on error, 0 if OK
//
typedef struct {
  double goert_freq;
  double goert_mag;
  double goert_real;
  double goert_imag;
} process_goert_t;

// threshold for Goertzel magnitude to save a reading
#define GMAG_THRESH 100.0
// default number of Goertzel peaks
#define GOERT_NUM_PEAKS 10

typedef struct {
  // fill in to request processing
  int goert_freq;
  double peak_ratio;

  // returned by function
  double* power_spectrum;
  double* power_frequency;
  int nspect;
  double peak_mag[MAX_PEAKS];
  double peak_freq[MAX_PEAKS];
  int npeaks;
  double median_power;
  int ngoert;
  int agoert;
  process_goert_t *g;
  double mean;
  double sdev;
  double smax;
} process_stats_t;


void print_process_stats( process_stats_t *ps);
char *format_process_stats( process_stats_t *ps);
void free_process_stats( process_stats_t* ps);
int process_data( int nPoints, double *dat, process_stats_t *ps);
int round_to_pow2( int v);
void binary_stats( uint32_t *data_ptr, int npt, process_stats_t *ps0, process_stats_t *ps1);
char *format_process_csv( process_stats_t *ps);
void print_goert_t( process_goert_t*);
char *format_goert_t( process_goert_t* g);
