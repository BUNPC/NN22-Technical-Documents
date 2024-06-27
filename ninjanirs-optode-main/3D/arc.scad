
$fn=64;

module arc(r1, r2, a1, a2) {

  rt=r2*2;

  points = [ [0,0], [rt*cos(a1),rt*sin(a1)], [rt*cos(a2),rt*sin(a2)], [0,0]];

  intersection() {
    difference() {
      circle( r=r2);
      circle( r=r1);
    }
    polygon( points);
  }
}
