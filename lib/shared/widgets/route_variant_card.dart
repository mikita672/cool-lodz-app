import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_icons.dart';
import 'shade_bar.dart';

enum RouteVariant { shortest, shaded, compromise, alternative }

/// One route option on S07: name, time and distance, shade share in
/// Display style with a [ShadeBar], extra minutes and stops on the way.
class RouteVariantCard extends StatelessWidget {
  const RouteVariantCard({
    super.key,
    required this.variant,
    required this.minutes,
    required this.distanceKm,
    required this.shadePercent,
    required this.selected,
    required this.onTap,
    this.extraMinutes = 0,
    this.coolStops = 0,
    this.waterStops = 0,
    this.number = 1,
  });

  final RouteVariant variant;
  final int minutes;
  final double distanceKm;

  /// 0–100.
  final int shadePercent;

  /// Minutes more than the shortest route; 0 shows «Najszybsza trasa».
  final int extraMinutes;
  final int coolStops;
  final int waterStops;
  final bool selected;
  final VoidCallback onTap;

  /// Which alternative this is («Inna trasa 2»); ignored for the others.
  final int number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = switch (variant) {
      RouteVariant.shortest => l10n.dsRouteShortest,
      RouteVariant.shaded => l10n.dsRouteShaded,
      RouteVariant.compromise => l10n.dsRouteCompromise,
      RouteVariant.alternative => l10n.dsRouteAlternative(number),
    };
    final radius = BorderRadius.circular(AppSizes.radiusCard);
    final secondary = AppTextStyles.bodyS.copyWith(
      color: AppColors.onSurfaceVariant,
    );

    final senior = context.palette.senior;
    final extraText = extraMinutes > 0
        ? l10n.dsExtraMinutes(extraMinutes)
        : l10n.dsFastestRoute;
    final stops = [
      if (coolStops > 0)
        _Stop(
          // Primary, not `cool`: keeps 3:1 contrast on the selected card.
          icon: const CoolPlaceIcon(size: 18, color: AppColors.primary),
          text: senior ? l10n.dsCoolStopsLabel(coolStops) : '$coolStops',
          label: l10n.dsCoolStopsSemantics(coolStops),
        ),
      if (waterStops > 0)
        _Stop(
          icon: const WaterTapIcon(size: 18, color: AppColors.water),
          text: senior ? l10n.dsWaterStopsLabel(waterStops) : '$waterStops',
          label: l10n.dsWaterStopsSemantics(waterStops),
        ),
    ];

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.surfaceVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l10n.dsRouteMeta(minutes, distanceKm),
                              style: secondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.s8),
                      // The ShadeBar below announces the share to TalkBack.
                      ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              l10n.dsPercentValue(shadePercent),
                              style: AppTextStyles.display.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            Text(l10n.dsInShade, style: AppTextStyles.label),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s8),
                  ShadeBar(percent: shadePercent, showPercent: false),
                  const SizedBox(height: AppSizes.s8),
                  if (senior) ...[
                    // Senior: every icon gets a visible label.
                    Text(extraText, style: secondary),
                    if (stops.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.s4),
                      Wrap(
                        spacing: AppSizes.s12,
                        runSpacing: AppSizes.s4,
                        children: stops,
                      ),
                    ],
                  ] else
                    Row(
                      children: [
                        Expanded(child: Text(extraText, style: secondary)),
                        for (final stop in stops)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSizes.s8),
                            child: stop,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.text, required this.label});

  final Widget icon;

  /// The count, or «Miejsca chłodu: 2» in Senior mode.
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 2),
          Text(text, style: AppTextStyles.label),
        ],
      ),
    );
  }
}
