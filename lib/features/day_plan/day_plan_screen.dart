import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../core/heat/heat_risk.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/tts.dart';
import '../cool_places/data/places_providers.dart';
import '../cool_places/place_format.dart';
import '../cool_places/place_sheet.dart';
import '../heat_risk/data/heat_risk_providers.dart';
import '../heat_risk/heat_risk_sheet.dart';
import '../map/data/map_providers.dart';
import 'day_plan.dart';

/// «Dzień w upale»: a day in Łódź around the hot hours, for tourists and
/// anyone with a free day.
class DayPlanScreen extends ConsumerWidget {
  const DayPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final risk = ref.watch(heatRiskProvider).value;
    final places = ref.watch(coolPlacesProvider).value ?? const <Place>[];
    final near = ref.watch(userLocationProvider).value?.position;
    final plan = dayPlan(day: now, risk: risk, places: places, near: near);
    final hm = DateFormat('H:mm', 'pl');
    final hot = risk != null && risk.level != HeatRiskLevel.low;

    String title(DayPart p) => switch (p) {
      DayPart.morning => l10n.dayPlanMorning,
      DayPart.midday => l10n.dayPlanMidday,
      DayPart.afternoon => l10n.dayPlanAfternoon,
      DayPart.evening => l10n.dayPlanEvening,
    };
    String body(DayPart p) => switch (p) {
      DayPart.morning => l10n.dayPlanMorningBody,
      DayPart.midday => l10n.dayPlanMiddayBody,
      DayPart.afternoon => l10n.dayPlanAfternoonBody,
      DayPart.evening => l10n.dayPlanEveningBody,
    };
    IconData icon(DayPart p) => switch (p) {
      DayPart.morning => Icons.wb_twilight_rounded,
      DayPart.midday => Icons.museum_rounded,
      DayPart.afternoon => Icons.water_rounded,
      DayPart.evening => Icons.nightlife_rounded,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dayPlanTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(
            hot
                ? l10n.dayPlanIntroHot(
                    heatRiskLabel(risk.level, l10n),
                    risk.peakFeelsLike?.round() ?? 0,
                  )
                : l10n.dayPlanIntro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: ReadAloudButton(
              text: () => [
                l10n.dayPlanTitle,
                for (final s in plan)
                  '${title(s.part)}, ${hm.format(s.from)}–${hm.format(s.to)}. '
                      '${body(s.part)}',
              ].join(' '),
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          for (final step in plan)
            Card(
              key: Key('day-plan-${step.part.name}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon(step.part), color: AppColors.primary),
                        const SizedBox(width: AppSizes.s8),
                        Expanded(
                          child: Text(
                            title(step.part),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${hm.format(step.from)}–${hm.format(step.to)}',
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.s4),
                    Text(body(step.part), style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSizes.s8),
                    ..._actions(context, ref, step, l10n),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    DayPlanStep step,
    AppLocalizations l10n,
  ) {
    void showLayer(MapLayer layer) {
      final layers = ref.read(mapLayersProvider.notifier);
      if (!ref.read(mapLayersProvider).contains(layer)) layers.toggle(layer);
      context.go(Routes.map);
    }

    return switch (step.part) {
      DayPart.morning => [
        OutlinedButton.icon(
          key: const Key('day-plan-walk'),
          onPressed: () => context.push(Routes.coolWalk),
          icon: const Icon(Icons.loop_rounded),
          label: Text(l10n.coolWalkTitle),
        ),
      ],
      DayPart.midday => [
        if (step.places.isEmpty)
          OutlinedButton.icon(
            onPressed: () => context.go(Routes.coolPlaces),
            icon: const Icon(Icons.ac_unit_rounded),
            label: Text(l10n.symptomsShowPlaces),
          )
        else
          for (final p in step.places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ac_unit_rounded, color: AppColors.cool),
              title: Text(p.title(l10n)),
              trailing: IconButton(
                tooltip: l10n.dsNavigateThere,
                icon: const Icon(Icons.directions_walk_rounded),
                onPressed: () => navigateToPlace(context, ref, p),
              ),
              onTap: () => showPlaceSheet(context, p),
            ),
      ],
      DayPart.afternoon => [
        OutlinedButton.icon(
          key: const Key('day-plan-water'),
          onPressed: () => showLayer(MapLayer.water),
          icon: const Icon(Icons.water_drop_rounded),
          label: Text(l10n.dayPlanShowWater),
        ),
      ],
      DayPart.evening => [
        OutlinedButton.icon(
          key: const Key('day-plan-night'),
          onPressed: () => showLayer(MapLayer.night),
          icon: const Icon(Icons.nightlife_rounded),
          label: Text(l10n.dayPlanShowNight),
        ),
      ],
    };
  }
}
