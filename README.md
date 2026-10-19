# Cool Łódź — App

Android-приложение на Flutter: в жару строит пешие маршруты по Лодзи через тень, зелень и тихие улицы, показывает miejsca chłodu и воду и превращает их посещение в игру. Hackathon Future Smart City 2026, область Health Shift, команда Better Than Never.

- **План по шагам:** [#48 — шаги по дням, 19–27.10](https://github.com/mikita672/cool-lodz-app/issues/48)
- **Доска:** [Cool Łódź — App](https://github.com/users/mikita672/projects/1) — Backlog → To do → In progress → Review → Done
- **Майлстоуны:** [M1–M6](https://github.com/mikita672/cool-lodz-app/milestones)
- **Спецификация:** [docs/spec.md](docs/spec.md)
- **Макет:** [Figma «Cool Łódź — App»](https://www.figma.com/design/U5IzePCuqa0gZlipjRQEOm/Cool-Lodz-App)
- **Журнал AI:** [docs/ai-log.md](docs/ai-log.md)

## Запуск

Нужны Flutter 3.41 (stable), JDK 17 и Android SDK 36; приложение — только Android 7.0+.

```sh
flutter pub get
flutter analyze && flutter test
flutter run
```

Устройство кода, правила и git-процесс — в [docs/dev.md](docs/dev.md). Release APK, подпись и GitHub Release — в [docs/release.md](docs/release.md).

**Источники данных:** без `--dart-define=API_BASE_URL=…` приложение само считает API модуля D на телефоне (`lib/core/api/live/`): маршруты OSRM + модель тени, алерты IMGW, воздух GIOŚ, места и слои из `assets/demo/` (см. [docs/api-contract.md](docs/api-contract.md#live-mode-liveapiclient)). С `API_BASE_URL` — сервер модуля D. **Demo-режим** (только данные из `assets/demo/`, без сети): Profil → O aplikacji → 5 нажатий на версию → «Tryb demo»; там же выбирается степень алерта для демо.

## Как работаем

- Одна задача — один issue `APP-xx` с шагами и чек-листом «Готово, когда».
- Ветка `feat/APP-xx-short-name`, PR со строкой `Closes #N`.
- Решения, которых нет в спецификации, не придумываем: заводим issue с лейблом `question`.
- Задача вышла больше 1,5× оценки — режем её, а не сдвигаем остальное.
- Что сделано с Claude Code, записываем в журнал AI.
