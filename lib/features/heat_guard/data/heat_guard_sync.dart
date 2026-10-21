import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../cool_places/data/places_providers.dart';
import '../../game/data/game_config_repository.dart';
import 'heat_guard_platform.dart';
import 'heat_guard_settings.dart';

/// From this temperature (°C) the service counts the day as hot.
const heatGuardHotCelsius = 28.0;

/// The texts the Android service shows; `{temp}`, `{names}`, `{place}`,
/// `{time}`, `{link}` and `{accuracy}` are filled in there.
Map<String, String> heatGuardTexts(AppLocalizations l10n) => {
  'monitorTitle': l10n.heatNativeMonitorTitle,
  'monitorWatching': l10n.heatNativeWatching('{temp}'),
  'monitorWaiting': l10n.heatNativeWaiting('{temp}'),
  'checkTitle': l10n.heatCheckQuestion,
  'checkBody': l10n.heatNativeCheckBody,
  'checkAlarmTitle': l10n.heatNativeAlarmTitle,
  'checkAlarmBody': l10n.heatNativeAlarmBody,
  'checkSmsSent': l10n.heatNativeSmsSent('{names}'),
  'actionOk': l10n.heatCheckOk,
  'actionHelp': l10n.heatCheckHelp,
  'sms': l10n.heatNativeSms('{place}', '{time}'),
  'smsPlace': l10n.heatNativeSmsPlace('{link}', '{accuracy}'),
  'smsNoPlace': l10n.heatNativeSmsNoPlace,
};

/// The JSON `HeatGuardConfig.kt` reads. [heatUntil]: end of an IMGW heat
/// warning (the service then watches whatever the thermometer says).
String heatGuardConfigJson(
  HeatGuardSettings settings, {
  required Map<String, String> texts,
  List<Place> safePlaces = const [],
  DateTime? heatUntil,
}) => jsonEncode({
  'waitMinutes': settings.waitMinutes,
  'heatOnly': settings.heatOnly,
  'hotCelsius': heatGuardHotCelsius,
  'heatUntil': heatUntil?.millisecondsSinceEpoch ?? 0,
  'contacts': [for (final c in settings.contacts) c.toJson()],
  if (settings.home case final h?) 'home': [h.latitude, h.longitude],
  'safePlaces': [
    for (final p in safePlaces) [p.lat, p.lon],
  ],
  'texts': texts,
});

/// Keeps the Android service in step with the settings, the cool places
/// (no checks there) and the IMGW heat warning. Watched by
/// [HeatGuardHandler] for the whole life of the app.
final heatGuardSyncProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(heatGuardSettingsProvider);
  final platform = ref.watch(heatGuardPlatformProvider);
  if (!settings.enabled) {
    await platform.stop();
    return;
  }
  final alert = ref.watch(currentAlertProvider);
  final places = ref.watch(coolPlacesProvider).value ?? const <Place>[];
  final l10n = lookupAppLocalizations(const Locale('pl'));
  final heatUntil =
      alert != null && alert.level >= 1 && alert.validTo.isAfter(DateTime.now())
      ? alert.validTo
      : null;
  await platform.configure(
    heatGuardConfigJson(
      settings,
      texts: heatGuardTexts(l10n),
      safePlaces: places,
      heatUntil: heatUntil,
    ),
  );
  await platform.start();
});
