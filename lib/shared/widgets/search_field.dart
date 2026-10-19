import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// «Dokąd idziesz?» field on the map. It is only a button: tapping it opens
/// the route planner through [onTap].
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onTap, this.hint});

  final VoidCallback onTap;

  /// Defaults to «Dokąd idziesz?».
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = hint ?? AppLocalizations.of(context).dsSearchHint;
    final radius = BorderRadius.circular(AppSizes.radiusCard);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      // The tap action must live here: excludeSemantics drops the InkWell one.
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.onSurface.withValues(alpha: 0.3),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: context.palette.buttonHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s16,
                vertical: AppSizes.s12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
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
