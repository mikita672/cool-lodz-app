import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/storage/preferences.dart';

/// Someone who gets the SMS when the user does not answer.
@immutable
class TrustedContact {
  const TrustedContact({required this.name, required this.phone});

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );

  final String name;

  /// Normalised by [normalizePhone], e.g. `+48601234567`.
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  @override
  bool operator ==(Object other) =>
      other is TrustedContact && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}

/// `+48 601-234-567`, `601234567`, `0048601234567` → `+48601234567`; other
/// countries need their `+` code. Null when it is not a phone number.
String? normalizePhone(String input) {
  var s = input.replaceAll(RegExp(r'[\s\-().]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (RegExp(r'^\d{9}$').hasMatch(s)) return '+48$s';
  if (RegExp(r'^\+\d{8,15}$').hasMatch(s)) return s;
  return null;
}

/// «Alarm upałowy» settings (on this phone only).
@immutable
class HeatGuardSettings {
  const HeatGuardSettings({
    this.enabled = false,
    this.heatOnly = true,
    this.waitMinutes = defaultWait,
    this.contacts = const [],
    this.home,
    this.fallDetection = true,
    this.imgwAuto = true,
    this.morning = true,
    this.checkin = false,
    this.checkinHour = 9,
    this.deadlineHour = 11,
  });

  factory HeatGuardSettings.fromJson(Map<String, dynamic> json) {
    final home = json['home'];
    return HeatGuardSettings(
      enabled: json['enabled'] as bool? ?? false,
      heatOnly: json['heatOnly'] as bool? ?? true,
      waitMinutes: (json['waitMinutes'] as num?)?.toInt() ?? defaultWait,
      contacts: [
        for (final c in json['contacts'] as List? ?? const [])
          if (c is Map<String, dynamic>) TrustedContact.fromJson(c),
      ],
      home: home is List && home.length == 2
          ? LatLng((home[0] as num).toDouble(), (home[1] as num).toDouble())
          : null,
      fallDetection: json['fallDetection'] as bool? ?? true,
      imgwAuto: json['imgwAuto'] as bool? ?? true,
      morning: json['morning'] as bool? ?? true,
      checkin: json['checkin'] as bool? ?? false,
      checkinHour: (json['checkinHour'] as num?)?.toInt() ?? 9,
      deadlineHour: (json['deadlineHour'] as num?)?.toInt() ?? 11,
    );
  }

  static const defaultWait = 7;
  static const seniorWait = 5;
  static const minWait = 3;
  static const maxWait = 15;
  static const maxContacts = 3;

  final bool enabled;

  /// Watch only when it is hot (IMGW heat warning or ≥ 28 °C).
  final bool heatOnly;

  /// Minutes standing still before «Wszystko w porządku?».
  final int waitMinutes;
  final List<TrustedContact> contacts;

  /// No checks within 80 m of home.
  final LatLng? home;

  /// A fall (free fall, impact, lying still) asks at once while it is hot.
  final bool fallDetection;

  /// The phone checks IMGW every 3 hours and notifies a new heat warning.
  final bool imgwAuto;

  /// «Dziś upał» at 7:00 with the best hours to go out.
  final bool morning;

  /// «Czuję się dobrze» every hot day at [checkinHour]; with no tap by
  /// [deadlineHour] the trusted contacts get an SMS.
  final bool checkin;
  final int checkinHour;
  final int deadlineHour;

  static const checkinHours = [7, 8, 9, 10, 11, 12];

  HeatGuardSettings copyWith({
    bool? enabled,
    bool? heatOnly,
    int? waitMinutes,
    List<TrustedContact>? contacts,
    LatLng? Function()? home,
    bool? fallDetection,
    bool? imgwAuto,
    bool? morning,
    bool? checkin,
    int? checkinHour,
    int? deadlineHour,
  }) => HeatGuardSettings(
    enabled: enabled ?? this.enabled,
    heatOnly: heatOnly ?? this.heatOnly,
    waitMinutes: waitMinutes ?? this.waitMinutes,
    contacts: contacts ?? this.contacts,
    home: home != null ? home() : this.home,
    fallDetection: fallDetection ?? this.fallDetection,
    imgwAuto: imgwAuto ?? this.imgwAuto,
    morning: morning ?? this.morning,
    checkin: checkin ?? this.checkin,
    checkinHour: checkinHour ?? this.checkinHour,
    deadlineHour: deadlineHour ?? this.deadlineHour,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'heatOnly': heatOnly,
    'waitMinutes': waitMinutes,
    'contacts': [for (final c in contacts) c.toJson()],
    if (home case final h?) 'home': [h.latitude, h.longitude],
    'fallDetection': fallDetection,
    'imgwAuto': imgwAuto,
    'morning': morning,
    'checkin': checkin,
    'checkinHour': checkinHour,
    'deadlineHour': deadlineHour,
  };

  @override
  bool operator ==(Object other) =>
      other is HeatGuardSettings &&
      other.enabled == enabled &&
      other.heatOnly == heatOnly &&
      other.waitMinutes == waitMinutes &&
      listEquals(other.contacts, contacts) &&
      other.home == home &&
      other.fallDetection == fallDetection &&
      other.imgwAuto == imgwAuto &&
      other.morning == morning &&
      other.checkin == checkin &&
      other.checkinHour == checkinHour &&
      other.deadlineHour == deadlineHour;

  @override
  int get hashCode => Object.hash(
    enabled,
    heatOnly,
    waitMinutes,
    Object.hashAll(contacts),
    home,
    fallDetection,
    imgwAuto,
    morning,
    checkin,
    checkinHour,
    deadlineHour,
  );
}

class HeatGuardSettingsNotifier extends Notifier<HeatGuardSettings> {
  static const prefsKey = 'heatGuard.settings';

  @override
  HeatGuardSettings build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    if (raw == null) return const HeatGuardSettings();
    try {
      return HeatGuardSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const HeatGuardSettings();
    }
  }

  Future<void> update(HeatGuardSettings settings) async {
    state = settings;
    await ref
        .read(sharedPreferencesProvider)
        .setString(prefsKey, jsonEncode(settings.toJson()));
  }
}

final heatGuardSettingsProvider =
    NotifierProvider<HeatGuardSettingsNotifier, HeatGuardSettings>(
      HeatGuardSettingsNotifier.new,
    );
