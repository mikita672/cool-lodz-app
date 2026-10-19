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
- **Rules.** `firestore.rules` and `firestore.indexes.json` are the source of truth for the real project too; deploy them with `firebase deploy --only firestore:rules,firestore:indexes` after every change (the emulator reads the files directly). Until APP-13 the rules deny everything.

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
- **Firebase:** go through repositories in the feature or `core/`; widgets never call `FirebaseFirestore.instance` directly. Debug builds talk to the Firebase Emulator Suite.
- **Game numbers:** only in `lib/core/game/game_config.dart`.
- **Models:** `json_serializable`; generated `*.g.dart` files are committed (`dart run build_runner build --delete-conflicting-outputs`).
- **Tests:** unit tests for logic (game rules, parsing, opening hours), widget tests for screens. Keep `flutter analyze` clean and code formatted with `dart format`.

## Git

- One ticket = one branch `feat/APP-xx-short-name` (or `fix/…`, `chore/…`), one PR into `main` with `Closes #N`.
- Commit messages: `type(scope): summary` in English, e.g. `feat(map): add shade layer`.
- `main` is protected: CI (`analyze + test`) must pass; PRs are squash-merged.
- Secrets never go into git: `google-services.json`, signing keys, `key.properties`, quest QR codes.
