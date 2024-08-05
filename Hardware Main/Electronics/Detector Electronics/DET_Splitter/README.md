# readout-splitter

This is a splitter board designed to be plug-compatible with the TIGRIS one.
See top-level README for some more details.

Connector from readout system is a Samtec SHF-117-01-L-D-SM shrouded 34-pin header
with 0.05" pitch.

Detector connector is Samtec SFMC-118-02-S-D 36-pin socket strip with 0.05" pitch.
Note that the TIGRIS schematic and layout use mirrored pinout for the detector connector
(odd-even swap).

Designed LDOs:

* Negative: ADP7182ACPZN-R7
* Positive: ADP7142ACPZN5.0-R7

The negative adjustable regulator should output -15.0V with the resistors shown.
There is an additional filter in the design (R+C on front side) which can
(according to the datasheet) reduce the noise a bit in the negative regulator.
There is no such provision for the positive regulator.

This is a 4-layer board and a bit dense.  There were a few compromises
made in routing with shared vias, etc but hopefully it will be OK.

