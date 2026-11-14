// Voronoi webs filling three outlines, with and without a rim.
use <../voronoi.scad>

kite = [[362.13, 35.7], [388.01, 47.59], [409.81, 58.66], [427.16, 68.73], [439.78, 77.62], [447.43, 85.19],
        [450.0, 91.29], [447.43, 95.84], [439.78, 98.75], [427.16, 99.96], [409.81, 99.47], [388.01, 97.27],
        [362.13, 93.41], [350.0, 60.5]];
color("Tomato") linear_extrude(height = 1) translate([-350, -35]) voronoi_polygon(kite, seed = 1);

box = [[0, 0], [-20, 0], [-20, -20], [0, -20]];
color("SteelBlue") linear_extrude(height = 2) translate([140, -5]) scale(3) voronoi_polygon(box, thickness = 0.2, round = 0.5, edging = 0, seed = 42);

column = [[0, 8], [20, 178], [40, 178], [60, 8]];
color("SeaGreen") linear_extrude(height = 10) translate([150, -10]) scale(0.5) voronoi_polygon(column, n = 50, seed = 7);
