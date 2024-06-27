#!/bin/bash
let dx=$1
let dy=dx*2
~/work/useful-scripts/kicad_automation/filter_pcb_coords.pl 300 400 0 300 $dx $dx flex-IQ80xL.kicad_pcb > test.kicad_pcb
~/work/useful-scripts/kicad_automation/filter_pcb_coords.pl 20 400 200 400 0 $dy test.kicad_pcb > test1.kicad_pcb
