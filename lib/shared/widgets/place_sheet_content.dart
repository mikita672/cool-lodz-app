import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_button.dart';
import 'place_parts.dart';

export 'place_parts.dart' show PlaceAmenity, PlaceOpenStatus;

/// Body of the place bottom sheet (S05/S09). The drag handle and the
/// rounded top come from the bottom sheet theme.
class PlaceSheetContent extends StatelessWidget {
  const PlaceSheetContent({
    super.key,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.statusText,
    required this.onNavigate,
    required this.onReport,
    this.statusDetail,
    this.amenities = const [],
    this.inQuest = false,
  });

  final String name;

  /// Category and address, e.g. «Centrum handlowe · ul. Drewnowska 58».
  final String subtitle;
  final PlaceOpenStatus status;

  /// «Otwarte teraz» or «Zamknięte, otwarcie o 10:00».
  final String statusText;

  /// Today's hours, e.g. «Dziś 10:00–22:00».
  final String? statusDetail;
  final List<PlaceAmenity> amenities;
  final bool inQuest;
  final VoidCallback onNavigate;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        AppSizes.screenPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inQuest) ...[
            const QuestLetterChip(),
            const SizedBox(height: AppSizes.s8),
          ],
          Semantics(
            header: true,
            child: Text(name, style: AppTextStyles.titleM),
          ),
          const SizedBox(height: AppSizes.s4),
          Text(
            subtitle,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.s4),
          PlaceStatusLine(
            status: status,
            text: statusText,
            detail: statusDetail,
          ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: AppSizes.s16),
            Wrap(
              spacing: AppSizes.s12,
              runSpacing: AppSizes.s12,
              children: [
                for (final a in amenities)
                  SizedBox(width: 76, child: AmenityBadge(amenity: a)),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.s16),
          AppButton(
            label: l10n.dsNavigateThere,
            icon: Icons.navigation_rounded,
            onPressed: onNavigate,
            expand: true,
          ),
          const SizedBox(height: AppSizes.s8),
          AppButton(
            label: l10n.dsReportProblem,
            icon: Icons.flag_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onReport,
            expand: true,
          ),
        ],
      ),
    );
  }
}
