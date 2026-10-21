import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/senior_mode.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/live/sun.dart';
import '../../../core/api/live/weather.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import 'quiet_layer.dart';

/// The S05 filters: fills (areas), points and street lines.
enum MapLayer {
  shade,
  green,
  quiet,
  air,
  water,
  cool,
  benches,
  toilets,
  night,
  winter;

  /// Fill layers cover areas; at most [MapLayers.maxFills] at once.
  bool get isFill => index <= MapLayer.air.index;

  /// Street line modes («Nocą», «Zima»): one at a time.
  bool get isLine => this == night || this == winter;
}

/// Active S05 filters. Turning on a third fill switches off the one that
/// was on the longest, so at most 2 fills plus any points are shown; a
/// street mode replaces the other one.
class MapLayers extends Notifier<List<MapLayer>> {
  static const maxFills = 2;

  /// Demo scenario step 2: shade and cool places on the map.
  static const initial = [MapLayer.shade, MapLayer.cool];

  /// Seniors also see benches from the start.
  static const initialSenior = [
    MapLayer.shade,
    MapLayer.cool,
    MapLayer.benches,
  ];

  @override
  List<MapLayer> build() =>
      ref.read(seniorModeProvider) ? initialSenior : initial;

  /// Returns the layer that was switched off to make room, if any.
  MapLayer? toggle(MapLayer layer) {
    if (state.contains(layer)) {
      state = [...state]..remove(layer);
      return null;
    }
    var next = [...state, layer];
    MapLayer? dropped;
    if (layer.isFill) {
      final fills = next.where((l) => l.isFill).toList();
      if (fills.length > maxFills) {
        dropped = fills.first;
        next = [...next]..remove(dropped);
      }
    } else if (layer.isLine) {
      for (final other in next.where((l) => l.isLine && l != layer).toList()) {
        dropped = other;
        next.remove(other);
      }
    }
    state = next;
    return dropped;
  }

  /// Heat mode: cool places must be visible.
  void ensure(MapLayer layer) {
    if (!state.contains(layer)) state = [...state, layer];
  }
}

final mapLayersProvider = NotifierProvider<MapLayers, List<MapLayer>>(
  MapLayers.new,
);

/// When the shade layer is drawn for («Cień o 14:30»), local time. Any
/// day and minute with the on-phone API; the bundled layer (demo mode,
/// fallback) is for 14:30 only.
class ShadeTime extends Notifier<DateTime> {
  static const demoHour = 14;
  static const demoMinute = 30;

  /// Today at 14:30 (the bundled layer's time).
  static DateTime demoTime(DateTime now) =>
      DateTime(now.year, now.month, now.day, demoHour, demoMinute);

  /// [now] rounded down to the wheel's 5-minute step.
  static DateTime roundDown(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute - now.minute % 5,
  );

  @override
  DateTime build() => ref.watch(staticShadeLayerProvider)
      ? demoTime(DateTime.now())
      : roundDown(DateTime.now());

  void set(DateTime time) => state = time;
}

final shadeTimeProvider = NotifierProvider<ShadeTime, DateTime>(ShadeTime.new);

/// A map layer from module D (static demo GeoJSON until DEP-04, #33).
final layerProvider = FutureProvider.family<GeoLayer, LayerKind>((ref, kind) {
  final api = ref.watch(apiClientProvider);
  final datetime = kind == LayerKind.shade
      ? ref.watch(shadeTimeProvider)
      : DateTime.now();
  return api.getLayer(kind, datetime: datetime);
}, retry: noRetry);

/// Shadows of buildings and trees at the chosen slot inside a map area
/// (on-phone API; the bbox keeps the polygon count small).
final shadeAreaProvider = FutureProvider.family<GeoLayer, GeoBounds>((
  ref,
  bbox,
) {
  final api = ref.watch(apiClientProvider);
  final datetime = ref.watch(shadeTimeProvider);
  return api.getLayer(LayerKind.shade, bbox: bbox, datetime: datetime);
}, retry: noRetry);

/// The visible map area grown by half a screen on each side and snapped to
/// a 0.004° grid, so small pans reuse the same shadows.
GeoBounds shadeArea({
  required double south,
  required double west,
  required double north,
  required double east,
}) {
  const step = 0.004;
  final dLat = (north - south) / 2;
  final dLon = (east - west) / 2;
  double down(double v) => (v / step).floorToDouble() * step;
  double up(double v) => (v / step).ceilToDouble() * step;
  return GeoBounds(
    minLat: down(south - dLat),
    minLon: down(west - dLon),
    maxLat: up(north + dLat),
    maxLon: up(east + dLon),
  );
}

/// Weather for the shade pill at the chosen slot (on-phone API only).
class ShadeWeather {
  const ShadeWeather({
    required this.strength,
    this.temperature,
    this.night = false,
    this.hour,
  });

  /// Direct sunlight 0..1 (`sunStrength`).
  final double strength;
  final double? temperature;

  /// The sun is below the horizon.
  final bool night;

  /// The forecast hour (sky icon, wind); null without a forecast.
  final WeatherHour? hour;
}

final shadeWeatherProvider = FutureProvider<ShadeWeather?>((ref) async {
  if (ref.watch(staticShadeLayerProvider)) return null;
  final time = ref.watch(shadeTimeProvider);
  final forecast = await ref.watch(forecastProvider.future);
  final night = sunPosition(51.77, 19.46, time).elevation <= 0;
  if (forecast == null && !night) return null;
  final hour = forecast?.at(time);
  return ShadeWeather(
    strength: sunStrength(forecast, time),
    temperature: hour?.temperature,
    night: night,
    hour: hour,
  );
}, retry: noRetry);

/// «Cisza»: where it is quiet (away from the noise bands, parks quietest).
final quietLayerProvider = FutureProvider<GeoLayer>((ref) async {
  final noise = await ref.watch(layerProvider(LayerKind.noise).future);
  GeoLayer? green;
  try {
    green = await ref.watch(layerProvider(LayerKind.green).future);
  } catch (_) {
    // Without parks every quiet cell is just «quiet».
  }
  // The loud bands too (red), so the map reads like a traffic light.
  return GeoLayer(
    features: [
      for (final f in noise.features)
        GeoFeature(geometry: f.geometry, properties: const {'quiet': 0}),
      ...quietAreas(noise, green: green).features,
    ],
  );
}, retry: noRetry);

/// GIOŚ stations for the Powietrze layer.
final airStationsProvider = FutureProvider<List<AirStation>>(
  (ref) => ref.watch(apiClientProvider).getAir(),
  retry: noRetry,
);

/// The user's position for S05, or why it is missing. Refresh with
/// `ref.invalidate(userLocationProvider)`.
@immutable
class UserLocation {
  const UserLocation.known(LatLng this.position) : problem = null;
  const UserLocation.unknown(LocationProblem this.problem) : position = null;

  final LatLng? position;
  final LocationProblem? problem;
}

final userLocationProvider = FutureProvider<UserLocation>((ref) async {
  final service = ref.watch(locationServiceProvider);
  // Only read here, never ask: S03 asked already, and S05 has a button.
  final problem = await service.check();
  if (problem != null) return UserLocation.unknown(problem);
  try {
    return UserLocation.known(await service.current());
  } on LocationUnavailable catch (e) {
    return UserLocation.unknown(e.problem);
  }
}, retry: noRetry);
