"""Shared constants and small geometry helpers (standard library only)."""

import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = REPO / "assets" / "demo"
RAW_DEFAULT = HERE / "raw"  # git-ignored download cache

USER_AGENT = "CoolLodz-demo-data/1.0 (student project; https://github.com/mikita672/cool-lodz-app)"

# Śródmieście (Łódź) — the area the demo layers cover.
BBOX_CENTRE = {"south": 51.745, "west": 19.425, "north": 51.790, "east": 19.495}

R_EARTH = 6371008.8
LAT0 = 51.77  # local projection origin
M_PER_DEG_LAT = math.pi * R_EARTH / 180
M_PER_DEG_LON = M_PER_DEG_LAT * math.cos(math.radians(LAT0))


def to_xy(lon: float, lat: float) -> tuple[float, float]:
    """Equirectangular projection to metres, good enough inside one city."""
    return lon * M_PER_DEG_LON, lat * M_PER_DEG_LAT


def to_lonlat(x: float, y: float) -> tuple[float, float]:
    return x / M_PER_DEG_LON, y / M_PER_DEG_LAT


def r6(v: float) -> float:
    return round(v, 6)


def dist_m(a, b) -> float:
    """Distance between two [lon, lat] points in metres."""
    ax, ay = to_xy(*a)
    bx, by = to_xy(*b)
    return math.hypot(ax - bx, ay - by)


def line_length(coords) -> float:
    return sum(dist_m(coords[i], coords[i + 1]) for i in range(len(coords) - 1))


def point_seg_dist(p, a, b) -> float:
    """Distance from point p to segment ab, all in projected metres."""
    (px, py), (ax, ay), (bx, by) = p, a, b
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def simplify(coords, tol_m: float):
    """Douglas–Peucker on [lon, lat] lists, tolerance in metres."""
    if len(coords) < 3:
        return coords
    pts = [to_xy(*c) for c in coords]
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        best, idx = 0.0, -1
        for k in range(i + 1, j):
            d = point_seg_dist(pts[k], pts[i], pts[j])
            if d > best:
                best, idx = d, k
        if best > tol_m and idx > 0:
            keep[idx] = True
            stack += [(i, idx), (idx, j)]
    return [c for c, k in zip(coords, keep) if k]


def point_in_ring(x: float, y: float, ring) -> bool:
    """Ray casting; ring as [lon, lat] list."""
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-15) + xi:
            inside = not inside
        j = i
    return inside


def ring_area_m2(ring) -> float:
    pts = [to_xy(*c) for c in ring]
    s = 0.0
    for i in range(len(pts) - 1):
        s += pts[i][0] * pts[i + 1][1] - pts[i + 1][0] * pts[i][1]
    return abs(s) / 2


def buffer_line(coords, r: float):
    """Polygon ring around a polyline (miter joins, flat caps), r in metres."""
    pts = [to_xy(*c) for c in coords]
    # drop duplicate points
    clean = [pts[0]]
    for p in pts[1:]:
        if math.hypot(p[0] - clean[-1][0], p[1] - clean[-1][1]) > 0.5:
            clean.append(p)
    if len(clean) < 2:
        return None
    normals = []
    for i in range(len(clean) - 1):
        dx, dy = clean[i + 1][0] - clean[i][0], clean[i + 1][1] - clean[i][1]
        L = math.hypot(dx, dy)
        normals.append((-dy / L, dx / L))
    left, right = [], []
    for i, p in enumerate(clean):
        if i == 0:
            nx, ny = normals[0]
            scale = 1.0
        elif i == len(clean) - 1:
            nx, ny = normals[-1]
            scale = 1.0
        else:
            ax, ay = normals[i - 1]
            bx, by = normals[i]
            nx, ny = ax + bx, ay + by
            L = math.hypot(nx, ny)
            if L < 1e-6:
                nx, ny, scale = ax, ay, 1.0
            else:
                nx, ny = nx / L, ny / L
                cos_half = nx * ax + ny * ay
                scale = min(1.0 / max(cos_half, 1e-6), 2.0)  # clamp sharp miters
        left.append((p[0] + nx * r * scale, p[1] + ny * r * scale))
        right.append((p[0] - nx * r * scale, p[1] - ny * r * scale))
    ring = left + right[::-1]
    ring.append(ring[0])
    return [[r6(v) for v in to_lonlat(*q)] for q in ring]


def offset_line(coords, d: float):
    """Polyline shifted sideways by d metres (positive = left of travel)."""
    pts = [to_xy(*c) for c in coords]
    out = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        out.append(to_lonlat(p[0] - dy / L * d, p[1] + dx / L * d))
    return [[r6(x), r6(y)] for x, y in out]
