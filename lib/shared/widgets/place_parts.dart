import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_icons.dart';

/// Pieces shared by [PlaceListItem] and [PlaceSheetContent].

enum PlaceOpenStatus { open, closed }

enum PlaceAmenity { airConditioning, water, toilet, accessible }

extension PlaceAmenityUi on PlaceAmenity {
  IconData get icon => switch (this) {
    PlaceAmenity.airConditioning => Icons.ac_unit_rounded,
    PlaceAmenity.water => Icons.water_drop_rounded,
    PlaceAmenity.toilet => Icons.wc_rounded,
    PlaceAmenity.accessible => Icons.accessible_rounded,
  };

  String label(AppLocalizations l10n) => switch (this) {
    PlaceAmenity.airConditioning => l10n.dsAmenityAirConditioning,
    PlaceAmenity.water => l10n.dsAmenityWater,
    PlaceAmenity.toilet => l10n.dsAmenityToilet,
    PlaceAmenity.accessible => l10n.dsAmenityAccessible,
  };
}

/// Coloured dot + status text («Otwarte teraz»), optionally followed by
/// grey details («Dziś 10:00–22:00»). The text carries the meaning, the
/// colour only repeats it.
class PlaceStatusLine extends StatelessWidget {
  const PlaceStatusLine({
    super.key,
    required this.status,
    required this.text,
    this.detail,
  });

  final PlaceOpenStatus status;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final color = status == PlaceOpenStatus.open
        ? AppColors.success
        : AppColors.error;
    final textScaler = MediaQuery.textScalerOf(context);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: textScaler.scale(8),
                height: textScaler.scale(8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          TextSpan(
            text: text,
            style: AppTextStyles.bodyS.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null)
            TextSpan(
              text: ' · $detail',
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// «Litera do zdobycia» chip for places that are part of the quest.
class QuestLetterChip extends StatelessWidget {
  const QuestLetterChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const QuestLetterIcon(size: 14),
          const SizedBox(width: AppSizes.s4),
          Flexible(
            child: Text(
              AppLocalizations.of(context).dsLetterToCollect,
              style: AppTextStyles.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round amenity icon with its label underneath.
class AmenityBadge extends StatelessWidget {
  const AmenityBadge({super.key, required this.amenity});

  final PlaceAmenity amenity;

  @override
  Widget build(BuildContext context) {
    final label = amenity.label(AppLocalizations.of(context));
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(amenity.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: AppSizes.s4),
          Text(label, style: AppTextStyles.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
