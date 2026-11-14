// What tests/test_voronoi.py renders, chosen by CHECK.
//   "cells":    echoes the sites and each cell's points (inset INSET)
//   "pattern":  voronoi() over the test sites, extruded 1 mm, cells grown by GROW
//   "random":   random_voronoi() with SEED, extruded 1 mm (CENTER to centre it)
//   "shifted":  the uncentred random pattern moved by minus its sites' midpoint
//   "spill":    voronoi_polygon() less its border: empty when it stays inside
//   "rim":      voronoi_polygon()'s rim of width EDGING against the result
//   "case":     one of the fixed cases whose volumes tests/volumes.txt pins
use <../voronoi.scad>

CHECK = "cells";
INSET = 2;
GROW = 0;
SEED = 42;
CENTER = false;
EDGING = 3;
CASE = 0;

SITES = random_points(40, 0, 100, 11);
BORDER = [[0, 0], [60, 10], [80, 60], [30, 90], [-10, 50]];

if (CHECK == "cells") {
  echo(str("SITES ", SITES));
  for (i = [0:len(SITES) - 1]) echo(str("CELL ", i, " ", voronoi_cell(SITES, i, 200, INSET)));
  // The smallest distance any cell vertex sits inside a bisector, less INSET,
  // worked out here at full precision rather than from the echoed points.
  worst = min([for (i = [0:len(SITES) - 1], v = voronoi_cell(SITES, i, 200, INSET), j = [0:len(SITES) - 1]) if (j != i)
    let (p = SITES[i], q = SITES[j]) (norm(v - q) ^ 2 - norm(v - p) ^ 2) / (2 * norm(p - q)) - INSET]);
  echo(str("WORST ", worst));
}
else if (CHECK == "pattern")
  linear_extrude(1) offset(delta = GROW) voronoi(SITES, thickness = 1, round = 1, nuclei = false);
else if (CHECK == "random")
  linear_extrude(1) random_voronoi(n = 25, thickness = 1, round = 1, min = 0, max = 100, seed = SEED, center = CENTER);
else if (CHECK == "shifted") {
  pts = random_points(25, 0, 100, SEED);
  mid = [(min([for (p = pts) p.x]) + max([for (p = pts) p.x])) / 2, (min([for (p = pts) p.y]) + max([for (p = pts) p.y])) / 2];
  linear_extrude(1) translate(-mid) random_voronoi(n = 25, thickness = 1, round = 1, min = 0, max = 100, seed = SEED);
}
else if (CHECK == "spill")
  linear_extrude(1) difference() { voronoi_polygon(BORDER, n = 30, edging = EDGING, seed = SEED); polygon(BORDER); }
else if (CHECK == "rim")
  linear_extrude(1) intersection() {
    voronoi_polygon(BORDER, n = 30, edging = EDGING, seed = SEED);
    difference() { polygon(BORDER); offset(delta = -EDGING) polygon(BORDER); }
  }
else if (CHECK == "case") {
  pts = [[0, 0], [30, 0], [20, 10], [50, 20], [15, 30], [85, 30], [35, 30], [12, 60], [45, 50], [80, 80], [20, -40],
         [-20, 20], [-15, 10], [-15, 50]];
  linear_extrude(1)
    if (CASE == 0) voronoi(pts, round = 4, nuclei = true);
    else if (CASE == 1) voronoi(pts, thickness = 0.5, round = 1, nuclei = false);
    else if (CASE == 2) voronoi(pts, L = 80, thickness = 1, round = 2);
    else if (CASE == 3) random_voronoi(n = 64, round = 6, min = 0, max = 300, seed = 42);
    else if (CASE == 4) random_voronoi(n = 20, thickness = 2, round = 2, min = 0, max = 100, seed = 7);
}
