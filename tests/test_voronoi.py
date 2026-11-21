"""Check the Voronoi library.

usage: python3 tests/test_voronoi.py [OPENSCAD] [--update]

1. Every vertex of every cell, for 40 random sites, lies at least `inset`
   inside its site's side of the bisector with every other site, and every
   site's own cell contains it when the inset is 0.
2. The web between cells is 2 * thickness wide: the cells grown by just under
   thickness stay apart, and grown by a little more, some meet.
3. A seed gives the same pattern every time and another seed a different one,
   and `center` moves the sites' midpoint to the origin.
4. voronoi_polygon() stays inside its border, and its rim is solid.
5. Five fixed cases keep the volumes in tests/volumes.txt; they are the
   volumes Felipe Sanches's original OpenSCAD_Voronoi_Generator gives for the
   same calls. --update rewrites the file.
6. Every example evaluates without warnings, and one site is refused; no
   other render prints an error or warning.
"""

import hashlib
import json
import math
import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROBE = os.path.join(ROOT, "tests", "probe.scad")
VOLUMES = os.path.join(ROOT, "tests", "volumes.txt")


ERRORS = []


def run(openscad, out, defines, export="binstl", scad=PROBE, refused=False):
    if os.path.exists(out):
        os.remove(out)  # an empty result writes nothing; never read a stale file
    cmd = [openscad, "--hardwarnings", "--export-format", export, "-o", out]
    for k, v in defines.items():
        cmd += ["-D", f"{k}={v}"]
    r = subprocess.run(cmd + [scad], capture_output=True, text=True)
    # A failed assert leaves the exit status at 0 and the top level empty, which
    # "spill" reads as a pass, so any error or warning fails the run. An echo
    # export prints them into its file, not to stderr.
    text = r.stderr + (open(out).read() if export == "echo" and os.path.exists(out) else "")
    if not refused:
        ERRORS.extend(f"{os.path.basename(scad)} {defines}: {l}" for l in text.splitlines()
                      if l.startswith(("ERROR", "WARNING")))
    return r


def mesh(path):
    if not os.path.exists(path):
        return []
    d = open(path, "rb").read()
    n = struct.unpack_from("<I", d, 80)[0]
    return [struct.unpack_from("<9f", d, 84 + i * 50 + 12) for i in range(n)]


def volume(path):
    v = 0.0
    for a in mesh(path):
        p, q, r = a[0:3], a[3:6], a[6:9]
        v += (p[0] * (q[1] * r[2] - q[2] * r[1]) - p[1] * (q[0] * r[2] - q[2] * r[0]) + p[2] * (q[0] * r[1] - q[1] * r[0])) / 6
    return abs(v)


def solids(path):
    parent = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a in mesh(path):
        c = [a[0:3], a[3:6], a[6:9]]
        for x in c:
            parent.setdefault(x, x)
        r = find(c[0])
        for x in c[1:]:
            parent[find(x)] = r
    return len({find(x) for x in parent})


def main():
    args = [a for a in sys.argv[1:] if a != "--update"]
    openscad = args[0] if args else "openscad"
    failures = []

    def report(label, ok, got):
        print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")
        if not ok:
            failures.append(label)

    tmp = tempfile.mkdtemp()
    stl = os.path.join(tmp, "x.stl")

    def empty(defines):
        r = run(openscad, stl, defines)
        return "top level object is empty" in r.stderr.lower()

    # 1. Cells lie inset inside their bisectors, and contain their sites.
    for inset in (0, 2):
        out = os.path.join(tmp, "cells.echo")
        run(openscad, out, {"CHECK": '"cells"', "INSET": inset}, export="echo")
        text = open(out).read()
        found = re.search(r'ECHO: "SITES (.*)"', text), re.search(r'ECHO: "WORST (.*)"', text)
        if not all(found):
            report(f"inset {inset}: the cells can be read", False, (re.findall(r"(?m)^(?:ERROR|WARNING).*", text) or ["no output"])[0][:100])
            continue
        sites = json.loads(found[0].group(1))
        cells = {int(i): json.loads(c) for i, c in re.findall(r'ECHO: "CELL (\d+) (.*)"', text)}
        # The margin is computed in OpenSCAD at full precision; echoed points
        # carry only 6 significant digits.
        worst = float(found[1].group(1))
        outside = []
        for i, cell in cells.items():
            p = sites[i]
            if inset == 0:
                # the site is inside its convex cell: on the same side of every edge
                k = len(cell)
                signs = [((cell[(e + 1) % k][0] - cell[e][0]) * (p[1] - cell[e][1])
                          - (cell[(e + 1) % k][1] - cell[e][1]) * (p[0] - cell[e][0])) for e in range(k)]
                if not (all(s >= -1e-9 for s in signs) or all(s <= 1e-9 for s in signs)):
                    outside.append(i)
        nonempty = sum(1 for c in cells.values() if len(c) >= 3)
        label = f"inset {inset}: every cell vertex is at least {inset} inside every bisector"
        report(label, worst >= -1e-9 and len(cells) == 40, f"worst margin {worst:+.2e}, {nonempty} of 40 cells non-empty")
        if inset == 0:
            report("inset 0: every site lies in its own cell", not outside and nonempty == 40,
                   "all do" if not outside else f"sites {outside[:5]} do not")

    # 2. The web is 2 * thickness wide.
    run(openscad, stl, {"CHECK": '"pattern"', "GROW": 0})
    cells = solids(stl)
    run(openscad, stl, {"CHECK": '"pattern"', "GROW": 0.98})
    apart = solids(stl)
    run(openscad, stl, {"CHECK": '"pattern"', "GROW": 1.1})
    meet = solids(stl)
    report("cells grown by 0.98 x thickness stay apart; by 1.1 x some meet", apart == cells and meet < cells,
           f"{cells} cells, {apart} after 0.98, {meet} after 1.1")

    # 3. Seeds and centring.
    digest = lambda: hashlib.sha256(open(stl, "rb").read()).hexdigest() if os.path.exists(stl) else "empty"
    run(openscad, stl, {"CHECK": '"random"', "SEED": 42}); a = digest()
    run(openscad, stl, {"CHECK": '"random"', "SEED": 42}); b = digest()
    run(openscad, stl, {"CHECK": '"random"', "SEED": 43}); c = digest()
    report("a seed repeats its pattern; another seed changes it", a == b and a != c, "repeats" if a == b else "differs")
    shifted = os.path.join(tmp, "shifted.stl")
    run(openscad, stl, {"CHECK": '"random"', "SEED": 9, "CENTER": "true"})
    run(openscad, shifted, {"CHECK": '"shifted"', "SEED": 9})
    diffs = []
    for x, y in ((stl, shifted), (shifted, stl)):
        scad = os.path.join(tmp, "d.scad")
        open(scad, "w").write(f'difference() {{ import("{x}"); import("{y}"); }}\n')
        r = subprocess.run([openscad, "--export-format", "binstl", "-o", os.path.join(tmp, "d.stl"), scad],
                           capture_output=True, text=True)
        diffs.append(0.0 if "empty" in r.stderr.lower() else volume(os.path.join(tmp, "d.stl")))
    report("center moves the sites' midpoint to the origin", max(diffs) < 0.01, f"differs by {max(diffs):.3f} cu mm")

    # 4. voronoi_polygon stays inside, with a solid rim.
    inside = empty({"CHECK": '"spill"', "SEED": 3})
    report("voronoi_polygon stays inside its border", inside, "inside" if inside else "spills outside")
    run(openscad, stl, {"CHECK": '"rim"', "SEED": 3, "EDGING": 3})
    rim = volume(stl)
    ring = os.path.join(tmp, "ring.scad")
    open(ring, "w").write("b = [[0, 0], [60, 10], [80, 60], [30, 90], [-10, 50]];\n"
                          "linear_extrude(1) difference() { polygon(b); offset(delta = -3) polygon(b); }\n")
    run(openscad, stl, {}, scad=ring)
    full = volume(stl)
    report("voronoi_polygon's rim is solid", abs(rim - full) < 0.01, f"{rim:.2f} of {full:.2f} sq mm")

    # 5. Fixed cases, pinned to the original's volumes.
    rows = []
    for k in range(5):
        run(openscad, stl, {"CHECK": '"case"', "CASE": k})
        rows.append(f"case {k} | {volume(stl):.2f}")
    if "--update" in sys.argv:
        open(VOLUMES, "w").write("\n".join(rows) + "\n")
    stored = open(VOLUMES).read().splitlines() if os.path.exists(VOLUMES) else []
    report("the fixed cases keep their volumes", rows == stored, f"{sum(r in stored for r in rows)} of {len(rows)} match")

    # 6. Examples, and a refusal.
    for f in sorted(os.listdir(os.path.join(ROOT, "examples"))):
        r = run(openscad, os.path.join(tmp, "ex.csg"), {}, export="csg", scad=os.path.join(ROOT, "examples", f))
        bad = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith(("WARNING", "ERROR"))]
        report(f"examples/{f} evaluates", r.returncode == 0 and not bad, bad[:1] or "clean")
    one = os.path.join(tmp, "one.scad")
    open(one, "w").write(f"use <{ROOT}/voronoi.scad>\nvoronoi([[0, 0]]);\n")
    r = run(openscad, os.path.join(tmp, "one.csg"), {}, export="csg", scad=one, refused=True)
    report("a single site is refused", "at least two points" in r.stderr, "refused" if "at least two" in r.stderr else "accepted")
    report("no other render printed an error or warning", not ERRORS, "; ".join(ERRORS[:3]) or "none")

    print("all checks passed" if not failures else f"{len(failures)} failed")
    sys.exit(1 if failures else 0)


main()
