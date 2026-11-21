// A 2 mm panel perforated with a Voronoi pattern inside a 4 mm frame.
use <../voronoi.scad>

size = [100, 60];
frame = 4;
linear_extrude(height=2) difference() {
        square(size);
        intersection() {
            translate([frame, frame]) square(size - 2 * [frame, frame]);
            translate(size / 2) random_voronoi(
                    n=45, nuclei=false, thickness=0.8, round=1.5, min=0, max=100,
                    seed=5, center=true
                );
        }
    }
