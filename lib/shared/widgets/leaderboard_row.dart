import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Ranking row (S13). [own] highlights the user's row and adds «Ty ·».
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    required this.points,
    this.own = false,
  });

  final int rank;

  /// Nickname or district name.
  final String name;
  final int points;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayName = own ? l10n.dsLeaderboardOwn(name) : name;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Semantics(
      label: l10n.dsLeaderboardRowSemantics(rank, displayName, points),
      selected: own,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s12,
          vertical: AppSizes.s8,
        ),
        decoration: BoxDecoration(
          color: own ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          border: own ? Border.all(color: AppColors.primary) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: AppTextStyles.bodyS.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            CircleAvatar(
              radius: 14,
              backgroundColor: own
                  ? AppColors.primary
                  : AppColors.surfaceVariant,
              child: Text(
                initial,
                textScaler: TextScaler.noScaling,
                style: AppTextStyles.label.copyWith(
                  color: own ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(child: Text(displayName, style: AppTextStyles.bodyS)),
            const SizedBox(width: AppSizes.s8),
            Text(
              l10n.dsPoints(points),
              style: AppTextStyles.bodyS.copyWith(
                fontWeight: FontWeight.w700,
                color: own ? AppColors.primary : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
