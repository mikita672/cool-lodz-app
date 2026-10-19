import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_icons.dart';

enum MapPinType { cool, water, bench, questLetter }

/// Round marker for the map. The visible circle is [size]; the tap area is
/// at least 48 dp. In Senior mode a short label is shown under the circle.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.type,
    this.letter = 'L',
    this.size = 32,
    this.onTap,
    this.semanticLabel,
    this.showLabel,
  });

  final MapPinType type;

  /// Letter shown on a [MapPinType.questLetter] pin.
  final String letter;
  final double size;
  final VoidCallback? onTap;

  /// Defaults to the pin type, e.g. «Miejsce chłodu».
  final String? semanticLabel;

  /// Visible label under the pin; defaults to on in Senior mode.
  final bool? showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final glyph = size * 0.55;
    // Glyph colours keep at least 3:1 contrast with the circle.
    final (
      Color background,
      Widget child,
      String label,
      String short,
    ) = switch (type) {
      MapPinType.cool => (
        AppColors.cool,
        Icon(Icons.ac_unit_rounded, size: glyph, color: AppColors.onSurface),
        l10n.dsIconCoolPlace,
        l10n.dsPinLabelCool,
      ),
      MapPinType.water => (
        AppColors.water,
        Icon(Icons.water_drop_rounded, size: glyph, color: AppColors.onPrimary),
        l10n.dsIconWaterTap,
        l10n.dsPinLabelWater,
      ),
      MapPinType.bench => (
        AppColors.surface,
        Icon(
          Icons.event_seat_rounded,
          size: glyph,
          color: AppColors.onSurfaceVariant,
        ),
        l10n.dsPinBench,
        l10n.dsPinBench,
      ),
      MapPinType.questLetter => (
        AppColors.primary,
        QuestLetterIcon(letter: letter, size: glyph),
        l10n.dsPinQuestLetter(letter),
        l10n.dsPinLabelQuest(letter),
      ),
    };
    final labelled = showLabel ?? context.palette.senior;

    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: type == MapPinType.bench ? AppColors.muted : AppColors.surface,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    return Semantics(
      label: semanticLabel ?? label,
      button: onTap != null,
      excludeSemantics: true,
      // The tap action must live here: excludeSemantics drops the detector's.
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.minTouchTarget,
            minHeight: AppSizes.minTouchTarget,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              circle,
              if (labelled)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.s4),
                  ),
                  child: Text(short, style: AppTextStyles.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
