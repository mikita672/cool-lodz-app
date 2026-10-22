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

/// A rough surface: 1 paving stones, 2 sett (granite blocks), 3 cobbles
/// («kocie łby»), 4 unpaved.
@immutable
class SurfaceLine {
  const SurfaceLine(this.points, this.surface);

  final List<LatLng> points;
  final int surface;
}

/// A flight of steps; [ramp] when a ramp for prams or wheelchairs is mapped.
@immutable
class Steps {
  const Steps(this.point, {required this.ramp});

  final LatLng point;
  final bool ramp;
}

/// A fountain or a splash pad (kids can play in the water).
@immutable
class Fountain {
  const Fountain(this.point, {required this.splash});

  final LatLng point;
  final bool splash;
}

/// One cell of the heat island estimate: [southWest] corner, [level] 0
/// cool island … 3 hot.
@immutable
class HeatCell {
  const HeatCell(this.southWest, this.northEast, this.level);

  final LatLng southWest;
  final LatLng northEast;
  final int level;
}

/// `assets/demo/street_modes.json` (built from OpenStreetMap by
/// `tools/demo-data/build_modes.py`).
@immutable
class StreetModes {
  const StreetModes({
    this.streets = const [],
    this.venues = const [],
    this.toilets = const [],
    this.surfaces = const [],
    this.steps = const [],
    this.fountains = const [],
    this.heat = const [],
  });

  factory StreetModes.fromJson(Map<String, dynamic> json) {
    final origin = (json['origin'] as List).cast<num>();
    final scale = (json['scale'] as num).toDouble();
    LatLng at(num x, num y) => LatLng(
      origin[1].toDouble() + y / scale,
      origin[0].toDouble() + x / scale,
    );
    List<LatLng> line(List<num> v, int start) {
      var x = v[start];
      var y = v[start + 1];
      final pts = [at(x, y)];
      for (var i = start + 2; i + 1 < v.length; i += 2) {
        x += v[i];
        y += v[i + 1];
        pts.add(at(x, y));
      }
      return pts;
    }

    final heat = <HeatCell>[];
    if (json['heat'] case {'cell': final num cell, 'cells': final List cells}) {
      // Metres to degrees at Łódź.
      final dLat = cell / 111195.0;
      final dLon = cell / (111195.0 * 0.6189);
      for (final raw in cells) {
        final v = (raw as List).cast<num>();
        if (v.length < 3) continue;
        final sw = at(v[0], v[1]);
        heat.add(
          HeatCell(
            sw,
            LatLng(sw.latitude + dLat, sw.longitude + dLon),
            v[2].toInt(),
          ),
        );
      }
    }
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
      surfaces: [
        for (final raw in json['surfaces'] as List? ?? const [])
          if ((raw as List).cast<num>() case final v when v.length >= 5)
            SurfaceLine(line(v, 1), v[0].toInt()),
      ],
      steps: [
        for (final raw in json['steps'] as List? ?? const [])
          if ((raw as List).cast<num>() case final v when v.length >= 3)
            Steps(at(v[0], v[1]), ramp: v[2] == 1),
      ],
      fountains: [
        for (final raw in json['fountains'] as List? ?? const [])
          if ((raw as List).cast<num>() case final v when v.length >= 3)
            Fountain(at(v[0], v[1]), splash: v[2] == 1),
      ],
      heat: heat,
    );
  }

  final List<StreetLine> streets;
  final List<Venue> venues;
  final List<PublicToilet> toilets;
  final List<SurfaceLine> surfaces;
  final List<Steps> steps;
  final List<Fountain> fountains;
  final List<HeatCell> heat;
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
