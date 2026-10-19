#!/usr/bin/env python3
"""Street centrelines of the Śródmieście tenement grid for the on-phone shade
layer (assets/demo/streets_core.geojson).

The app draws building shadows on these streets for any time of day: the
shadow width across a street follows the sun (lib/core/api/live/
shade_layer.dart). Each LineString carries `w`, the street width in metres
by road class (same table as the route model in build.py).

Input: <raw>/osm_streets.json from fetch_osm.py.
Usage: python3 -I build_streets.py [raw_dir]
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I drops the script dir
from build import STREET_W, STREET_W_DEFAULT, in_core, merge_lines  # noqa: E402
from common import OUT, RAW_DEFAULT, r6, simplify  # noqa: E402


def core_runs(line):
    """Parts of a polyline inside the tenement grid."""
    runs, cur = [], []
    for c in line:
        if in_core(*c):
            cur.append(c)
        else:
            if len(cur) >= 2:
                runs.append(cur)
            cur = []
    if len(cur) >= 2:
        runs.append(cur)
    return runs


def main() -> None:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW_DEFAULT
    data = json.loads((raw / "osm_streets.json").read_text(encoding="utf-8"))
    groups = {}
    for e in data["elements"]:
        if e.get("type") != "way" or "geometry" not in e:
            continue
        t = e.get("tags", {})
        key = (t.get("name"), t.get("highway"))
        groups.setdefault(key, []).append([[p["lon"], p["lat"]] for p in e["geometry"]])
    feats = []
    for (name, hw), lines in sorted(groups.items(), key=lambda kv: (str(kv[0][0]), str(kv[0][1]))):
        width = STREET_W.get(hw, STREET_W_DEFAULT)
        for line in merge_lines(lines):
            for run in core_runs(line):
                run = simplify(run, 3.0)
                if len(run) < 2:
                    continue
                feats.append({
                    "type": "Feature",
                    "properties": {"name": name, "w": width},
                    "geometry": {"type": "LineString", "coordinates": [[r6(x), r6(y)] for x, y in run]},
                })
    out = OUT / "streets_core.geojson"
    text = json.dumps({"type": "FeatureCollection", "features": feats}, ensure_ascii=False, separators=(",", ":"))
    out.write_text(text + "\n", encoding="utf-8")
    print(f"streets_core.geojson: {len(feats)} lines, {len(text.encode()) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
