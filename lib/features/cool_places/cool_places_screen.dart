import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/clock.dart';
import '../../core/location/location_service.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/map/base_map.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/map_pin.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/place_list_item.dart';
import '../../shared/widgets/skeleton.dart';
import '../map/data/map_providers.dart';
import 'data/places_providers.dart';
import 'place_format.dart';
import 'place_sheet.dart';

/// S09 filters.
enum CoolFilter { openNow, water, accessible, quest }

/// Active S09 filters (kept while switching tabs).
class CoolFilters extends Notifier<Set<CoolFilter>> {
  @override
  Set<CoolFilter> build() => const {};

  void toggle(CoolFilter f) =>
      state = state.contains(f) ? ({...state}..remove(f)) : {...state, f};

  void clear() => state = const {};
}

final coolFiltersProvider = NotifierProvider<CoolFilters, Set<CoolFilter>>(
  CoolFilters.new,
);

/// Places matching all [filters], nearest to [from] first.
List<Place> filterAndSort(
  List<Place> places,
  Set<CoolFilter> filters, {
  required LatLng from,
  required DateTime now,
}) {
  bool keep(Place p) => filters.every(
    (f) => switch (f) {
      CoolFilter.openNow => p.isOpenAt(now),
      CoolFilter.water => p.has(Amenity.water),
      CoolFilter.accessible =>
        p.accessible == true || p.has(Amenity.wheelchair),
      CoolFilter.quest => p.questPlace,
    },
  );
  return places.where(keep).toList()
    ..sort((a, b) => distanceTo(a, from).compareTo(distanceTo(b, from)));
}

/// S09 Miejsca chłodu (tab Chłód): list by distance or map, with filters.
class CoolPlacesScreen extends ConsumerStatefulWidget {
  const CoolPlacesScreen({super.key});

  @override
  ConsumerState<CoolPlacesScreen> createState() => _CoolPlacesScreenState();
}

class _CoolPlacesScreenState extends ConsumerState<CoolPlacesScreen> {
  bool _map = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = ref.watch(coolFiltersProvider);
    final placesAsync = ref.watch(coolPlacesProvider);
    final location = ref.watch(userLocationProvider).value;
    final from = location?.position ?? lodzCenter;
    final now = ref.watch(clockProvider)();
    final offline = ref.watch(dataSourceProvider) == DataSource.fallback;

    final Widget content;
    if (placesAsync.value case final places?) {
      final shown = filterAndSort(places, filters, from: from, now: now);
      if (shown.isEmpty) {
        content = Center(
          child: SingleChildScrollView(
            child: EmptyState(
              icon: Icons.ac_unit_rounded,
              title: l10n.coolEmptyTitle,
              message: l10n.coolEmptyBody,
              actionLabel: l10n.coolShowAll,
              onAction: ref.read(coolFiltersProvider.notifier).clear,
            ),
          ),
        );
      } else if (_map) {
        content = _PlacesMap(places: shown, center: from);
      } else {
        content = _PlacesList(
          places: shown,
          from: from,
          now: now,
          showDistanceNote: location?.position == null,
        );
      }
    } else if (placesAsync.hasError) {
      content = Center(
        child: ErrorState(
          title: l10n.coolLoadError,
          onRetry: () => ref.invalidate(coolPlacesProvider),
        ),
      );
    } else {
      content = ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          for (var i = 0; i < 5; i++) ...const [
            SkeletonCard(),
            SizedBox(height: AppSizes.s8),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.coolTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.s12),
            child: SegmentedButton<bool>(
              key: const Key('cool-view'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.list_rounded),
                  label: Text(l10n.coolViewList),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.map_rounded),
                  label: Text(l10n.coolViewMap),
                ),
              ],
              selected: {_map},
              onSelectionChanged: (v) => setState(() => _map = v.single),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
            ),
            child: Row(
              children: [
                for (final f in CoolFilter.values) ...[
                  FilterChip(
                    key: Key('cool-filter-${f.name}'),
                    label: Text(_filterName(f, l10n)),
                    selected: filters.contains(f),
                    showCheckmark: true,
                    labelStyle: AppTextStyles.label.copyWith(
                      color: filters.contains(f)
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                    ),
                    onSelected: (_) =>
                        ref.read(coolFiltersProvider.notifier).toggle(f),
                  ),
                  const SizedBox(width: AppSizes.s8),
                ],
              ],
            ),
          ),
          if (offline)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.s8,
                AppSizes.screenPadding,
                0,
              ),
              child: OfflineBanner(),
            ),
          const SizedBox(height: AppSizes.s8),
          Expanded(child: content),
        ],
      ),
    );
  }

  static String _filterName(CoolFilter f, AppLocalizations l10n) => switch (f) {
    CoolFilter.openNow => l10n.coolFilterOpen,
    CoolFilter.water => l10n.coolFilterWater,
    CoolFilter.accessible => l10n.coolFilterAccessible,
    CoolFilter.quest => l10n.coolFilterQuest,
  };
}

class _PlacesList extends StatelessWidget {
  const _PlacesList({
    required this.places,
    required this.from,
    required this.now,
    required this.showDistanceNote,
  });

  final List<Place> places;
  final LatLng from;
  final DateTime now;
  final bool showDistanceNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      key: const Key('cool-list'),
      itemCount: places.length + (showDistanceNote ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(indent: AppSizes.screenPadding),
      itemBuilder: (context, i) {
        if (showDistanceNote && i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
              vertical: AppSizes.s4,
            ),
            child: Text(
              l10n.coolNoLocationNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final p = places[i - (showDistanceNote ? 1 : 0)];
        return PlaceListItem(
          key: Key('cool-item-${p.id}'),
          name: p.title(l10n),
          subtitle: [
            p.typeLabel(l10n),
            formatDistance(distanceTo(p, from), l10n),
            ?p.todayHours(l10n, now),
          ].join(' · '),
          status: p.statusAt(now),
          statusText: p.statusText(l10n, now),
          inQuest: p.questPlace,
          onTap: () => showPlaceSheet(context, p),
        );
      },
    );
  }
}

class _PlacesMap extends ConsumerWidget {
  const _PlacesMap({required this.places, required this.center});

  final List<Place> places;
  final LatLng center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final senior = ref.watch(seniorModeProvider);
    return BaseMap(
      key: const Key('cool-map'),
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.5,
        minZoom: MapTiles.minZoom,
        maxZoom: MapTiles.maxZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        MarkerLayer(
          markers: [
            for (final p in places)
              Marker(
                key: ValueKey('cool-pin-${p.id}'),
                point: p.latLng,
                width: senior ? 96 : 48,
                height: senior ? 88 : 48,
                child: MapPin(
                  type: MapPinType.cool,
                  semanticLabel: p.title(l10n),
                  onTap: () => showPlaceSheet(context, p),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
