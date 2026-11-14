// Random Voronoi tiles in a 120 mm square, extruded. Change the seed for another
// pattern. The square trims the outer cells, which otherwise reach out to L.
use <../voronoi.scad>

linear_extrude(height = 3) intersection() {
  square(120, center = true);
  random_voronoi(n = 40, thickness = 1, round = 2, min = 0, max = 120, seed = 42, center = true);
}
