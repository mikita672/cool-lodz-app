import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/api/live/air_quality.dart';
import '../../core/heat/heat_risk.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/tts.dart';
import '../profile/data/comfort_profile_provider.dart';
import 'data/heat_risk_providers.dart';

String heatRiskLabel(HeatRiskLevel level, AppLocalizations l10n) =>
    switch (level) {
      HeatRiskLevel.low => l10n.heatRiskLow,
      HeatRiskLevel.moderate => l10n.heatRiskModerate,
      HeatRiskLevel.high => l10n.heatRiskHigh,
      HeatRiskLevel.extreme => l10n.heatRiskExtreme,
    };

Color heatRiskColor(HeatRiskLevel level) => switch (level) {
  HeatRiskLevel.low => AppColors.success,
  HeatRiskLevel.moderate => AppColors.heat1,
  HeatRiskLevel.high => AppColors.heat2,
  HeatRiskLevel.extreme => AppColors.heat3,
};

/// WHO UV categories.
String pollenName(PollenKind k, AppLocalizations l10n) => switch (k) {
  PollenKind.alder => l10n.pollenAlder,
  PollenKind.birch => l10n.pollenBirch,
  PollenKind.grass => l10n.pollenGrass,
  PollenKind.ragweed => l10n.pollenRagweed,
};

String pollenLevelName(PollenLevel l, AppLocalizations l10n) => switch (l) {
  PollenLevel.none => l10n.pollenNone,
  PollenLevel.low => l10n.pollenLow,
  PollenLevel.moderate => l10n.pollenModerate,
  PollenLevel.high => l10n.pollenHigh,
};

String aqiName(double aqi, AppLocalizations l10n) => switch (aqiBand(aqi)) {
  0 => l10n.aqiVeryGood,
  1 => l10n.aqiGood,
  2 => l10n.aqiModerate,
  3 => l10n.aqiPoor,
  4 => l10n.aqiVeryPoor,
  _ => l10n.aqiExtreme,
};

String uvCategory(double uv, AppLocalizations l10n) => switch (uv) {
  < 3 => l10n.heatRiskUvLow,
  < 6 => l10n.heatRiskUvModerate,
  < 8 => l10n.heatRiskUvHigh,
  < 11 => l10n.heatRiskUvVeryHigh,
  _ => l10n.heatRiskUvExtreme,
};

/// «Ryzyko upałowe: wysokie · 37°C» on the map; a tap opens the details.
class HeatRiskChip extends ConsumerWidget {
  const HeatRiskChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = ref.watch(heatRiskProvider).value;
    if (risk == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final dog = ref.watch(walksWithDogProvider);
    final level = heatRiskLabel(risk.level, l10n);
    final peak = risk.peakFeelsLike;
    final text = peak == null
        ? l10n.heatRiskChip(level)
        : l10n.heatRiskChipTemp(level, peak.round());
    final paws = dog && (risk.asphaltPeak ?? 0) >= asphaltCaution;
    return Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      child: InkWell(
        key: const Key('heat-risk-chip'),
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        onTap: () {
          // The rest of the day may have changed since it was computed.
          ref.invalidate(heatRiskProvider);
          showHeatRiskSheet(context);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.device_thermostat_rounded,
                  size: 20,
                  color: heatRiskColor(risk.level),
                ),
                const SizedBox(width: AppSizes.s4),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label,
                  ),
                ),
                if (paws) ...[
                  const SizedBox(width: AppSizes.s4),
                  const Icon(
                    Icons.pets_rounded,
                    size: 18,
                    color: AppColors.heat3,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showHeatRiskSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const HeatRiskSheet(),
    );

/// The details: how hot it feels, the hottest hours, UV, the pavement and
/// what to do for the user's profile.
class HeatRiskSheet extends ConsumerWidget {
  const HeatRiskSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final risk = ref.watch(heatRiskProvider).value;
    if (risk == null) return const SizedBox(height: 120);
    final profile = ref.watch(comfortProfileProvider);
    final dog = ref.watch(walksWithDogProvider);
    final demo = ref.watch(isDemoModeEffectiveProvider);
    final hm = DateFormat('H:mm', 'pl');
    final senior = profile.id == ProfileId.senior || profile.seniorMode;
    final air = ref.watch(airTodayProvider).value;

    final advice = <String>[
      ...switch (risk.level) {
        HeatRiskLevel.low => [l10n.heatRiskAdviceLow],
        HeatRiskLevel.moderate => [
          l10n.heatRiskAdviceWater,
          l10n.heatRiskAdviceShade,
        ],
        HeatRiskLevel.high => [
          l10n.heatRiskAdviceAvoid,
          l10n.heatRiskAdviceWater,
          l10n.heatRiskAdviceShade,
          l10n.heatRiskAdviceClothes,
        ],
        HeatRiskLevel.extreme => [
          l10n.heatRiskAdviceOnlyIfNeeded,
          l10n.heatRiskAdviceWater,
          l10n.heatRiskAdviceShade,
          l10n.heatRiskAdviceCheckOthers,
        ],
      },
      if (senior && risk.level != HeatRiskLevel.low) l10n.heatRiskAdviceSenior,
      if (profile.id == ProfileId.tourist &&
          risk.level.index >= HeatRiskLevel.high.index)
        l10n.heatRiskAdviceTourist,
      if (air != null && air.allergyWarning) l10n.heatRiskAdviceAllergy,
    ];

    final asphalt = risk.asphaltPeak;
    final uv = risk.uvMax;
    final facts = <(IconData, String)>[
      if (risk.feelsLikeNow case final f?)
        (Icons.thermostat_rounded, l10n.heatRiskFeelsNow(f.round())),
      if ((risk.peakFeelsLike, risk.peakAt) case (final p?, final at?))
        (
          Icons.trending_up_rounded,
          l10n.heatRiskPeak(p.round(), hm.format(at)),
        ),
      if ((risk.riskFrom, risk.riskTo) case (final from?, final to?))
        (
          Icons.schedule_rounded,
          l10n.heatRiskHours(hm.format(from), hm.format(to)),
        ),
      if (uv != null && uv >= 1)
        (
          Icons.wb_sunny_rounded,
          l10n.heatRiskUv(uv.round(), uvCategory(uv, l10n)),
        ),
      if (asphalt != null)
        (Icons.add_road_rounded, l10n.heatRiskAsphalt(asphalt.round())),
      if (air?.aqiMax case final aqi?)
        (Icons.air_rounded, l10n.heatRiskAir(aqiName(aqi, l10n), aqi.round())),
      if (air != null && air.pollen.isNotEmpty)
        (
          Icons.local_florist_rounded,
          air.pollenLevels.isEmpty
              ? l10n.heatRiskPollenNone
              : l10n.heatRiskPollen(
                  air.pollenLevels
                      .map(
                        (p) =>
                            '${pollenName(p.$1, l10n)} – '
                            '${pollenLevelName(p.$2, l10n)}',
                      )
                      .join(', '),
                ),
        ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('heat-risk-sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.heatRiskTitle, style: AppTextStyles.titleM),
            const SizedBox(height: AppSizes.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s12,
                vertical: AppSizes.s8,
              ),
              decoration: BoxDecoration(
                color: heatRiskColor(risk.level).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                border: Border.all(color: heatRiskColor(risk.level), width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.device_thermostat_rounded,
                    color: heatRiskColor(risk.level),
                    size: 32,
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: Text(
                      heatRiskLabel(risk.level, l10n).toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (risk.alertLevel > 0) ...[
              const SizedBox(height: AppSizes.s8),
              Text(
                l10n.dsHeatTitle(risk.alertLevel.clamp(1, 3)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.s8),
            for (final (icon, text) in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Text(text, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            if (uv != null && uv >= 3) ...[
              const SizedBox(height: AppSizes.s4),
              Text(
                uv >= 8 ? l10n.heatRiskUvAdviceHigh : l10n.heatRiskUvAdvice,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (dog && asphalt != null) ...[
              const SizedBox(height: AppSizes.s12),
              _PawNote(asphalt: asphalt),
            ],
            const SizedBox(height: AppSizes.s16),
            Text(l10n.heatRiskAdviceTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.s4),
            for (final a in advice)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(child: Text(a, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: AppSizes.s16),
            ReadAloudButton(
              text: () => [
                l10n.heatRiskTitle,
                heatRiskLabel(risk.level, l10n),
                for (final (_, text) in facts) text,
                l10n.heatRiskAdviceTitle,
                ...advice,
              ].join('. '),
            ),
            const SizedBox(height: AppSizes.s8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('heat-risk-day-plan'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.dayPlan);
                    },
                    icon: const Icon(Icons.event_note_rounded),
                    label: Text(
                      l10n.heatRiskDayPlan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('heat-risk-cool-walk'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.coolWalk);
                    },
                    icon: const Icon(Icons.loop_rounded),
                    label: Text(
                      l10n.coolWalkTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            OutlinedButton.icon(
              key: const Key('heat-risk-heat-symptoms'),
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.heatSymptoms);
              },
              icon: const Icon(Icons.medical_information_rounded),
              label: Text(l10n.heatRiskSymptoms),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(
              [
                if (demo) l10n.heatRiskDemo,
                if (risk.peakFeelsLike == null) l10n.heatRiskAlertOnly,
                l10n.heatRiskSource,
              ].join(' '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PawNote extends StatelessWidget {
  const _PawNote({required this.asphalt});

  final double asphalt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final danger = asphalt >= asphaltDanger;
    final caution = asphalt >= asphaltCaution;
    final color = danger
        ? AppColors.heat3
        : caution
        ? AppColors.heat2
        : AppColors.success;
    return Container(
      key: const Key('heat-risk-paws'),
      padding: const EdgeInsets.all(AppSizes.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pets_rounded, color: color),
          const SizedBox(width: AppSizes.s8),
          Expanded(
            child: Text(
              danger
                  ? l10n.heatRiskPawDanger(asphalt.round())
                  : caution
                  ? l10n.heatRiskPawCaution
                  : l10n.heatRiskPawOk,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
