import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Badge in the grid (S12): earned in colour, locked in grey with a lock
/// and the condition to unlock it.
class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.icon,
    required this.name,
    required this.earned,
    required this.caption,
    this.color = AppColors.primary,
    this.onTap,
  });

  final IconData icon;
  final String name;
  final bool earned;

  /// «Zdobyta 12.10» when earned, the unlock condition when locked.
  final String caption;

  /// Accent of an earned badge.
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(AppSizes.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? Color.alphaBlend(
                      color.withValues(alpha: 0.18),
                      AppColors.surface,
                    )
                  : AppColors.surfaceVariant,
              border: earned ? Border.all(color: color, width: 2) : null,
            ),
            child: Icon(
              earned ? icon : Icons.lock_rounded,
              color: earned ? color : AppColors.muted,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label:
          '${earned ? l10n.dsBadgeEarnedSemantics(name) : l10n.dsBadgeLockedSemantics(name)}. $caption',
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              child: content,
            ),
    );
  }
}
