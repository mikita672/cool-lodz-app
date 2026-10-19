#!/usr/bin/env python3
"""Download the GIOŚ station list (api.gios.gov.pl, open data).

Output: <raw>/gios_stations.json. Usage: python3 -I fetch_gios.py [raw_dir]
"""

import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I drops the script dir
from common import RAW_DEFAULT, USER_AGENT  # noqa: E402

URL = "https://api.gios.gov.pl/pjp-api/v1/rest/station/findAll?size=500"


def main() -> None:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW_DEFAULT
    raw.mkdir(parents=True, exist_ok=True)
    target = raw / "gios_stations.json"
    req = urllib.request.Request(URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        target.write_bytes(resp.read())
    print(f"saved {target.name}: {target.stat().st_size} B")


if __name__ == "__main__":
    main()
