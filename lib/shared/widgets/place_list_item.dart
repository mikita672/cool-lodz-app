import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'app_icons.dart';
import 'place_parts.dart';

export 'place_parts.dart' show PlaceAmenity, PlaceOpenStatus;

/// Row in the list of cool places (S09).
class PlaceListItem extends StatelessWidget {
  const PlaceListItem({
    super.key,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.statusText,
    required this.onTap,
    this.inQuest = false,
  });

  final String name;

  /// Category and distance, e.g. «Biblioteka · 350 m».
  final String subtitle;
  final PlaceOpenStatus status;

  /// E.g. «Otwarte teraz · do 19:00» or «Zamknięte, otwarcie o 10:00».
  final String statusText;
  final bool inQuest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
                vertical: AppSizes.s12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const CoolPlaceIcon(
                      size: 22,
                      color: AppColors.primary,
                      innerColor: AppColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),
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
                          subtitle,
                          style: AppTextStyles.bodyS.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        PlaceStatusLine(status: status, text: statusText),
                        if (inQuest) ...[
                          const SizedBox(height: AppSizes.s4),
                          const QuestLetterChip(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceVariant,
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
