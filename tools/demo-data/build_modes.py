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

    out = {
        "origin": list(ORIGIN),
        "scale": SCALE,
        "streets": streets,
        "venues": [[*xy(*c), k] for c, k in venues],
        "toilets": toilets,
    }
    OUT.write_text(json.dumps(out, separators=(",", ":")))
    nights = [s[0] for s in streets]
    winters = [s[1] for s in streets]
    print(
        f"{len(streets)} streets (night 3/2/1: {nights.count(3)}/{nights.count(2)}/"
        f"{nights.count(1)}; winter 1/2/3: {winters.count(1)}/{winters.count(2)}/"
        f"{winters.count(3)}), {len(venues)} venues, {len(toilets)} toilets, "
        f"{OUT.stat().st_size // 1024} KB"
    )


if __name__ == "__main__":
    main()
