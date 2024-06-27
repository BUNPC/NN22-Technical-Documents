# ninjaNIRS optode study

  - [Flex board with Vishay photodiode](#flex-board-with-vishay-photodiode)
  - [Flex board with IQ80x photosensor](#flex-board-with-iq80x-photosensor)
  - [Readout box](#readout-box)
    - [Other devices considered](#other-devices-considered)


This repo contains work towards an implementation of an "optode" sensor unit
using off-the-shelf components.

The first design is essentially a mechanical test of the use of inexpensive
flex circuits to implement a complete optode, including connector pigtail.

## Flex board with Vishay photodiode

See `KiCAD/flex-VEMD`.

This board has a VEMD5160X01 photodiode and Analog devices ADPD2210 current amplifier.
Tests showed excessive sensitivity to 60Hz pickup, even with the flexi shielded
with copper tape.  This design has been abandoned for now (late 2023).

JLC double-layer flex has a 25um polyimide dielectric with 0.5oz copper on both sides.
There is 25um adhesive and 25um polyimide cover on each side.  Trace width is 0.5mm
with adjacent GND separated by 0.15mm.  Length 340mm.

PI dielectric constant is 3-4.

```
Parallel plate C = E(A/d) = (k * E0 * A) / d

  k = relative permittivity of dielectric (say, 3.5 for polyimide)
  E0 = permittivity of space = 8.854e-12 F/m
  A = area
  d = spacing
```

## Flex board with IQ80x photosensor

See `KiCAD/flex-IQ80xL`

This is a flexi designed for the Roithner LaserTechnik IQ80xL family of photodiodes
with integrated transimpedance amplifier.

Prototypes of two types fabricated in late 2023 with two different length flexis.
Unfortunately the pinout doesn't match the TIGRIS breakout box.  The pin numbering on the
schematics is identical (1-V-, 2-OUT, 3-V+, 4-GND) but there is an odd/even swap.

Bernhard Z has done some preliminary tests, which look promising (Dec 2023)

## Readout box

See `KiCAD/readout-box`

This is a readout box with 8 channels of TIA and LDO, to read the flex-VEMD
or other sensors with current amplifier.  Prototype built in 2023 and tested
with flex-VEMD.  Too much 60Hz pickup to pursue in this setup.
Used RT9058 LDOs and ADA4001-2 dual op-amps.

This board deliberately designed with hand-solderable parts:  SOT-23,
SO-8, 0603 passives.

### Other devices considered

This info left for reference

* THS4631 - single supply (up to +/-15V)
* LHM6611 - single supply 345MHz rail-to-rail amp (SOT-23-5)
* OPA842/3/6/7 and OPA656/7

Berhard suggests some quad options

* OPA4141 - Quad - 10MHz GBW - 36V supply - TSSOP, SOIC
* OPA2156 - Dual - 25MHz GBW - 36V supply - TSSOP, SOIC
* ADA4001-2 - Dual - 17MHz GBW - 36V supply - SOIC

Some others from a quick search:

| P/N           | GBW    | Supply | Noise                  | I(Bias) | Packages           | Notes |
|---------------|--------|--------|------------------------|---------|--------------------|-------|
| AD8672/4      | 10MHz  | 30V    | 2.8nV/Hz, 77nV p/p LF  | 12nA    | SOIC, MSOP         |       |
| ADA4004-2, -4 | 12MHz  | 30V    | 1.8nV/Hz  100nV p/p LF | 90nA    | SOIC, MSOP, LFCSP  |       |
| TLV2172/4172  | 10MHz  | 36V    | 9nV/Hz                 | 10pA    | SOIC, VSSOP, TSSOP |       |
| OPA2172       | 10MHz  | 36V    | 7nV/Hz                 | 8pA     | VSSOP, TSSOP       |       |
| OPA42140/4140 | 11MHz  | 36V    | 5.1nV/Hz  250nV p/p LF | 20pA    | TSSOP, VSSOP       |       |
| THS4032       | 100MHz | 30V    | 1.6nV/Hz               | 3uA (!) |                    |       |
| BA4560        | 10MHz  | 36V    | 8nV/Hz                 | 500nA   | TSSOP, MSOP        |       |
| BA4580        | 10MHz  | 32V    | 5nV/Hz                 | 500nA   | MSOP, SSOP         |       |
| MC33272       | 24MHz  | 36V    | 18nV/Hz                | 300nA   | TSSOP              |       |
|               |        |        |                        |         |                    |       |

Some references:

* https://www.ti.com/lit/pdf/sboa268
* https://www.electronicdesign.com/technologies/analog/article/21801223/whats-all-this-transimpedance-amplifier-stuff-anyhow-part-1

## Readout splitter

This is a new (Dec 2023) splitter box to provide the same function as the TIGRIS
box but with LDOs instead of the capacitance multipler circuits.

See [README](KiCAD/readout-box/README.md) for some more details.
