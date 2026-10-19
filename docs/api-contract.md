# Module D API contract (as used by the app)

Based on section 6 of the brief and the spec section «Данные». Module D has no public server yet, so the app runs on the demo files in `assets/demo/`, which follow this contract exactly. Coordinates are WGS84; GeoJSON order is `[lon, lat]`.

## Common types

```jsonc
// LatLng
{ "lat": 51.7769, "lon": 19.4547 }

// Point with a label (route endpoints)
{ "lat": 51.7769, "lon": 19.4547, "label": "Manufaktura" }
```

## POST /v1/routes  (S06, S07)

Request:

```jsonc
{
  "from": { "lat": 51.7794, "lon": 19.4466, "label": "Manufaktura" },             // label optional
  "to": { "lat": 51.7676, "lon": 19.4568, "label": "ul. Piotrkowska (Pasaż Rubinsteina)" },
  "datetime": "2026-07-15T14:30:00+02:00",   // departure, local time with offset
  "profile": {
    "id": "senior",                           // senior | tourist | default
    "weights": { "shade": 90, "time": 20, "quiet": 60, "air": 50 }  // 0..100
  },
  "filters": {}                               // reserved, may be empty
}
```

Response `200`:

```jsonc
{
  "coverage": "full",            // full | approximate («Dla tego obszaru cień jest przybliżony»)
  "variants": [                  // always 3: shortest, shaded, compromise
    {
      "variant": "shaded",       // shortest | shaded | compromise
      "geometry": { "type": "LineString", "coordinates": [[19.4466, 51.7794], [19.4568, 51.7676]] },
      "segments": [              // coordinate index ranges [from, to] with their sun share
        { "from": 0, "to": 12, "sunShare": 0.15 }
      ],
      "distance_m": 2140,
      "duration_s": 1680,
      "sunShare": 0.28,          // share of the walk in the sun, 0..1 (shade = 1 - sunShare)
      "extraTimeVsShortest_s": 240,
      "stops": [{ "placeId": "cool-017", "type": "cool" }],   // cool | water
      "sunShareByHour": { "08:00": 0.12, "08:30": 0.15 }       // 08:00..20:00 every 30 min
    }
  ]
}
```

- `sunShare` is the share at the requested `datetime`; `sunShareByHour` gives it for other departures (keys `"HH:mm"`, sorted).
- `segments[].from`/`to` are inclusive indices into `geometry.coordinates`.
- `segments`, `stops` and `sunShareByHour` may be omitted: `segments` and `sunShareByHour` are still being agreed with module D (issue DEP-03), so the app treats all three as optional (missing = empty).
- Errors: `404 {"error": "route_not_found"}` (shown as «route not found», no demo fallback); timeouts, network errors and `5xx` switch the app to demo/cached data.

## GET /v1/places?type=cool,water,bench&bbox=minLon,minLat,maxLon,maxLat  (S05, S08, S09, S10)

```jsonc
{
  "places": [
    {
      "id": "cool-001",
      "type": "cool",                   // cool | water | bench
      "name": "EC1 Łódź – Miasto Kultury",
      "category": "culture",            // library | museum | culture | mall | park | station | church | other (cool only)
      "address": "ul. Targowa 1/3, 90-022 Łódź",
      "lat": 51.7684, "lon": 19.4694,
      "hours": {                        // summer opening hours; null = always open; [] = closed that day
        "mon": [], "tue": [["10:00", "18:00"]], "wed": [["10:00", "18:00"]],
        "thu": [["10:00", "18:00"]], "fri": [["10:00", "20:00"]],
        "sat": [["10:00", "20:00"]], "sun": [["10:00", "18:00"]]
      },
      "amenities": ["airConditioning", "water", "toilet", "wheelchair"],
      "accessible": true,
      "questPlace": true,
      "source": "https://ec1lodz.pl/..."  // where the hours come from
    }
  ]
}
```

Water points and benches only need `id`, `type`, `lat`, `lon`; the other fields may be null. Benches are shown from zoom 17.

`hours` details: a weekday key that is missing counts as closed (same as `[]`); times are `"HH:mm"` local time (Europe/Warsaw), the end is exclusive, `"24:00"` is allowed, and an interval whose end is before its start runs past midnight (`["22:00", "02:00"]`). Unknown `amenities` values are ignored by the app; an unknown `category` is read as `other`. `questPlace` defaults to `false`.

## GET /v1/alerts?lat&lon  (S05, S14)

```jsonc
{
  "alerts": [                                   // empty list = no alert
    {
      "id": "imgw-2026-07-15-lodz",
      "level": 2,                               // 1..3
      "title": "Ostrzeżenie przed upałem 2. stopnia",
      "area": "Łódź",
      "validFrom": "2026-07-15T10:00:00+02:00",
      "validTo": "2026-07-15T20:00:00+02:00",
      "source": "IMGW-PIB",
      "recommendations": ["…", "…", "…"],       // 3 short tips, Polish
      "officialUrl": "https://…"
    }
  ]
}
```

## GET /v1/air?bbox  (S05, layer Powietrze)

```jsonc
{
  "stations": [
    {
      "id": "gios-lodz-czernika",
      "name": "Łódź, ul. Czernika",
      "lat": 51.7586, "lon": 19.5295,
      "indexLevel": 1,              // GIOŚ index: 0 bardzo dobry … 5 bardzo zły; null = no data
      "updatedAt": "2026-07-15T14:00:00+02:00"
    }
  ]
}
```

## GET /v1/layers/{shade|green|noise}?bbox&datetime  (S05)

New endpoint requested from module D (issue DEP-04). Returns a GeoJSON `FeatureCollection` of polygons:

- `shade` — properties `{ "shade": 0.8 }` (share of shade at `datetime`, 0..1);
- `green` — properties `{ "kind": "park" }`;
- `noise` — properties `{ "db": 65 }`.

## POST /v1/reports  (S15, optional)

The app writes reports straight to Firestore `reports`; this endpoint is the alternative from the spec and is not used.

## Demo files (`assets/demo/`)

| File | Endpoint |
| --- | --- |
| `routes_manufaktura_piotrkowska.json`, `routes_plac_wolnosci_piotrkowska.json` | `/v1/routes` — object `{ "departures": { "10:00": <response>, "14:30": <response>, "18:00": <response> } }` |
| `places_cool.json`, `places_water.json`, `places_bench.json` | `/v1/places` |
| `alerts_none.json`, `alerts_level2.json`, `alerts_level3.json` | `/v1/alerts` |
| `layer_shade_1430.geojson`, `layer_green.geojson`, `layer_noise.geojson`, `air.json` | `/v1/layers/*`, `/v1/air` |
| `quest.json` | quest places and letters (seed for Firestore `questPlaces`), format below |

### `quest.json`

Not a module D endpoint (the game lives in Firestore); the app reads the bundled file. Fields match Firestore `questPlaces/{placeId}`; `placeId` is the `id` from `places_cool.json`. The password itself is not stored here.

```jsonc
{
  "questId": "chlodne-haslo",          // optional
  "title": "Chłodne hasło",            // optional
  "places": [                          // 7 places; a bare array of places is also accepted
    { "placeId": "cool-001", "name": "EC1 Łódź – Miasto Kultury", "letter": "C", "order": 1, "lat": 51.7684, "lon": 19.4694 }
  ]
}
```

## Demo mode (`DemoApiClient`)

- **Reference routes** (`lib/core/api/reference_routes.dart`):
  - Manufaktura (51.7794, 19.4466) → ul. Piotrkowska (Pasaż Rubinsteina) (51.7676, 19.4568): `routes_manufaktura_piotrkowska.json`;
  - Plac Wolności (51.7768, 19.4547) → OFF Piotrkowska (51.7596, 19.4577): `routes_plac_wolnosci_piotrkowska.json`.

  A request matches when both endpoints are within 300 m (same direction only). The departure whose `"HH:mm"` key is closest to the requested time of day is returned (a tie goes to the earlier one).
- **Any other pair** gets a generated response with `coverage: "approximate"`: three variants along a gently bent line, distance ≈ straight line × 1.3 (shaded ×1.12, compromise ×1.05 on top), walking speed 1.3 m/s, sun shares derived from the coordinates, `sunShareByHour` 08:00–20:00.
- **Alerts:** `alerts_none` / `alerts_level2` (default, demo scenario) / `alerts_level3`, chosen in the app; `lat`/`lon` are ignored.
- **Layers:** `layer_shade_1430.geojson` is returned for any `datetime`; `bbox` is ignored for layers (the files cover Śródmieście). Places and air stations are filtered by `bbox`.
