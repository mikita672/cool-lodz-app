# Cool Łódź — App

Aplikacja na Androida we Flutterze: w upał wyznacza piesze trasy po Łodzi przez cień, zieleń i ciche ulice, pokazuje miejsca chłodu i wodę, a ich odwiedzanie zamienia w grę. Hackathon Future Smart City 2026, obszar Health Shift, zespół Better Than Never.

- **Plan krok po kroku:** [#48 — kroki na każdy dzień, 19–27.10](https://github.com/mikita672/cool-lodz-app/issues/48)
- **Tablica:** [Cool Łódź — App](https://github.com/users/mikita672/projects/1) — Backlog → To do → In progress → Review → Done
- **Kamienie milowe:** [M1–M6](https://github.com/mikita672/cool-lodz-app/milestones)
- **Specyfikacja:** [docs/spec.md](docs/spec.md)
- **Makieta:** [Figma «Cool Łódź — App»](https://www.figma.com/design/U5IzePCuqa0gZlipjRQEOm/Cool-Lodz-App)
- **Dziennik AI:** [docs/ai-log.md](docs/ai-log.md)

## Uruchomienie

Potrzebne są Flutter 3.41 (stable), JDK 17 i Android SDK 36; aplikacja działa tylko na Androidzie 7.0+.

```sh
flutter pub get
flutter analyze && flutter test
flutter run
```

Budowa kodu, zasady i proces w gicie — w [docs/dev.md](docs/dev.md). Release APK, podpis i GitHub Release — w [docs/release.md](docs/release.md).

**Źródła danych:** bez `--dart-define=API_BASE_URL=…` aplikacja sama liczy API modułu D na telefonie (`lib/core/api/live/`): trasy z OSRM + model cienia, alerty IMGW, powietrze z GIOŚ, miejsca i warstwy z `assets/demo/` (zob. [docs/api-contract.md](docs/api-contract.md#live-mode-liveapiclient)). Z `API_BASE_URL` — serwer modułu D. **Tryb demo** (tylko dane z `assets/demo/`, bez sieci): Profil → O aplikacji → 5 stuknięć w numer wersji → «Tryb demo»; tam też wybiera się stopień alertu na potrzeby demo.

**Mapa:** podkład CARTO wymaga darmowego klucza (<https://carto.com/basemaps/apikey>): `flutter run --dart-define=MAP_TILES_KEY=…`, w CI sekret `MAP_TILES_KEY` (zob. [docs/release.md](docs/release.md)).

**Kody QR questu:** obrazki do druku są w [docs/quest-qr/](docs/quest-qr/README.md).

## Jak pracujemy

- Jedno zadanie — jeden issue `APP-xx` z krokami i listą kontrolną „Gotowe, gdy”.
- Gałąź `feat/APP-xx-short-name`, PR z linijką `Closes #N`.
- Decyzji, których nie ma w specyfikacji, nie wymyślamy: zakładamy issue z etykietą `question`.
- Zadanie zajęło ponad 1,5× szacunku — przycinamy je, zamiast przesuwać resztę.
- To, co zrobiono z Claude Code, zapisujemy w dzienniku AI.
