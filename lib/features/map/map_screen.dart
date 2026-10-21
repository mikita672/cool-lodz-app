import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/api/live/weather.dart';
import '../../core/game/game_config.dart';
import '../../core/location/location_service.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/map/base_map.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/heat_banner.dart';
import '../../shared/widgets/layer_filter_chip.dart';
import '../../shared/widgets/map_pin.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/time_wheel_sheet.dart';
import '../../shared/widgets/weather_icon.dart';
import '../cool_places/data/places_providers.dart';
import '../cool_places/place_format.dart';
import '../cool_places/place_sheet.dart';
import '../game/data/game_config_repository.dart';
import '../heat_risk/data/heat_risk_providers.dart';
import '../heat_risk/heat_risk_sheet.dart';
import 'data/map_layers_style.dart';
import 'data/map_providers.dart';

/// S05 Mapa (main screen): search, six filters, layers, points, the heat
/// banner and the user's position.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  /// Benches only from this zoom (spec: "benches only at zoom ≥ 17").
  static const benchMinZoom = 17.0;
  static const startZoom = 14.0;

  /// Building and tree shadows are drawn from this zoom on.
  static const shadowMinZoom = 15.0;
  static const userZoom = 15.0;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  double _zoom = MapScreen.startZoom;

  /// Map bearing in degrees (0 = north up), for the compass button.
  final _rotation = ValueNotifier<double>(0);
  late final StreamSubscription<MapEvent> _mapEvents;
  bool _ready = false;
  bool _centeredOnUser = false;
  LatLng? _pendingCenter;
  late final AppLifecycleListener _lifecycle;

  /// The last fill layer and what it was built from. A new PolygonLayer
  /// widget makes flutter_map re-project every polygon (~1 800 here), so
  /// it is rebuilt only when the active fills or their data change.
  List<Object?>? _fillsKey;
  Widget? _fillsLayer;

  @override
  void initState() {
    super.initState();
    // Back from the system settings (location turned on), or after a walk:
    // read the position again.
    // Every camera change (gesture or code) updates the compass.
    _mapEvents = _map.mapEventStream.listen(
      (event) => _rotation.value = event.camera.rotation,
    );
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(userLocationProvider);
        // Later in the day: the rest of today's heat risk.
        ref.invalidate(heatRiskProvider);
      },
    );
    // Heat mode: cool places first (spec S14), also when it is on at start.
    ref.listenManual(heatLevelProvider, (_, level) {
      if (level >= GameConfig.heatModeLevel) {
        ref.read(mapLayersProvider.notifier).ensure(MapLayer.cool);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _mapEvents.cancel();
    _shadeAreaTimer?.cancel();
    _rotation.dispose();
    _map.dispose();
    super.dispose();
  }

  /// The map area the shadows are drawn for; null when zoomed out.
  GeoBounds? _shadeArea;
  Timer? _shadeAreaTimer;

  /// The last shadows shown, kept while the next area loads.
  GeoLayer? _lastShade;

  void _updateShadeArea(MapCamera camera) {
    final b = camera.visibleBounds;
    final next = camera.zoom >= MapScreen.shadowMinZoom
        ? shadeArea(south: b.south, west: b.west, north: b.north, east: b.east)
        : null;
    if (next != _shadeArea && mounted) setState(() => _shadeArea = next);
  }

  void _onMapReady() {
    _ready = true;
    _updateShadeArea(_map.camera);
    final pending = _pendingCenter;
    if (pending != null) {
      _pendingCenter = null;
      _centeredOnUser = true;
      _map.move(pending, MapScreen.userZoom);
    }
  }

  /// The shade layer to draw: the bundled 14:30 file (demo, fallback), or
  /// the shadows of the visible area at the chosen time.
  GeoLayer? _shade(GeoLayer? Function(LayerKind) layer) {
    if (ref.watch(staticShadeLayerProvider)) return layer(LayerKind.shade);
    final area = _shadeArea;
    if (area == null) return null;
    final next = ref.watch(shadeAreaProvider(area)).value;
    if (next != null) _lastShade = next;
    return _lastShade;
  }

  Widget? _fills(List<MapLayer> layers, Map<MapLayer, GeoLayer?> data) {
    final key = [
      for (final l in [MapLayer.green, MapLayer.quiet, MapLayer.shade])
        if (layers.contains(l)) ...[l, data[l]],
    ];
    final same =
        _fillsKey != null &&
        _fillsKey!.length == key.length &&
        [
          for (var i = 0; i < key.length; i++) identical(_fillsKey![i], key[i]),
        ].every((x) => x);
    if (same) return _fillsLayer;
    final polygons = <Polygon>[
      for (final l in [MapLayer.green, MapLayer.quiet, MapLayer.shade])
        if (layers.contains(l)) ...polygonsFor(data[l], l),
    ];
    _fillsKey = key;
    _fillsLayer = polygons.isEmpty ? null : PolygonLayer(polygons: polygons);
    return _fillsLayer;
  }

  void _toggle(MapLayer layer) {
    final dropped = ref.read(mapLayersProvider.notifier).toggle(layer);
    if (dropped != null) {
      final l10n = AppLocalizations.of(context);
      showAppToast(context, l10n.mapFillLimit(layerName(dropped, l10n)));
    }
  }

  void _moveTo(LatLng point, double zoom) {
    if (_ready) _map.move(point, zoom);
  }

  Future<void> _myLocation() async {
    final current = ref.read(userLocationProvider).value;
    if (current?.position == null) {
      await ref.read(locationServiceProvider).enable();
    }
    // A fresh fix: the user may have walked since the last one.
    ref.invalidate(userLocationProvider);
    final fresh = await ref.read(userLocationProvider.future);
    if (fresh.position case final p? when mounted) {
      _moveTo(p, MapScreen.userZoom);
    }
  }

  Future<void> _pickShadeTime() async {
    final l10n = AppLocalizations.of(context);
    if (ref.read(staticShadeLayerProvider)) {
      await _showDemoShadeTime(l10n);
      return;
    }
    final forecast = await _forecast();
    if (!mounted) return;
    final picked = await showTimeWheelSheet(
      context,
      title: l10n.mapShadeTimeTitle,
      initial: ref.read(shadeTimeProvider),
      now: DateTime.now(),
      forecast: forecast,
    );
    if (picked != null) ref.read(shadeTimeProvider.notifier).set(picked);
  }

  Future<WeatherForecast?> _forecast() async {
    try {
      return await ref
          .read(forecastProvider.future)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return null; // the picker works without weather
    }
  }

  /// The bundled layer is for 14:30 only: say so instead of a picker.
  Future<void> _showDemoShadeTime(AppLocalizations l10n) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              0,
              AppSizes.screenPadding,
              AppSizes.screenPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.mapShadeTimeTitle, style: AppTextStyles.titleM),
                const SizedBox(height: AppSizes.s8),
                Text(l10n.mapShadeDemoNote, style: AppTextStyles.bodyS),
                const SizedBox(height: AppSizes.s16),
                ChoiceChip(
                  label: const Text('14:30'),
                  selected: true,
                  onSelected: (_) => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layers = ref.watch(mapLayersProvider);
    final senior = ref.watch(seniorModeProvider);
    final alert = ref.watch(currentAlertProvider);
    final heatMode = ref.watch(heatLevelProvider) >= GameConfig.heatModeLevel;
    final offline = ref.watch(dataSourceProvider) == DataSource.fallback;
    final location = ref.watch(userLocationProvider).value;
    final userPosition = location?.position;
    final showRisk = ref.watch(heatRiskProvider).value != null;

    // Center on the user once the first position arrives (after the map
    // is ready, or as soon as it is).
    ref.listen(userLocationProvider, (_, next) {
      final p = next.value?.position;
      if (p == null || _centeredOnUser) return;
      if (_ready) {
        _centeredOnUser = true;
        _map.move(p, MapScreen.userZoom);
      } else {
        _pendingCenter = p;
      }
    });

    List<Place> places(PlaceType type) =>
        ref.watch(placesOfTypeProvider(type)).value ?? const [];
    GeoLayer? layer(LayerKind kind) => ref.watch(layerProvider(kind)).value;

    final fills = _fills(layers, {
      MapLayer.green: layers.contains(MapLayer.green)
          ? layer(LayerKind.green)
          : null,
      MapLayer.quiet: layers.contains(MapLayer.quiet)
          ? ref.watch(quietLayerProvider).value
          : null,
      MapLayer.shade: layers.contains(MapLayer.shade) ? _shade(layer) : null,
    });
    final air = layers.contains(MapLayer.air)
        ? ref.watch(airStationsProvider).value ?? const <AirStation>[]
        : const <AirStation>[];

    Marker pin(Place place, MapPinType type, {double size = 32}) => Marker(
      key: ValueKey('pin-${place.id}'),
      point: place.latLng,
      // Senior pins carry a label under the circle (text ×1.25).
      width: senior ? 96 : 48,
      height: senior ? size + 56 : (size + 16).clamp(48, 64),
      child: MapPin(
        type: type,
        size: size,
        semanticLabel: place.title(l10n),
        onTap: () => showPlaceSheet(context, place),
      ),
    );

    final markers = <Marker>[
      if (_zoom >= MapScreen.benchMinZoom)
        for (final p in places(PlaceType.bench)) pin(p, MapPinType.bench),
      if (layers.contains(MapLayer.water))
        for (final p in places(PlaceType.water)) pin(p, MapPinType.water),
      // Drawn last: on top. Bigger in heat mode.
      if (layers.contains(MapLayer.cool))
        for (final p in places(PlaceType.cool))
          pin(p, MapPinType.cool, size: heatMode ? 40 : 32),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Semantics(
            label: l10n.mapSemantics(
              layers.map((l) => layerName(l, l10n)).join(', '),
            ),
            child: BaseMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: userPosition ?? lodzCenter,
                initialZoom: userPosition == null
                    ? MapScreen.startZoom
                    : MapScreen.userZoom,
                minZoom: MapTiles.minZoom,
                maxZoom: MapTiles.maxZoom,
                // Two-finger rotation like Google Maps; the compass button
                // turns the map back to north.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: _onMapReady,
                onPositionChanged: (camera, _) {
                  // Shadows for the new area once the map stops moving.
                  _shadeAreaTimer?.cancel();
                  _shadeAreaTimer = Timer(
                    const Duration(milliseconds: 300),
                    () => _updateShadeArea(camera),
                  );
                  final crossed =
                      (camera.zoom >= MapScreen.benchMinZoom) !=
                      (_zoom >= MapScreen.benchMinZoom);
                  _zoom = camera.zoom;
                  if (crossed) setState(() {});
                },
              ),
              children: [
                ?fills,
                if (air.isNotEmpty) ...[
                  CircleLayer(circles: [for (final s in air) airCircle(s)]),
                  MarkerLayer(
                    markers: [
                      for (final s in air)
                        Marker(
                          point: s.latLng,
                          width: 120,
                          height: 32,
                          child: _AirLabel(station: s),
                        ),
                    ],
                  ),
                ],
                MarkerLayer(markers: markers),
                if (userPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: userPosition,
                        width: 24,
                        height: 24,
                        child: const _UserDot(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchField(
                    key: const Key('map-search'),
                    onTap: () => context.push(Routes.routePlan),
                  ),
                  const SizedBox(height: AppSizes.s8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final l in MapLayer.values) ...[
                          LayerFilterChip(
                            key: Key('map-layer-${l.name}'),
                            label: layerName(l, l10n),
                            icon: layerIcon(l),
                            selected: layers.contains(l),
                            onSelected: (_) => _toggle(l),
                          ),
                          const SizedBox(width: AppSizes.s8),
                        ],
                      ],
                    ),
                  ),
                  if (alert != null) ...[
                    const SizedBox(height: AppSizes.s8),
                    HeatBanner(
                      key: const Key('map-heat-banner'),
                      level: alert.level,
                      subtitle: isOverrideAlert(alert)
                          ? null
                          : l10n.mapAlertSubtitle(
                              alert.source,
                              '${alert.validTo.hour}:${alert.validTo.minute.toString().padLeft(2, '0')}',
                            ),
                      onTap: () => context.push(Routes.alert),
                    ),
                  ],
                  if (heatMode) ...[
                    const SizedBox(height: AppSizes.s8),
                    _Pill(
                      icon: Icons.ac_unit_rounded,
                      text: l10n.mapHeatModeHint,
                      onTap: () => context.push(Routes.alert),
                    ),
                  ],
                  if (offline) ...[
                    const SizedBox(height: AppSizes.s8),
                    const OfflineBanner(),
                  ],
                  if (showRisk || layers.contains(MapLayer.shade)) ...[
                    const SizedBox(height: AppSizes.s8),
                    Wrap(
                      spacing: AppSizes.s8,
                      runSpacing: AppSizes.s8,
                      children: [
                        if (showRisk) const HeatRiskChip(),
                        if (layers.contains(MapLayer.shade))
                          _ShadeTimePill(
                            time: shadeTimeLabel(
                              ref.watch(shadeTimeProvider),
                              DateTime.now(),
                              l10n,
                            ),
                            at: ref.watch(shadeTimeProvider),
                            weather: ref.watch(shadeWeatherProvider).value,
                            onChange: _pickShadeTime,
                          ),
                      ],
                    ),
                  ],
                  if (layers.contains(MapLayer.shade)) ...[
                    if (!ref.watch(staticShadeLayerProvider) &&
                        _shadeArea == null) ...[
                      const SizedBox(height: AppSizes.s8),
                      _Pill(
                        icon: Icons.zoom_in_rounded,
                        text: l10n.mapShadowZoomIn,
                        onTap: () {
                          if (_ready) {
                            _map.move(
                              _map.camera.center,
                              MapScreen.shadowMinZoom + 0.5,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                  if (location?.problem != null) ...[
                    const SizedBox(height: AppSizes.s8),
                    _NoLocationCard(onEnable: _myLocation),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSizes.s12,
            bottom: AppSizes.s32,
            child: _Legend(layers: layers),
          ),
          Positioned(
            right: AppSizes.s12,
            bottom: AppSizes.s32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CompassButton(
                  rotation: _rotation,
                  tooltip: l10n.mapCompass,
                  onPressed: () {
                    if (_ready) _map.rotate(0);
                  },
                ),
                FloatingActionButton.small(
                  key: const Key('map-my-location'),
                  heroTag: 'map-my-location',
                  tooltip: l10n.mapMyLocation,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  onPressed: _myLocation,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Google Maps-style compass: shown while the map is turned away from north,
/// the needle points north; a tap turns the map back.
class _CompassButton extends StatelessWidget {
  const _CompassButton({
    required this.rotation,
    required this.tooltip,
    required this.onPressed,
  });

  final ValueListenable<double> rotation;
  final String tooltip;
  final VoidCallback onPressed;

  /// Below this the map counts as north up and the button hides.
  static const minDegrees = 0.5;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: rotation,
    builder: (context, degrees, _) {
      final turned = (degrees % 360 + 360) % 360;
      final visible = turned > minDegrees && turned < 360 - minDegrees;
      if (!visible) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.s8),
        child: FloatingActionButton.small(
          key: const Key('map-compass'),
          heroTag: 'map-compass',
          tooltip: tooltip,
          backgroundColor: AppColors.surface,
          onPressed: onPressed,
          child: Transform.rotate(
            // The map is rotated by `degrees`; north on screen is there.
            angle: degrees * math.pi / 180,
            child: const CustomPaint(
              size: Size(18, 26),
              painter: _NeedlePainter(),
            ),
          ),
        ),
      );
    },
  );
}

/// Two-coloured compass needle: red half points north.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final north = ui.Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(0, h / 2)
      ..close();
    final south = ui.Path()
      ..moveTo(0, h / 2)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..close();
    canvas
      ..drawPath(north, Paint()..color = AppColors.heat3)
      ..drawPath(south, Paint()..color = AppColors.muted);
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => false;
}

/// «14:30», «jutro 9:00» or «pt 24.10 18:00».
String shadeTimeLabel(DateTime time, DateTime now, AppLocalizations l10n) {
  final hm = DateFormat('H:mm', 'pl').format(time);
  final days = DateUtils.dateOnly(
    time,
  ).difference(DateUtils.dateOnly(now)).inDays;
  if (days == 0) return hm;
  if (days == 1) return l10n.mapShadeTomorrow(hm);
  return '${DateFormat('EEE d.MM', 'pl').format(time)} $hm';
}

String? _weatherText(ShadeWeather w, AppLocalizations l10n) {
  if (w.night) return l10n.mapWeatherNight;
  final t = w.temperature;
  if (t == null) return null;
  final temp = t.round();
  if (w.hour case final hour?) {
    final kind = WeatherKind.of(hour);
    if (kind.index >= WeatherKind.fog.index) {
      return l10n.mapWeatherOther(temp, weatherLabel(kind, l10n).toLowerCase());
    }
  }
  if (w.strength >= 0.6) return l10n.mapWeatherSunny(temp);
  if (w.strength >= 0.25) return l10n.mapWeatherPartly(temp);
  return l10n.mapWeatherCloudy(temp);
}

class _ShadeTimePill extends StatelessWidget {
  const _ShadeTimePill({
    required this.time,
    required this.onChange,
    this.weather,
    this.at,
  });

  final String time;

  /// The instant [time] names (for the moon at night).
  final DateTime? at;
  final ShadeWeather? weather;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      child: InkWell(
        key: const Key('map-shade-time'),
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        onTap: onChange,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.shadeLayer,
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (weather?.hour case final hour?) ...[
                  const SizedBox(width: AppSizes.s8),
                  WeatherIcon(hour: hour, instant: at!, size: 20),
                ],
                const SizedBox(width: AppSizes.s8),
                Flexible(
                  child: Text(
                    [
                      l10n.mapShadeAt(time),
                      if (weather case final w?) _weatherText(w, l10n),
                    ].whereType<String>().join(' · '),
                    style: AppTextStyles.label,
                  ),
                ),
                const SizedBox(width: AppSizes.s4),
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.primary,
                  semanticLabel: l10n.mapShadeChangeTime,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoLocationCard extends StatelessWidget {
  const _NoLocationCard({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const Key('map-no-location'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.s12,
          AppSizes.s8,
          AppSizes.s8,
          AppSizes.s8,
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.primary),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mapNoLocationTitle, style: AppTextStyles.label),
                  Text(l10n.mapNoLocationBody, style: AppTextStyles.label),
                ],
              ),
            ),
            TextButton(
              onPressed: onEnable,
              child: Text(l10n.mapEnableLocation),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s12,
        vertical: AppSizes.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSizes.s8),
          Expanded(child: Text(text, style: AppTextStyles.label)),
        ],
      ),
    ),
  );
}

class _AirLabel extends StatelessWidget {
  const _AirLabel({required this.station});

  final AirStation station;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final level = airLevelName(station.indexLevel, l10n);
    return Center(
      child: Semantics(
        label: l10n.mapAirStation(station.name, level),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusChip),
            border: Border.all(color: airColor(station.indexLevel), width: 2),
          ),
          child: Text(
            level,
            style: AppTextStyles.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.layers});

  final List<MapLayer> layers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = [
      if (layers.contains(MapLayer.shade))
        (AppColors.shadeLayer, l10n.mapLegendShade),
      if (layers.contains(MapLayer.quiet)) (quietColor(2), l10n.mapLegendQuiet),
      if (layers.contains(MapLayer.air)) (airColor(1), l10n.mapLegendAir),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSizes.s8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (color, text) in rows)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: AppSizes.s4),
                Text(text, style: AppTextStyles.label),
              ],
            ),
        ],
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.water,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.surface, width: 3),
      boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x40000000))],
    ),
  );
}
