# Check cells, web width, seeds, polygon fill, the pinned volumes and the examples
test:
    python3 tests/test_voronoi.py

# Rewrite tests/volumes.txt after an intended change to the pattern
volumes:
    python3 tests/test_voronoi.py --update

# Everything CI runs, bar the tests
check: fmt-check

# Format the .scad sources with topiary (.topiary/languages.ncl)
fmt:
    git ls-files -z '*.scad' | xargs -0 -r topiary format

# Check the .scad sources are formatted, without changing them
fmt-check:
    git ls-files -z '*.scad' | xargs -0 -r -n1 topiary format --check

# Render the README pictures into images/
images:
    mkdir -p images
    openscad --render --imgsize 900,800 --viewall --autocenter --colorscheme Tomorrow --projection=ortho --camera 0,0,0,0,0,0,0 -o images/explicit_points.png examples/explicit_points.scad
    openscad --render --imgsize 1000,700 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,55,0,25,0 -o images/random_tiles.png examples/random_tiles.scad
    openscad --render --imgsize 1200,700 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,50,0,20,0 -o images/fill_polygon.png examples/fill_polygon.scad
    openscad --render --imgsize 1000,700 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,50,0,20,0 -o images/perforated_panel.png examples/perforated_panel.scad
