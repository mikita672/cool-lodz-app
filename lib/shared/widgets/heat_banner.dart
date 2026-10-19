import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// IMGW heat warning, levels 1–3. Level 1 and 2 backgrounds are light, so
/// they use dark text; level 3 uses white (both pass WCAG AA).
class HeatBanner extends StatelessWidget {
  const HeatBanner({
    super.key,
    required this.level,
    this.title,
    this.subtitle,
    this.onTap,
  });

  /// 1, 2 or 3.
  final int level;

  /// Defaults to «Ostrzeżenie przed upałem, stopień N».
  final String? title;

  /// E.g. «IMGW · do 20:00».
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lvl = level.clamp(1, 3);
    final heading = title ?? AppLocalizations.of(context).dsHeatTitle(lvl);
    final foreground = lvl == 3 ? AppColors.onPrimary : AppColors.onSurface;
    final radius = BorderRadius.circular(AppSizes.radiusCard);

    return Semantics(
      button: onTap != null,
      liveRegion: true,
      label: [heading, ?subtitle].join('. '),
      excludeSemantics: true,
      // The tap action must live here: excludeSemantics drops the InkWell one.
      onTap: onTap,
      child: Material(
        color: AppColors.heat(lvl),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s12,
                vertical: AppSizes.s8,
              ),
              child: Row(
                children: [
                  Icon(
                    lvl == 3
                        ? Icons.warning_rounded
                        : Icons.device_thermostat_rounded,
                    color: foreground,
                    size: 20,
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: AppTextStyles.bodyS.copyWith(
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: AppTextStyles.label.copyWith(
                              color: foreground,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
