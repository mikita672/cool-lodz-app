#!/usr/bin/env python3
"""Download walking geometry for the two reference routes from the public
OSM foot router (OSRM, routing.openstreetmap.de).

Each variant is a list of (lat, lon) waypoints; via points force the shaded
and compromise variants onto tree-lined streets and park passages.
Output: <raw>/route_<route>_<variant>.json (raw OSRM responses).

Usage: python3 -I fetch_routes.py [raw_dir]
"""

import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I drops the script dir
from common import RAW_DEFAULT, USER_AGENT  # noqa: E402

ROUTER = "https://routing.openstreetmap.de/routed-foot/route/v1/foot/"

MANUFAKTURA = (51.7794, 19.4466)
RUBINSTEIN = (51.7676, 19.4568)  # ul. Piotrkowska at the entrance to Pasaż Rubinsteina
PLAC_WOLNOSCI = (51.7768, 19.4547)
OFF_PIOTRKOWSKA = (51.7596, 19.4577)

ROUTES = {
    "manufaktura_piotrkowska": {
        "from": {**dict(zip(("lat", "lon"), MANUFAKTURA)), "label": "Manufaktura"},
        "to": {**dict(zip(("lat", "lon"), RUBINSTEIN)), "label": "Piotrkowska, Pasaż Rubinsteina"},
        "variants": {
            "shortest": [MANUFAKTURA, RUBINSTEIN],
            # Through Park Staromiejski (Ogrodowa side), Nowomiejska, then Piotrkowska.
            "shaded": [MANUFAKTURA, (51.7800, 19.4540), RUBINSTEIN],
            # Gdańska, Legionów, Zachodnia, Próchnika, then Piotrkowska.
            "compromise": [MANUFAKTURA, (51.7766, 19.4478), (51.7762, 19.4510), RUBINSTEIN],
        },
    },
    "plac_wolnosci_piotrkowska": {
        "from": {**dict(zip(("lat", "lon"), PLAC_WOLNOSCI)), "label": "Plac Wolności"},
        "to": {**dict(zip(("lat", "lon"), OFF_PIOTRKOWSKA)), "label": "OFF Piotrkowska"},
        "variants": {
            "shortest": [PLAC_WOLNOSCI, OFF_PIOTRKOWSKA],
            # Traugutta, Moniuszki (tree-lined), Sienkiewicza, Plac Komuny
            # Paryskiej and Pasaż Schillera.
            "shaded": [PLAC_WOLNOSCI, (51.7682, 19.4598), (51.7660, 19.4600), OFF_PIOTRKOWSKA],
            # Piotrkowska with a pass through the green Pasaż Rubinsteina.
            "compromise": [PLAC_WOLNOSCI, (51.7675, 19.4552), OFF_PIOTRKOWSKA],
        },
    },
}


def main() -> None:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW_DEFAULT
    raw.mkdir(parents=True, exist_ok=True)
    for route, spec in ROUTES.items():
        for variant, pts in spec["variants"].items():
            target = raw / f"route_{route}_{variant}.json"
            if target.exists():
                continue
            coords = ";".join(f"{lon},{lat}" for lat, lon in pts)
            url = f"{ROUTER}{coords}?overview=full&geometries=geojson&continue_straight=true"
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as resp:
                target.write_bytes(resp.read())
            print(f"saved {target.name}")
            time.sleep(1.5)


if __name__ == "__main__":
    main()
