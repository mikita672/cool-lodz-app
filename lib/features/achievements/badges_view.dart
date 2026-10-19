import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_rules.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/badge_tile.dart';
import '../../shared/widgets/error_state.dart';
import '../game/game_service.dart';
import 'badge_info.dart';

/// S12 Odznaki i punkty: total points, the last 10 entries and the badge
/// grid (3 per row; earned in colour, locked grey with the condition).
class BadgesView extends ConsumerWidget {
  const BadgesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = ref.watch(playerProvider);
    final log = ref.watch(recentPointsProvider).value ?? const [];
    final coolGuard = ref.watch(isDemoModeEffectiveProvider)
        ? GameConfig.demoBadgeCoolGuardPlaces
        : GameConfig.badgeCoolGuardPlaces;

    if (player.hasError && !player.hasValue) {
      return Center(
        child: ErrorState(
          title: l10n.badgesLoadError,
          onRetry: () => ref.invalidate(playerProvider),
        ),
      );
    }
    final state = player.value;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.s8,
        AppSizes.screenPadding,
        AppSizes.s24,
      ),
      children: [
        Card(
          color: AppColors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.badgesTotal, style: theme.textTheme.bodyMedium),
                Text(
                  l10n.dsPoints(state.points),
                  key: const Key('badges-total'),
                  style: theme.textTheme.displaySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.s24),
        Semantics(
          header: true,
          child: Text(l10n.badgesTitle, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSizes.s12),
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            final width =
                (constraints.maxWidth - AppSizes.s8 * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSizes.s8,
              runSpacing: AppSizes.s8,
              children: [
                for (final badge in GameBadge.values)
                  SizedBox(
                    width: width,
                    child: _tile(
                      badge,
                      earned: state.badges.contains(badge),
                      l10n: l10n,
                      coolGuard: coolGuard,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSizes.s24),
        Semantics(
          header: true,
          child: Text(l10n.badgesRecent, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSizes.s8),
        if (log.isEmpty)
          Text(l10n.badgesNoPoints, style: theme.textTheme.bodySmall)
        else
          for (final e in log)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_logIcon(e.type), color: AppColors.primary),
              title: Text(_logLabel(e, l10n)),
              subtitle: e.at == null ? null : Text(_formatAt(e.at!)),
              trailing: Text(
                l10n.dsPointsGained(e.points),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.successText,
                ),
              ),
            ),
      ],
    );
  }

  static Widget _tile(
    GameBadge badge, {
    required bool earned,
    required AppLocalizations l10n,
    required int coolGuard,
  }) {
    final info = badgeInfo(badge, l10n, coolGuardPlaces: coolGuard);
    return BadgeTile(
      key: Key('badge-${badge.id}'),
      icon: info.icon,
      name: info.name,
      earned: earned,
      caption: earned ? l10n.badgesEarned : info.condition,
      color: info.color,
    );
  }

  static IconData _logIcon(PointsType type) => switch (type) {
    PointsType.route => Icons.directions_walk_rounded,
    PointsType.scan => Icons.qr_code_2_rounded,
    PointsType.password => Icons.password_rounded,
    PointsType.badge => Icons.emoji_events_rounded,
    PointsType.report => Icons.flag_rounded,
  };

  static String _logLabel(PointsEntry e, AppLocalizations l10n) =>
      switch (e.type) {
        PointsType.route => l10n.badgesLogRoute,
        PointsType.scan => l10n.badgesLogScan,
        PointsType.password => l10n.badgesLogPassword,
        PointsType.badge => l10n.badgesLogBadge(switch (GameBadge.fromId(
          e.refId ?? '',
        )) {
          final b? => badgeInfo(b, l10n).name,
          null => e.refId ?? '',
        }),
        PointsType.report => l10n.badgesLogReport,
      };

  static String _formatAt(DateTime at) {
    final l = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}, ${l.hour}:${two(l.minute)}';
  }
}
