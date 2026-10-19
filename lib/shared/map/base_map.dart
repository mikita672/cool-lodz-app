import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';

/// Raster tiles: CARTO Voyager, no key (decision Q-04, #41). The app never
/// uses tile.openstreetmap.org.
abstract final class MapTiles {
  static const urlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const subdomains = ['a', 'b', 'c', 'd'];
  static const userAgentPackageName = 'pl.betterthannever.cool_lodz';
  static const attribution = '© OpenStreetMap contributors © CARTO';
  static final osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
  static const minZoom = 11.0;
  static const maxZoom = 19.0;
}

/// False in widget tests: no network tiles, only the layers on top.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// FlutterMap with the app tiles and the OSM attribution; feature layers
/// (lines, polygons, markers) go in [children].
class BaseMap extends ConsumerWidget {
  const BaseMap({
    super.key,
    required this.options,
    this.children = const [],
    this.mapController,
  });

  final MapOptions options;
  final List<Widget> children;
  final MapController? mapController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(mapTilesEnabledProvider);
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: FlutterMap(
        mapController: mapController,
        options: options,
        children: [
          if (tiles)
            TileLayer(
              urlTemplate: MapTiles.urlTemplate,
              subdomains: MapTiles.subdomains,
              userAgentPackageName: MapTiles.userAgentPackageName,
              retinaMode: RetinaMode.isHighDensity(context),
              maxNativeZoom: 20,
            ),
          ...children,
          const MapAttribution(),
        ],
      ),
    );
  }
}

/// «© OpenStreetMap contributors © CARTO», opens the OSM copyright page.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Semantics(
      link: true,
      child: GestureDetector(
        onTap: () => launchUrl(
          MapTiles.osmCopyright,
          mode: LaunchMode.externalApplication,
        ),
        child: Container(
          margin: const EdgeInsets.all(AppSizes.s4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            MapTiles.attribution,
            style: AppTextStyles.label.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Keep it small: system font size must not cover the map.
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    ),
  );
}
