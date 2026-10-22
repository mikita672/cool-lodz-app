import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_providers.dart';
import '../../core/api/live/live_api_client.dart';
import '../../core/clock.dart';
import '../../core/location/location_service.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/map/base_map.dart';
import '../../shared/widgets/app_toast.dart';
import '../map/data/map_providers.dart';
import '../route/data/google_maps.dart';
import '../route/route_result_screen.dart';

/// Walk lengths to pick from, minutes.
const coolWalkMinutes = [15, 30, 45, 60];

/// Finds loops; overridden in tests.
typedef CoolWalkFinder =
    Future<RouteResponse> Function(
      LatLng from, {
      required int minutes,
      required DateTime departure,
    });

final coolWalkFinderProvider = Provider<CoolWalkFinder>((ref) {
  final api = ref.watch(liveApiClientProvider);
  return (from, {required minutes, required departure}) {
    if (api is! LiveApiClient) {
      throw const ApiException(ApiErrorKind.server, 'no live client');
    }
    return api.loop(from, minutes: minutes, departure: departure);
  };
});

/// «Chłodny spacer»: a loop of N minutes from here and back through shade
/// and parks.
class CoolWalkScreen extends ConsumerStatefulWidget {
  const CoolWalkScreen({super.key, this.launch = _launch});

  final Future<bool> Function(Uri url) launch;

  static Future<bool> _launch(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  ConsumerState<CoolWalkScreen> createState() => _CoolWalkScreenState();
}

class _CoolWalkScreenState extends ConsumerState<CoolWalkScreen> {
  int _minutes = 30;
  bool _busy = false;
  bool _failed = false;
  RouteResponse? _result;
  RouteVariant? _selected;
  bool _fromCentre = false;

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final location = await ref.read(userLocationProvider.future);
    final from = location.position ?? lodzCenter;
    try {
      final result = await ref.read(coolWalkFinderProvider)(
        from,
        minutes: _minutes,
        departure: ref.read(clockProvider)(),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _selected = result.variants.first;
        _fromCentre = location.position == null;
      });
    } catch (e) {
      debugPrint('Cool walk: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go(RouteVariant v) async {
    final l10n = AppLocalizations.of(context);
    final ok = await widget
        .launch(GoogleMapsLink.walking(v.geometry))
        .catchError((Object _) => false);
    if (!ok && mounted) {
      showAppToast(context, l10n.routeMapsError, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.coolWalkTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(l10n.coolWalkIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.s12),
          Wrap(
            spacing: AppSizes.s8,
            runSpacing: AppSizes.s8,
            children: [
              for (final m in coolWalkMinutes)
                ChoiceChip(
                  key: Key('cool-walk-$m'),
                  label: Text(l10n.coolWalkMinutes(m)),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          FilledButton.icon(
            key: const Key('cool-walk-find'),
            onPressed: _busy ? null : _find,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.loop_rounded),
            label: Text(l10n.coolWalkFind),
          ),
          if (_failed) ...[
            const SizedBox(height: AppSizes.s12),
            Text(l10n.coolWalkError, style: theme.textTheme.bodyMedium),
          ],
          if (result != null && selected != null) ...[
            const SizedBox(height: AppSizes.s16),
            if (_fromCentre)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.s8),
                child: Text(
                  l10n.coolWalkFromCentre,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              child: SizedBox(
                height: 260,
                child: BaseMap(
                  key: ValueKey(result),
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints([
                        for (final v in result.variants) ...v.geometry,
                      ]),
                      padding: const EdgeInsets.all(AppSizes.s24),
                    ),
                    minZoom: MapTiles.minZoom,
                    maxZoom: MapTiles.maxZoom,
                  ),
                  children: [
                    PolylineLayer(polylines: routePolylines(result, selected)),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: selected.geometry.first,
                          width: 24,
                          height: 24,
                          child: const Icon(
                            Icons.home_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            for (final (i, v) in result.variants.indexed)
              Card(
                key: Key('cool-walk-option-$i'),
                color: identical(v, selected)
                    ? AppColors.primaryContainer
                    : null,
                child: ListTile(
                  onTap: () => setState(() => _selected = v),
                  leading: Icon(
                    i == 0 ? Icons.star_rounded : Icons.loop_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    i == 0 ? l10n.coolWalkBest : l10n.coolWalkOther(i),
                  ),
                  subtitle: Text(
                    l10n.coolWalkStats(
                      (v.durationS / 60).round(),
                      (v.distanceM / 1000).toStringAsFixed(1),
                      ((1 - v.sunShare) * 100).round(),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSizes.s8),
            FilledButton.icon(
              key: const Key('cool-walk-go'),
              onPressed: () => _go(selected),
              icon: const Icon(Icons.navigation_rounded),
              label: Text(l10n.routeGo),
            ),
          ],
        ],
      ),
    );
  }
}
