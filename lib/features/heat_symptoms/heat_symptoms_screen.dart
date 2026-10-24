import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/tts.dart';
import '../cool_places/data/places_providers.dart';
import '../cool_places/place_format.dart';
import '../cool_places/place_sheet.dart';
import '../heat_guard/heat_check_screen.dart';
import '../map/data/map_providers.dart';

/// The pages the texts come from (checked 24.10.2026).
abstract final class HeatSymptomsSources {
  static final mz = Uri.parse(
    'https://www.gov.pl/web/zdrowie/udar-sloneczny-udar-cieplny-przegrzanie-cieplne',
  );
  static final nhs = Uri.parse(
    'https://www.nhs.uk/conditions/heat-exhaustion-heatstroke/',
  );
}

/// The nearest cool place open at [now], with its distance in metres.
(Place, double)? nearestOpenPlace(
  Iterable<Place> places,
  LatLng from,
  DateTime now,
) {
  (Place, double)? best;
  for (final p in places) {
    if (!p.isOpenAt(now)) continue;
    final d = distanceTo(p, from);
    if (best == null || d < best.$2) best = (p, d);
  }
  return best;
}

/// «Objawy upału»: information only. Warning signs and first aid quoted
/// from the Ministry of Health and the NHS, the 112 button (opens the
/// dialer) and the nearest open cool place. No questions, no assessment
/// of the user and nothing is stored.
class HeatSymptomsScreen extends ConsumerWidget {
  const HeatSymptomsScreen({super.key, this.launch = _launch});

  /// Opens a source page (injected in tests).
  final Future<bool> Function(Uri url) launch;

  static Future<bool> _launch(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final call = [
      l10n.heatSymptomsCall1,
      l10n.heatSymptomsCall2,
      l10n.heatSymptomsCall3,
      l10n.heatSymptomsCall4,
      l10n.heatSymptomsCall5,
      l10n.heatSymptomsCall6,
      l10n.heatSymptomsCall7,
      l10n.heatSymptomsCall8,
    ];
    final wait = [l10n.heatSymptomsWait1, l10n.heatSymptomsWait2];
    final exhaustion = [
      l10n.heatSymptomsExh1,
      l10n.heatSymptomsExh2,
      l10n.heatSymptomsExh3,
      l10n.heatSymptomsExh4,
      l10n.heatSymptomsExh5,
      l10n.heatSymptomsExh6,
      l10n.heatSymptomsExh7,
      l10n.heatSymptomsExh8,
      l10n.heatSymptomsExh9,
    ];
    final aid = [
      l10n.heatSymptomsAid1,
      l10n.heatSymptomsAid2,
      l10n.heatSymptomsAid3,
      l10n.heatSymptomsAid4,
      l10n.heatSymptomsAid5,
    ];
    final note = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.heatSymptomsTitle)),
      body: ListView(
        key: const Key('heat-symptoms'),
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(l10n.heatSymptomsIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: ReadAloudButton(
              text: () => [
                l10n.heatSymptomsTitle,
                l10n.heatSymptomsIntro,
                l10n.heatSymptomsCallTitle,
                ...call,
                l10n.heatSymptomsWaitTitle,
                ...wait,
                l10n.heatSymptomsExhTitle,
                ...exhaustion,
                l10n.heatSymptomsAidTitle,
                ...aid,
                l10n.heatSymptomsAid6,
                l10n.heatSymptomsWhen,
              ].join('. '),
            ),
          ),
          const SizedBox(height: AppSizes.s12),
          _Section(
            key: const Key('heat-symptoms-112'),
            color: AppColors.heat3,
            title: l10n.heatSymptomsCallTitle,
            items: call,
            source: l10n.heatSymptomsCallSource,
            children: [
              const SizedBox(height: AppSizes.s12),
              FilledButton.icon(
                key: const Key('heat-symptoms-call'),
                onPressed: () => ref.read(dialEmergencyProvider)(),
                icon: const Icon(Icons.call_rounded),
                label: Text(l10n.heatSymptomsCall112),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.heat3,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              const SizedBox(height: AppSizes.s4),
              Text(l10n.heatSymptomsCallNote, style: note),
              const SizedBox(height: AppSizes.s12),
              Text(
                l10n.heatSymptomsWaitTitle,
                style: theme.textTheme.titleSmall,
              ),
              for (final w in wait) _Item(w, color: AppColors.heat3),
              Text(l10n.heatSymptomsWaitSource, style: note),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          _Section(
            key: const Key('heat-symptoms-exhaustion'),
            color: AppColors.heat2,
            title: l10n.heatSymptomsExhTitle,
            items: exhaustion,
            source: l10n.heatSymptomsExhSource,
            children: [
              const SizedBox(height: AppSizes.s12),
              Text(
                l10n.heatSymptomsAidTitle,
                style: theme.textTheme.titleSmall,
              ),
              for (final a in aid) _Item(a, color: AppColors.heat2),
              _Item(l10n.heatSymptomsAid6, color: AppColors.heat2),
              const SizedBox(height: AppSizes.s8),
              Text(l10n.heatSymptomsWhen, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSizes.s4),
              Text(l10n.heatSymptomsAidSource, style: note),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          const _NearestPlace(),
          const SizedBox(height: AppSizes.s16),
          Semantics(
            header: true,
            child: Text(
              l10n.heatSymptomsSourcesTitle,
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final (key, text, url) in [
            ('mz', l10n.heatSymptomsSourceMz, HeatSymptomsSources.mz),
            ('nhs', l10n.heatSymptomsSourceNhs, HeatSymptomsSources.nhs),
          ])
            ListTile(
              key: Key('heat-symptoms-source-$key'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(text, style: theme.textTheme.bodySmall),
              subtitle: Text(
                url.toString(),
                style: note?.copyWith(decoration: TextDecoration.underline),
              ),
              onTap: () => launch(url),
            ),
          const SizedBox(height: AppSizes.s8),
          Text(
            l10n.medicalNote,
            key: const Key('heat-symptoms-footer'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.color,
    required this.title,
    required this.items,
    required this.source,
    this.children = const [],
  });

  final Color color;
  final String title;
  final List<String> items;
  final String source;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          for (final i in items) _Item(i, color: color),
          Text(
            source,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 8, color: color),
        ),
        const SizedBox(width: AppSizes.s8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// A fact, not advice: where the nearest cool place open now is.
class _NearestPlace extends ConsumerWidget {
  const _NearestPlace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final position = ref.watch(userLocationProvider).value?.position;
    final places = ref.watch(coolPlacesProvider).value ?? const <Place>[];
    final nearest = position == null
        ? null
        : nearestOpenPlace(places, position, ref.read(clockProvider)());
    if (nearest == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.heatSymptomsNoPlace,
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => context.go(Routes.coolPlaces),
            child: Text(l10n.showCoolPlaces),
          ),
        ],
      );
    }
    final (place, distance) = nearest;
    return Card(
      key: const Key('heat-symptoms-nearest'),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.heatSymptomsNearest, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSizes.s4),
            Row(
              children: [
                const Icon(Icons.ac_unit_rounded, color: AppColors.cool),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Text(
                    place.name ?? '',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatDistance(distance, l10n),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            FilledButton.icon(
              key: const Key('heat-symptoms-go'),
              onPressed: () => navigateToPlace(context, ref, place),
              icon: const Icon(Icons.directions_walk_rounded),
              label: Text(l10n.dsNavigateThere),
            ),
          ],
        ),
      ),
    );
  }
}
