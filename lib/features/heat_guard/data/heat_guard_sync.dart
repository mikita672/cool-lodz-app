import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/heat/heat_risk.dart';
import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../cool_places/data/places_providers.dart';
import '../../cool_places/place_format.dart';
import '../../game/data/game_config_repository.dart';
import '../../game/game_service.dart';
import '../../heat_risk/data/heat_risk_providers.dart';
import '../../heat_risk/heat_risk_sheet.dart';
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
  'checkFallBody': l10n.heatNativeFallBody,
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
  'fallDetection': settings.fallDetection,
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

/// The texts of the daily jobs (`HeatDaily.kt`); `{level}`, `{from}`,
/// `{to}`, `{max}`, `{before}`, `{after}`, `{place}`, `{deadline}`,
/// `{name}` and `{names}` are filled in there.
Map<String, String> heatDailyTexts(AppLocalizations l10n) => {
  'imgwTitle': l10n.dailyImgwTitle('{level}'),
  'imgwBody': l10n.dailyImgwBody('{from}', '{to}'),
  'morningTitle': l10n.dailyMorningTitle('{max}'),
  'morningBody': l10n.dailyMorningBody('{before}', '{after}'),
  'morningAllDay': l10n.dailyMorningAllDay,
  'morningPlace': l10n.dailyMorningPlace('{place}'),
  'widgetTitle': l10n.widgetTitleFeels('{max}'),
  'widgetHours': l10n.widgetHours('{before}', '{after}'),
  'checkinTitle': l10n.dailyCheckinTitle,
  'checkinBody': l10n.dailyCheckinBody('{deadline}'),
  'checkinAction': l10n.dailyCheckinAction,
  'checkinThanks': l10n.dailyCheckinThanks,
  'checkinSms': l10n.dailyCheckinSms('{name}', '{deadline}'),
  'checkinMissedTitle': l10n.dailyCheckinMissedTitle,
  'checkinSmsSent': l10n.heatNativeSmsSent('{names}'),
  'checkinNoSms': l10n.dailyCheckinNoSms,
};

/// The cool place nearest to [home], whatever its hours (for the 7:00 tip).
Place? nearestCoolPlace(Iterable<Place> places, LatLng home) {
  Place? best;
  var bestD = double.infinity;
  for (final p in places) {
    final d = distanceTo(p, home);
    if (d < bestD) {
      best = p;
      bestD = d;
    }
  }
  return best;
}

/// The JSON `HeatDailyConfig` (HeatDaily.kt) reads.
String heatDailyConfigJson(
  HeatGuardSettings settings, {
  required Map<String, String> texts,
  String name = '',
  String? coolPlace,
}) => jsonEncode({
  'imgw': settings.imgwAuto,
  'morning': settings.morning,
  'checkin': settings.checkin,
  'checkinHour': settings.checkinHour,
  'deadlineHour': settings.deadlineHour,
  'morningCelsius': heatRiskThresholds.first,
  'checkinCelsius': 30,
  'name': name,
  'coolPlace': ?coolPlace,
  'contacts': [for (final c in settings.contacts) c.toJson()],
  'texts': texts,
});

/// Keeps the daily jobs (IMGW every 3 h, 7:00, check-in) in step with the
/// settings. Watched by [HeatGuardHandler].
final heatDailySyncProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(heatGuardSettingsProvider);
  final platform = ref.watch(heatGuardPlatformProvider);
  final name = ref.watch(playerProvider.select((p) => p.value?.nickname ?? ''));
  final home = settings.home;
  final places = home == null
      ? const <Place>[]
      : ref.watch(coolPlacesProvider).value ?? const <Place>[];
  final place = home == null ? null : nearestCoolPlace(places, home);
  final l10n = lookupAppLocalizations(const Locale('pl'));
  await platform.daily(
    heatDailyConfigJson(
      settings,
      texts: heatDailyTexts(l10n),
      name: name,
      coolPlace: place?.name,
    ),
  );
});

/// The home-screen widget's two lines for [risk].
(int, String, String) heatWidgetLines(HeatRisk? risk, AppLocalizations l10n) {
  if (risk == null) return (0, l10n.widgetNoData, l10n.widgetOpenApp);
  final hm = DateFormat('H:mm', 'pl');
  final level = heatRiskLabel(risk.level, l10n);
  final peak = risk.peakFeelsLike;
  final title = peak == null
      ? l10n.heatRiskChip(level)
      : l10n.heatRiskChipTemp(level, peak.round());
  final line = switch ((risk.riskFrom, risk.riskTo)) {
    (final from?, final to?) when risk.level != HeatRiskLevel.low =>
      l10n.widgetHours(hm.format(from), hm.format(to)),
    _ => risk.level == HeatRiskLevel.low ? l10n.widgetNoHeat : l10n.widgetShade,
  };
  return (risk.level.index, title, line);
}

/// Sends today's heat risk to the home-screen widget.
final heatWidgetSyncProvider = FutureProvider<void>((ref) async {
  final risk = await ref.watch(heatRiskProvider.future);
  final l10n = lookupAppLocalizations(const Locale('pl'));
  final (level, title, line) = heatWidgetLines(risk, l10n);
  await ref
      .read(heatGuardPlatformProvider)
      .widget(level: level, title: title, line: line);
});
