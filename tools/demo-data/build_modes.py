#!/usr/bin/env python3
"""Build assets/demo/street_modes.json: street lines for the «Nocą» and
«Zima» map modes, night venues and public toilets.

Input (gitignored, see fetch_osm.py and the Overpass queries in
docs/data-sources.md): raw/osm_streets.json, raw/osm_bus_ways.json,
raw/osm_night.json, raw/osm_toilets.json.

Coordinates are integers in 1e-5 degrees from "origin", delta-encoded per
line. Streets: [night, winter, x0, y0, dx1, dy1, …]
  night 0 = no data, 1 = lit, 2 = lively at night (≥ 3 venue points within
  40 m), 3 = busiest (≥ 8)
  winter 1 = cleared first (main roads, bus and tram routes),
  2 = then (district streets, pedestrian precincts), 3 = last (residential)
Venues: [x, y, kind] kind 0 bar/pub/club, 1 food/café, 2 theatre/cinema.
Toilets: [x, y, fee] fee 0 free, 1 paid, 2 unknown.
Surfaces (prams, wheelchairs, seniors): [surface, x0, y0, dx1, dy1, …]
  1 paving stones / concrete plates, 2 sett (granite blocks),
  3 cobblestones («kocie łby»), 4 unpaved; smooth asphalt is left out.
Steps: [x, y, ramp] at the middle of each flight; ramp 1 = a ramp for
  prams or wheelchairs is mapped (or a separate one), 0 = none known.
Fountains: [x, y, kind] kind 0 fountain, 1 splash pad (kids can play).
Heat: {"cell": metres, "cells": [[x, y, level], …]} the south-west corners
  of a grid; level 0 cool island (parks, trees), 1 mild, 2 warm, 3 hot
  (dense roofs and pavement, few trees). An estimate from OSM building
  footprints, trees and parks, not a satellite measurement.

Extra input: raw/osm_paths.json (any way with surface sett /
cobblestone / unhewn_cobblestone), raw/osm_steps.json (highway=steps),
raw/osm_fountains.json (amenity=fountain, leisure/playground=splash_pad),
raw/osm_buildings.json, raw/osm_trees.json and the green layer
assets/demo/layer_green.geojson.

Usage: python3 -I build_modes.py [raw_dir] [out_file]
"""

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "raw"
OUT = (
    Path(sys.argv[2])
    if len(sys.argv) > 2
    else HERE.parent.parent / "assets" / "demo" / "street_modes.json"
)
ORIGIN = (19.425, 51.745)  # lon, lat
SCALE = 100_000
M_LAT = 111_195.0
M_LON = M_LAT * math.cos(math.radians(51.77))

VENUE_KIND = {
    "bar": 0, "pub": 0, "nightclub": 0, "biergarten": 0,
    "restaurant": 1, "fast_food": 1, "cafe": 1,
    "theatre": 2, "cinema": 2,
}
# Bars and clubs count double for «where people are at night».
VENUE_WEIGHT = {0: 2, 1: 1, 2: 1}


def load(name):
    return json.loads((RAW / name).read_text())["elements"]


def xy(lon, lat):
    return (round((lon - ORIGIN[0]) * SCALE), round((lat - ORIGIN[1]) * SCALE))


def metres(lon, lat):
    return ((lon - ORIGIN[0]) * M_LON, (lat - ORIGIN[1]) * M_LAT)


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    vx, vy = bx - ax, by - ay
    l2 = vx * vx + vy * vy
    t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * vx + (py - ay) * vy) / l2))
    cx, cy = ax + t * vx, ay + t * vy
    return math.hypot(px - cx, py - cy)


def centre(e):
    if "lat" in e:
        return e["lon"], e["lat"]
    c = e.get("center")
    return (c["lon"], c["lat"]) if c else None


SURFACE = {
    "paving_stones": 1, "concrete:plates": 1, "brick": 1, "bricks": 1,
    "sett": 2, "pebblestone": 3,
    "cobblestone": 3, "unhewn_cobblestone": 3,
    "gravel": 4, "fine_gravel": 4, "ground": 4, "dirt": 4, "unpaved": 4,
    "grass": 4, "sand": 4,
}
HEAT_CELL = 200  # metres
ASSETS = HERE.parent.parent / "assets" / "demo"


def line_flat(first, pts):
    coords = [xy(*p) for p in pts]
    flat = [*first, coords[0][0], coords[0][1]]
    for (x0, y0), (x1, y1) in zip(coords, coords[1:]):
        flat += [x1 - x0, y1 - y0]
    return flat


def surfaces_and_steps():
    lines = []
    seen = set()
    for name in ("osm_streets.json", "osm_paths.json"):
        if not (RAW / name).exists():
            continue
        for e in load(name):
            tags = e.get("tags", {})
            kind = SURFACE.get(tags.get("surface"))
            geom = e.get("geometry") or []
            if kind is None or "highway" not in tags or len(geom) < 2 or e["id"] in seen:
                continue
            seen.add(e["id"])
            lines.append(line_flat([kind], [(g["lon"], g["lat"]) for g in geom]))
    steps = []
    if (RAW / "osm_steps.json").exists():
        for e in load("osm_steps.json"):
            tags = e.get("tags", {})
            geom = e.get("geometry") or []
            if tags.get("highway") != "steps" or not geom or tags.get("conveying"):
                continue
            mid = geom[len(geom) // 2]
            ramp = tags.get("ramp:wheelchair") or tags.get("ramp:stroller") or tags.get("ramp")
            steps.append([*xy(mid["lon"], mid["lat"]), 1 if ramp in ("yes", "separate") else 0])
    return lines, steps


def fountains():
    out = []
    if not (RAW / "osm_fountains.json").exists():
        return out
    for e in load("osm_fountains.json"):
        c = centre(e)
        if c is None:
            continue
        tags = e.get("tags", {})
        splash = (
            tags.get("fountain") == "splash_pad"
            or tags.get("leisure") == "splash_pad"
            or tags.get("playground") == "splash_pad"
        )
        out.append([*xy(*c), 1 if splash else 0])
    return out


def ring_area(ring):
    a = 0.0
    for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
        a += x0 * y1 - x1 * y0
    return abs(a) / 2


def inside(pt, ring):
    x, y = pt
    hit = False
    for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def heat_islands():
    """Per 200 m cell: roof share and tree crown share (OSM), park share
    (the green layer). Hot = many roofs, few trees; cool = parks/trees."""
    lon0, lat0, lon1, lat1 = 19.425, 51.745, 19.495, 51.79
    w, h = metres(lon1, lat1)
    nx, ny = int(w // HEAT_CELL) + 1, int(h // HEAT_CELL) + 1
    roofs = [[0.0] * ny for _ in range(nx)]
    crowns = [[0.0] * ny for _ in range(nx)]

    def cell(mx, my):
        i, j = int(mx // HEAT_CELL), int(my // HEAT_CELL)
        return (i, j) if 0 <= i < nx and 0 <= j < ny else None

    for e in load("osm_buildings.json"):
        geom = e.get("geometry") or []
        if len(geom) < 3:
            continue
        ring = [metres(g["lon"], g["lat"]) for g in geom]
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        c = cell(cx, cy)
        if c:
            roofs[c[0]][c[1]] += ring_area(ring)
    for e in load("osm_trees.json"):
        tags = e.get("tags", {})
        if e.get("type") == "node":
            c = cell(*metres(e["lon"], e["lat"]))
            if c:
                crowns[c[0]][c[1]] += math.pi * 9  # 3 m crown
        elif tags.get("natural") == "tree_row":
            geom = e.get("geometry") or []
            for a, b in zip(geom, geom[1:]):
                pa, pb = metres(a["lon"], a["lat"]), metres(b["lon"], b["lat"])
                n = max(1, int(math.dist(pa, pb) // 7))
                for k in range(n):
                    t = (k + 0.5) / n
                    c = cell(pa[0] + t * (pb[0] - pa[0]), pa[1] + t * (pb[1] - pa[1]))
                    if c:
                        crowns[c[0]][c[1]] += math.pi * 9
    green = json.loads((ASSETS / "layer_green.geojson").read_text())
    rings = []
    for f in green["features"]:
        g = f["geometry"]
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        for poly in polys:
            ring = [metres(lon, lat) for lon, lat in poly[0]]
            xs, ys = [p[0] for p in ring], [p[1] for p in ring]
            rings.append((ring, min(xs), min(ys), max(xs), max(ys)))
    area = HEAT_CELL * HEAT_CELL
    cells = []
    for i in range(nx):
        for j in range(ny):
            x0, y0 = i * HEAT_CELL, j * HEAT_CELL
            # Park share from a 10 × 10 sample.
            near = [r for r in rings if r[1] < x0 + HEAT_CELL and r[3] > x0 and r[2] < y0 + HEAT_CELL and r[4] > y0]
            park = 0
            if near:
                for a in range(10):
                    for b in range(10):
                        p = (x0 + (a + 0.5) * HEAT_CELL / 10, y0 + (b + 0.5) * HEAT_CELL / 10)
                        if any(inside(p, r[0]) for r in near):
                            park += 1
            park /= 100
            roof = min(1.0, roofs[i][j] / area)
            tree = min(1.0, crowns[i][j] / area)
            score = roof - 1.5 * tree - park
            if park >= 0.4 or score < 0.0:
                level = 0
            elif score < 0.2:
                level = 1
            elif score < 0.35:
                level = 2
            else:
                level = 3
            lon = ORIGIN[0] + x0 / M_LON
            lat = ORIGIN[1] + y0 / M_LAT
            cells.append([*xy(lon, lat), level])
    return cells


def main():
    transit = {e["id"] for e in load("osm_bus_ways.json")}
    venues = []
    for e in load("osm_night.json"):
        kind = VENUE_KIND.get(e.get("tags", {}).get("amenity"))
        c = centre(e)
        if kind is None or c is None:
            continue
        venues.append((c, kind))
    # 50 m grid for the venue search.
    grid = {}
    for (lon, lat), kind in venues:
        mx, my = metres(lon, lat)
        grid.setdefault((int(mx // 50), int(my // 50)), []).append((mx, my, kind))

    streets = []
    for e in load("osm_streets.json"):
        tags = e.get("tags", {})
        geom = e.get("geometry") or []
        if len(geom) < 2:
            continue
        hw = tags.get("highway")
        pts = [(g["lon"], g["lat"]) for g in geom]
        m = [metres(*p) for p in pts]
        score = 0
        seen = set()
        for i in range(len(m) - 1):
            a, b = m[i], m[i + 1]
            for gx in range(int(min(a[0], b[0]) // 50) - 1, int(max(a[0], b[0]) // 50) + 2):
                for gy in range(int(min(a[1], b[1]) // 50) - 1, int(max(a[1], b[1]) // 50) + 2):
                    for v in grid.get((gx, gy), ()):
                        if id(v) in seen:
                            continue
                        if seg_dist(v[:2], a, b) <= 40:
                            seen.add(id(v))
                            score += VENUE_WEIGHT[v[2]]
        lit = tags.get("lit") in ("yes", "24/7")
        if score >= 8 or (hw == "pedestrian" and score >= 3):
            night = 3
        elif score >= 3:
            night = 2
        elif lit:
            night = 1
        else:
            night = 0
        if hw in ("trunk", "primary", "secondary") or e["id"] in transit or "embedded_rails" in tags:
            winter = 1
        elif hw in ("tertiary", "pedestrian"):
            winter = 2
        else:
            winter = 3
        coords = [xy(*p) for p in pts]
        flat = [night, winter, coords[0][0], coords[0][1]]
        for (x0, y0), (x1, y1) in zip(coords, coords[1:]):
            flat += [x1 - x0, y1 - y0]
        streets.append(flat)

    toilets = []
    for e in load("osm_toilets.json"):
        c = centre(e)
        if c is None:
            continue
        tags = e.get("tags", {})
        if tags.get("access") in ("private", "no", "customers"):
            continue
        fee = {"no": 0, "yes": 1}.get(tags.get("fee"), 2)
        toilets.append([*xy(*c), fee])

    surfaces, steps = surfaces_and_steps()
    fount = fountains()
    heat = heat_islands()
    out = {
        "origin": list(ORIGIN),
        "scale": SCALE,
        "streets": streets,
        "venues": [[*xy(*c), k] for c, k in venues],
        "toilets": toilets,
        "surfaces": surfaces,
        "steps": steps,
        "fountains": fount,
        "heat": {"cell": HEAT_CELL, "cells": heat},
    }
    OUT.write_text(json.dumps(out, separators=(",", ":")))
    nights = [s[0] for s in streets]
    winters = [s[1] for s in streets]
    print(
        f"{len(streets)} streets (night 3/2/1: {nights.count(3)}/{nights.count(2)}/"
        f"{nights.count(1)}; winter 1/2/3: {winters.count(1)}/{winters.count(2)}/"
        f"{winters.count(3)}), {len(venues)} venues, {len(toilets)} toilets, "
        f"{len(surfaces)} rough surfaces, {len(steps)} steps, {len(fount)} fountains, "
        f"heat cells 0/1/2/3: {[sum(1 for c in heat if c[2] == k) for k in range(4)]}, "
        f"{OUT.stat().st_size // 1024} KB"
    )


if __name__ == "__main__":
    main()
