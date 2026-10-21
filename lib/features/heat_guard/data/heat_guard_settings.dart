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

  HeatGuardSettings copyWith({
    bool? enabled,
    bool? heatOnly,
    int? waitMinutes,
    List<TrustedContact>? contacts,
    LatLng? Function()? home,
  }) => HeatGuardSettings(
    enabled: enabled ?? this.enabled,
    heatOnly: heatOnly ?? this.heatOnly,
    waitMinutes: waitMinutes ?? this.waitMinutes,
    contacts: contacts ?? this.contacts,
    home: home != null ? home() : this.home,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'heatOnly': heatOnly,
    'waitMinutes': waitMinutes,
    'contacts': [for (final c in contacts) c.toJson()],
    if (home case final h?) 'home': [h.latitude, h.longitude],
  };

  @override
  bool operator ==(Object other) =>
      other is HeatGuardSettings &&
      other.enabled == enabled &&
      other.heatOnly == heatOnly &&
      other.waitMinutes == waitMinutes &&
      listEquals(other.contacts, contacts) &&
      other.home == home;

  @override
  int get hashCode => Object.hash(
    enabled,
    heatOnly,
    waitMinutes,
    Object.hashAll(contacts),
    home,
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
