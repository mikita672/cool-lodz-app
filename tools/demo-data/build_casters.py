#!/usr/bin/env python3
"""Shadow casters for the on-phone shade model: building footprints with a
height and trees with a crown (assets/demo/shadow_casters.json).

Input: <raw>/osm_buildings.json and <raw>/osm_trees.json (Overpass, see
docs/data-sources.md). Coordinates are metres east/north of `origin`
(equirectangular, latitude 51.77) in decimetres; every ring is delta-encoded
after its first point to keep the file small.

Heights: `height`, else `building:levels` × 3.2 m (+ roof levels × 2 m),
else a typical height for the building type (tenement core 14 m).
Trees: `height` (default 9 m) and `diameter_crown` (default 6 m); tree rows
become a tree every 7 m.

Usage: python3 -I build_casters.py [raw_dir]
"""

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I drops the script dir
from build import in_core, join_rings  # noqa: E402
from common import OUT, RAW_DEFAULT, M_PER_DEG_LAT, M_PER_DEG_LON, ring_area_m2, simplify  # noqa: E402

ORIGIN = (19.425, 51.745)
LOW = {"garage", "garages", "shed", "roof", "carport", "kiosk", "service", "hut", "container", "toilets"}
HOUSE = {"house", "detached", "semidetached_house", "bungalow", "terrace"}
TALL = {"church", "cathedral", "chapel"}


def num(v):
    if v is None:
        return None
    try:
        return float(str(v).replace(",", ".").split()[0].rstrip("m"))
    except ValueError:
        return None


def height(tags, lon, lat):
    h = num(tags.get("height"))
    if h and 2 <= h <= 200:
        return h
    levels = num(tags.get("building:levels"))
    if levels and 0 < levels <= 60:
        return levels * 3.2 + (num(tags.get("roof:levels")) or 0) * 2
    kind = tags.get("building", "yes")
    if kind in LOW:
        return 3.0
    if kind in HOUSE:
        return 7.0
    if kind in TALL:
        return 25.0
    if kind in ("industrial", "warehouse", "manufacture"):
        return 8.0
    return 14.0 if in_core(lon, lat) else 10.0


def xy(lon, lat):
    return (round((lon - ORIGIN[0]) * M_PER_DEG_LON * 10), round((lat - ORIGIN[1]) * M_PER_DEG_LAT * 10))


def encode(ring):
    pts = [xy(*c) for c in ring]
    if pts[0] == pts[-1]:
        pts = pts[:-1]
    out = [pts[0][0], pts[0][1]]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        out += [bx - ax, by - ay]
    return out


def main() -> None:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW_DEFAULT
    buildings = []
    for e in json.loads((raw / "osm_buildings.json").read_text(encoding="utf-8"))["elements"]:
        tags = e.get("tags", {})
        if e["type"] == "way":
            if "geometry" not in e:
                continue
            rings = [[[p["lon"], p["lat"]] for p in e["geometry"]]]
        else:
            outer = [[[p["lon"], p["lat"]] for p in m["geometry"]] for m in e.get("members", []) if m.get("role") == "outer" and m.get("geometry")]
            rings = join_rings(outer)
        for ring in rings:
            if len(ring) < 4 or ring[0] != ring[-1] or ring_area_m2(ring) < 15:
                continue
            ring = simplify(ring, 0.7)
            if len(ring) < 4:
                continue
            cx = sum(c[0] for c in ring) / len(ring)
            cy = sum(c[1] for c in ring) / len(ring)
            buildings.append([round(height(tags, cx, cy))] + encode(ring))
    trees = []
    for e in json.loads((raw / "osm_trees.json").read_text(encoding="utf-8"))["elements"]:
        tags = e.get("tags", {})
        h = num(tags.get("height"))
        h = h if h and 2 <= h <= 40 else None
        crown = num(tags.get("diameter_crown"))
        r = crown / 2 if crown and 1 <= crown <= 30 else None
        extra = [round(h or 9), round(r or 3)] if (h or r) else []
        if e["type"] == "node":
            trees.append(list(xy(e["lon"], e["lat"])) + extra)
        elif "geometry" in e:
            line = [[p["lon"], p["lat"]] for p in e["geometry"]]
            for (alon, alat), (blon, blat) in zip(line, line[1:]):
                ax, ay = xy(alon, alat)
                bx, by = xy(blon, blat)
                n = max(1, int(math.hypot(bx - ax, by - ay) / 70))  # every 7 m
                for k in range(n):
                    trees.append([round(ax + (bx - ax) * k / n), round(ay + (by - ay) * k / n)] + extra)
    data = {
        "origin": list(ORIGIN),
        "metresPerDegree": [round(M_PER_DEG_LON, 3), round(M_PER_DEG_LAT, 3)],
        "unit": "dm",
        "buildings": buildings,
        "trees": trees,
    }
    text = json.dumps(data, separators=(",", ":"))
    (OUT / "shadow_casters.json").write_text(text + "\n", encoding="utf-8")
    print(f"shadow_casters.json: {len(buildings)} buildings, {len(trees)} trees, {len(text) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
