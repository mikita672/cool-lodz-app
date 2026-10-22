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
- Shadows on the map and in the routes come from OSM building footprints and trees in Śródmieście; where OSM has no height, a typical height for the building type is assumed (most of the tenement core is 14 m), and unmapped trees cast no shadow. Outside Śródmieście the routes use a simpler street-canyon estimate and the map shows no shadows. Greenery and noise are static GeoJSON for Śródmieście until module D has `/v1/layers` (DEP-04). Noise levels are estimates by road class, not measurements; «Cisza» shows the areas away from those roads.
- Alerts are IMGW «Upał» warnings for the city of Łódź (TERYT 1061); air is the GIOŚ index of four Łódź stations.
- In demo mode, routes between arbitrary points are synthetic; only the two reference routes are accurate.
- Address search uses Nominatim (OSM), only within the Łódź city limits, at most 1 request per second.
- There is no module D server; the app runs on the API computed on the phone (APP-20). If a server appears, its address is set with `--dart-define=API_BASE_URL=…`.

**Alerts and push**
- The alert push is sent manually from the Firebase console (a test message); there is no automatic sending based on IMGW data — that needs a server side.
- Heat mode for the demo is turned on with the `config/game.heatOverride` field.

**Map modes**
- «Zima» is an estimate from street categories, not ZDiT's real clearing plan (not published as open data); «Nocą» counts venues from OSM, not real foot traffic. Both, the toilets and the trees cover Śródmieście only.

**Shop**
- Rewards and codes are a demo: no agreement with MPK Łódź or the venues yet, codes are not checked anywhere. Spending is validated only by the Firestore rules (the client could add points the same way it earns them, see above).

**Heat risk, pavement, symptoms**
- The heat risk uses the feels-like temperature on UTCI-like steps, not a full UTCI calculation; the asphalt temperature is an estimate from air temperature and sun (no surface sensors).
- The symptom check is fixed advice from NHS/GIS guidance, not a diagnosis.
- «Twój wpływ» counts only walks started with «Prowadź»; routes saved before 22.10 estimate their time from the distance and have no «Mniej słońca». CO₂ assumes an average car.
- The weekly challenge, like all points, is awarded by the client (no Cloud Functions).

**Alarm upałowy**
- Android only, in the APK from GitHub releases: Google Play allows SMS sending and background location only after a review.
- It must keep running in the background: swiping the app away from recent apps or aggressive battery savers (Xiaomi, Huawei, some Samsungs) can stop it. The settings screen lists what to allow; the service restarts after the system kills it, but not after a reboot (open the app once).
- «Still» comes from GPS only (stays within 40 m after walking ≥ 100 m). It can ask while you wait at a stop or sit on a bench (answer «OK», or set a longer time) and it cannot notice a fall while walking.
- The SMS needs a SIM, signal and credit; it goes once per alarm. The location is the last GPS fix (accuracy in the message).
- Android 14+ shows the full-screen alarm only after the user allows it in the system settings; otherwise it is a loud notification.
- Not a medical device and not an emergency service: it does not call 112.

**Daily heat jobs, data and community (22.10)**
- The IMGW check, the 7:00 message and the check-in use inexact alarms: Android may run them up to ~15 minutes late, later in deep battery saving. They stop after the app is force-stopped and come back after a reboot or opening the app.
- The check-in SMS goes once a day and only on hot days; without a SIM or credit the user sees a notification instead.
- Fall detection needs the phone on the body; dropping the phone and leaving it can trigger the question (answer «OK»). It runs only while the alarm watches (hot days).
- Pollen and AQI are a model forecast (CAMS, ~10 km grid), not measurements.
- Surfaces, steps and fountains come from OSM in Śródmieście; unmapped cobbles or steps are not warned about. Heat islands are an estimate from roofs, trees and parks, not satellite land-surface temperature.
- «Chłodny spacer» needs the internet (OSRM); outside Śródmieście the shade is an estimate.
- Community points: anyone signed in can add them (no moderation yet); votes stay counted after the voter deletes the account (only their own points are removed).
- The widget refreshes when the app runs or at 7:00, not live.
- «Wypełnij konto demo» writes real points to the account (for presentations only).

**Platform and UI**
- Android 7.0+ only (minSdk 24), Polish only, light theme only, portrait orientation only.
- Turn-by-turn navigation is not done in the app: «Prowadź» opens Google Maps (walking, with waypoints of the selected line).
- Only signed-in app users see the leaderboard; the website does not show it (Q-03).
- **[check]** The app has not been tested on real phones yet (APP-24); it is covered by automated tests (widget tests at 360 dp width and in Senior mode ×1.25, Firestore rules tests in the emulator).

## Kolejne kroki

- Alarm upałowy: fall detection (accelerometer), Android activity recognition instead of GPS only, restart after a reboot, a push to the trusted person's Cool Łódź app, smartwatches.
- In-app turn-by-turn navigation.
- Post-walk route rating.
- Natural-language AI assistant.
- Photos in zgłoszenia, group walks, referral code, the Ambasador and Wspólny spacer badges.
- 5 more comfort profiles as separate cards (dog, pram, commute, active, sensitivity to noise and smog); their weights can already be set with the sliders.
- Sign-in with Google and other accounts.
- Real MPK codes in MigAppka (requires an agreement with MPK).
- Server-side validation of points and scans (Cloud Functions), automatic sending of IMGW alerts.
- iOS, English language, dark theme.
