import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Share of the route in shade: `primary` for shade, `sun` for the rest.
/// The number is shown next to the colour unless the parent already shows
/// it (the route card prints it in Display style).
class ShadeBar extends StatelessWidget {
  const ShadeBar({super.key, required this.percent, this.showPercent = true});

  /// 0–100.
  final int percent;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = percent.clamp(0, 100);
    return Semantics(
      label: l10n.dsShadeBarSemantics(value),
      excludeSemantics: true,
      child: Row(
        children: [
          const Icon(
            Icons.beach_access_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSizes.s8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.s4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (value > 0)
                      Expanded(
                        flex: value,
                        child: const ColoredBox(color: AppColors.primary),
                      ),
                    if (value < 100)
                      Expanded(
                        flex: 100 - value,
                        child: const ColoredBox(color: AppColors.sunTrack),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showPercent) ...[
            const SizedBox(width: AppSizes.s8),
            Text(
              l10n.dsPercentValue(value),
              style: AppTextStyles.bodyS.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
