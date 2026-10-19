#!/usr/bin/env python3
"""Build every demo file in assets/demo/ (except places_cool.json and
quest.json) from the raw downloads.

Real data: route geometry, distance and duration (OSM foot router), parks,
trees, streets, benches and drinking water (OpenStreetMap), GIOŚ station
locations. Synthetic: sun shares, the shade layer and noise levels — they come
from the simple model below until module D sends real numbers.

Usage: python3 -I build.py [raw_dir] [places_cool.json]
"""

import json
import math
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I drops the script dir
from common import (  # noqa: E402
    BBOX_CENTRE,
    OUT,
    RAW_DEFAULT,
    buffer_line,
    dist_m,
    line_length,
    offset_line,
    point_in_ring,
    point_seg_dist,
    r6,
    ring_area_m2,
    simplify,
    to_xy,
)
from fetch_routes import ROUTES  # noqa: E402

DEMO_DATE = (2026, 7, 15)  # a July heatwave day, same as in docs/api-contract.md
TZ = timezone(timedelta(hours=2))
DEPARTURES = ["10:00", "14:30", "18:00"]
HOURS = [f"{h:02d}:{m:02d}" for h in range(8, 21) for m in (0, 30)][:25]  # 08:00..20:00

# Shade model parameters.
BUILDING_H = 16.0  # typical Śródmieście tenement height, m
STREET_W = {"trunk": 40, "primary": 40, "secondary": 30, "tertiary": 24, "pedestrian": 20}
STREET_W_DEFAULT = 18
PASSAGE_W = 14  # courtyards and passages without a named street nearby
BUILDING_WEIGHT = 0.6  # a pedestrian uses one sidewalk, not the whole canyon
# OSM maps only part of the street trees, so the raw model cannot tell the
# variants apart well. Each variant is calibrated (sun' = sun ** gamma) to the
# sun share at 14:30 below, in the range from the spec (Zacieniona ≈ 72 % shade
# vs Najkrótsza ≈ 31 %); the model still gives the shape along the route and
# over the day. Replace with module D numbers once they arrive.
TARGET_SUN_1430 = {
    "manufaktura_piotrkowska": {"shortest": 0.69, "shaded": 0.28, "compromise": 0.47},
    "plac_wolnosci_piotrkowska": {"shortest": 0.66, "shaded": 0.31, "compromise": 0.49},
}

# Noise (dB) by road class, with overrides for the main arteries.
NOISE_CLASS = {"trunk": 72, "primary": 68, "secondary": 63, "tertiary": 58}
NOISE_NAMED = {
    "Aleja Włókniarzy": 75,
    "Aleja Marszałka Józefa Piłsudskiego": 72,
    "Aleja Adama Mickiewicza": 72,
    "Zachodnia": 70,
    "Aleja Tadeusza Kościuszki": 68,
    "Prezydenta Gabriela Narutowicza": 66,
    "Jana Kilińskiego": 65,
    "Północna": 65,
    "Stefana Żeromskiego": 64,
}


def load(raw: Path, name: str):
    return json.loads((raw / name).read_text(encoding="utf-8"))


def write(name: str, data) -> None:
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    (OUT / name).write_text(text + "\n", encoding="utf-8")
    print(f"{name}: {len(text.encode()) / 1024:.0f} KB")


def in_bbox(lon: float, lat: float) -> bool:
    b = BBOX_CENTRE
    return b["west"] <= lon <= b["east"] and b["south"] <= lat <= b["north"]


# ---------------------------------------------------------------- sun position


def sun_position(lat: float, lon: float, when: datetime) -> tuple[float, float]:
    """(elevation, azimuth from north clockwise) in degrees; low-precision
    almanac formula, accurate to a fraction of a degree."""
    utc = when.astimezone(timezone.utc)
    n = (utc - datetime(2000, 1, 1, 12, tzinfo=timezone.utc)).total_seconds() / 86400
    L = (280.460 + 0.9856474 * n) % 360
    g = math.radians((357.528 + 0.9856003 * n) % 360)
    lam = math.radians(L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g))
    eps = math.radians(23.439 - 0.0000004 * n)
    ra = math.atan2(math.cos(eps) * math.sin(lam), math.cos(lam))
    dec = math.asin(math.sin(eps) * math.sin(lam))
    gmst = (18.697374558 + 24.06570982441908 * n) % 24
    ha = math.radians(gmst * 15 + lon) - ra
    phi = math.radians(lat)
    el = math.asin(math.sin(phi) * math.sin(dec) + math.cos(phi) * math.cos(dec) * math.cos(ha))
    az = math.atan2(-math.sin(ha), math.cos(phi) * math.tan(dec) - math.sin(phi) * math.cos(ha))
    return math.degrees(el), math.degrees(az) % 360


def at(hhmm: str) -> datetime:
    h, m = map(int, hhmm.split(":"))
    return datetime(*DEMO_DATE, h, m, tzinfo=TZ)


# ------------------------------------------------------------------ OSM input


class Grid:
    """Bucket index of items by 50 m cells."""

    def __init__(self) -> None:
        self.cells = defaultdict(list)

    @staticmethod
    def key(x: float, y: float):
        return int(x // 50), int(y // 50)

    def add_point(self, x, y, item) -> None:
        self.cells[self.key(x, y)].append(item)

    def add_segment(self, a, b, item) -> None:
        for gx in range(int(min(a[0], b[0]) // 50) - 1, int(max(a[0], b[0]) // 50) + 2):
            for gy in range(int(min(a[1], b[1]) // 50) - 1, int(max(a[1], b[1]) // 50) + 2):
                self.cells[(gx, gy)].append(item)

    def near(self, x, y):
        kx, ky = self.key(x, y)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                yield from self.cells.get((kx + dx, ky + dy), ())


def join_rings(ways):
    """Join member ways ([lon, lat] lists) into closed rings."""
    ways = [w[:] for w in ways if len(w) >= 2]
    rings = []
    while ways:
        ring = ways.pop(0)
        changed = True
        while ring[0] != ring[-1] and changed:
            changed = False
            for i, w in enumerate(ways):
                if w[0] == ring[-1]:
                    ring += w[1:]
                elif w[-1] == ring[-1]:
                    ring += w[::-1][1:]
                elif w[-1] == ring[0]:
                    ring = w + ring[1:]
                elif w[0] == ring[0]:
                    ring = w[::-1] + ring[1:]
                else:
                    continue
                ways.pop(i)
                changed = True
                break
        if ring[0] == ring[-1] and len(ring) >= 4:
            rings.append(ring)
    return rings


class Osm:
    def __init__(self, raw: Path) -> None:
        g = load(raw, "osm_green_trees.json")["elements"]
        self.trees = Grid()
        self.tree_rows = []
        self.tree_row_grid = Grid()
        self.green = []  # (kind, name, outer ring, osm ref)
        self.benches = []
        for e in g:
            t = e.get("tags", {})
            if e["type"] == "node":
                if t.get("natural") == "tree":
                    self.trees.add_point(*to_xy(e["lon"], e["lat"]), to_xy(e["lon"], e["lat"]))
                elif t.get("amenity") == "bench":
                    self.benches.append(e)
                continue
            if e["type"] == "way" and t.get("natural") == "tree_row":
                line = [[p["lon"], p["lat"]] for p in e["geometry"]]
                self.tree_rows.append(line)
                xy = [to_xy(*c) for c in line]
                for i in range(len(xy) - 1):
                    self.tree_row_grid.add_segment(xy[i], xy[i + 1], (xy[i], xy[i + 1]))
                continue
            kind = self.green_kind(t)
            if not kind:
                continue
            if e["type"] == "way":
                rings = [[[p["lon"], p["lat"]] for p in e["geometry"]]]
                if rings[0][0] != rings[0][-1]:
                    continue
            else:
                outer = [
                    [[p["lon"], p["lat"]] for p in m["geometry"]]
                    for m in e.get("members", [])
                    if m.get("role") == "outer" and m.get("geometry")
                ]
                rings = join_rings(outer)
            for ring in rings:
                if ring_area_m2(ring) >= 800:
                    self.green.append((kind, t.get("name"), ring, f"{e['type']}/{e['id']}"))
        self.parks = [r for k, _, r, _ in self.green if k in ("park", "forest")]

        self.streets = []  # (name, highway, [lon, lat] line)
        self.street_grid = Grid()
        for e in load(raw, "osm_streets.json")["elements"]:
            line = [[p["lon"], p["lat"]] for p in e["geometry"]]
            st = (e["tags"]["name"], e["tags"]["highway"], line)
            self.streets.append(st)
            xy = [to_xy(*c) for c in line]
            for i in range(len(xy) - 1):
                self.street_grid.add_segment(xy[i], xy[i + 1], (xy[i], xy[i + 1], st))
        self.water = load(raw, "osm_water.json")["elements"]

    @staticmethod
    def green_kind(t):
        if t.get("leisure") == "park":
            return "park"
        if t.get("leisure") == "garden" and t.get("name"):
            return "garden"
        if t.get("natural") == "wood" or (t.get("landuse") == "forest" and t.get("name")):
            return "forest"
        if t.get("landuse") == "grass" and t.get("name"):
            return "grass"
        return None

    def tree_count(self, x, y, r=15.0) -> int:
        return sum(1 for tx, ty in self.trees.near(x, y) if math.hypot(tx - x, ty - y) < r)

    def canopy(self, lon, lat) -> float:
        """Share of the walk covered by tree crowns around a point, 0..1."""
        x, y = to_xy(lon, lat)
        s = min(0.9, 0.3 * self.tree_count(x, y))
        if any(point_seg_dist((x, y), a, b) < 10 for a, b in self.tree_row_grid.near(x, y)):
            s = max(s, 0.75)
        return s

    def in_park(self, lon, lat) -> bool:
        return any(point_in_ring(lon, lat, ring) for ring in self.parks)

    def street_width(self, lon, lat) -> float:
        x, y = to_xy(lon, lat)
        best, width = 20.0, PASSAGE_W
        for a, b, (_, hw, _) in self.street_grid.near(x, y):
            d = point_seg_dist((x, y), a, b)
            if d < best:
                best, width = d, STREET_W.get(hw, STREET_W_DEFAULT)
        return width


# ----------------------------------------------------------------- shade model


def bearing(a, b) -> float:
    ax, ay = to_xy(*a)
    bx, by = to_xy(*b)
    return math.degrees(math.atan2(bx - ax, by - ay)) % 360


def building_shadow(width: float, theta: float, el: float, az: float) -> float:
    """Share of the walk along a street canyon of `width` (bearing theta) that
    lies in building shadow; saturates once the shadow covers both sidewalks."""
    if el <= 2:
        return 1.0
    across = BUILDING_H / math.tan(math.radians(el)) * abs(math.sin(math.radians(az - theta)))
    return min(1.0, BUILDING_WEIGHT * across / width)


class EdgeModel:
    """Per-edge static context of a route; sun share for any time."""

    def __init__(self, osm: Osm, coords) -> None:
        self.coords = coords
        self.length = [dist_m(coords[i], coords[i + 1]) for i in range(len(coords) - 1)]
        self.ctx = []
        for i in range(len(coords) - 1):
            mid = [(coords[i][0] + coords[i + 1][0]) / 2, (coords[i][1] + coords[i + 1][1]) / 2]
            park = osm.in_park(*mid)
            canopy = max(osm.canopy(*mid), 0.8 if park else 0.0)
            width = None if park else osm.street_width(*mid)
            self.ctx.append((canopy, width, bearing(coords[i], coords[i + 1]), mid))

    def sun(self, start: datetime, duration_s: float, gamma: float = 1.0):
        total = sum(self.length) or 1.0
        out, walked = [], 0.0
        for length, (canopy, width, theta, mid) in zip(self.length, self.ctx):
            t = start + timedelta(seconds=duration_s * (walked + length / 2) / total)
            walked += length
            el, az = sun_position(mid[1], mid[0], t)
            b = 0.0 if width is None else building_shadow(width, theta, el, az)
            # crowns cast longer shadows when the sun is low
            crowns = min(0.95, canopy * (2 - math.sin(math.radians(max(el, 0)))))
            raw = 0.0 if el <= 2 else (1 - b) * (1 - crowns)
            out.append(min(0.97, max(0.03, raw**gamma)))
        return out

    def calibrate(self, duration_s: float, target: float) -> float:
        """gamma for which the mean sun share at 14:30 equals target."""
        lo, hi = 0.05, 20.0
        for _ in range(60):
            mid = math.sqrt(lo * hi)
            if self.mean(self.sun(at("14:30"), duration_s, mid)) > target:
                lo = mid
            else:
                hi = mid
        return math.sqrt(lo * hi)

    def mean(self, values) -> float:
        return sum(v * l for v, l in zip(values, self.length)) / (sum(self.length) or 1.0)


def make_segments(model: EdgeModel, sun, lo=6, hi=12):
    """Group edges into lo..hi runs of similar sun share; returns
    [(from_vertex, to_vertex, sunShare)]."""
    n = len(sun)
    # smooth over ~40 m, then quantise to quarters
    smooth = []
    for i in range(n):
        acc = w = 0.0
        j, d = i, 0.0
        while j >= 0 and d < 20:
            acc += sun[j] * model.length[j]
            w += model.length[j]
            d += model.length[j]
            j -= 1
        j, d = i + 1, 0.0
        while j < n and d < 20:
            acc += sun[j] * model.length[j]
            w += model.length[j]
            d += model.length[j]
            j += 1
        smooth.append(acc / w if w else sun[i])
    runs = []  # [start_edge, end_edge_exclusive]
    for i, v in enumerate(smooth):
        q = round(v * 4)
        if runs and runs[-1][2] == q:
            runs[-1][1] = i + 1
        else:
            runs.append([i, i + 1, q])

    def length(r):
        return sum(model.length[r[0] : r[1]])

    def value(r):
        return sum(sun[k] * model.length[k] for k in range(r[0], r[1])) / (length(r) or 1.0)

    def merge(i):  # merge run i with run i+1
        runs[i][1] = runs[i + 1][1]
        del runs[i + 1]

    # drop short runs into the more similar neighbour
    changed = True
    while changed and len(runs) > lo:
        changed = False
        for i, r in enumerate(runs):
            if length(r) < 80 and len(runs) > 1:
                if i == 0:
                    merge(0)
                elif i == len(runs) - 1:
                    merge(i - 1)
                else:
                    left = abs(value(runs[i - 1]) - value(r))
                    right = abs(value(runs[i + 1]) - value(r))
                    merge(i - 1 if left <= right else i)
                changed = True
                break
    while len(runs) > hi:
        i = min(range(len(runs) - 1), key=lambda k: abs(value(runs[k]) - value(runs[k + 1])) * min(length(runs[k]), length(runs[k + 1])))
        merge(i)
    while len(runs) < lo:
        i = max(range(len(runs)), key=lambda k: length(runs[k]) if runs[k][1] - runs[k][0] > 1 else -1)
        a, b = runs[i][0], runs[i][1]
        half, acc, cut = length(runs[i]) / 2, 0.0, a + 1
        for k in range(a, b - 1):
            acc += model.length[k]
            if acc >= half:
                cut = k + 1
                break
        runs[i : i + 1] = [[a, cut, None], [cut, b, None]]
    return [(r[0], r[1], round(value(r), 2)) for r in runs]


# ----------------------------------------------------------------------- stops


def find_stops(coords, places, kind, radius):
    """Places within radius of the route, by distance; skips the start area."""
    xy = [to_xy(*c) for c in coords]
    found = []
    for p in places:
        if dist_m(coords[0], [p["lon"], p["lat"]]) < 150:
            continue
        px = to_xy(p["lon"], p["lat"])
        d = min(point_seg_dist(px, xy[i], xy[i + 1]) for i in range(len(xy) - 1))
        if d <= radius:
            found.append((d, p["id"]))
    return [{"placeId": pid, "type": kind} for _, pid in sorted(found)]


# Used only when places_cool.json (APP-05) is not available: the stops found
# with the APP-05 list of 2026-10-19 (cool-006 Mediateka MeMo, cool-007
# Biblioteka Wolność, cool-011 Muzeum Miasta Łodzi).
FALLBACK_COOL = {
    ("manufaktura_piotrkowska", "shortest"): ["cool-007", "cool-011"],
    ("manufaktura_piotrkowska", "shaded"): ["cool-007"],
    ("manufaktura_piotrkowska", "compromise"): [],
    ("plac_wolnosci_piotrkowska", "shortest"): [],
    ("plac_wolnosci_piotrkowska", "shaded"): ["cool-006"],
    ("plac_wolnosci_piotrkowska", "compromise"): [],
}


# ---------------------------------------------------------------------- routes


def remove_spurs(coords):
    """Drop duplicate points, loops and out-and-back detours (A, B, A -> A)."""
    out, seen = [], {}
    for c in coords:
        key = tuple(c)
        if key in seen:
            del out[seen[key] + 1 :]
            seen = {tuple(p): i for i, p in enumerate(out)}
            continue
        seen[key] = len(out)
        out.append(c)
    return out


def build_routes(osm: Osm, raw: Path, cool_places, water_places) -> None:
    for route in ROUTES:
        variants = {}
        for variant in ("shortest", "shaded", "compromise"):
            r = load(raw, f"route_{route}_{variant}.json")["routes"][0]
            coords = [[r6(lon), r6(lat)] for lon, lat in r["geometry"]["coordinates"]]
            clean = remove_spurs(coords)
            # a via point can snap onto a dead end: drop the out-and-back part
            # and shorten distance and time by its length
            ratio = line_length(clean) / line_length(coords)
            variants[variant] = (clean, r["distance"] * ratio, r["duration"] * ratio)
        shortest_s = round(variants["shortest"][2])
        models = {v: EdgeModel(osm, c) for v, (c, _, _) in variants.items()}
        gammas = {v: models[v].calibrate(dur, TARGET_SUN_1430[route][v]) for v, (_, _, dur) in variants.items()}
        print(f"  gamma: {', '.join(f'{v} {g:.2f}' for v, g in gammas.items())}")
        by_hour = {}
        for v, (_, _, dur) in variants.items():
            by_hour[v] = {h: round(models[v].mean(models[v].sun(at(h), dur, gammas[v])), 2) for h in HOURS}
        departures = {}
        for dep in DEPARTURES:
            out = []
            for v, (coords, dist, dur) in variants.items():
                m = models[v]
                sun = m.sun(at(dep), dur, gammas[v])
                segs = make_segments(m, sun)
                seg_len = [sum(m.length[a:b]) for a, b, _ in segs]
                share = round(sum(s * l for (_, _, s), l in zip(segs, seg_len)) / sum(seg_len), 2)
                hours = dict(by_hour[v])
                hours[dep] = share  # keep the slider consistent with the card
                if cool_places is not None:
                    stops = find_stops(coords, cool_places, "cool", 80)[:2]
                else:
                    stops = [{"placeId": p, "type": "cool"} for p in FALLBACK_COOL[(route, v)]]
                stops += find_stops(coords, water_places, "water", 25)[:2]
                out.append(
                    {
                        "variant": v,
                        "geometry": {"type": "LineString", "coordinates": coords},
                        "segments": [{"from": a, "to": b, "sunShare": s} for a, b, s in segs],
                        "distance_m": round(dist),
                        "duration_s": round(dur),
                        "sunShare": share,
                        "extraTimeVsShortest_s": round(dur) - shortest_s,
                        "stops": stops,
                        "sunShareByHour": hours,
                    }
                )
            departures[dep] = {"coverage": "full", "variants": out}
        write(f"routes_{route}.json", {"departures": departures})
        for dep in DEPARTURES:
            summary = ", ".join(
                f"{v['variant']} {v['distance_m']} m {v['duration_s'] / 60:.1f} min "
                f"shade {100 - round(v['sunShare'] * 100)}% +{v['extraTimeVsShortest_s'] / 60:.1f}"
                for v in departures[dep]["variants"]
            )
            print(f"  {dep}: {summary}")


# ---------------------------------------------------------------------- layers


def feature(ring, props):
    return {"type": "Feature", "properties": props, "geometry": {"type": "Polygon", "coordinates": [ring]}}


def collection(features):
    return {"type": "FeatureCollection", "features": features}


def clip_ok(line) -> bool:
    return any(in_bbox(*c) for c in line)


def build_green(osm: Osm) -> None:
    feats = []
    for kind, name, ring, ref in osm.green:
        if not clip_ok(ring):
            continue
        ring = simplify(ring, 2.0)
        if len(ring) < 4:
            continue
        props = {"kind": kind, "name": name, "osm": ref}
        feats.append(feature([[r6(x), r6(y)] for x, y in ring], props))
    write("layer_green.geojson", collection(feats))


def in_core(lon: float, lat: float) -> bool:
    """The 19th-century tenement grid, where building shadows are modelled."""
    return 19.435 <= lon <= 19.480 and 51.755 <= lat <= 51.785


def merge_lines(lines):
    """Join open polylines that share endpoints into longer ones."""
    lines = [l[:] for l in lines if len(l) >= 2]
    out = []
    while lines:
        cur = lines.pop(0)
        changed = True
        while changed:
            changed = False
            for i, l in enumerate(lines):
                if l[0] == cur[-1]:
                    cur += l[1:]
                elif l[-1] == cur[-1]:
                    cur += l[::-1][1:]
                elif l[-1] == cur[0]:
                    cur = l + cur[1:]
                elif l[0] == cur[0]:
                    cur = l[::-1] + cur[1:]
                else:
                    continue
                lines.pop(i)
                changed = True
                break
        out.append(cur)
    return out


def merged_streets(osm: Osm):
    groups = defaultdict(list)
    for name, hw, line in osm.streets:
        groups[(name, hw)].append(line)
    for (name, hw), lines in sorted(groups.items()):
        for line in merge_lines(lines):
            yield name, hw, line


def street_runs(line, chunk_m=40.0):
    """Split a polyline into consecutive pieces of about chunk_m metres."""
    pieces, cur, acc = [], [line[0]], 0.0
    for a, b in zip(line, line[1:]):
        cur.append(b)
        acc += dist_m(a, b)
        if acc >= chunk_m:
            pieces.append(cur)
            cur, acc = [b], 0.0
    if len(cur) > 1:
        if pieces and acc < chunk_m / 2:
            pieces[-1] += cur[1:]
        else:
            pieces.append(cur)
    return pieces


def build_shade(osm: Osm) -> None:
    feats = []
    when = at("14:30")
    el, az = sun_position(51.77, 19.46, when)
    # 1. parks and woods: more mapped trees per hectare, more shade
    for kind, name, ring, _ in osm.green:
        if kind not in ("park", "forest") or not clip_ok(ring):
            continue
        area_ha = ring_area_m2(ring) / 10000
        xs = [to_xy(*c) for c in ring]
        cx = sum(p[0] for p in xs) / len(xs)
        cy = sum(p[1] for p in xs) / len(xs)
        reach = max(math.hypot(p[0] - cx, p[1] - cy) for p in xs)
        trees = 0
        for gx in range(int((cx - reach) // 50), int((cx + reach) // 50) + 1):
            for gy in range(int((cy - reach) // 50), int((cy + reach) // 50) + 1):
                for tx, ty in osm.trees.cells.get((gx, gy), ()):
                    lon, lat = tx / (to_xy(1, 0)[0]), ty / (to_xy(0, 1)[1])
                    if point_in_ring(lon, lat, ring):
                        trees += 1
        shade = 0.9 if kind == "forest" else 0.55 + 0.35 * min(1.0, trees / max(area_ha, 0.05) / 60)
        ring = simplify(ring, 3.0)
        feats.append(feature([[r6(x), r6(y)] for x, y in ring], {"shade": round(shade, 2)}))
    # 2. tree rows
    for line in osm.tree_rows:
        if not clip_ok(line):
            continue
        poly = buffer_line(simplify(line, 2.0), 8.0)
        if poly:
            feats.append(feature(poly, {"shade": 0.7}))
    # 3. streets: tree-lined runs and building shadows on the sun side
    for name, hw, line in merged_streets(osm):
        if not clip_ok(line):
            continue
        width = STREET_W.get(hw, STREET_W_DEFAULT)
        treed, shadow = [], []  # runs: [coords, value]
        prev_treed = prev_side = None
        for piece in street_runs(line):
            mid = piece[len(piece) // 2]
            park = osm.in_park(*mid)
            n = sum(osm.tree_count(*to_xy(*c), 12.0) for c in piece[:: max(1, len(piece) // 3)])
            is_treed = not park and n >= 2
            if is_treed:
                s = min(0.85, 0.4 + 0.08 * n)
                if prev_treed:
                    treed[-1][0] += piece[1:]
                    treed[-1][1].append(s)
                else:
                    treed.append([piece[:], [s]])
            prev_treed = is_treed
            theta = bearing(piece[0], piece[-1])
            across = BUILDING_H / math.tan(math.radians(el)) * abs(math.sin(math.radians(az - theta)))
            w = min(width, across)
            side = None
            if w >= 3 and not park and in_core(*mid):
                # left normal of travel (bearing theta) points to theta - 90°
                side = 1 if math.cos(math.radians(az - (theta - 90))) > 0 else -1
                if prev_side == side:
                    shadow[-1][0] += piece[1:]
                    shadow[-1][1].append(w)
                else:
                    shadow.append([piece[:], [w], side])
            prev_side = side
        for coords, values in treed:
            poly = buffer_line(simplify(coords, 3.0), 12.0)
            if poly:
                feats.append(feature(poly, {"shade": round(sum(values) / len(values), 2)}))
        for coords, ws, side in shadow:
            coords = simplify(coords, 3.0)
            w = sum(ws) / len(ws)
            outer = offset_line(coords, side * width / 2)
            inner = offset_line(coords, side * (width / 2 - w))
            feats.append(feature(outer + inner[::-1] + [outer[0]], {"shade": 0.85}))
    write("layer_shade_1430.geojson", collection(feats))


def build_noise(osm: Osm) -> None:
    feats = []
    for name, hw, line in merged_streets(osm):
        db = NOISE_NAMED.get(name, NOISE_CLASS.get(hw))
        if db is None or hw == "pedestrian" or not clip_ok(line):
            continue
        line = simplify(line, 4.0)
        if db >= 63:  # quieter roads get no outer band
            outer = buffer_line(line, 40.0)
            if outer:
                feats.append(feature(outer, {"db": db - 8}))
        inner = buffer_line(line, 15.0)
        if inner:
            feats.append(feature(inner, {"db": db}))
    write("layer_noise.geojson", collection(feats))


# ---------------------------------------------------------------------- places


def build_places(osm: Osm):
    water = [
        {"id": f"water-{e['id']}", "type": "water", "lat": r6(e["lat"]), "lon": r6(e["lon"])}
        for e in sorted(osm.water, key=lambda e: e["id"])
    ]
    write("places_water.json", {"places": water})
    centre = [19.4560, 51.7700]  # ul. Piotrkowska, the middle of the demo area
    benches = sorted(osm.benches, key=lambda e: dist_m(centre, [e["lon"], e["lat"]]))[:500]
    benches = [
        {"id": f"bench-{e['id']}", "type": "bench", "lat": r6(e["lat"]), "lon": r6(e["lon"])}
        for e in sorted(benches, key=lambda e: e["id"])
    ]
    write("places_bench.json", {"places": benches})
    return water


# ------------------------------------------------------------------ air, alerts

AIR_INDEX = {  # plausible GIOŚ index for a hot July afternoon (ozone)
    "LdLodzCzerni": ("gios-lodz-czernika", 1),
    "LdLodzGdansk": ("gios-lodz-gdanska", 2),
    "LdLodzLegion": ("gios-lodz-legionow", 1),
    "LdLodzJanPaw": ("gios-lodz-jana-pawla-ii", 2),
}


def build_air(raw: Path) -> None:
    data = load(raw, "gios_stations.json")
    rows = next(v for k, v in data.items() if isinstance(v, list))
    stations = []
    for s in rows:
        if s["Nazwa miasta"] != "Łódź":
            continue
        sid, level = AIR_INDEX.get(s["Kod stacji"], (f"gios-{s['Identyfikator stacji']}", 1))
        stations.append(
            {
                "id": sid,
                "name": s["Nazwa stacji"],
                "lat": r6(float(s["WGS84 φ N"])),
                "lon": r6(float(s["WGS84 λ E"])),
                "indexLevel": level,
                "updatedAt": "2026-07-15T14:00:00+02:00",
            }
        )
    write("air.json", {"stations": stations})


RCB_URL = "https://www.gov.pl/web/rcb/jak-przetrwac-upal2"


def build_alerts() -> None:
    write("alerts_none.json", {"alerts": []})
    write(
        "alerts_level2.json",
        {
            "alerts": [
                {
                    "id": "imgw-2026-07-15-lodz",
                    "level": 2,
                    "title": "Ostrzeżenie przed upałem 2. stopnia",
                    "area": "Łódź",
                    "validFrom": "2026-07-15T10:00:00+02:00",
                    "validTo": "2026-07-15T20:00:00+02:00",
                    "source": "IMGW-PIB",
                    "recommendations": [
                        "Pij wodę regularnie, nie czekaj, aż poczujesz pragnienie.",
                        "W najcieplejszych godzinach wybieraj trasy w cieniu i rób przerwy w chłodnych miejscach.",
                        "Zadzwoń do starszych bliskich lub sąsiadów i zapytaj, czy czegoś nie potrzebują.",
                    ],
                    "officialUrl": RCB_URL,
                }
            ]
        },
    )
    write(
        "alerts_level3.json",
        {
            "alerts": [
                {
                    "id": "imgw-2026-07-16-lodz",
                    "level": 3,
                    "title": "Ostrzeżenie przed upałem 3. stopnia",
                    "area": "Łódź",
                    "validFrom": "2026-07-16T10:00:00+02:00",
                    "validTo": "2026-07-17T21:00:00+02:00",
                    "source": "IMGW-PIB",
                    "recommendations": [
                        "Jeśli możesz, przenieś dłuższe wyjścia i wysiłek na rano albo na wieczór.",
                        "Odpoczywaj w chłodnych miejscach: w bibliotekach, muzeach i galeriach handlowych.",
                        "Nie zostawiaj dzieci ani zwierząt w zaparkowanym samochodzie.",
                    ],
                    "officialUrl": RCB_URL,
                }
            ]
        },
    )


def main() -> None:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW_DEFAULT
    cool_path = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT / "places_cool.json"
    cool = json.loads(cool_path.read_text(encoding="utf-8"))["places"] if cool_path.exists() else None
    if cool is None:
        print(f"{cool_path} not found: using fallback cool stop ids")
    OUT.mkdir(parents=True, exist_ok=True)
    osm = Osm(raw)
    water = build_places(osm)
    build_routes(osm, raw, cool, water)
    build_green(osm)
    build_shade(osm)
    build_noise(osm)
    build_air(raw)
    build_alerts()


if __name__ == "__main__":
    main()
