import 'dart:convert';

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
}
