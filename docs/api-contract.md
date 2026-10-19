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
  "from": { "lat": 51.7801, "lon": 19.4475, "label": "Manufaktura" },
  "to": { "lat": 51.7592, "lon": 19.4581, "label": "Piotrkowska 104" },
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
      "geometry": { "type": "LineString", "coordinates": [[19.4466, 51.7794], [19.4570, 51.7720]] },
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

`segments` and `sunShareByHour` are still being agreed with module D (issue DEP-03), so the app treats both as optional. Errors: `404 {"error": "route_not_found"}`.

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
      "indexLevel": 1,              // GIOŚ index: 0 bardzo dobry … 5 bardzo zły
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
| `quest.json` | quest places and letters (seed for Firestore `questPlaces`) |
