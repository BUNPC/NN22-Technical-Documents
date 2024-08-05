//
// Amphenol / Adamtech PCB BNC
//

// center on signal pin

e = 0.1;
$fn = 32;

box_x = 14.75;
box_y = 14.20;
box_z = 13.11;

pin_z = 3.80;
pin_y = -2.55;
sig_d = 0.70;
gnd_d = 1.80;

thr_len = 8.8;
thr_d = 12;
cyl_len = 12;
cyl_d = 9.6;


translate( [-box_x/2, -2.02, 0]) {
     color("darkgrey")
     cube( [box_x, box_y, box_z]);
}
translate( [0, 0, -pin_z])  cylinder( d=sig_d, h=pin_z);
translate( [pin_y, 0, -pin_z])  cylinder( d=sig_d, h=pin_z);
translate( [-5.08, 5.08, -pin_z]) cylinder( d=gnd_d, h=pin_z);
translate( [ 5.08, 5.08, -pin_z]) cylinder( d=gnd_d, h=pin_z);


translate( [0, pin_y+box_y+thr_len, box_z/2])
rotate( [90, 0, 0])
cylinder( h=thr_len, d=thr_d);

translate( [0, pin_y+box_y+thr_len+cyl_len, box_z/2])
rotate( [90, 0, 0])
cylinder( h=cyl_len, d=cyl_d);

