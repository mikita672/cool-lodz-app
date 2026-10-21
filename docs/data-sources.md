# Data sources

## Cooling places — miejsca chłodu (APP-05)

File: `assets/demo/places_cool.json` (contract `/v1/places`), quest: `assets/demo/quest.json`.

> **Opening hours must be re-checked before the demo.** The data was collected on 2026-10-19, i.e. outside the summer season. Where a place does not publish separate summer hours, `hours` contains the current hours (marked in the notes).

Rules:

- Coordinates: OpenStreetMap / Nominatim (the building's point; for parks the centre point of the park, for the Botanical Garden the address of the ticket office on ul. Krzemieniecka). Postcodes: from the place's website, or from OSM if the website does not give them.
- `hours: null` = open 24 hours, `[]` = closed on that day.
- `amenities` and `accessible` are filled in only when a source confirms them (the place's website, an accessibility statement) or they are obvious (toilets and air conditioning in a shopping centre). `accessible: false` means "not confirmed", not "inaccessible".
- No drinking water points (`water`) were assigned to any place: no source confirming them was found.

| id | Place | Source of hours | Checked | Notes |
| --- | --- | --- | --- | --- |
| cool-001 | EC1 Łódź – Miasto Kultury | [ec1lodz.pl/ckini/informacje-praktyczne](https://ec1lodz.pl/ckini/informacje-praktyczne) | 2026-10-19 | Hours of the Comics Centre (Tue–Sun 10:00–18:00), the only hours given on the site without JavaScript. The hours of the Science and Technology Centre and the Planetarium may differ. No separate summer hours. Step-free entrances, automatic doors. |
| cool-002 | Manufaktura | [manufaktura.com/godziny-otwarcia/obiekt](https://manufaktura.com/godziny-otwarcia/obiekt) | 2026-10-19 | Shopping centre Mon–Sat 10:00–22:00. On non-trading Sundays the shopping centre is closed but Qulinarium is open (12:00–20:00), and those hours are entered for Sunday. Toilets for people with disabilities: [accessibility](https://manufaktura.com/site/613/dostepnosc-w-manufakturze). |
| cool-003 | Galeria Łódzka | [galeria-lodzka.pl/o-centrum/godziny-otwarcia](https://www.galeria-lodzka.pl/o-centrum/godziny-otwarcia/) | 2026-10-19 | Mon–Sat 9:30–21:00. Sunday is entered as "closed"; the site gives 10:00–20:00, which applies only to trading Sundays. |
| cool-004 | Port Łódź | [portlodz.pl/pl/godziny-otwarcia](https://portlodz.pl/pl/godziny-otwarcia) | 2026-10-19 | Mon–Sat 10:00–21:00 (the site's structured data). Closed on non-trading Sundays, 10:00–20:00 on trading Sundays. |
| cool-005 | Dworzec Łódź Fabryczna | [plk-sa.pl/…/dworzec-lodz-fabryczna/o-dworcu](https://www.plk-sa.pl/informacje/dworce/dworzec-lodz-fabryczna/o-dworcu) | 2026-10-19 | The station is open 24 hours. Paid toilets (open 24 hours, accessible), 10 lifts. |
| cool-006 | Mediateka MeMo (filia nr 29) | [biblioteka.lodz.pl/filie/filia-nr-29-mediateka-memo](https://www.biblioteka.lodz.pl/filie/filia-nr-29-mediateka-memo/) | 2026-10-19 | Current hours; in July and August branches may have shorter hours. Lift and accessible toilets according to the [accessibility statement](https://www.biblioteka.lodz.pl/deklaracja-dostepnosci/). |
| cool-007 | Biblioteka Wolność (filia nr 39) | [biblioteka.lodz.pl/filie/filia-nr-39-biblioteka-wolnosc](https://www.biblioteka.lodz.pl/filie/filia-nr-39-biblioteka-wolnosc/) | 2026-10-19 | Current hours; may differ during the summer holidays. Ground floor, accessible toilet according to the accessibility statement. |
| cool-008 | Wojewódzka Biblioteka Publiczna | [nowa.wbp.lodz.pl/godziny-otwarcia](https://nowa.wbp.lodz.pl/godziny-otwarcia/) | 2026-10-19 | Current hours (Mon–Fri 8:00–19:45, Sat 8:00–15:00); no information on summer hours. Wheelchair entrance, lift and toilet on the ground floor according to the [accessibility statement](https://nowa.wbp.lodz.pl/deklaracja-dostepnosci/). |
| cool-009 | Muzeum Sztuki ms¹ | [msl.org.pl/godziny-otwarcia-1](https://msl.org.pl/godziny-otwarcia-1) | 2026-10-19 | No separate summer hours. Accessibility not confirmed on the site, hence `accessible: false`. |
| cool-010 | Muzeum Sztuki ms² | [msl.org.pl/godziny-otwarcia-1](https://msl.org.pl/godziny-otwarcia-1) | 2026-10-19 | Same as ms¹. |
| cool-011 | Muzeum Miasta Łodzi | [muzeum-lodz.pl/palac-rodziny-poznanskich-zaplanuj-wizyte](https://muzeum-lodz.pl/palac-rodziny-poznanskich-zaplanuj-wizyte/) | 2026-10-19 | No separate summer hours. Stair platform at the entrance from ul. Zachodnia (with staff assistance), «Komfortka» toilet. The palace is closed 27–31.10.2026. |
| cool-012 | Centralne Muzeum Włókiennictwa | [cmwl.pl/public/informacje/godziny-otwarcia](https://cmwl.pl/public/informacje/godziny-otwarcia) | 2026-10-19 | No separate summer hours. Accessibility not confirmed. |
| cool-013 | Muzeum Kinematografii | [muzeumkinematografii.pl/wizyta/zaplanuj-wizyte](https://muzeumkinematografii.pl/wizyta/zaplanuj-wizyte/) | 2026-10-19 | No separate summer hours. Lifts and 3 accessible toilets according to the [accessibility page](https://muzeumkinematografii.pl/wizyta/muzeum-dostepne/). |
| cool-015 | Park Źródliska I | [zzm.lodz.pl/…/parki-i-zielence](https://zzm.lodz.pl/zarzad-zieleni-miejskiej/zielen/parki-i-zielence/) | 2026-10-19 | ZZM does not give hours; the park is fenced, so it needs checking whether the gates are locked at night. Pond and water features. |
| cool-016 | Park im. H. Sienkiewicza | as above | 2026-10-19 | Hours not given; fountain. |
| cool-017 | Park im. S. Staszica | as above | 2026-10-19 | Hours not given; pond. Low fence. |
| cool-018 | Park im. ks. J. Poniatowskiego | as above | 2026-10-19 | Hours not given; pond, ground-level fountain, automatic toilet accessible to people with disabilities. |
| cool-019 | Park Helenów | as above | 2026-10-19 | Hours not given; ponds. |
| cool-020 | Ogród Botaniczny w Łodzi | [botaniczny.lodz.pl/ogrod-botaniczny/godziny-otwarcia](https://www.botaniczny.lodz.pl/ogrod-botaniczny/godziny-otwarcia/) | 2026-10-19 | Season hours May–August (daily 9:00–20:00); in October 9:00–17:00, closed from 1 November to 31 March. Paid entry. |

### Quest „Chłodne hasło”

Password (hasło) **CHŁODNO**. The 7 places form a walking route through Śródmieście (5 km in a straight line, about 6 km on foot) from Manufaktura to Galeria Łódzka. The QR code hangs by the public entrance.

| Order | Letter | id | Place |
| --- | --- | --- | --- |
| 1 | C | cool-002 | Manufaktura |
| 2 | H | cool-007 | Biblioteka Wolność (pl. Wolności 4) |
| 3 | Ł | cool-006 | Mediateka MeMo (ul. Moniuszki 5) |
| 4 | O | cool-017 | Park im. S. Staszica |
| 5 | D | cool-005 | Dworzec Łódź Fabryczna |
| 6 | N | cool-001 | EC1 Łódź – Miasto Kultury |
| 7 | O | cool-003 | Galeria Łódzka |

MeMo and EC1 are closed on Mondays; Biblioteka Wolność and (on non-trading Sundays) Galeria Łódzka are closed on Sundays. The quest does not require collecting the letters in one day.

Palmiarnia (the tropical glasshouse) is deliberately not on the list: in summer it is warm and humid inside, so it is not suitable as a cooling place.

## Demo data: routes, alerts, layers (APP-04)

The app runs on the files in `assets/demo/` until module D has a public API. They follow [api-contract.md](api-contract.md). This page lists where each file comes from, under which licence, and which numbers are synthetic.

Demo day: **15 July 2026** (a heatwave day, times in CEST, +02:00). Area of the layers: Śródmieście, bbox `19.425,51.745,19.495,51.790` (lon/lat).

### Files

| File | Source | Real | Synthetic |
| --- | --- | --- | --- |
| `routes_manufaktura_piotrkowska.json` | OSM foot router ([routing.openstreetmap.de](https://routing.openstreetmap.de), OSRM) | geometry along real streets, `distance_m`, `duration_s`, `extraTimeVsShortest_s` | `segments[].sunShare`, `sunShare`, `sunShareByHour` (model below) |
| `routes_plac_wolnosci_piotrkowska.json` | same | same | same |
| `alerts_none.json`, `alerts_level2.json`, `alerts_level3.json` | written by hand in the format of IMGW-PIB heat warnings; link to the RCB advice page [Jak przetrwać upał?](https://www.gov.pl/web/rcb/jak-przetrwac-upal2) | warning levels and wording as IMGW uses them | the warnings themselves (dates, periods) |
| `layer_green.geojson` | OpenStreetMap: `leisure=park`, named `leisure=garden`, `natural=wood`, named `landuse=grass/forest`; polygons ≥ 800 m², simplified to 2 m | polygons, names, `osm` ids | — |
| `layer_shade_1430.geojson` | derived from OpenStreetMap trees (`natural=tree`, `natural=tree_row`), parks and streets | positions of trees, parks and streets | the `shade` values and the building-shadow strips |
| `layer_noise.geojson` | OpenStreetMap roads (`highway=trunk/primary/secondary/tertiary`) | road geometry | `db` values |
| `streets_core.geojson` | OpenStreetMap named streets in the tenement grid (`19.435–19.480 × 51.755–51.785`), merged per name and class, simplified to 3 m; built by `tools/demo-data/build_streets.py` from `osm_streets.json` (downloaded 2026-10-19 from the overpass.private.coffee mirror, data as of 2026-05-31) | centrelines | `w`, the street width by road class (18–40 m) |
| `air.json` | GIOŚ station list, [api.gios.gov.pl](https://api.gios.gov.pl/pjp-api/v1/rest/station/findAll) | the 4 Łódź stations: names, coordinates | `indexLevel`, `updatedAt` |
| `places_water.json` | OpenStreetMap `amenity=drinking_water` inside the Łódź city boundary | all points | — |
| `places_bench.json` | OpenStreetMap `amenity=bench` in the Śródmieście bbox, the 500 closest to ul. Piotrkowska (51.7700, 19.4560) | all points | — |
| `places_cool.json`, `quest.json` | APP-05, see that ticket | | |

OSM data was downloaded on 2026-10-19 (Overpass base timestamp 2026-10-18T23:18Z). Ids: `water-<osm node id>`, `bench-<osm node id>`.

### Reference routes

| Route | Variant | Streets | Length | Time | Shade at 14:30 |
| --- | --- | --- | --- | --- | --- |
| Manufaktura → Piotrkowska (Pasaż Rubinsteina) | Najkrótsza | Ogrodowa, Zachodnia, Legionów, Piotrkowska | 1874 m | 24 min | 31 % |
| | Zacieniona | Park Staromiejski, Nowomiejska, Piotrkowska | 2223 m | +4.7 min | 72 % |
| | Kompromis | Gdańska, Legionów, Zachodnia, Próchnika, Piotrkowska | 1999 m | +1.7 min | 53 % |
| Plac Wolności → OFF Piotrkowska | Najkrótsza | Piotrkowska | 1994 m | 27 min | 34 % |
| | Zacieniona | Traugutta, Moniuszki, Sienkiewicza, Plac Komuny Paryskiej, Pasaż Schillera | 2565 m | +7.6 min | 69 % |
| | Kompromis | Piotrkowska through Pasaż Rubinsteina | 2180 m | +2.4 min | 51 % |

The destination of the first route is the Piotrkowska entrance of Pasaż Rubinsteina (51.7676, 19.4568), where the passage really is (around Piotrkowska 67–71). The second shaded variant is longer than +6 min: every tree-lined street near Piotrkowska is a full block (≈ 300 m) away, so no shorter shaded detour exists.

Departures: 10:00, 14:30, 18:00. `stops` lists cool places (`places_cool.json`) within 80 m and drinking water within 25 m of the line, except those next to the start.

### Sun and shade model (synthetic)

Each edge of a route gets a sun share from:

- **sun position** for the edge's mid-point at the time the walker gets there (departure + walking time);
- **building shadow**: street canyon with 16 m tenements and a width by road class (18–40 m); the share of the walk in shadow is `0.6 × shadow width across the street / street width`, capped at 1 — so N–S streets such as Piotrkowska are fully shaded by 18:00;
- **tree crowns**: 0.3 per mapped tree within 15 m (max 0.9), 0.75 near a tree row, 0.8 inside a park; crowns count more when the sun is low.

OSM maps only part of the street trees in Łódź, so the raw model barely tells the variants apart. Each variant is therefore calibrated with one exponent (`sun' = sun^γ`) so that its share at 14:30 matches the numbers from the spec (Zacieniona ≈ 72 % shade vs Najkrótsza ≈ 31 %). The model still decides where along the route the sun is and how it changes over the day. Replace all of this with module D results when they arrive.

`layer_shade_1430.geojson` uses the same inputs at 14:30 (each polygon has `source`: `trees` or `buildings`; the live route engine uses only `trees` and computes building shadow for the actual time): parks (`shade` 0.55–0.9 by mapped trees per hectare, woods 0.9), 8 m buffers around tree rows (0.7), 12 m buffers along tree-lined stretches of streets (0.4–0.85), and building-shadow strips on the sun side of streets in the tenement grid (0.85).

`layer_noise.geojson`: a 15 m band per road at its level and, for roads ≥ 63 dB, a 40 m band 8 dB lower. Levels by class (trunk 72, primary 68, secondary 63, tertiary 58 dB) with overrides for the main arteries (al. Włókniarzy 75, al. Piłsudskiego and al. Mickiewicza 72, Zachodnia 70, al. Kościuszki 68, Narutowicza 66, Kilińskiego and Północna 65, Żeromskiego 64). These are estimates, not measurements from the Łódź noise map.

### Live sources (on the phone)

Without a module D server the app calls these public APIs itself (`lib/core/api/live/`, see [api-contract.md](api-contract.md#live-mode-liveapiclient)). The parsers were checked against real answers on 2026-10-19; the test fixtures in `test/fixtures/live/` are trimmed real responses.

| Source | URL | What we found in the real payloads |
| --- | --- | --- |
| IMGW-PIB meteorological warnings | `https://danepubliczne.imgw.pl/api/data/warningsmeteo` | A list of `{id, nazwa_zdarzenia, stopien, prawdopodobienstwo, obowiazuje_od, obowiazuje_do, opublikowano, tresc, komentarz, biuro, teryt}`; `stopien` is a string, times are Warsaw wall clock without offset (`2026-08-15 12:02:00`), `teryt` is a list of 4-digit county codes (Łódź = `1061`, the county around it = `1062`). With no warnings in Poland the API answers `{"message": "Brak ostrzeżeń meteorologicznych"}` instead of `[]`. No heat warning was active on 2026-10-19, so the heat fixture is the real warning `Sk20260815100248479` (Upał, 1st degree, Łódź, 15–16 Aug 2026) from the public archive [StormFunnel/stormfunnel-pl-recorder](https://github.com/StormFunnel/stormfunnel-pl-recorder). |
| GIOŚ air quality | `https://api.gios.gov.pl/pjp-api/v1/rest/station/findAll?size=500`, `…/aqindex/getIndex/{id}` | JSON-LD with Polish keys (`Lista stacji pomiarowych`, `Identyfikator stacji`, `WGS84 φ N` as a string, `AqIndex.Wartość indeksu`). The server answers **406** to `Accept: application/json` alone, so the app also accepts `application/ld+json`. The old paths without `/v1` answer **410 Gone**. A station without an index (Łódź, ul. Legionów) gets every field `null`. Łódź stations: 295 Czernika, 296 Gdańska, 302 Legionów, 10058 Al. Jana Pawła II. |
| Open-Meteo weather | `https://api.open-meteo.com/v1/forecast?latitude=51.77&longitude=19.46&hourly=temperature_2m,cloud_cover,direct_radiation&timezone=GMT&forecast_days=3` | `hourly.time` in GMT without offset; `direct_radiation` (W/m²) is the mean of the hour *before* the time stamp. Free, no key, CC BY 4.0 (attribution in S16). On 2026-10-21 the sky over Łódź was 85–100 % cloud with 200–290 W/m² direct radiation at midday. |
| OSRM foot router (FOSSGIS) | `https://routing.openstreetmap.de/routed-foot/route/v1/foot/{lon,lat;…}?overview=full&geometries=geojson&alternatives=2` | `{code: "Ok", routes: [{geometry, distance, duration, …}]}`; walking speed ≈ 1.28 m/s. Errors come as HTTP 400 `{code, message}` (`NoRoute`, `NoSegment`, `InvalidQuery`, `InvalidOptions` for `0,0`). It routes anywhere reachable, ferries included, so the app refuses straight lines over 25 km. |

### Licences

- OpenStreetMap data: © OpenStreetMap contributors, [ODbL 1.0](https://opendatacommons.org/licenses/odbl/). The app must show the attribution on the map.
- Routes: computed by the FOSSGIS OSRM service on OSM data (ODbL).
- Air-quality stations: Główny Inspektorat Ochrony Środowiska (GIOŚ), open data from the PJP API.
- Heat warnings: format and levels of the IMGW-PIB warnings; the texts here are our own. Live: IMGW-PIB public data (source: IMGW-PIB).

### Regenerate

Python 3, standard library only. Downloads go to `tools/demo-data/raw/` (git-ignored); every fetch script skips files that already exist.

```sh
cd tools/demo-data
python3 -I fetch_osm.py      # 3 Overpass queries (OVERPASS_URL=… for a mirror)
python3 -I fetch_routes.py   # 6 router requests
python3 -I fetch_gios.py
python3 -I build.py [raw_dir] [path/to/places_cool.json]
python3 -I build_streets.py [raw_dir]   # streets_core.geojson for the live shade layer
flutter test test/assets/demo_assets_test.dart
```

Without `places_cool.json` the build uses the cool stop ids hard-coded in `build.py`.
