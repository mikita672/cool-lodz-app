import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// «Brak połączenia z serwerem, pokazujemy ostatnie dane».
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.message});

  /// Defaults to the standard offline text.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? AppLocalizations.of(context).dsOfflineBanner;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s12,
          vertical: AppSizes.s8,
        ),
        decoration: BoxDecoration(
          color: AppColors.onSurfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.onPrimary,
              size: 18,
            ),
            const SizedBox(width: AppSizes.s8),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.label.copyWith(color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
