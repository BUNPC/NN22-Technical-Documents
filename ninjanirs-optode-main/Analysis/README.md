This directory contains some waveforms and simple analysis software
for evaluating the prototype ninjaNIRS optode.

The initial device under test is a flexi with a Visha VEMD5160X01
photodiode, followed by an ADPD2210 24X current amplifier, and finally
an ADA4001-2 op-amp configured as a transimpedance amplifier with a
1.0Meg feedback resistor in parallel withh a 1.6pF compensation
capacitor.

The program ```wf_stats.c``` reads a CSV waveform file with T,V pairs
and calculates mean, standard deviation, maximum value and sampling
rate.

Several waveform files (scope_0, scope_2, scope_3) were collected
under more-or-less dark conditions and different sampling rates.

The RMS value is around 8mV which corresponds to the oscilloscope's
built-in RMS voltage display.
