import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'game_rules.dart';

/// «Twój wpływ»: what the walks started with «Prowadź» added up to.
@immutable
class Impact {
  const Impact({
    this.walks = 0,
    this.distanceKm = 0,
    this.minutesInShade = 0,
    this.sunAvoidedMinutes,
    this.waterPoints = 0,
    this.coolPlaces = 0,
  });

  /// From the user's routes and quest scans.
  factory Impact.from(GameHistory history) {
    var meters = 0;
    var shade = 0.0;
    double? avoided;
    var water = 0;
    for (final r in history.routes) {
      meters += r.distanceM;
      final minutes = r.duration.inSeconds / 60;
      shade += minutes * r.shadeShare;
      final shortest = r.shortestSunShare;
      if (shortest != null) {
        avoided = (avoided ?? 0) + minutes * math.max(0, shortest - r.sunShare);
      }
      water += r.waterStops;
    }
    return Impact(
      walks: history.routes.length,
      distanceKm: meters / 1000,
      minutesInShade: shade.round(),
      sunAvoidedMinutes: avoided?.round(),
      waterPoints: water,
      coolPlaces: history.scannedPlaces.length,
    );
  }

  /// kg CO₂ per km of an average car (UK DEFRA conversion factors).
  static const carCo2KgPerKm = 0.17;

  final int walks;
  final double distanceKm;
  final int minutesInShade;

  /// Compared with the shortest variant at the same time; null when no
  /// route stored it.
  final int? sunAvoidedMinutes;

  /// Drinking water points along the walks.
  final int waterPoints;

  /// Distinct quest places scanned.
  final int coolPlaces;

  /// CO₂ a car would have emitted for the same distance.
  double get co2SavedKg => distanceKm * carCo2KgPerKm;
}
