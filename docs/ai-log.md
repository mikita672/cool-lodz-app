# AI usage log

Which tasks were done with the help of AI (required by the competition rules). The log is handed to Mikita Kutsenka for the documentation, see APP-26.

| Date | Task | Tool | What was done | Checked by |
| :-- | :-- | :-- | :-- | :-- |
| 18.10.2026 | APP-00 | Claude Code + Figma MCP | Mock-up «Cool Łódź — App»: tokens with Default and Senior modes, about 30 component sets, 52 frames S01–S16, prototype and demo flow | review by MD + AH in APP-00 |
| 18.10.2026 | GitHub setup | Claude Code + GitHub CLI | Repository, labels, milestones M1–M6, issues APP-00…APP-28 with steps, questions and dependencies, board, day-by-day plan | MD |
| 19.10.2026 | APP-03, APP-07, APP-13 | Claude Code | API models and clients with an 8 s fallback; S01–S03 and the start flow; Firestore rules, indexes, seed and rules tests | automated tests; PR review — MD |
| 19.10.2026 | APP-08…APP-12 | Claude Code | S04 comfort profile and Senior; S06 planning (Nominatim search); S07 three variants, «Prowadź», «Zapisz»; S05 map with layers and alert; S08 sheet and S09 list | automated tests (widget tests at 360 dp and Senior); phone check — APP-24 |
| 19.10.2026 | APP-14, APP-16…APP-19 | Claude Code | Points and badges engine and S12; S10 quest and S11 QR scanner; S13 leaderboard; push, S14 and heat mode; S16 settings, account deletion, «O aplikacji» | automated tests, Firestore rules tests in the emulator; review — MD |
| 19.10.2026 | APP-15, APP-21…APP-23 | Claude Code | PDF with the quest QR codes; release signing and release instructions; «Najlepsza pora wyjścia» slider; S15 zgłoszenia | automated tests; printing, APK build and release — team |
| 19.10.2026 | APP-26 | Claude Code | Draft list of limitations and kolejne kroki (`docs/limitations.md`) | MD before sending |
| 21.10.2026 | Time picker and advice | Claude Code | Alarm-style day/hour/minute picker with weather icons (Open-Meteo weather code, wind, rain chance) for the shade and the departure; «Kiedy najlepiej iść?» ranking departures by shade, weather and opening hours | automated tests; phone check — team |
| 21.10.2026 | Alarm upałowy | Claude Code | Opt-in heat alarm: Android foreground service watching location in heat, stillness detector, full-screen check, siren at half then full volume with the flashlight, SMS with the location to trusted contacts, first-aid screen for passers-by; settings screen and tests | automated tests (Flutter + JVM); phone check — team |
| 22.10.2026 | Health and game additions | Claude Code | Heat risk card (UTCI steps, UV, profile advice), hot pavement warning for dog walkers, route sharing, «Twój wpływ», heatstroke symptom check, weekly challenge; rules for the new route fields | automated tests (Flutter + Firestore rules); phone check — team |
| 22.10.2026 | Shop, onboarding, fixes | Claude Code | Rewards shop (spent counter, redemptions, rules and rules tests), quest password 500 points, onboarding with a slide per feature and a replay from Profil, one-line buttons, compact map pills | automated tests (Flutter + Firestore rules); phone check — team |
