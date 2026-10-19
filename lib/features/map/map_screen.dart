import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
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
import '../alerts/data/alert_providers.dart';
import '../cool_places/data/places_providers.dart';
import '../cool_places/place_format.dart';
import '../cool_places/place_sheet.dart';
import 'data/map_layers_style.dart';
import 'data/map_providers.dart';

/// S05 Mapa (main screen): search, six filters, layers, points, the heat
/// banner and the user's position.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  /// Benches only from this zoom (spec: «лавки только при зуме ≥ 17»).
  static const benchMinZoom = 17.0;
  static const startZoom = 14.0;
  static const userZoom = 15.0;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  double _zoom = MapScreen.startZoom;
  bool _ready = false;
  bool _centeredOnUser = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
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
    if (current?.position case final p?) {
      _moveTo(p, MapScreen.userZoom);
      return;
    }
    await ref.read(locationServiceProvider).enable();
    ref.invalidate(userLocationProvider);
  }

  Future<void> _pickShadeTime() async {
    final l10n = AppLocalizations.of(context);
    final demo = ref.read(isDemoModeEffectiveProvider);
    final current = ref.read(shadeTimeProvider);
    final slot = await showModalBottomSheet<String>(
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
              if (demo) ...[
                const SizedBox(height: AppSizes.s8),
                Text(l10n.mapShadeDemoNote, style: AppTextStyles.bodyS),
              ],
              const SizedBox(height: AppSizes.s16),
              Wrap(
                spacing: AppSizes.s8,
                runSpacing: AppSizes.s8,
                children: [
                  for (final s in ShadeTime.slots(demo: demo))
                    ChoiceChip(
                      label: Text(s),
                      selected: s == current,
                      onSelected: (_) => Navigator.of(context).pop(s),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (slot != null) ref.read(shadeTimeProvider.notifier).set(slot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layers = ref.watch(mapLayersProvider);
    final senior = ref.watch(seniorModeProvider);
    final alert = ref.watch(activeAlertProvider).value;
    final heatMode = (alert?.level ?? 0) >= GameConfig.heatModeLevel;
    final offline = ref.watch(dataSourceProvider) == DataSource.fallback;
    final location = ref.watch(userLocationProvider).value;
    final userPosition = location?.position;

    // Heat mode: cool places first (spec S14).
    ref.listen(activeAlertProvider, (_, next) {
      if ((next.value?.level ?? 0) >= GameConfig.heatModeLevel) {
        ref.read(mapLayersProvider.notifier).ensure(MapLayer.cool);
      }
    });
    // Center on the user once the first position arrives.
    ref.listen(userLocationProvider, (_, next) {
      final p = next.value?.position;
      if (p != null && !_centeredOnUser) {
        _centeredOnUser = true;
        _moveTo(p, MapScreen.userZoom);
      }
    });

    List<Place> places(PlaceType type) =>
        ref.watch(placesOfTypeProvider(type)).value ?? const [];
    GeoLayer? layer(LayerKind kind) => ref.watch(layerProvider(kind)).value;

    final fills = <Polygon>[
      if (layers.contains(MapLayer.green))
        ...polygonsFor(layer(LayerKind.green), MapLayer.green),
      if (layers.contains(MapLayer.quiet))
        ...polygonsFor(layer(LayerKind.noise), MapLayer.quiet),
      if (layers.contains(MapLayer.shade))
        ...polygonsFor(layer(LayerKind.shade), MapLayer.shade),
    ];
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
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () => _ready = true,
                onPositionChanged: (camera, _) {
                  final crossed =
                      (camera.zoom >= MapScreen.benchMinZoom) !=
                      (_zoom >= MapScreen.benchMinZoom);
                  _zoom = camera.zoom;
                  if (crossed) setState(() {});
                },
              ),
              children: [
                if (fills.isNotEmpty) PolygonLayer(polygons: fills),
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
                      subtitle: l10n.mapAlertSubtitle(
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
                    ),
                  ],
                  if (offline) ...[
                    const SizedBox(height: AppSizes.s8),
                    const OfflineBanner(),
                  ],
                  if (layers.contains(MapLayer.shade)) ...[
                    const SizedBox(height: AppSizes.s8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ShadeTimePill(
                        time: ref.watch(shadeTimeProvider),
                        onChange: _pickShadeTime,
                      ),
                    ),
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
            child: FloatingActionButton.small(
              key: const Key('map-my-location'),
              heroTag: 'map-my-location',
              tooltip: l10n.mapMyLocation,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              onPressed: _myLocation,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShadeTimePill extends StatelessWidget {
  const _ShadeTimePill({required this.time, required this.onChange});

  final String time;
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
                const SizedBox(width: AppSizes.s8),
                Text(l10n.mapShadeAt(time), style: AppTextStyles.label),
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
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
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
      if (layers.contains(MapLayer.quiet))
        (noiseColor(75), l10n.mapLegendQuiet),
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
