import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game/challenges.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_rules.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/badge_unlocked_dialog.dart';
import '../game/game_service.dart';
import '../quest/challenge_card.dart';

/// Name, unlock condition, description, icon and colour of a badge.
@immutable
class BadgeInfo {
  const BadgeInfo({
    required this.name,
    required this.condition,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String name;
  final String condition;
  final String description;
  final IconData icon;
  final Color color;
}

BadgeInfo badgeInfo(
  GameBadge badge,
  AppLocalizations l10n, {
  int coolGuardPlaces = GameConfig.badgeCoolGuardPlaces,
}) => switch (badge) {
  GameBadge.firstStep => BadgeInfo(
    name: l10n.badgeFirstStepName,
    condition: l10n.badgeFirstStepCondition,
    description: l10n.badgeFirstStepDescription,
    icon: Icons.directions_walk_rounded,
    color: AppColors.primary,
  ),
  GameBadge.shadedTen => BadgeInfo(
    name: l10n.badgeShadedTenName,
    condition: l10n.badgeShadedTenCondition,
    description: l10n.badgeShadedTenDescription,
    icon: Icons.wb_shade_rounded,
    color: AppColors.primary,
  ),
  GameBadge.coolGuard => BadgeInfo(
    name: l10n.badgeCoolGuardName,
    condition: l10n.badgeCoolGuardCondition(coolGuardPlaces),
    description: l10n.badgeCoolGuardDescription,
    icon: Icons.ac_unit_rounded,
    color: AppColors.primary,
  ),
  GameBadge.earlyBird => BadgeInfo(
    name: l10n.badgeEarlyBirdName,
    condition: l10n.badgeEarlyBirdCondition,
    description: l10n.badgeEarlyBirdDescription,
    icon: Icons.wb_twilight_rounded,
    color: AppColors.heat2,
  ),
  GameBadge.eveningWalker => BadgeInfo(
    name: l10n.badgeEveningName,
    condition: l10n.badgeEveningCondition,
    description: l10n.badgeEveningDescription,
    icon: Icons.nights_stay_rounded,
    color: AppColors.primary,
  ),
  GameBadge.parkHunter => BadgeInfo(
    name: l10n.badgeParkHunterName,
    condition: l10n.badgeParkHunterCondition,
    description: l10n.badgeParkHunterDescription,
    icon: Icons.park_rounded,
    color: AppColors.green,
  ),
  GameBadge.cityHelper => BadgeInfo(
    name: l10n.badgeCityHelperName,
    condition: l10n.badgeCityHelperCondition,
    description: l10n.badgeCityHelperDescription,
    icon: Icons.volunteer_activism_rounded,
    color: AppColors.green,
  ),
};

/// Shows what [award] gave: [message] (or «+N pkt») as a toast, then one
/// «Nowa odznaka!» dialog per new badge.
Future<void> showAwardFeedback(
  BuildContext context,
  GameAward award, {
  String? message,
}) async {
  final l10n = AppLocalizations.of(context);
  final points = award.points - award.pointsFor(PointsType.badge);
  if (message != null || points > 0) {
    showAppToast(
      context,
      message ?? l10n.gamePointsToast(points),
      kind: ToastKind.success,
    );
  }
  if (award.challenge case final c? when context.mounted) {
    await showBadgeUnlockedDialog(
      context,
      icon: challengeIcon(c.challenge.kind),
      name: l10n.challengeUnlocked,
      description: challengeText(c.challenge, c.target, l10n),
      points: Challenge.bonus,
      kicker: l10n.challengeTitle,
    );
  }
  for (final badge in GameBadge.values) {
    if (!award.badges.contains(badge) || !context.mounted) continue;
    final info = badgeInfo(badge, l10n);
    await showBadgeUnlockedDialog(
      context,
      icon: info.icon,
      name: info.name,
      description: info.description,
      points: GameConfig.pointsBadge,
    );
  }
}
