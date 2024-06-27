//
// parameterized model for flexi with right-angle exit
//

use <IQ80xL.scad>
use <arc.scad>

e = 0.1;
$fn=64;

//
// flexi parameters
//
flex_down = 2;

flex_dia = 9.0;			// circle diameter for components
flex_wid = 2.5;			// width of flex body
flex_thk = 0.1;                 // thickness of flex

flex_tail = 40;                 // length of tail after turn
flex_curv = 1.5;                // curve radius

flex_before = 1.0;              // horizontal length before curve up
flex_up = 3;                    // vertical run before right-angle

flex_ext = 1;			// overlap with circle (non-critical)

//
// enclosure parameters
//
// large cylinder
enc_id=10;			// inner diameter
enc_od=12;			// outer diameter
enc_h=10.5;			// overall hight
enc_down = 2;			// z offset down from flex surface
enc_slot = 3;			// slot depth

enc_floor = 1.5;		// "floor" of large cylinder

// small cylinder
enc_sm_id=3;
enc_sm_od=7;
enc_sm_h=6;


//
// render a flattened flexi outline for PCB layout
//

module flexi_flat() {
  // circle body for flex
  translate( [0, 0, -flex_thk/2]) {
    cylinder( h=flex_thk, d=flex_dia);
    x0 = flex_dia/2-flex_ext;
    dx = flex_ext + flex_before + (PI*flex_curv)/4 + flex_up;

    linear_extrude( height=flex_thk) {
      polygon( points=[ [x0, -flex_wid/2], [x0+dx, -flex_wid/2], 
			[x0+dx, flex_tail], [x0+dx-flex_wid, flex_tail],
			[x0+dx-flex_wid, flex_wid/2],
			[x0, flex_wid/2]]);
    }
  }
}


//
// make 90 degree curve in quadrant 1 with len1 tail downwards (-Y) and len1 tail left (-X)
//
module curv( len1, len2, rad, wid) {
  arc( rad-wid/2, rad+wid/2, 0, 90);
  p1 = [[rad-wid/2, 0], [rad+wid/2, 0], [rad+wid/2, -len1], [rad-wid/2, -len1], [rad-wid/2, 0] ];
  polygon( p1);
  p2 = [[0, rad-wid/2], [0, rad+wid/2], [-len2, rad+wid/2], [-len2, rad-wid/2], [0, rad-wid/2] ];
  polygon( p2);
}

module flexi() {

  //
  // circle body for flex
  //
  translate( [0, 0, -flex_thk/2])
    cylinder( h=flex_thk, d=flex_dia);


  //
  // upward curve
  //
  translate( [flex_dia/2+flex_before, -flex_wid/2, flex_curv])
    rotate( [270, 0, 0])

    linear_extrude( height=flex_wid) {
    curv( flex_up, flex_before+flex_ext, flex_curv, flex_thk);
  }

  //
  // right angle tail
  //

  p3 = [ [0, flex_wid/2], [flex_tail, flex_wid/2], [flex_tail, -flex_wid/2], [0, -flex_wid/2]];

  translate( [flex_dia/2+flex_before+flex_curv-flex_thk/2, 0, flex_up+flex_curv-flex_wid/2])
    rotate( [90, 0, 90])
    linear_extrude( height=flex_thk) {  polygon(p3); }
}


module enc_body() {
  cylinder( h=enc_h, d=enc_od);	// large cylinder
  translate( [0, 0, -enc_sm_h])
    cylinder( h=enc_sm_h+e, d=enc_sm_od); // small cylinder
}

module enc_cutouts() {
  translate( [0, 0, -enc_sm_h-e])   // light guide
    cylinder( h=enc_floor+enc_sm_h+2*e, d=enc_sm_id);
  translate( [0, 0, enc_floor])     // optical sensor and flex
    cylinder( h=enc_h, d=enc_id);
  translate( [0, -flex_wid/2, enc_h-enc_slot])
    cube( [10,flex_wid,enc_slot+e]);
}


module enclosure() {
  difference() {
    enc_body();
    enc_cutouts();
  }
}

module flex_assy() {
  flexi();
  pkg();
}  


module assembly() {
  translate( [0, 0, enc_h-flex_down])  rotate( [0, 180, 180])  flex_assy();
  difference() {
    color("DarkSlateGrey",0.75)
      enclosure();
    translate( [0, 0, -20])
    cube( [100, 100, 100]);
  }
}

// flattened flexi
projection( cut=false)  translate( [0, 0, -30])  flexi_flat();

// cross-section
// projection( cut=true) rotate( [0, 90, 0])

// assembly();


