import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';
import 'map_providers.dart';

/// Names, icons and colours of the S05 layers.
String layerName(MapLayer layer, AppLocalizations l10n) => switch (layer) {
  MapLayer.shade => l10n.mapLayerShade,
  MapLayer.green => l10n.mapLayerGreen,
  MapLayer.quiet => l10n.mapLayerQuiet,
  MapLayer.air => l10n.mapLayerAir,
  MapLayer.water => l10n.mapLayerWater,
  MapLayer.cool => l10n.mapLayerCool,
};

IconData layerIcon(MapLayer layer) => switch (layer) {
  MapLayer.shade => Icons.wb_shade_rounded,
  MapLayer.green => Icons.park_rounded,
  MapLayer.quiet => Icons.volume_off_rounded,
  MapLayer.air => Icons.air_rounded,
  MapLayer.water => Icons.water_drop_rounded,
  MapLayer.cool => Icons.ac_unit_rounded,
};

/// Polygons of [layer] styled for [kind]: shade `primary` (35 % at full
/// shade), green 30 %, quiet a purple heat map by dB.
List<Polygon> polygonsFor(GeoLayer? layer, MapLayer kind) {
  if (layer == null) return const [];
  return [
    for (final f in layer.features)
      for (final p in f.geometry.polygons)
        Polygon(
          points: p.outer,
          holePointsList: p.holes.isEmpty ? null : p.holes,
          color: switch (kind) {
            MapLayer.shade => AppColors.primary.withValues(
              alpha: 0.35 * (f.shade ?? 1).clamp(0.2, 1),
            ),
            MapLayer.green => AppColors.greenLayer,
            MapLayer.quiet => noiseColor(f.db ?? 55),
            _ => AppColors.shadeLayer,
          },
        ),
  ];
}

/// Noise as a purple heat map: darker = louder (45 dB light, 75 dB dark).
Color noiseColor(double db) {
  final t = ((db - 45) / 30).clamp(0.0, 1.0);
  return AppColors.quiet.withValues(alpha: 0.12 + 0.45 * t);
}

/// Official GIOŚ air quality index colours (powietrze.gios.gov.pl).
const airIndexColors = [
  Color(0xFF57B108), // 0 bardzo dobry
  Color(0xFFB0DD10), // 1 dobry
  Color(0xFFFFD911), // 2 umiarkowany
  Color(0xFFE58100), // 3 dostateczny
  Color(0xFFE50000), // 4 zły
  Color(0xFF990000), // 5 bardzo zły
];

Color airColor(int? index) => index == null
    ? AppColors.muted
    : airIndexColors[index.clamp(0, airIndexColors.length - 1)];

String airLevelName(int? index, AppLocalizations l10n) => switch (index) {
  0 => l10n.mapAirVeryGood,
  1 => l10n.mapAirGood,
  2 => l10n.mapAirModerate,
  3 => l10n.mapAirSufficient,
  4 => l10n.mapAirBad,
  5 => l10n.mapAirVeryBad,
  _ => l10n.mapAirNoData,
};

/// One GIOŚ station as a 600 m circle in its index colour.
CircleMarker airCircle(AirStation station) => CircleMarker(
  point: station.latLng,
  radius: 600,
  useRadiusInMeter: true,
  color: airColor(station.indexLevel).withValues(alpha: 0.3),
  borderColor: airColor(station.indexLevel),
  borderStrokeWidth: 2,
);
