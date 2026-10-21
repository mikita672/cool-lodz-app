import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/live/sun.dart';
import '../../../core/api/live/weather.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import 'quiet_layer.dart';

/// The six S05 filters. The first four are fills, the last two are points.
enum MapLayer {
  shade,
  green,
  quiet,
  air,
  water,
  cool;

  /// Fill layers cover areas; at most [MapLayers.maxFills] at once.
  bool get isFill => index <= MapLayer.air.index;
}

/// Active S05 filters. Turning on a third fill switches off the one that
/// was on the longest, so at most 2 fills plus any points are shown.
class MapLayers extends Notifier<List<MapLayer>> {
  static const maxFills = 2;

  /// Demo scenario step 2: shade and cool places on the map.
  static const initial = [MapLayer.shade, MapLayer.cool];

  @override
  List<MapLayer> build() => initial;

  /// Returns the fill that was switched off to make room, if any.
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

/// "HH:mm" of the shade layer («Cień o 14:30»): 30-minute slots 8:00–20:00.
/// The demo has one shade file, for 14:30, so demo mode offers only that.
class ShadeTime extends Notifier<String> {
  static const demoSlot = '14:30';

  static List<String> slots({required bool demo}) => demo
      ? const [demoSlot]
      : [
          for (var m = 8 * 60; m <= 20 * 60; m += 30)
            '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}',
        ];

  /// The slot at or just before [now], kept inside 8:00–20:00.
  static String slotFor(DateTime now) {
    final minute = (now.hour * 60 + now.minute).clamp(8 * 60, 20 * 60);
    final slot = minute - minute % 30;
    return '${slot ~/ 60}:${(slot % 60).toString().padLeft(2, '0')}';
  }

  @override
  String build() =>
      // The bundled shade layer (demo mode, fallback) is for 14:30 only.
      ref.watch(staticShadeLayerProvider) ? demoSlot : slotFor(DateTime.now());

  void set(String slot) => state = slot;
}

final shadeTimeProvider = NotifierProvider<ShadeTime, String>(ShadeTime.new);

/// Today at the shade slot, as the `datetime` of `/v1/layers/shade`.
DateTime shadeDateTime(String slot, DateTime now) {
  final parts = slot.split(':');
  return DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

/// A map layer from module D (static demo GeoJSON until DEP-04, #33).
final layerProvider = FutureProvider.family<GeoLayer, LayerKind>((ref, kind) {
  final api = ref.watch(apiClientProvider);
  final datetime = kind == LayerKind.shade
      ? shadeDateTime(ref.watch(shadeTimeProvider), DateTime.now())
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
  final datetime = shadeDateTime(ref.watch(shadeTimeProvider), DateTime.now());
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
  });

  /// Direct sunlight 0..1 (`sunStrength`).
  final double strength;
  final double? temperature;

  /// The sun is below the horizon.
  final bool night;
}

final shadeWeatherProvider = FutureProvider<ShadeWeather?>((ref) async {
  if (ref.watch(staticShadeLayerProvider) ||
      ref.watch(apiBaseUrlProvider).isNotEmpty) {
    return null;
  }
  final time = shadeDateTime(ref.watch(shadeTimeProvider), DateTime.now());
  final forecast = await ref.watch(weatherClientProvider).forecastOrNull();
  final night = sunPosition(51.77, 19.46, time).elevation <= 0;
  if (forecast == null && !night) return null;
  return ShadeWeather(
    strength: sunStrength(forecast, time),
    temperature: forecast?.at(time)?.temperature,
    night: night,
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
  return quietAreas(noise, green: green);
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
