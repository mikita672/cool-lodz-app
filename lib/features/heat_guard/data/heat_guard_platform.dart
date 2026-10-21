import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the check is: asking, siren at half volume, full alarm.
enum HeatGuardPhase { idle, ask, half, full }

@immutable
class HeatGuardStatus {
  const HeatGuardStatus({
    this.running = false,
    this.hot = false,
    this.temperature,
    this.phase = HeatGuardPhase.idle,
    this.smsSentTo = const [],
  });

  factory HeatGuardStatus.fromMap(Map<Object?, Object?> map) => HeatGuardStatus(
    running: map['running'] == true,
    hot: map['hot'] == true,
    temperature: (map['temperature'] as num?)?.toDouble(),
    phase: HeatGuardPhase.values.firstWhere(
      (p) => p.name == map['phase'],
      orElse: () => HeatGuardPhase.idle,
    ),
    smsSentTo: [for (final n in map['smsSentTo'] as List? ?? const []) '$n'],
  );

  /// The service is on.
  final bool running;

  /// It is hot (or «only in heat» is off): location is watched.
  final bool hot;
  final double? temperature;
  final HeatGuardPhase phase;

  /// Names (or numbers) the SMS went to.
  final List<String> smsSentTo;
}

/// What the alarm needs from Android.
@immutable
class HeatGuardPermissions {
  const HeatGuardPermissions({
    this.location = false,
    this.backgroundLocation = false,
    this.notifications = false,
    this.sms = false,
    this.telephony = true,
    this.fullScreen = true,
    this.battery = true,
  });

  factory HeatGuardPermissions.fromMap(Map<Object?, Object?> map) =>
      HeatGuardPermissions(
        location: map['location'] == true,
        backgroundLocation: map['backgroundLocation'] == true,
        notifications: map['notifications'] == true,
        sms: map['sms'] == true,
        telephony: map['telephony'] != false,
        fullScreen: map['fullScreen'] != false,
        battery: map['battery'] != false,
      );

  final bool location;

  /// «Zezwalaj zawsze» (Android 10+).
  final bool backgroundLocation;
  final bool notifications;
  final bool sms;

  /// The phone can send SMS at all (has a SIM slot).
  final bool telephony;

  /// Android 14+: full-screen alarms over the lock screen.
  final bool fullScreen;

  /// Not stopped by battery optimisation.
  final bool battery;

  /// Enough to watch and ask (SMS and the rest make it better).
  bool get canWatch => location && backgroundLocation && notifications;
}

/// The `cool_lodz/heat_guard` channel to the Android service
/// (`HeatGuardService.kt`). Off Android every call is a no-op.
class HeatGuardPlatform {
  HeatGuardPlatform([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('cool_lodz/heat_guard');

  final MethodChannel _channel;
  final _checks = StreamController<void>.broadcast();
  bool _listening = false;

  /// Fires when the service opens the app for a check.
  Stream<void> get checks {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'check') _checks.add(null);
      });
    }
    return _checks.stream;
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('heat_guard.$method: $e');
      return null;
    }
  }

  Future<void> configure(String json) => _call<void>('configure', json);
  Future<void> start() => _call<void>('start');
  Future<void> stop() => _call<void>('stop');

  /// The whole check with 5-second steps and no SMS.
  Future<void> test() => _call<void>('test');

  Future<void> answer({required bool needHelp}) =>
      _call<void>('answer', needHelp ? 'help' : 'ok');

  Future<HeatGuardStatus> status() async {
    final map = await _call<Map<Object?, Object?>>('status');
    return map == null ? const HeatGuardStatus() : HeatGuardStatus.fromMap(map);
  }

  /// A check is waiting for the app (opened from the full-screen alarm).
  Future<bool> pendingCheck() async =>
      await _call<bool>('pendingCheck') ?? false;

  Future<void> checkClosed() => _call<void>('checkClosed');

  Future<HeatGuardPermissions> permissions() async {
    final map = await _call<Map<Object?, Object?>>('permissions');
    return map == null
        ? const HeatGuardPermissions()
        : HeatGuardPermissions.fromMap(map);
  }

  /// `location`, `backgroundLocation`, `notifications` or `sms`.
  Future<bool> request(String kind) async =>
      await _call<bool>('request', kind) ?? false;

  /// `fullScreen`, `battery` or the app's settings page.
  Future<void> openSettings(String kind) => _call<void>('openSettings', kind);
}

final heatGuardPlatformProvider = Provider<HeatGuardPlatform>(
  (ref) => HeatGuardPlatform(),
);
