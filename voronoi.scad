// voronoi.scad: Voronoi patterns in OpenSCAD.
//
// Each site gets one cell: the region nearer to it than to any other site,
// pulled in from every neighbour so a web of width 2 * thickness runs between
// cells, with its corners rounded to `round`. The cells are what is drawn, so
// subtract them from a plate for a perforated panel, or extrude them as tiles.
//
// MIT License, Copyright (c) 2026 Cameron Brooks.

// ---------------- Cells as polygons ----------------

// Clip a convex polygon to the half-plane (x - a) . n >= 0.
function _clip(poly, a, n) =
    let (
        k = len(poly),
        side = [for (v = poly) (v - a) * n]
    )
    k == 0 ? []
    : [
        for (i = [0:k - 1])
        let (j = (i + 1) % k, si = side[i], sj = side[j]) each concat(
            si >= 0 ? [poly[i]] : [],
            (si >= 0) != (sj >= 0) ? [poly[i] + (poly[j] - poly[i]) * (si / (si - sj))] : []
        ),
    ];

// Clip by every half-plane in a list of [point, normal] pairs.
function _clip_all(poly, planes, i = 0) =
    i >= len(planes) || len(poly) == 0 ? poly : _clip_all(_clip(poly, planes[i][0], planes[i][1]), planes, i + 1);

/**
 * The cell of site points[i], as a list of points.
 *
 * Each other site q bounds the cell to a strip on the site's side of their
 * bisector: it starts `inset` short of the bisector and reaches L back toward
 * the site, and is 2 * L wide along the bisector. The cell is the intersection
 * of these strips, so L limits how far the outer cells reach. Empty when the
 * inset leaves nothing.
 */
function voronoi_cell(points, i, L = 200, inset = 0) =
    let (
        p = points[i],
        planes = [
            for (j = [0:len(points) - 1]) if (j != i && points[j] != p) let (
                q = points[j],
                d = (p - q) / norm(p - q), // from q toward p
                t = [-d.y, d.x], // along the bisector
                m = (p + q) / 2 + d * inset // the strip's near edge
            ) each [[m, d], [m + d * L, -d], [m - t * L, t], [m + t * L, -t]],
        ],
        box = 4 * L,
        start = [p + [-box, -box], p + [box, -box], p + [box, box], p + [-box, box]]
    )
    _clip_all(start, planes);

// ---------------- Patterns ----------------

/**
 * A Voronoi pattern: one cell per site, each pulled in by `thickness` from
 * every neighbour and rounded to `round`, so the web between two cells is
 * 2 * thickness wide.
 *
 *   points     the sites, [[x, y], ...]
 *   L          how far an outer cell reaches (see voronoi_cell)
 *   thickness  half the width of the web between cells
 *   round      corner radius
 *   nuclei     punch a hole of nucleus_r at each site
 *   nucleus_r  radius of those holes
 *
 * Keep these in proportion to the spacing of the sites: a cell narrower than
 * 2 * (thickness + round) vanishes.
 */
module voronoi(points, L = 200, thickness = 1, round = 6, nuclei = true, nucleus_r = 1) {
    assert(is_list(points) && len(points) >= 2, "voronoi: give at least two points");
    assert(thickness >= 0 && round >= 0, "voronoi: thickness and round must not be negative");
    for (i = [0:len(points) - 1]) {
        cell = voronoi_cell(points, i, L, thickness + round);
        if (len(cell) >= 3)
            difference() {
                // Rounded by sweeping a 20-sided circle round the cell, which keeps the
                // corner facets at fixed angles whatever the cell's shape.
                minkowski() { polygon(cell); circle(r=round, $fn=20); }
                if (nuclei) translate(points[i]) circle(r=nucleus_r, $fn=20);
            }
    }
}

// n random sites in [lo, hi] on both axes, the same for the same seed.
function random_points(n, lo, hi, seed) =
    let (x = rands(lo, hi, n, seed), y = rands(lo, hi, n, seed + 1))
    [for (i = [0:n - 1]) [x[i], y[i]]];

/**
 * A Voronoi pattern over n random sites in the square [min, max] on both
 * axes. The same seed gives the same pattern; with no seed, one is drawn and
 * echoed so a pattern you like can be kept. `center` moves the sites' bounding
 * box to the origin.
 */
module random_voronoi(
    n = 20,
    nuclei = true,
    L = 200,
    thickness = 1,
    round = 6,
    min = 0,
    max = 100,
    seed = undef,
    center = false
) {
    s = is_undef(seed) ? rands(0, 100, 1)[0] : seed;
    echo("Seed", s);
    pts = random_points(n, min, max, s);
    mid = center ? [(min_of(pts, 0) + max_of(pts, 0)) / 2, (min_of(pts, 1) + max_of(pts, 1)) / 2] : [0, 0];
    voronoi([for (p = pts) p - mid], L=L, thickness=thickness, round=round, nuclei=nuclei);
}

function min_of(pts, k) = min([for (p = pts) p[k]]);
function max_of(pts, k) = max([for (p = pts) p[k]]);

/**
 * Fills a polygon (no holes) with a random Voronoi pattern: the polygon less
 * the cells, so what remains is the web, with an optional solid rim of width
 * `edging`. The pattern is drawn on a square the size of the polygon's longer
 * side, stretched to its bounding box.
 */
module voronoi_polygon(border, n = 30, thickness = 1.7, round = 1.0, edging = 3.0, seed = undef) {
    lo = [min_of(border, 0), min_of(border, 1)];
    hi = [max_of(border, 0), max_of(border, 1)];
    size = hi - lo;
    L = max(size.x, size.y);
    difference() {
        polygon(border);
        translate((lo + hi) / 2) scale([size.x / L, size.y / L])
                random_voronoi(
                    n=n, nuclei=false, L=L, thickness=thickness, round=round, min=0, max=L, seed=seed,
                    center=true
                );
    }
    if (edging > 0)
        difference() {
            polygon(border);
            offset(delta=-edging) polygon(border);
        }
}
