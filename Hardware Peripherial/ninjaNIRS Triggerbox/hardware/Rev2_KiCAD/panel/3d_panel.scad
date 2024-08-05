$fn=64;

module panel_only() {
  import("panel_only.dxf");
}

rotate( [90, 0, 0])
linear_extrude( height=0.8, center=true, convexity=10) {
  panel_only();
}
