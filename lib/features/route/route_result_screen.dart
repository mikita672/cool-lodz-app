import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_providers.dart';
import '../../core/clock.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_rules.dart';
import '../../core/heat/heat_risk.dart';
import '../../core/location/location_service.dart';
import '../../core/models/models.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/warsaw_time.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/map/base_map.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icons.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/route_variant_card.dart' as ds;
import '../../shared/widgets/skeleton.dart';
import '../achievements/badge_info.dart';
import '../cool_places/data/places_providers.dart';
import '../cool_places/place_sheet.dart';
import '../game/data/game_config_repository.dart';
import '../game/game_service.dart';
import '../heat_risk/data/heat_risk_providers.dart';
import '../profile/data/comfort_profile_provider.dart';
import 'data/google_maps.dart';
import 'data/route_history_repository.dart';
import 'data/route_plan.dart';
import 'route_plan_screen.dart';

/// S07 Wynik trasy: three variants on the map, cards to compare them,
/// «Prowadź» (Google Maps, counts for the game) and «Zapisz» (offline).
class RouteResultScreen extends ConsumerStatefulWidget {
  const RouteResultScreen({super.key, this.launch = _launchExternal});

  /// Opens a URL outside the app; injected in tests.
  final Future<bool> Function(Uri url) launch;

  static Future<bool> _launchExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  ConsumerState<RouteResultScreen> createState() => _RouteResultScreenState();
}

/// Kompromis by default, Zacieniona for the Senior profile.
RouteVariantType defaultVariant(ProfileId profile) =>
    profile == ProfileId.senior
    ? RouteVariantType.shaded
    : RouteVariantType.compromise;

/// Order of the cards and of the Senior pages.
const variantOrder = [
  RouteVariantType.shortest,
  RouteVariantType.shaded,
  RouteVariantType.compromise,
  RouteVariantType.alternative,
];

/// [response]'s variants in card order (alternatives keep their order).
List<RouteVariant> orderedVariants(RouteResponse response) => [
  for (final t in variantOrder)
    ...response.variants.where((v) => v.variant == t),
];

class _RouteResultScreenState extends ConsumerState<RouteResultScreen> {
  /// The user's pick; null = the profile default.
  RouteVariant? _picked;

  /// «Najlepsza pora wyjścia» (APP-22): "HH:mm", null = the asked time.
  String? _slot;
  bool _saving = false;
  bool _going = false;

  /// The departure the cards show: the slider's slot (Warsaw time) on the
  /// asked day.
  DateTime _departure(RouteRequest request) {
    final slot = _slot;
    if (slot == null) return request.datetime;
    final m = parseHhMm(slot);
    final d = warsawWallClock(request.datetime);
    return warsawWallClockToUtc(
      d.year,
      d.month,
      d.day,
      m ~/ 60,
      m % 60,
    ).toLocal();
  }

  /// Sun share for leaving at [time]: the hourly slot when module D sends
  /// them and [time] is inside 8:00–20:00, else the answer's own value.
  static double _sunShareAt(RouteVariant v, DateTime time) {
    final minute = warsawMinuteOfDay(time);
    if (v.sunShareByHour.isEmpty || minute < 8 * 60 || minute > 20 * 60) {
      return v.sunShare;
    }
    return v.sunShareAt(time);
  }

  /// The picked card, else the profile default, else the first variant.
  RouteVariant _selected(RouteResponse response) {
    final picked = _picked;
    if (picked != null && response.variants.any((v) => identical(v, picked))) {
      return picked;
    }
    return response.variant(
          defaultVariant(ref.read(comfortProfileProvider).id),
        ) ??
        orderedVariants(response).first;
  }

  Future<void> _go(RouteRequest request, RouteVariant variant) async {
    if (_going || variant.geometry.length < 2) return;
    _going = true;
    try {
      await _goNow(request, variant);
    } finally {
      _going = false;
    }
  }

  Future<void> _goNow(RouteRequest request, RouteVariant variant) async {
    final l10n = AppLocalizations.of(context);
    // The walk starts now: that time counts for points, the heat rule and
    // the morning/evening badges (the slider only explores other times).
    final startedAt = ref.read(clockProvider)();
    final messenger = ScaffoldMessenger.of(context);
    final award = _record(request, variant, startedAt);
    final ok = await widget
        .launch(GoogleMapsLink.walking(variant.geometry))
        .catchError((Object _) => false);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.routeMapsError)));
    }
    // Shown when the user is back from Google Maps.
    final result = await award;
    if (result == null || !mounted) return;
    final routePoints = result.pointsFor(PointsType.route);
    final heatBlocked =
        1 - _sunShareAt(variant, startedAt) >= GameConfig.shadedRouteMinShade &&
        GameRules.isHeatBlocked(startedAt, ref.read(heatLevelProvider));
    await showAwardFeedback(
      context,
      result,
      message: routePoints > 0
          ? l10n.gameRoutePointsToast(routePoints)
          : heatBlocked
          ? l10n.gameHeatNoPoints
          : null,
    );
  }

  /// «Prowadź» counts the route (Q-08): it goes to `users/{uid}/routes` and
  /// through the points and badges rules.
  Future<GameAward?> _record(
    RouteRequest request,
    RouteVariant variant,
    DateTime startedAt,
  ) async {
    final to = ref.read(routePlanProvider).to;
    // The place only if it is still this request's destination.
    final place =
        to is PointEndpoint &&
            to.point.lat == request.to.lat &&
            to.point.lon == request.to.lon
        ? to.place
        : null;
    try {
      return await ref
          .read(gameServiceProvider)
          .routeStarted(
            StartedRoute(
              from: request.from,
              to: request.to,
              departAt: startedAt,
              variant: variant.variant,
              sunShare: _sunShareAt(variant, startedAt),
              distanceM: variant.distanceM,
              endPlaceType: place?.category?.name,
            ),
          );
    } catch (e) {
      debugPrint('Recording the route failed: $e');
      return null;
    }
  }

  Future<void> _save(RouteRequest request, RouteResponse response) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(offlineCacheProvider).saveLastRoute(request, response);
      if (mounted) {
        showAppToast(context, l10n.routeSaved, kind: ToastKind.success);
      }
    } catch (e) {
      debugPrint('Saving the route failed: $e');
      if (mounted) {
        showAppToast(context, l10n.routeSaveError, kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requestAsync = ref.watch(routeRequestProvider);
    final resultAsync = ref.watch(routeResultProvider);
    final fallback = ref.watch(dataSourceProvider) == DataSource.fallback;
    // A new profile default applies when nothing was picked by hand.
    ref.watch(comfortProfileProvider.select((p) => p.id));
    ref.listen(routeResultProvider, (_, _) {
      _picked = null;
      _slot = null;
    });

    final request = requestAsync.value;
    final response = resultAsync.value;
    final error = resultAsync.error ?? requestAsync.error;
    // A new request (another destination, profile or retry) keeps the old
    // value while loading: show the skeleton, never the previous route.
    final loading =
        requestAsync.isLoading ||
        resultAsync.isLoading ||
        (response == null && error == null);

    Widget body;
    if (loading) {
      body = const _Loading();
    } else if (response != null &&
        request != null &&
        (response.variants.isEmpty ||
            response.variants.every((v) => v.geometry.length < 2))) {
      body = const _Problem(error: ApiException(ApiErrorKind.notFound));
    } else if (response != null && request != null && error == null) {
      body = _Result(
        request: request,
        response: response,
        selected: _selected(response),
        departure: _slot == null ? null : _departure(request),
        onSlot: (slot) => setState(() => _slot = slot),
        onSelect: (v) => setState(() => _picked = v),
        onGo: (v) => _go(request, v),
        onSave: () => _save(request, response),
        saving: _saving,
        offline: fallback,
      );
    } else {
      body = _Problem(error: error!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          request == null
              ? l10n.routeResultTitle
              : l10n.routeResultHeader(
                  request.from.label ?? l10n.routeMyLocation,
                  request.to.label ?? '',
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }
}

/// Map lines for [response]: the others thin and grey underneath, the
/// selected one on top, split into shade (primary) and sun (orange) parts
/// by `segments`, or in one colour when module D sends none (DEP-03).
List<Polyline> routePolylines(RouteResponse response, RouteVariant selected) {
  final lines = <Polyline>[
    for (final v in response.variants)
      if (!identical(v, selected))
        Polyline(
          points: v.geometry,
          color: AppColors.muted,
          strokeWidth: AppSizes.routeOtherWidth,
        ),
  ];
  final chosen = selected;
  final segments = chosen.segments
      .where(
        (s) => s.from >= 0 && s.to < chosen.geometry.length && s.to > s.from,
      )
      .toList();
  // The whole line first, so parts without a segment are never missing.
  lines.add(
    Polyline(
      points: chosen.geometry,
      color: AppColors.primary,
      strokeWidth: AppSizes.routeSelectedWidth,
      borderColor: AppColors.surface,
      borderStrokeWidth: 1.5,
    ),
  );
  if (segments.isEmpty) return lines;
  for (final s in segments) {
    lines.add(
      Polyline(
        points: chosen.geometry.sublist(s.from, s.to + 1),
        color: isSunny(s) ? AppColors.sun : AppColors.primary,
        strokeWidth: AppSizes.routeSelectedWidth,
        borderColor: AppColors.surface,
        borderStrokeWidth: 1.5,
      ),
    );
  }
  return lines;
}

/// A segment counts as sunny when at least half of it is in the sun.
bool isSunny(RouteSegment segment) => segment.sunShare >= 0.5;

class _Result extends ConsumerWidget {
  const _Result({
    required this.request,
    required this.response,
    required this.selected,
    required this.departure,
    required this.onSlot,
    required this.onSelect,
    required this.onGo,
    required this.onSave,
    required this.saving,
    required this.offline,
  });

  final RouteRequest request;
  final RouteResponse response;
  final RouteVariant selected;

  /// The slider's departure; null = the asked time (cards then show the
  /// answer's own shade share).
  final DateTime? departure;
  final ValueChanged<String> onSlot;
  final ValueChanged<RouteVariant> onSelect;
  final ValueChanged<RouteVariant> onGo;
  final VoidCallback onSave;
  final bool saving;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final senior = ref.watch(seniorModeProvider);
    final places = ref.watch(placeByIdProvider);
    final variant = selected;
    final ordered = orderedVariants(response);
    final alternatives = [
      for (final v in ordered)
        if (v.variant == RouteVariantType.alternative) v,
    ];
    int number(RouteVariant v) => alternatives.indexOf(v) + 1;
    final shortest = response.shortest;
    final now = DateTime.now();
    // «Chodzę z psem»: how hot the asphalt is at the departure.
    final asphalt = ref.watch(walksWithDogProvider)
        ? ref.watch(asphaltAtProvider(departure ?? request.datetime)).value
        : null;

    final all = [for (final v in response.variants) ...v.geometry];
    final stops = [
      for (final s in variant.stops)
        if (places[s.placeId] case final place?) (s, place),
    ];

    ds.RouteVariantCard card(RouteVariant v) => ds.RouteVariantCard(
      key: Key(
        v.variant == RouteVariantType.alternative
            ? 'route-card-alternative-${number(v)}'
            : 'route-card-${v.variant.name}',
      ),
      variant: switch (v.variant) {
        RouteVariantType.shortest => ds.RouteVariant.shortest,
        RouteVariantType.shaded => ds.RouteVariant.shaded,
        RouteVariantType.compromise => ds.RouteVariant.compromise,
        RouteVariantType.alternative => ds.RouteVariant.alternative,
      },
      number: number(v),
      minutes: (v.durationS / 60).round(),
      distanceKm: v.distanceM / 1000,
      shadePercent:
          ((departure == null ? v.shadeShare : 1 - v.sunShareAt(departure!)) *
                  100)
              .round(),
      extraMinutes: v.variant == RouteVariantType.shortest || shortest == null
          ? 0
          : (v.extraTimeVsShortestS / 60).round(),
      coolStops: v.stops.where((s) => s.type == StopType.cool).length,
      waterStops: v.stops.where((s) => s.type == StopType.water).length,
      selected: identical(v, selected),
      onTap: () => onSelect(v),
    );

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Semantics(
                label: l10n.routeMapSemantics(
                  _name(selected.variant, l10n, number(selected)),
                  (variant.shadeShare * 100).round(),
                ),
                child: ExcludeSemantics(
                  child: BaseMap(
                    // A new selection keeps the camera; new data refits it.
                    key: ValueKey(response),
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(all),
                        padding: const EdgeInsets.all(AppSizes.s32),
                      ),
                      minZoom: MapTiles.minZoom,
                      maxZoom: MapTiles.maxZoom,
                    ),
                    children: [
                      PolylineLayer(
                        polylines: routePolylines(response, selected),
                      ),
                      MarkerLayer(
                        markers: [
                          for (final (stop, place) in stops)
                            Marker(
                              point: place.latLng,
                              width: 28,
                              height: 28,
                              child: Semantics(
                                button: true,
                                label: place.name,
                                child: GestureDetector(
                                  onTap: () => showPlaceSheet(context, place),
                                  child: _StopMarker(type: stop.type),
                                ),
                              ),
                            ),
                          Marker(
                            point: variant.geometry.first,
                            width: 24,
                            height: 24,
                            child: const _EndMarker(start: true),
                          ),
                          Marker(
                            point: variant.geometry.last,
                            width: 32,
                            height: 32,
                            alignment: Alignment.topCenter,
                            child: const _EndMarker(start: false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSizes.s12,
                right: AppSizes.s12,
                top: AppSizes.s12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (offline) ...[
                      const OfflineBanner(),
                      const SizedBox(height: AppSizes.s8),
                    ],
                    if (response.isApproximate)
                      _Notice(
                        key: const Key('route-approximate'),
                        text: l10n.routeApproximate,
                      ),
                    if (response.weather case final w? when w.littleSun) ...[
                      if (response.isApproximate)
                        const SizedBox(height: AppSizes.s8),
                      _Notice(
                        key: const Key('route-little-sun'),
                        text: w.sunStrength <= 0.01
                            ? l10n.routeNoSun
                            : l10n.routeCloudy,
                      ),
                    ],
                    if (asphalt != null && asphalt >= asphaltCaution) ...[
                      if (response.isApproximate ||
                          (response.weather?.littleSun ?? false))
                        const SizedBox(height: AppSizes.s8),
                      _Notice(
                        key: const Key('route-paws'),
                        icon: Icons.pets_rounded,
                        text: asphalt >= asphaltDanger
                            ? l10n.routePawWarning(asphalt.round())
                            : l10n.routePawCaution(asphalt.round()),
                      ),
                    ],
                  ],
                ),
              ),
              const Positioned(
                left: AppSizes.s12,
                bottom: AppSizes.s32,
                child: _Legend(),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.surface,
          elevation: 8,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusSheet),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.screenPadding,
                        AppSizes.s12,
                        AppSizes.screenPadding,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.routeResultDeparture(
                              formatDeparture(
                                departure ?? request.datetime,
                                now,
                                l10n,
                              ),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSizes.s8),
                          if (senior)
                            _SeniorPager(
                              variants: ordered,
                              selected: selected,
                              onSelect: onSelect,
                              card: card,
                            )
                          else
                            for (final v in ordered) ...[
                              card(v),
                              const SizedBox(height: AppSizes.s8),
                            ],
                          if (variant.sunShareByHour.length > 1)
                            _BestTime(
                              variant: variant,
                              departure: departure ?? request.datetime,
                              onSlot: onSlot,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.screenPadding,
                      AppSizes.s8,
                      AppSizes.screenPadding,
                      AppSizes.screenPadding,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            key: const Key('route-save'),
                            label: l10n.routeSave,
                            icon: Icons.bookmark_add_rounded,
                            variant: AppButtonVariant.secondary,
                            loading: saving,
                            onPressed: onSave,
                            expand: true,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            key: const Key('route-go'),
                            label: l10n.routeGo,
                            icon: Icons.navigation_rounded,
                            onPressed: () => onGo(variant),
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _name(
    RouteVariantType type,
    AppLocalizations l10n, [
    int number = 1,
  ]) => switch (type) {
    RouteVariantType.shortest => l10n.dsRouteShortest,
    RouteVariantType.shaded => l10n.dsRouteShaded,
    RouteVariantType.compromise => l10n.dsRouteCompromise,
    RouteVariantType.alternative => l10n.dsRouteAlternative(number),
  };
}

/// «Najlepsza pora wyjścia» (APP-22): 30-minute slots of the selected
/// variant with a mini chart of its shade share. Moving it changes the
/// shade on every card from `sunShareByHour`, without a new request.
class _BestTime extends StatelessWidget {
  const _BestTime({
    required this.variant,
    required this.departure,
    required this.onSlot,
  });

  final RouteVariant variant;
  final DateTime departure;
  final ValueChanged<String> onSlot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slots = variant.sunShareByHour.keys.toList();
    final current = nearestTimeKey(slots, warsawMinuteOfDay(departure))!;
    final index = slots.indexOf(current);
    final best = variant.bestDepartureSlot!;
    int shade(String slot) =>
        ((1 - variant.sunShareByHour[slot]!) * 100).round();
    String label(String slot) =>
        slot.startsWith('0') ? slot.substring(1) : slot;

    return Column(
      key: const Key('route-best-time'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSizes.s8),
        Text(l10n.routeBestTimeTitle, style: theme.textTheme.titleSmall),
        Text(
          l10n.routeBestTimeHint(label(best), shade(best)),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSizes.s8),
        Semantics(
          label: l10n.routeBestTimeChart,
          excludeSemantics: true,
          child: SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final s in slots)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: FractionallySizedBox(
                        heightFactor: (shade(s) / 100).clamp(0.05, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: s == current
                                ? AppColors.primary
                                : AppColors.primaryContainer,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Slider(
          key: const Key('route-time-slider'),
          value: index.toDouble(),
          max: (slots.length - 1).toDouble(),
          divisions: slots.length - 1,
          label: label(current),
          semanticFormatterCallback: (v) {
            final s = slots[v.round()];
            return l10n.routeBestTimeSlider(label(s), shade(s));
          },
          onChanged: (v) => onSlot(slots[v.round()]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label(slots.first), style: theme.textTheme.labelSmall),
            Text(label(slots.last), style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

/// Senior mode: one whole card at a time; swipe or use the arrows.
class _SeniorPager extends StatelessWidget {
  const _SeniorPager({
    required this.variants,
    required this.selected,
    required this.onSelect,
    required this.card,
  });

  final List<RouteVariant> variants;
  final RouteVariant selected;
  final ValueChanged<RouteVariant> onSelect;
  final Widget Function(RouteVariant) card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = math.max(
      0,
      variants.indexWhere((v) => identical(v, selected)),
    );
    void go(int i) {
      if (i >= 0 && i < variants.length) onSelect(variants[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: const Key('route-senior-pager'),
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) go(index + 1);
            if (v > 200) go(index - 1);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(index),
              child: card(variants[index]),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: l10n.routePrevVariant,
              onPressed: index > 0 ? () => go(index - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              l10n.routeVariantsPage(index + 1, variants.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            IconButton(
              tooltip: l10n.routeNextVariant,
              onPressed: index < variants.length - 1
                  ? () => go(index + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSizes.screenPadding),
    children: const [
      SkeletonBox(height: 220),
      SizedBox(height: AppSizes.s16),
      SkeletonRouteCard(),
      SizedBox(height: AppSizes.s8),
      SkeletonRouteCard(),
      SizedBox(height: AppSizes.s8),
      SkeletonRouteCard(),
    ],
  );
}

/// No route, no location, or an error.
class _Problem extends ConsumerWidget {
  const _Problem({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final err = error;
    void retry() => ref.invalidate(routeRequestProvider);

    if (err is LocationUnavailable) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              EmptyState(
                icon: Icons.location_off_rounded,
                title: l10n.routeNoLocationTitle,
                message: l10n.routeNoLocationBody,
                actionLabel: l10n.routeEnableLocation,
                onAction: () async {
                  await ref.read(locationServiceProvider).enable();
                  retry();
                },
              ),
              AppButton(
                key: const Key('route-choose-start'),
                label: l10n.routeChooseStart,
                variant: AppButtonVariant.text,
                onPressed: () => _backToPlan(context),
              ),
            ],
          ),
        ),
      );
    }
    if (err is ApiException && err.kind == ApiErrorKind.notFound) {
      return Center(
        child: EmptyState(
          icon: Icons.wrong_location_rounded,
          title: l10n.routeNotFoundTitle,
          message: l10n.routeNotFoundBody,
          actionLabel: l10n.routeChangePoints,
          onAction: () => _backToPlan(context),
        ),
      );
    }
    debugPrint('Routes failed: $err');
    return Center(child: ErrorState(onRetry: retry));
  }

  /// Back to S06 (it is underneath when we came from it).
  static void _backToPlan(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/route');
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s12,
        vertical: AppSizes.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        border: Border.all(color: AppColors.sun),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSizes.s8),
          Expanded(child: Text(text, style: AppTextStyles.label)),
        ],
      ),
    ),
  );
}

/// What the line colours mean (colour is never the only signal: the cards
/// show the shade share as a number).
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget item(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 4, color: color),
        const SizedBox(width: AppSizes.s4),
        Text(text, style: AppTextStyles.label),
      ],
    );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item(AppColors.primary, l10n.routeLegendShade),
            const SizedBox(height: AppSizes.s4),
            item(AppColors.sun, l10n.routeLegendSun),
          ],
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({required this.type});

  final StopType type;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      shape: BoxShape.circle,
      border: Border.all(
        color: type == StopType.cool ? AppColors.cool : AppColors.water,
        width: 2,
      ),
    ),
    child: Center(
      child: type == StopType.cool
          ? const CoolPlaceIcon(size: 16, color: AppColors.primary)
          : const WaterTapIcon(size: 16, color: AppColors.water),
    ),
  );
}

class _EndMarker extends StatelessWidget {
  const _EndMarker({required this.start});

  final bool start;

  @override
  Widget build(BuildContext context) => start
      ? DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.onSurface, width: 4),
          ),
        )
      : const Icon(Icons.place_rounded, color: AppColors.onSurface, size: 32);
}
