# Limitations and kolejne kroki (draft for APP-26)

A list for the competition documentation (MD hands it to Mikita Kutsenka). The draft was compiled from the code as of 19.10.2026; before sending, check the items marked **[check]**.

## Known limitations

**Game and fairness**
- Points are awarded by the app, not by a server (no Cloud Functions, which need the Blaze plan). Firestore rules only limit each write: at most +200 points, points and badges never decrease, the leaderboard matches the profile. Server-side validation is in kolejne kroki.
- The quest hasło and letters are stored in the app (`assets/demo/quest.json`) and in `questPlaces`, which any signed-in user can read, so the hasło can be found out without visiting the places.
- The "no further than 150 m from the place" check runs on the phone using GPS; it does not detect a spoofed location. The place code is checked by the Firestore rules.
- QR codes are changed manually (`seed --new-codes`); after that the PDF must be printed again.
- After an account is deleted, the same places can be scanned again (decision Q-10).
- Around midnight one place can be scanned twice: the rules accept both Polish summer and winter time.
- Ranny ptaszek and Wieczorny spacerowicz are evaluated against the alert at the moment the route starts: alert history is not stored.
- Points for an approved zgłoszenie (+20) and the Pomocnik miasta badge are awarded when the user opens the Odznaki tab after approval in the Firebase console.
- The MPK discount code is a mock (the same for every user, not connected to MigAppka).

**Data and map**
- Without a module D server the API is computed on the phone: routes from the public OSRM (FOSSGIS, with no availability guarantee and with rate limits) plus a shade model from trees and parks in OSM and building shadows from the sun position. The shade model is an estimate, not a measurement; not all trees are mapped in OSM, and building height and street width are assumed uniform (16 m / 18 m in Śródmieście, 10 m / 24 m outside it). Outside Śródmieście there is no tree data: the route is marked «Dla tego obszaru cień jest przybliżony».
- If no detour is shadier, the three route variants may be identical.
- The profile's «cisza» and «powietrze» weights do not affect route choice yet (only shade and time are taken into account).
- Shade and routes follow the sun position and the Open-Meteo forecast (direct sunlight, clouds, temperature) for one point in Łódź; the weather is a forecast, not a measurement, and without network the app assumes a clear sky.
- The map's shade layer is drawn on the phone for any time 08:00–20:00, from mapped trees and parks plus building shadows of uniform 16 m tenements on the street centrelines (OSM, Śródmieście only). Greenery and noise are static GeoJSON for Śródmieście until module D has `/v1/layers` (DEP-04). Noise levels are estimates by road class, not measurements; «Cisza» shows the areas away from those roads.
- Alerts are IMGW «Upał» warnings for the city of Łódź (TERYT 1061); air is the GIOŚ index of four Łódź stations.
- In demo mode, routes between arbitrary points are synthetic; only the two reference routes are accurate.
- Address search uses Nominatim (OSM), only within the Łódź city limits, at most 1 request per second.
- There is no module D server; the app runs on the API computed on the phone (APP-20). If a server appears, its address is set with `--dart-define=API_BASE_URL=…`.

**Alerts and push**
- The alert push is sent manually from the Firebase console (a test message); there is no automatic sending based on IMGW data — that needs a server side.
- Heat mode for the demo is turned on with the `config/game.heatOverride` field.

**Platform and UI**
- Android 7.0+ only (minSdk 24), Polish only, light theme only, portrait orientation only.
- Turn-by-turn navigation is not done in the app: «Prowadź» opens Google Maps (walking, with waypoints of the selected line).
- Only signed-in app users see the leaderboard; the website does not show it (Q-03).
- **[check]** The app has not been tested on real phones yet (APP-24); it is covered by automated tests (widget tests at 360 dp width and in Senior mode ×1.25, Firestore rules tests in the emulator).

## Kolejne kroki

- In-app turn-by-turn navigation.
- Post-walk route rating.
- Natural-language AI assistant.
- Photos in zgłoszenia, group walks, referral code, the Ambasador and Wspólny spacer badges.
- 5 more comfort profiles as separate cards (dog, pram, commute, active, sensitivity to noise and smog); their weights can already be set with the sliders.
- Sign-in with Google and other accounts.
- Real MPK codes in MigAppka (requires an agreement with MPK).
- Server-side validation of points and scans (Cloud Functions), automatic sending of IMGW alerts.
- iOS, English language, dark theme.
