//
// IQ80xL photosensor
//
$fn = 64;

can_dia = 8.45;
win_dia = 6.35;
can_hgt = 6.5;

pin_dia = 0.45;
pin_len = 1.5;

pin_off = 5.08/2;

module pin_at( x, y) {
  translate( [x, y, -pin_len])
    color("gold")
    cylinder( d=pin_dia, h=pin_len);
}

module can() {
  color("grey") {
    difference() {
      cylinder( h=can_hgt, d=can_dia);
      translate( [0, 0, 0.1])
	cylinder( h=can_hgt, d=win_dia);
    }
  }
  translate( [0, 0, can_hgt-0.1])
    color("white",0.5)
    cylinder( d=win_dia, h=0.1);
}

module pkg() {
  can();
  pin_at( -2.54, 0);
  pin_at( +2.54, 0);
  pin_at( 0, -2.54);
  pin_at( 0, +2.54);
  pin_at( 0, 0);
}

pkg();
