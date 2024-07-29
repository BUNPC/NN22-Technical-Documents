//
// Assman 4 pin RJ connector
// A-2004-3-4-LP-N
//

e = 0.1;
function mm(x)=x*25.4;
$fn=32;

pin_dia = mm(0.7);
pin_len = mm(3.25);

peg_dia = mm(2.5);
peg_len = mm(3.25);

body_wid = mm(11.2);
body_len = mm(18);
body_hgt = mm(11.7);

pin_dx = mm(1.27);
pin_dy = mm(2.54);

peg_dx = mm(7.62);

pin_x0 = (body_wid-3*pin_dx)/2;
pin_y0 = mm(14.2);

module pin_at(x,y) {
  translate( [x, y, -pin_len])
    cylinder(h=pin_len, d=pin_dia);
}

module peg_at(x,y) {
  translate( [x, y, -peg_len])
    cylinder(h=peg_len, d=peg_dia);
}

cut_wid = mm(8);
cut_hgt = mm(6);
cut_len = mm(4);

module body() {
  difference() {
    cube( [body_wid, body_len, body_hgt]);
    translate( [(body_wid-cut_wid)/2, -e, (body_hgt-cut_hgt)/2])
      cube( [cut_wid, cut_len, cut_hgt]);
  }
}


module rj() {
  body();
  peg_at( (body_wid-peg_dx)/2, mm(7.85));
  peg_at( (body_wid-peg_dx)/2+peg_dx, mm(7.85));
  pin_at( pin_x0, pin_y0);
  pin_at( pin_x0+pin_dx, pin_y0+pin_dy);
  pin_at( pin_x0+2*pin_dx, pin_y0);
  pin_at( pin_x0+3*pin_dx, pin_y0+pin_dy);
}


rj();
