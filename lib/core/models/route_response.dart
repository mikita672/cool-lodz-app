import 'dart:collection';

import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

import '../warsaw_time.dart';
import 'date_time_converter.dart';
import 'geo.dart';

part 'route_response.g.dart';

/// `full`, or `approximate` → «Dla tego obszaru cień jest przybliżony».
enum RouteCoverage { full, approximate }

/// The three named variants, then any further distinct walks
/// (`alternative`, on-phone API only).
enum RouteVariantType { shortest, shaded, compromise, alternative }

enum StopType { cool, water }

/// The weather the sun shares were computed for (optional in the contract).
@JsonSerializable()
class RouteWeather {
  const RouteWeather({
    required this.sunStrength,
    this.temperature,
    this.cloudCover,
  });

  factory RouteWeather.fromJson(Map<String, dynamic> json) =>
      _$RouteWeatherFromJson(json);

  /// How strong direct sunlight is at the departure, 0 (night, overcast)
  /// to 1 (clear sky).
  final double sunStrength;

  /// °C.
  final double? temperature;

  /// 0..100 %.
  final double? cloudCover;

  /// Little sun: the shaded walks barely differ from the others.
  bool get littleSun => sunStrength < 0.3;

  Map<String, dynamic> toJson() => _$RouteWeatherToJson(this);
}

/// Response of `POST /v1/routes`: 1–5 variants (see api-contract.md).
@JsonSerializable()
class RouteResponse {
  const RouteResponse({
    required this.coverage,
    required this.variants,
    this.weather,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) =>
      _$RouteResponseFromJson(json);

  final RouteCoverage coverage;
  final List<RouteVariant> variants;

  /// Weather at the departure, when the routes took it into account
  /// (on-phone API); null otherwise.
  final RouteWeather? weather;

  bool get isApproximate => coverage == RouteCoverage.approximate;

  RouteVariant? variant(RouteVariantType type) {
    for (final v in variants) {
      if (v.variant == type) return v;
    }
    return null;
  }

  RouteVariant? get shortest => variant(RouteVariantType.shortest);

  Map<String, dynamic> toJson() => _$RouteResponseToJson(this);
}

/// Index range `[from, to]` (inclusive) into the geometry with its sun share.
@JsonSerializable()
class RouteSegment {
  const RouteSegment({
    required this.from,
    required this.to,
    required this.sunShare,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) =>
      _$RouteSegmentFromJson(json);

  final int from;
  final int to;
  final double sunShare;

  double get shadeShare => 1 - sunShare;

  Map<String, dynamic> toJson() => _$RouteSegmentToJson(this);
}

@JsonSerializable()
class RouteStop {
  const RouteStop({required this.placeId, required this.type});

  factory RouteStop.fromJson(Map<String, dynamic> json) =>
      _$RouteStopFromJson(json);

  final String placeId;
  final StopType type;

  Map<String, dynamic> toJson() => _$RouteStopToJson(this);
}

@JsonSerializable()
class RouteVariant {
  RouteVariant({
    required this.variant,
    required this.geometry,
    this.segments = const [],
    required this.distanceM,
    required this.durationS,
    required this.sunShare,
    required this.extraTimeVsShortestS,
    this.stops = const [],
    Map<String, double> sunShareByHour = const {},
  }) : sunShareByHour = sortedByTime(sunShareByHour);

  factory RouteVariant.fromJson(Map<String, dynamic> json) =>
      _$RouteVariantFromJson(json);

  final RouteVariantType variant;

  @LineStringConverter()
  final List<LatLng> geometry;

  /// Optional until DEP-03 is agreed; empty when module D omits it.
  final List<RouteSegment> segments;

  @JsonKey(name: 'distance_m')
  final int distanceM;

  @JsonKey(name: 'duration_s')
  final int durationS;

  /// Share of the walk in the sun at the requested departure, 0..1.
  final double sunShare;

  @JsonKey(name: 'extraTimeVsShortest_s')
  final int extraTimeVsShortestS;

  final List<RouteStop> stops;

  /// `"HH:mm"` → sun share, ordered by time (08:00..20:00 every 30 min).
  /// Optional until DEP-03 is agreed; empty when module D omits it.
  final Map<String, double> sunShareByHour;

  double get shadeShare => 1 - sunShare;

  Duration get duration => Duration(seconds: durationS);

  Duration get extraTimeVsShortest => Duration(seconds: extraTimeVsShortestS);

  /// Sun share for the `sunShareByHour` slot closest to [time] (slots are
  /// Warsaw wall clock); falls back to [sunShare] when there are no slots.
  double sunShareAt(DateTime time) {
    final key = nearestTimeKey(sunShareByHour.keys, warsawMinuteOfDay(time));
    return key == null ? sunShare : sunShareByHour[key]!;
  }

  /// Slot with the most shade, e.g. `"18:00"`; null without slots.
  String? get bestDepartureSlot {
    String? best;
    for (final entry in sunShareByHour.entries) {
      if (best == null || entry.value < sunShareByHour[best]!) {
        best = entry.key;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => _$RouteVariantToJson(this);
}

/// Copy of [map] with keys sorted by time of day (`"HH:mm"` sorts as text).
Map<String, double> sortedByTime(Map<String, double> map) {
  final keys = map.keys.toList()..sort();
  return UnmodifiableMapView(
    LinkedHashMap.fromIterables(keys, [for (final k in keys) map[k]!]),
  );
}

/// The `"HH:mm"` key closest to [minute] (minutes since midnight); the earlier
/// one wins a tie. Null when [keys] is empty.
String? nearestTimeKey(Iterable<String> keys, int minute) {
  String? best;
  var bestDiff = 1 << 30;
  final sorted = keys.toList()..sort();
  for (final key in sorted) {
    final diff = (parseHhMm(key) - minute).abs();
    if (diff < bestDiff) {
      best = key;
      bestDiff = diff;
    }
  }
  return best;
}
