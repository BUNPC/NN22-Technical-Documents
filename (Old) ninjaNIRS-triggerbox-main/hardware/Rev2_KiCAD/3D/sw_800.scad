//
// E-switch 800SP9B6M6RE
//
$fn = 32;

box_x = 8.13;
box_y = 9.09;
box_z = 5.08;

pin_len = 1.3;
pin_dia = 0.51;

module pin_at(x,y) {
     translate( [x, y, -pin_len])
	  cylinder( d=pin_dia, h=pin_len);
}

module switch() {

translate( [-box_x/2, -2.54, 0])
cube( [box_x, box_y, box_z]);

translate( [0, box_y-2.54, 6.1/2] )
  rotate( [-90, 0, 0])
  cylinder( h=5.59, d=6.1);

translate( [0, box_y-2.54+5.59, 6.1/2] )
  rotate( [-90, 0, 0])
  cylinder( h=3.56, d=2.45);

pin_at(2.54,2.54);
pin_at(2.54,-2.54);
pin_at(-2.54,2.54);
pin_at(-2.54,-2.54);

}

switch();

