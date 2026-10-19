# Developer guide

How the code is organised and the rules every ticket follows. The product spec is [spec.md](spec.md).

## Run

```sh
flutter pub get
flutter gen-l10n          # also runs automatically on build
flutter analyze && flutter test
flutter run               # Android emulator or phone, Android 7.0+
```

## Firebase

Project `coollodz` (Firestore in europe-central2). Code gets Firebase only through the providers in `lib/core/firebase/firebase_providers.dart`; `FirebaseBootstrap.init()` in `main.dart` starts it.

- **Config file.** `android/app/google-services.json` is not in git. Get it from a teammate or download it: `firebase apps:sdkconfig ANDROID --project coollodz -o android/app/google-services.json` (pick the `pl.betterthannever.cool_lodz` app). Without it the Android build fails.
- **Emulators.** Debug builds talk to the local Emulator Suite (Auth 9099, Firestore 8080, UI <http://localhost:4000>). Start it from the repo root:

  ```sh
  firebase emulators:start --only auth,firestore --import .firebase-data --export-on-exit
  ```

  Needs Java 21+ (firebase-tools 15). Data is kept in `.firebase-data/` (ignored by git), created on the first exit. On the Android emulator `localhost` is mapped to the host (`10.0.2.2`) automatically.
- **Switch.** `--dart-define=USE_FIREBASE_EMULATORS=false` makes a debug build use the real project. The default is `true` in debug; profile and release builds always use the real project (cleartext HTTP is allowed only in `android/app/src/debug`). On a physical phone add `--dart-define=FIREBASE_EMULATOR_HOST=<PC LAN IP>` and start the emulators listening on the LAN with a local copy of the config: `cp firebase.json firebase.local.json` (ignored by git), set `"host": "0.0.0.0"` for `auth` and `firestore` there and run `firebase emulators:start --config firebase.local.json …`.
- **Push (APP-18).** `PushHandler` (app root) saves `users/{uid}.fcmToken` while the user allows push (S03), opens S14 when a notification is tapped (also when it started the app) and shows a banner with «Zobacz» when a push arrives with the app open. Demo: set `config/game.heatOverride` (e.g. 2) in the console — S05, S10 and S14 follow it live — and send a test message to the token. There is no FCM emulator: debug builds get a real FCM token, printed to the log as `FCM token: …`. Send a test message from the Firebase console (Messaging → New campaign → Send test message) to that token. On Android 13+ allow notifications first (system settings, or `adb shell pm grant pl.betterthannever.cool_lodz android.permission.POST_NOTIFICATIONS`) and put the app in the background — FCM shows nothing while the app is in front (debug builds log `FCM foreground: …` instead).
- **Rules.** `firestore.rules` and `firestore.indexes.json` are the source of truth for the real project too; see [Firestore rules](#firestore-rules) below.

### Firestore rules

Collection and field names are in `lib/core/firestore/collections.dart`, together with `weekId()` (ISO week, `2026-W43`) and `visitId()` (`{uid}_{placeId}_{yyyyMMdd}`). Keep them in sync with `firestore.rules`. Things the client must do to pass the rules:

- `createdAt` in `visits`, `reports` and `pointsLog` is `FieldValue.serverTimestamp()`.
- `users.points` and `weekPoints` only grow, by at most 200 per write; a new `weekId` resets `weekPoints` (0–200). `badges` only grow. `users.district` is a district id (`baluty`, `gorna`, `polesie`, `srodmiescie`, `widzew`).
- District totals change only with `FieldValue.increment(1..200)`; the week doc `districts/{id}/weeks/{weekId}` is created by the first `set(..., merge)` with an increment.
- `users/{uid}` is readable only by its owner (RODO). The user ranking reads `rankings/{uid}`: nickname, district, points, weekId, weekPoints, updatedAt (server timestamp), written by the owner **in the same batch** as the user document and only while `consents.ranking` is true; the values must equal the user document after the batch. Withdrawing the consent must delete `rankings/{uid}` in the same batch (the rules reject the user update otherwise); "Usuń konto" deletes it too. Queries: `orderBy('points', descending: true).limit(50)` and `where('weekId', isEqualTo: weekId(now)).orderBy('weekPoints', descending: true).limit(50)` (composite index in `firestore.indexes.json`; `points` alone uses the automatic single-field index). S13 pins the user's own row with a rank from a `count()` of users with more points (`weekId ==` + `weekPoints >` has its own ascending index).

**Tests** (`tools/firestore-tests`, Node 22 + Java 21, `node --test`):

```sh
npm ci --prefix tools/firestore-tests
firebase emulators:exec --only firestore --project demo-coollodz "npm --prefix tools/firestore-tests test"
```

The `demo-` project id keeps everything offline. If port 8080 is busy (another emulator running), use a copy of `firebase.json` with other ports as `firebase.local.json` and add `--config firebase.local.json`. CI runs the same command in the `firestore rules` job.

**Deploy** (the lead does it, after the PR is merged): `firebase deploy --only firestore:rules,firestore:indexes`. The emulator reads the files directly, no deploy needed for local work.

**Seed** `config/game`, the 5 `districts`, `questPlaces` and `questCodes` (needs `assets/demo/quest.json` and `places_cool.json` from APP-05):

```sh
firebase emulators:start --only auth,firestore      # in another terminal
node tools/firestore-seed/seed.mjs                  # emulator, project coollodz
```

Quest codes are written to `tools/qr/codes.json` (ignored by git, input for the QR generator). Re-running keeps existing codes, `config/game` and district points; `--new-codes` rotates the codes (old QR prints stop working), `--force` resets config and districts, `--dry-run` only prints. For the real project pass an OAuth token of an account with access to `coollodz`: `node tools/firestore-seed/seed.mjs --project coollodz --token "$(gcloud auth print-access-token)"` (after `gcloud auth login`).

## Layout

```
lib/
  app/            app root, router (routes.dart), theme (tokens), senior mode
  core/           api (remote + demo), models, game config, location, storage
  features/<f>/   one folder per area; screens are named <name>_screen.dart
  shared/         design-system widgets (widgets/), debug showcase (debug/)
  l10n/           app_pl.arb (all UI strings, Polish) + generated code
assets/demo/      demo JSON following the module D API contract
test/             mirrors lib/ (test/features/<f>/..., test/core/...)
```

Routes for every screen already exist in `lib/app/router.dart`; a feature ticket replaces its placeholder screen and adds routes only when it needs new ones.

**Start flow (S01 → S02 → S03 → S04 → map).** `lib/features/auth/start_flow.dart` holds `StartFlowState` (onboarding seen, signed-in user, consents accepted, comfort profile chosen) and the pure `startFlowRedirect`. `main.dart` plugs it into the router with `startFlowRouterOverrides` (overrides of `routerRedirectProvider` / `routerRefreshProvider`). Widget tests that pump `CoolLodzApp` without these overrides see every route unguarded; to test the flow, add the overrides plus fakes for `authRepositoryProvider`, `userProfileRepositoryProvider`, `onboardingStoreProvider`, `systemPermissionsProvider` (see `test/features/auth/fakes.dart`). `/start` is a short loading screen while the state is read; `/privacy` is reachable at every step. Every test that builds the app needs `sharedPreferencesProvider` (use `testPrefs()` from `test/helpers/test_app.dart`).

**Comfort profiles (S04).** `ComfortProfile` (`features/profile/data/`) is `users/{uid}.profile` = `{id, weights, seniorMode}`; `comfortProfileProvider` holds the current one, keeps a copy in shared_preferences (Senior mode is on from the first frame, also offline) and `seniorModeProvider` is derived from it. S04 is shown once after S03 when the account has no profile, and from Profil. The spec has no starting weights, so we chose these (0..100, change them in `ComfortProfile.presetWeights`):

| Profile | shade | time | quiet | air | Senior mode |
| :-- | --: | --: | --: | --: | :-- |
| Senior (`senior`) | 90 | 20 | 60 | 60 | on |
| Turysta (`tourist`) | 70 | 40 | 30 | 40 | off |
| Domyślny (`default`) | 60 | 60 | 30 | 30 | off | Detail screens are sub-routes of their tab (`/quest/scan`, `/map/alert`, `/profile/about`, `/route/result`), so a deep link still has a back stack; inside the app open them with `context.push`. The router is created once — redirect re-checks go through `routerRefreshProvider`.

**Route planning (S06 → S07).** `routePlanProvider` (`features/route/data/route_plan.dart`) holds from / to / departure (`null` = «Teraz»); S06 and «Prowadź tam» (S08) fill it. `routeRequestProvider` turns it into the `POST /v1/routes` body (resolves «Moja lokalizacja» through `locationServiceProvider`, adds the comfort profile) and `routeResultProvider` asks `apiClientProvider`. Address search uses Nominatim (decision Q-04): only inside Łódź (`viewbox` + `bounded=1`), app User-Agent, typing debounced 1 s and at most 1 request per second; cool places are searched on the device.

**Map tiles key.** CARTO basemaps need a free key (<https://carto.com/basemaps/apikey>); without it the tiles only say «API KEY REQUIRED». Pass it at build time: `flutter run --dart-define=MAP_TILES_KEY=…`, or keep it in `defines.local.json` (ignored by git: `{"MAP_TILES_KEY": "…"}`) and run `flutter run --dart-define-from-file=defines.local.json`. CI reads the `MAP_TILES_KEY` secret ([release.md](release.md)). The key ends up inside the APK (any map app's key does), so restrict it to the app if CARTO offers that and watch the usage.

**S07 actions (Q-08).** «Prowadź» opens Google Maps walking directions (start, end and up to 8 points of the chosen line) and writes the route to `users/{uid}/routes` — that is the route that counts for points and badges. «Zapisz» only keeps the route on the device (`OfflineCache`), no points. Map tiles: `BaseMap` in `lib/shared/map/` (CARTO Voyager, OSM attribution); widget tests override `mapTilesEnabledProvider` with `false`, and use `RecordingApiClient` from `test/helpers/fakes.dart` (it reads the demo files from disk: `rootBundle` decodes big assets in an isolate the test does not wait for).

**Map (S05).** `mapLayersProvider` keeps the active filters; turning on a third fill (Cień, Zieleń, Cisza, Powietrze) switches off the oldest one with a message. Layers come from `layerProvider(kind)` (demo GeoJSON until `/v1/layers`, DEP-04); the on-phone API draws the shade layer for any 30-minute slot 08:00–20:00; in demo mode and after a fallback it is the bundled 14:30 file, so the picker then offers only that slot (`staticShadeLayerProvider`). «Cisza» shows quiet areas derived from the noise layer (`quietLayerProvider`). Quest places use the normal cool pin: a letter on the map would give the password away. Every widget test that builds the app uses `appTestOverrides()` (`test/helpers/fakes.dart`).

**Game (APP-16).** Rules are pure functions in `lib/core/game/game_rules.dart` (numbers in `game_config.dart`); `GameService` (`features/game/`) applies them to events — «Prowadź» (S07), a QR scan, the quest password — and `FirestoreGameRepository.award` writes the result: `pointsLog` entries, absolute `points`/`weekId`/`weekPoints`/`badges` on `users/{uid}`, the `rankings/{uid}` mirror (with consent) and `FieldValue.increment` on the district and its week. Every batch carries at most 200 points (the rules cap each write), so «hasło» (200) and a badge (30) go in two batches. The heat level is the stronger of the IMGW alert and `config/game.heatOverride`. In demo mode Strażnik chłodu needs 1 place instead of 5 (`GameConfig.demoBadgeCoolGuardPlaces`).

**Quest (S10, S11).** The quest comes from `assets/demo/quest.json` (+ names and positions from the cool places); progress is the user's own `visits` (readable by the owner). A scan checks, in order: the `coollodz://quest/{placeId}?c={kod}` format and that the place is in the quest → not scanned today (own visits) → within 150 m → the visit write, where the rules compare the code → `GameService.placeScanned` (+50, badges). The camera is behind `qrScannerBuilderProvider`; tests use `FakeQrScanner`. The reward code is a stable demo code per user (real MPK codes are a next step).

**Printing the quest QR codes (APP-15).** After the seed (it writes `tools/qr/codes.json`): `npm --prefix tools/qr ci && node tools/qr/generate.mjs` → `tools/qr/out/quest-codes.pdf`, one A4 page per place (QR with `coollodz://quest/{placeId}?c={kod}`, the place name, «Zeskanuj kod przy wejściu»; the letter is not printed). `codes.json` and the PDF are gitignored. `--png docs/quest-qr` also writes one PNG per place plus an index into `docs/quest-qr/`; the team keeps those in the repository for printing and the video. They are public, so a photo is enough to score without a visit: before real users play, run `seed --new-codes`, regenerate and reprint.

## Rules

- **State:** Riverpod 3 (`flutter_riverpod`), no code generation. Repositories and clients are providers, so tests and demo mode can override them.
- **Strings:** never hard-code UI text. Add keys to `lib/l10n/app_pl.arb` with the feature prefix (`map…`, `route…`, `quest…`) inside the block for your feature.
- **Theme:** colours, sizes and text styles come from `lib/app/theme.dart` (`AppColors`, `AppSizes`, `AppTextStyles`, `context.palette`). No raw hex values in features.
- **Accessibility:** tap targets ≥ 48 dp, `Semantics` labels for icons, colour is never the only signal (shade colour always has a % next to it). Senior mode must not break layouts at 360 dp width.
- **Firebase:** collection and field names come from `lib/core/firestore/collections.dart`; go through repositories in the feature or `core/`; widgets never call `FirebaseFirestore.instance` directly. Debug builds talk to the Firebase Emulator Suite.
- **Game numbers:** only in `lib/core/game/game_config.dart`.
- **Models:** `json_serializable`; generated `*.g.dart` files are committed (`dart run build_runner build --delete-conflicting-outputs`).
- **API:** features read `apiClientProvider` (`lib/core/api/api_providers.dart`). It is `DemoApiClient` when `demoModeProvider` (hidden toggle) is on; otherwise `FallbackApiClient` around `RemoteApiClient` when `API_BASE_URL` is set (`--dart-define=API_BASE_URL=https://…`) or around `LiveApiClient` (module D on the phone: OSRM, IMGW, GIOŚ, `lib/core/api/live/`) when it is empty; both fall back to cache/demo after 8 s. `isDemoModeEffectiveProvider` is the toggle only; `staticShadeLayerProvider` says the map shows the bundled 14:30 shade layer (demo mode, fallback). Widget tests that need demo semantics (July alerts, demo badge thresholds) start with `testPrefs({DemoMode.prefsKey: true})`. Show the `apiFallbackBanner` banner when `dataSourceProvider` is `DataSource.fallback`. Contract: [api-contract.md](api-contract.md). Widget tests that touch the API override `sharedPreferencesProvider` (see `test/core/api/api_providers_test.dart`) and `assetLoaderProvider`.
- **Tests:** unit tests for logic (game rules, parsing, opening hours), widget tests for screens. Keep `flutter analyze` clean and code formatted with `dart format`.

## Git

- One ticket = one branch `feat/APP-xx-short-name` (or `fix/…`, `chore/…`), one PR into `main` with `Closes #N`.
- Commit messages: `type(scope): summary` in English, e.g. `feat(map): add shade layer`.
- `main` is protected: CI (`analyze + test`) must pass; PRs are squash-merged.
- Secrets never go into git: `google-services.json`, signing keys, `key.properties`, `tools/qr/codes.json`. (The quest QR images in `docs/quest-qr/` are committed on purpose, see «Printing the quest QR codes».)
- Language: everything in git is English (code, comments, docs, commits, PRs), except `README.md` (Polish) and the app's UI strings (Polish).
