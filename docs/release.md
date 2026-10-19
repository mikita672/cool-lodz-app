# Release APK (APP-21)

How to build, sign and publish `v1.0.0`. The signing key never goes into git.

## 1. Team key (once)

```sh
keytool -genkey -v -keystore ~/cool-lodz-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias coollodz
```

Keep a copy with MD and AH (a lost key means a new app id on users' phones). Create `android/key.properties` (ignored by git):

```properties
storeFile=/absolute/path/to/cool-lodz-release.jks
storePassword=…
keyAlias=coollodz
keyPassword=…
```

`storeFile` may also be relative to `android/app/`. Without this file `android/app/build.gradle.kts` signs release builds with the debug key and prints a warning — fine for testing, not for the GitHub Release.

## 2. Build

Needs `android/app/google-services.json` (see [dev.md](dev.md#firebase)). Release builds always use the real Firebase project.

```sh
flutter pub get
flutter analyze && flutter test
flutter build apk --release
# With a hosted module D instead of the on-phone API (APP-20):
# flutter build apk --release --dart-define=API_BASE_URL=https://<module-d-host>
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. `versionName` 1.0.0 comes from `pubspec.yaml` (`version: 1.0.0+1`); bump the `+N` build number for every new upload.

Check the signature: `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk` must show the team certificate, not `Android Debug`.

## 3. Before publishing

- Firestore rules and indexes are deployed: `firebase deploy --only firestore:rules,firestore:indexes`.
- The seed ran on the real project (`config/game`, districts, quest places and codes) and the QR codes were printed (APP-15).
- Install on a clean phone with Android 7.0+ and go through the demo scenario (spec «Сценарий демо»): set `config/game.heatOverride` = 2, send the test push, S05 → S06 → S07, a QR scan, S13. Cold start under 3 s.
- Without network (or with a wrong `API_BASE_URL`) the app switches to cached/demo data after 8 s and shows the banner.
- With network, a route between two addresses in Śródmieście has three variants without «Dla tego obszaru cień jest przybliżony», S05 shows the GIOŚ stations, and S14 shows a real IMGW heat warning when one is active (otherwise none).

## CI: APK on every merge to main

`.github/workflows/release-apk.yml` builds the release APK on each push to `main` (and on demand: Actions → Release APK → Run workflow) and publishes it as the latest GitHub Release `build-<N>`. Stable link to the newest APK:

https://github.com/mikita672/cool-lodz-app/releases/latest/download/cool-lodz.apk

Repository secrets (Settings → Secrets and variables → Actions → New repository secret):

| Secret | Required | Value |
| --- | --- | --- |
| `GOOGLE_SERVICES_JSON` | yes | the whole `google-services.json` (Firebase console → Project settings → Your apps → Android `pl.betterthannever.cool_lodz` → download). Plain JSON or base64. Without it the workflow builds nothing and shows a warning. |
| `ANDROID_KEYSTORE_BASE64` | for updates | `base64 -w0 cool-lodz-release.jks` of the team key from step 1 |
| `ANDROID_KEYSTORE_PASSWORD` | with the key | store password |
| `ANDROID_KEY_ALIAS` | with the key | `coollodz` |
| `ANDROID_KEY_PASSWORD` | optional | key password, if different from the store password |
| `MAP_TILES_KEY` | yes, for a usable map | free CARTO basemaps key from <https://carto.com/basemaps/apikey> (no account needed, 5 M tiles a month free). Without it every map tile only says «API KEY REQUIRED». |

Without the key secrets every build gets a new throw-away debug key, so Android refuses to install a new build over an older one (uninstall first). The build number is the workflow run number, so `versionCode` always grows.

Optional repository variable `API_BASE_URL` (Variables tab) points the APK at a hosted module D; empty = the on-device API (see api-contract.md).

## 4. GitHub Release

Tag `v1.0.0`, attach `app-release.apk` (rename to `cool-lodz-1.0.0.apk`), notes below. Give the asset link to the website team for `/pobierz` (DEP-07, #36) and put it in the ChallengeRocket form.

```markdown
Cool Łódź 1.0.0 — Android 7.0+

Trasy piesze przez cień, zieleń i ciche ulice Łodzi, miejsca chłodu i woda,
quest «Chłodne hasło», odznaki i ranking dzielnic.

Instalacja: pobierz plik APK na telefon i otwórz go (Android zapyta o zgodę
na instalację z tego źródła).

Tryb demo: Profil → O aplikacji → 5 razy dotknij numeru wersji → «Tryb demo».
Trasy, miejsca i alerty pochodzą wtedy z danych zapisanych w aplikacji.

Aplikacja nie jest wyrobem medycznym. W razie złego samopoczucia dzwoń 112.
```
