import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/game/challenges.dart';
import '../../l10n/app_localizations.dart';
import '../game/game_service.dart';

/// «Przejdź 3 trasy z co najmniej 60% cienia» for [target].
String challengeText(Challenge c, int target, AppLocalizations l10n) =>
    switch (c.kind) {
      ChallengeKind.shadedRoutes => l10n.challengeShadedRoutes(target),
      ChallengeKind.coolScans => l10n.challengeCoolScans(target),
      ChallengeKind.distance => l10n.challengeDistance(target),
      ChallengeKind.coolHours => l10n.challengeCoolHours(target),
      ChallengeKind.waterRoutes => l10n.challengeWaterRoutes(target),
    };

IconData challengeIcon(ChallengeKind kind) => switch (kind) {
  ChallengeKind.shadedRoutes => Icons.park_rounded,
  ChallengeKind.coolScans => Icons.qr_code_2_rounded,
  ChallengeKind.distance => Icons.straighten_rounded,
  ChallengeKind.coolHours => Icons.wb_twilight_rounded,
  ChallengeKind.waterRoutes => Icons.water_drop_rounded,
};

/// S10: this week's challenge, progress, bonus and days left.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(challengeProvider).value;
    if (state == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final done = state.complete;
    final shown = state.progress.clamp(0, state.target);

    return Card(
      key: const Key('challenge-card'),
      color: done ? AppColors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  challengeIcon(state.challenge.kind),
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.challengeTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        done
                            ? l10n.challengeDone(Challenge.bonus)
                            : l10n.challengeBonus(Challenge.bonus),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.successText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              challengeText(state.challenge, state.target, l10n),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSizes.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const Key('challenge-progress'),
                value: state.target == 0 ? 1 : shown / state.target,
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.s4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.challengeProgress(shown, state.target),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!done)
                  Flexible(
                    child: Text(
                      l10n.challengeDaysLeft(state.daysLeft),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            if (!done) ...[
              const SizedBox(height: AppSizes.s8),
              Text(
                l10n.challengeHint,
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
