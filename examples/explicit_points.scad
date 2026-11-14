// A Voronoi pattern over sites you place yourself.
use <../voronoi.scad>

points = [
  [0, 0], [30, 0], [20, 10], [50, 20], [15, 30], [85, 30], [35, 30], [12, 60],
  [45, 50], [80, 80], [20, -40], [-20, 20], [-15, 10], [-15, 50]
];
voronoi(points, L = 80, thickness = 1, round = 4, nuclei = true);
