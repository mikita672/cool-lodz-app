import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_providers.dart';

/// A street of Śródmieście with what the «Nocą» and «Zima» modes show.
@immutable
class StreetLine {
  const StreetLine(this.points, {required this.night, required this.winter});

  final List<LatLng> points;

  /// 0 no data, 1 lit, 2 lively at night, 3 busiest.
  final int night;

  /// Snow clearing order (estimate): 1 first, 2 then, 3 last.
  final int winter;
}

enum VenueKind { nightlife, food, culture }

@immutable
class Venue {
  const Venue(this.point, this.kind);

  final LatLng point;
  final VenueKind kind;
}

/// 0 free, 1 paid, 2 unknown.
@immutable
class PublicToilet {
  const PublicToilet(this.point, this.fee);

  final LatLng point;
  final int fee;

  bool get free => fee == 0;
}

/// `assets/demo/street_modes.json` (built from OpenStreetMap by
/// `tools/demo-data/build_modes.py`).
@immutable
class StreetModes {
  const StreetModes({
    this.streets = const [],
    this.venues = const [],
    this.toilets = const [],
  });

  factory StreetModes.fromJson(Map<String, dynamic> json) {
    final origin = (json['origin'] as List).cast<num>();
    final scale = (json['scale'] as num).toDouble();
    LatLng at(num x, num y) => LatLng(
      origin[1].toDouble() + y / scale,
      origin[0].toDouble() + x / scale,
    );
    final streets = <StreetLine>[];
    for (final raw in json['streets'] as List? ?? const []) {
      final v = (raw as List).cast<num>();
      if (v.length < 6) continue;
      var x = v[2];
      var y = v[3];
      final pts = [at(x, y)];
      for (var i = 4; i + 1 < v.length; i += 2) {
        x += v[i];
        y += v[i + 1];
        pts.add(at(x, y));
      }
      streets.add(StreetLine(pts, night: v[0].toInt(), winter: v[1].toInt()));
    }
    return StreetModes(
      streets: streets,
      venues: [
        for (final raw in json['venues'] as List? ?? const [])
          if ((raw as List).cast<num>() case final v when v.length >= 3)
            Venue(at(v[0], v[1]), VenueKind.values[v[2].toInt().clamp(0, 2)]),
      ],
      toilets: [
        for (final raw in json['toilets'] as List? ?? const [])
          if ((raw as List).cast<num>() case final v when v.length >= 3)
            PublicToilet(at(v[0], v[1]), v[2].toInt()),
      ],
    );
  }

  final List<StreetLine> streets;
  final List<Venue> venues;
  final List<PublicToilet> toilets;
}

final streetModesProvider = FutureProvider<StreetModes>((ref) async {
  final raw = await ref.watch(assetLoaderProvider)(
    'assets/demo/street_modes.json',
  );
  return StreetModes.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}, retry: noRetry);

/// A tree crown: where and how wide (metres).
@immutable
class TreeCrown {
  const TreeCrown(this.point, this.radius);

  final LatLng point;
  final double radius;
}

/// The trees whose shadows the shade layer draws
/// (`assets/demo/shadow_casters.json`).
final treesProvider = FutureProvider<List<TreeCrown>>((ref) async {
  final raw = await ref.watch(assetLoaderProvider)(
    'assets/demo/shadow_casters.json',
  );
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final origin = (json['origin'] as List).cast<num>();
  final scale = (json['metresPerDegree'] as List).cast<num>();
  const dm = 0.1;
  return [
    for (final t in json['trees'] as List? ?? const [])
      if ((t as List).cast<num>() case final v when v.length >= 2)
        TreeCrown(
          LatLng(
            origin[1] + v[1] * dm / scale[1],
            origin[0] + v[0] * dm / scale[0],
          ),
          v.length > 3 ? v[3].toDouble() : 3,
        ),
  ];
}, retry: noRetry);
