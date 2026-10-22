import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

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

/// What the answers point to.
enum SymptomResult {
  /// Confusion, fainting or hot dry skin: heatstroke signs, call 112.
  urgent,

  /// Headache, dizziness, nausea, cramps, weakness: heat exhaustion.
  exhaustion,

  /// None of the typical signs.
  ok,
}

/// The first three questions are heatstroke red flags (NHS: call 999/112),
/// the last two heat exhaustion. Null until all five are answered.
SymptomResult? symptomResult(List<bool?> answers) {
  if (answers.length != 5 || answers.any((a) => a == null)) return null;
  if (answers.take(3).any((a) => a!)) return SymptomResult.urgent;
  if (answers.skip(3).any((a) => a!)) return SymptomResult.exhaustion;
  return SymptomResult.ok;
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

/// «Objawy przegrzania»: five yes/no questions, then what to do now.
class SymptomCheckScreen extends ConsumerStatefulWidget {
  const SymptomCheckScreen({super.key});

  @override
  ConsumerState<SymptomCheckScreen> createState() => _SymptomCheckScreenState();
}

class _SymptomCheckScreenState extends ConsumerState<SymptomCheckScreen> {
  final _answers = List<bool?>.filled(5, null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final questions = [
      l10n.symptomsQ1,
      l10n.symptomsQ2,
      l10n.symptomsQ3,
      l10n.symptomsQ4,
      l10n.symptomsQ5,
    ];
    final result = symptomResult(_answers);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.symptomsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(l10n.symptomsIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.s12),
          for (final (i, q) in questions.indexed) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: AppSizes.s8),
                    Row(
                      children: [
                        for (final yes in [true, false]) ...[
                          ChoiceChip(
                            key: Key('symptom-$i-${yes ? 'yes' : 'no'}'),
                            label: Text(
                              yes ? l10n.symptomsYes : l10n.symptomsNo,
                            ),
                            selected: _answers[i] == yes,
                            onSelected: (_) =>
                                setState(() => _answers[i] = yes),
                          ),
                          const SizedBox(width: AppSizes.s8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s8),
          ],
          const SizedBox(height: AppSizes.s8),
          if (result == null)
            Text(l10n.symptomsAnswerAll, style: theme.textTheme.bodySmall)
          else
            _Result(result: result),
          const SizedBox(height: AppSizes.s16),
          Text(
            l10n.symptomsDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.result});

  final SymptomResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (color, title, steps) = switch (result) {
      SymptomResult.urgent => (
        AppColors.heat3,
        l10n.symptomsUrgentTitle,
        [
          l10n.heatCheckAid2,
          l10n.heatCheckAid3,
          l10n.heatCheckAid4,
          l10n.heatCheckAid5,
        ],
      ),
      SymptomResult.exhaustion => (
        AppColors.heat2,
        l10n.symptomsExhaustionTitle,
        [
          l10n.symptomsExhaustion1,
          l10n.symptomsExhaustion2,
          l10n.symptomsExhaustion3,
          l10n.symptomsExhaustion4,
        ],
      ),
      SymptomResult.ok => (
        AppColors.success,
        l10n.symptomsOkTitle,
        [l10n.symptomsOkBody],
      ),
    };

    return Column(
      key: Key('symptoms-result-${result.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.s16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result == SymptomResult.urgent) ...[
                const SizedBox(height: AppSizes.s12),
                FilledButton.icon(
                  key: const Key('symptoms-call'),
                  onPressed: () => ref.read(dialEmergencyProvider)(),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(l10n.heatCheckCall112),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.heat3,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: AppSizes.s12),
                Text(l10n.symptomsUrgentLead, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: AppSizes.s8),
              for (final step in steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle, size: 8, color: color),
                      ),
                      const SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: Text(step, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s8),
        ReadAloudButton(
          text: () => [
            title,
            if (result == SymptomResult.urgent) l10n.symptomsUrgentLead,
            ...steps,
          ].join('. '),
        ),
        if (result != SymptomResult.urgent) ...[
          const SizedBox(height: AppSizes.s12),
          const _NearestPlace(),
        ],
      ],
    );
  }
}

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
            child: Text(l10n.symptomsNoPlace, style: theme.textTheme.bodySmall),
          ),
          TextButton(
            onPressed: () => context.go(Routes.coolPlaces),
            child: Text(l10n.symptomsShowPlaces),
          ),
        ],
      );
    }
    final (place, distance) = nearest;
    return Card(
      key: const Key('symptoms-nearest'),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.symptomsNearest, style: theme.textTheme.labelLarge),
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
              key: const Key('symptoms-go'),
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
