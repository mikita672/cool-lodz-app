import 'dart:convert';

import 'package:cool_lodz/core/heat/heat_risk.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/storage/preferences.dart';
import 'package:cool_lodz/features/heat_guard/data/heat_guard_platform.dart';
import 'package:cool_lodz/features/heat_guard/data/heat_guard_settings.dart';
import 'package:cool_lodz/features/heat_guard/data/heat_guard_sync.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phone numbers: Polish without +48, spaces, 00, other countries', () {
    expect(normalizePhone('601 234 567'), '+48601234567');
    expect(normalizePhone('+48 601-234-567'), '+48601234567');
    expect(normalizePhone('0048601234567'), '+48601234567');
    expect(normalizePhone('+380 50 123 4567'), '+380501234567');
    expect(normalizePhone('12345'), isNull);
    expect(normalizePhone('abc'), isNull);
    expect(normalizePhone(''), isNull);
  });

  test('settings survive a restart', () async {
    final prefs = await testPrefs();
    final c = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(c.read(heatGuardSettingsProvider), const HeatGuardSettings());
    const s = HeatGuardSettings(
      enabled: true,
      heatOnly: false,
      waitMinutes: 5,
      contacts: [TrustedContact(name: 'Anna', phone: '+48601234567')],
      home: LatLng(51.77, 19.45),
    );
    await c.read(heatGuardSettingsProvider.notifier).update(s);
    final again = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(again.read(heatGuardSettingsProvider), s);

    await prefs.setString(HeatGuardSettingsNotifier.prefsKey, '{broken');
    final broken = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(broken.read(heatGuardSettingsProvider), const HeatGuardSettings());
  });

  test('the service config: settings, safe places, heat warning, texts', () {
    final l10n = lookupAppLocalizations(const Locale('pl'));
    final json =
        jsonDecode(
              heatGuardConfigJson(
                const HeatGuardSettings(
                  enabled: true,
                  waitMinutes: 5,
                  contacts: [
                    TrustedContact(name: 'Anna', phone: '+48601234567'),
                  ],
                  home: LatLng(51.77, 19.45),
                ),
                texts: heatGuardTexts(l10n),
                safePlaces: const [
                  Place(id: 'p', type: PlaceType.cool, lat: 51.76, lon: 19.46),
                ],
                heatUntil: DateTime.utc(2026, 7, 15, 20),
              ),
            )
            as Map<String, dynamic>;
    expect(json['waitMinutes'], 5);
    expect(json['heatOnly'], isTrue);
    expect(json['hotCelsius'], heatGuardHotCelsius);
    expect(
      json['heatUntil'],
      DateTime.utc(2026, 7, 15, 20).millisecondsSinceEpoch,
    );
    expect(json['contacts'], [
      {'name': 'Anna', 'phone': '+48601234567'},
    ]);
    expect(json['home'], [51.77, 19.45]);
    expect(json['safePlaces'], [
      [51.76, 19.46],
    ]);
    final texts = json['texts'] as Map<String, dynamic>;
    // Placeholders stay for the service to fill in.
    expect(texts['monitorWatching'], contains('{temp}'));
    expect(texts['sms'], allOf(contains('{place}'), contains('{time}')));
    expect(texts['sms'], contains('112'));
    expect(
      texts['smsPlace'],
      allOf(contains('{link}'), contains('{accuracy}')),
    );
    expect(texts['checkSmsSent'], contains('{names}'));
    expect(texts['actionOk'], 'Tak, wszystko OK');
  });

  test('the channel: status, permissions, missing plugin', () async {
    const channel = MethodChannel('test/heat_guard');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'status' => {
              'running': true,
              'hot': true,
              'temperature': 31.4,
              'phase': 'full',
              'smsSentTo': ['Anna'],
            },
            'permissions' => {
              'location': true,
              'backgroundLocation': false,
              'notifications': true,
              'sms': true,
            },
            'request' => true,
            _ => null,
          };
        });
    final platform = HeatGuardPlatform(channel);
    final status = await platform.status();
    expect(status.running, isTrue);
    expect(status.hot, isTrue);
    expect(status.temperature, 31.4);
    expect(status.phase, HeatGuardPhase.full);
    expect(status.smsSentTo, ['Anna']);
    final p = await platform.permissions();
    expect(p.canWatch, isFalse); // no «Zezwalaj zawsze»
    expect(await platform.request('sms'), isTrue);
    await platform.answer(needHelp: true);
    expect(calls.last.method, 'answer');
    expect(calls.last.arguments, 'help');

    // Off Android nothing breaks.
    final none = HeatGuardPlatform(const MethodChannel('test/none'));
    expect((await none.status()).running, isFalse);
    expect(await none.pendingCheck(), isFalse);
    await none.start();
  });

  test('daily jobs: settings round trip and the native config', () {
    const settings = HeatGuardSettings(
      contacts: [TrustedContact(name: 'Ola', phone: '+48601234567')],
      home: LatLng(51.77, 19.45),
      checkin: true,
      checkinHour: 8,
      deadlineHour: 10,
      fallDetection: false,
      morning: false,
    );
    expect(HeatGuardSettings.fromJson(settings.toJson()), settings);
    // Older saved settings: the daily jobs on, the check-in off.
    final old = HeatGuardSettings.fromJson(const {'enabled': true});
    expect(old.imgwAuto && old.morning && old.fallDetection, isTrue);
    expect(old.checkin, isFalse);

    final l10n = lookupAppLocalizations(const Locale('pl'));
    final json =
        jsonDecode(
              heatDailyConfigJson(
                settings,
                texts: heatDailyTexts(l10n),
                name: 'Ania',
                coolPlace: 'Biblioteka',
              ),
            )
            as Map<String, dynamic>;
    expect(json['checkin'], isTrue);
    expect(json['checkinHour'], 8);
    expect(json['deadlineHour'], 10);
    expect(json['morning'], isFalse);
    expect(json['coolPlace'], 'Biblioteka');
    expect(json['contacts'], [
      {'name': 'Ola', 'phone': '+48601234567'},
    ]);
    final texts = json['texts'] as Map<String, dynamic>;
    expect(texts['checkinSms'], contains('{name}'));
    expect(texts['checkinSms'], contains('{deadline}'));
    expect(texts['morningBody'], contains('{before}'));
    expect(
      jsonDecode(
        heatGuardConfigJson(settings, texts: const {}),
      )['fallDetection'],
      isFalse,
    );
  });

  test('the nearest cool place to home', () {
    Place p(String id, double lat) =>
        Place(id: id, type: PlaceType.cool, name: id, lat: lat, lon: 19.45);
    expect(
      nearestCoolPlace([
        p('far', 51.80),
        p('near', 51.771),
      ], const LatLng(51.77, 19.45))?.id,
      'near',
    );
    expect(nearestCoolPlace(const [], const LatLng(51.77, 19.45)), isNull);
  });

  test('widget lines: level, peak and the hours to stay in', () async {
    await initializeDateFormatting('pl');
    final l10n = lookupAppLocalizations(const Locale('pl'));
    final (level, title, line) = heatWidgetLines(
      HeatRisk(
        level: HeatRiskLevel.high,
        peakFeelsLike: 34.4,
        riskFrom: DateTime(2026, 7, 15, 12),
        riskTo: DateTime(2026, 7, 15, 18),
      ),
      l10n,
    );
    expect(level, 2);
    expect(title, contains('34'));
    expect(line, contains('12:00'));
    expect(line, contains('18:00'));
    expect(heatWidgetLines(null, l10n).$1, 0);
    expect(
      heatWidgetLines(const HeatRisk(level: HeatRiskLevel.low), l10n).$3,
      l10n.widgetNoHeat,
    );
  });
}
