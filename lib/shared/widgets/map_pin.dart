import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_icons.dart';

enum MapPinType { cool, water, bench, questLetter }

/// Round marker for the map. The visible circle is [size]; the tap area is
/// at least 48 dp.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.type,
    this.letter = 'L',
    this.size = 32,
    this.onTap,
    this.semanticLabel,
  });

  final MapPinType type;

  /// Letter shown on a [MapPinType.questLetter] pin.
  final String letter;
  final double size;
  final VoidCallback? onTap;

  /// Defaults to the pin type, e.g. «Miejsce chłodu».
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final glyph = size * 0.55;
    final (Color background, Widget child, String label) = switch (type) {
      MapPinType.cool => (
        AppColors.cool,
        Icon(Icons.ac_unit_rounded, size: glyph, color: AppColors.onPrimary),
        l10n.dsIconCoolPlace,
      ),
      MapPinType.water => (
        AppColors.water,
        Icon(Icons.water_drop_rounded, size: glyph, color: AppColors.onPrimary),
        l10n.dsIconWaterTap,
      ),
      MapPinType.bench => (
        AppColors.surface,
        Icon(
          Icons.event_seat_rounded,
          size: glyph,
          color: AppColors.onSurfaceVariant,
        ),
        l10n.dsPinBench,
      ),
      MapPinType.questLetter => (
        AppColors.primary,
        QuestLetterIcon(letter: letter, size: glyph),
        l10n.dsPinQuestLetter(letter),
      ),
    };

    final hit = size < AppSizes.minTouchTarget ? AppSizes.minTouchTarget : size;
    return Semantics(
      label: semanticLabel ?? label,
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: type == MapPinType.bench
                      ? AppColors.muted
                      : AppColors.surface,
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
            ),
          ),
        ),
      ),
    );
  }
}
