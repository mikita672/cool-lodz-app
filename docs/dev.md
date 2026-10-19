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
- **Push.** There is no FCM emulator: debug builds get a real FCM token, printed to the log as `FCM token: …`. Send a test message from the Firebase console (Messaging → New campaign → Send test message) to that token. On Android 13+ allow notifications first (system settings, or `adb shell pm grant pl.betterthannever.cool_lodz android.permission.POST_NOTIFICATIONS`) and put the app in the background — FCM shows nothing while the app is in front (debug builds log `FCM foreground: …` instead).
- **Rules.** `firestore.rules` and `firestore.indexes.json` are the source of truth for the real project too; see [Firestore rules](#firestore-rules) below.

### Firestore rules

Collection and field names are in `lib/core/firestore/collections.dart`, together with `weekId()` (ISO week, `2026-W43`) and `visitId()` (`{uid}_{placeId}_{yyyyMMdd}`). Keep them in sync with `firestore.rules`. Things the client must do to pass the rules:

- `createdAt` in `visits`, `reports` and `pointsLog` is `FieldValue.serverTimestamp()`.
- `users.points` and `weekPoints` only grow, by at most 200 per write; a new `weekId` resets `weekPoints` (0–200). `badges` only grow. `users.district` is a district id (`baluty`, `gorna`, `polesie`, `srodmiescie`, `widzew`).
- District totals change only with `FieldValue.increment(1..200)`; the week doc `districts/{id}/weeks/{weekId}` is created by the first `set(..., merge)` with an increment.
- `users/{uid}` is readable only by its owner (RODO). The user ranking reads `rankings/{uid}`: nickname, district, points, weekId, weekPoints, updatedAt (server timestamp), written by the owner **in the same batch** as the user document and only while `consents.ranking` is true; the values must equal the user document after the batch. Withdrawing the consent must delete `rankings/{uid}` in the same batch (the rules reject the user update otherwise); "Usuń konto" deletes it too. Queries: `orderBy('points', descending: true).limit(50)` and `where('weekId', isEqualTo: weekId(now)).orderBy('weekPoints', descending: true).limit(50)` (composite index in `firestore.indexes.json`; `points` alone uses the automatic single-field index).

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

**Start flow (S01 → S02 → S03 → map).** `lib/features/auth/start_flow.dart` holds `StartFlowState` (onboarding seen, signed-in user, consents accepted) and the pure `startFlowRedirect`. `main.dart` plugs it into the router with `startFlowRouterOverrides` (overrides of `routerRedirectProvider` / `routerRefreshProvider`). Widget tests that pump `CoolLodzApp` without these overrides see every route unguarded; to test the flow, add the overrides plus fakes for `authRepositoryProvider`, `userProfileRepositoryProvider`, `onboardingStoreProvider`, `systemPermissionsProvider` (see `test/features/auth/fakes.dart`). `/start` is a short loading screen while the state is read; `/privacy` is reachable at every step. Detail screens are sub-routes of their tab (`/quest/scan`, `/map/alert`, `/profile/about`, `/route/result`), so a deep link still has a back stack; inside the app open them with `context.push`. The router is created once — redirect re-checks go through `routerRefreshProvider`.

## Rules

- **State:** Riverpod 3 (`flutter_riverpod`), no code generation. Repositories and clients are providers, so tests and demo mode can override them.
- **Strings:** never hard-code UI text. Add keys to `lib/l10n/app_pl.arb` with the feature prefix (`map…`, `route…`, `quest…`) inside the block for your feature.
- **Theme:** colours, sizes and text styles come from `lib/app/theme.dart` (`AppColors`, `AppSizes`, `AppTextStyles`, `context.palette`). No raw hex values in features.
- **Accessibility:** tap targets ≥ 48 dp, `Semantics` labels for icons, colour is never the only signal (shade colour always has a % next to it). Senior mode must not break layouts at 360 dp width.
- **Firebase:** collection and field names come from `lib/core/firestore/collections.dart`; go through repositories in the feature or `core/`; widgets never call `FirebaseFirestore.instance` directly. Debug builds talk to the Firebase Emulator Suite.
- **Game numbers:** only in `lib/core/game/game_config.dart`.
- **Models:** `json_serializable`; generated `*.g.dart` files are committed (`dart run build_runner build --delete-conflicting-outputs`).
- **API:** features read `apiClientProvider` (`lib/core/api/api_providers.dart`). It is `DemoApiClient` when `API_BASE_URL` is empty (`--dart-define=API_BASE_URL=https://…`) or `demoModeProvider` is on, otherwise `FallbackApiClient` (Remote, then cache/demo after 8 s). Show the `apiFallbackBanner` banner when `dataSourceProvider` is `DataSource.fallback`. Contract: [api-contract.md](api-contract.md). Widget tests that touch the API override `sharedPreferencesProvider` (see `test/core/api/api_providers_test.dart`) and `assetLoaderProvider`.
- **Tests:** unit tests for logic (game rules, parsing, opening hours), widget tests for screens. Keep `flutter analyze` clean and code formatted with `dart format`.

## Git

- One ticket = one branch `feat/APP-xx-short-name` (or `fix/…`, `chore/…`), one PR into `main` with `Closes #N`.
- Commit messages: `type(scope): summary` in English, e.g. `feat(map): add shade layer`.
- `main` is protected: CI (`analyze + test`) must pass; PRs are squash-merged.
- Secrets never go into git: `google-services.json`, signing keys, `key.properties`, quest QR codes.
