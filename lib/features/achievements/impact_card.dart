import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/game/impact.dart';
import '../../l10n/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import '../game/data/game_repository.dart';
import '../game/game_service.dart';

/// «Twój wpływ» from the user's routes and scans; refreshed when the
/// points change.
final impactProvider = FutureProvider.autoDispose<Impact>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Impact();
  ref.watch(playerProvider.select((p) => p.value?.points));
  final history = await ref.watch(gameRepositoryProvider).history(uid);
  return Impact.from(history);
});

/// S12 card: walks, distance, minutes in shade, sun avoided, water on the
/// way, cool places and CO₂ saved compared with a car.
class ImpactCard extends ConsumerWidget {
  const ImpactCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final impact = ref.watch(impactProvider).value;
    if (impact == null) return const SizedBox.shrink();
    final one = NumberFormat('0.0', 'pl');
    final tiles = <(IconData, String, String)>[
      (Icons.directions_walk_rounded, '${impact.walks}', l10n.impactWalks),
      (
        Icons.straighten_rounded,
        l10n.impactKm(one.format(impact.distanceKm)),
        l10n.impactDistance,
      ),
      (
        Icons.park_rounded,
        l10n.impactMinutes(impact.minutesInShade),
        l10n.impactShade,
      ),
      if (impact.sunAvoidedMinutes case final m?)
        (Icons.wb_sunny_outlined, l10n.impactMinutes(m), l10n.impactSunAvoided),
      (Icons.water_drop_rounded, '${impact.waterPoints}', l10n.impactWater),
      (Icons.ac_unit_rounded, '${impact.coolPlaces}', l10n.impactCool),
      (
        Icons.eco_rounded,
        l10n.impactKg(one.format(impact.co2SavedKg)),
        l10n.impactCo2,
      ),
    ];

    return Card(
      key: const Key('impact-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.impactTitle, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSizes.s8),
            if (impact.walks == 0)
              Text(l10n.impactEmpty, style: theme.textTheme.bodyMedium)
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - AppSizes.s8) / 2;
                  return Wrap(
                    spacing: AppSizes.s8,
                    runSpacing: AppSizes.s8,
                    children: [
                      for (final (icon, value, label) in tiles)
                        SizedBox(
                          width: width,
                          child: _Stat(icon: icon, value: value, label: label),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                l10n.impactNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.s12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSizes.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
