#!/usr/bin/env python3
"""Download the raw OpenStreetMap data used to build the demo layers.

Three Overpass queries (green + trees + benches in Śródmieście, streets in
Śródmieście, drinking water in the whole city). Output: <raw>/osm_*.json.

Usage: python3 -I fetch_osm.py [raw_dir]
"""

import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I drops the script dir
from common import BBOX_CENTRE, RAW_DEFAULT, USER_AGENT  # noqa: E402

OVERPASS = "https://overpass-api.de/api/interpreter"

S, W, N, E = BBOX_CENTRE["south"], BBOX_CENTRE["west"], BBOX_CENTRE["north"], BBOX_CENTRE["east"]
BB = f"({S},{W},{N},{E})"

QUERIES = {
    "osm_green_trees.json": f"""
[out:json][timeout:120];
(
  way["leisure"~"^(park|garden)$"]{BB};
  relation["leisure"~"^(park|garden)$"]{BB};
  way["landuse"~"^(grass|forest)$"]["name"]{BB};
  relation["landuse"~"^(grass|forest)$"]["name"]{BB};
  way["natural"="wood"]{BB};
  way["natural"="tree_row"]{BB};
  node["natural"="tree"]{BB};
  node["amenity"="bench"]{BB};
);
out geom;
""",
    "osm_streets.json": f"""
[out:json][timeout:120];
(
  way["highway"~"^(trunk|primary|secondary|tertiary|residential|living_street|pedestrian|unclassified)$"]["name"]{BB};
);
out geom;
""",
    # Whole city: the administrative boundary of Łódź (miasto na prawach powiatu).
    "osm_water.json": """
[out:json][timeout:120];
area["boundary"="administrative"]["name"="Łódź"]["admin_level"="6"]->.city;
(
  node["amenity"="drinking_water"](area.city);
);
out body;
""",
}


def main() -> None:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW_DEFAULT
    raw.mkdir(parents=True, exist_ok=True)
    for name, query in QUERIES.items():
        target = raw / name
        if target.exists():
            print(f"skip {name} (exists)")
            continue
        data = urllib.parse.urlencode({"data": query}).encode()
        req = urllib.request.Request(OVERPASS, data=data, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=180) as resp:
            target.write_bytes(resp.read())
        print(f"saved {name}: {target.stat().st_size} B")
        time.sleep(5)  # be polite to the public Overpass instance


if __name__ == "__main__":
    main()
