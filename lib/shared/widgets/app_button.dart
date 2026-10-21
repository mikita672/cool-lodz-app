import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

enum AppButtonVariant { primary, secondary, text }

/// Button from the design system. Height comes from the theme
/// (52 dp, 60 dp in Senior mode).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Shows a spinner instead of the icon and ignores taps.
  final bool loading;

  /// Stretch to the full available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final callback = loading ? null : onPressed;
    final size = Size(AppSizes.minTouchTarget, palette.buttonHeight);
    final spinnerColor = variant == AppButtonVariant.primary
        ? AppColors.onPrimary
        : AppColors.primary;

    final Widget? leading = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: spinnerColor,
            ),
          )
        : (icon == null ? null : Icon(icon, size: 20));
    // One line always: a long label shrinks instead of wrapping.
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, textAlign: TextAlign.center),
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton.icon(
        onPressed: callback,
        style: FilledButton.styleFrom(
          minimumSize: size,
          // Keep the brand colour while loading.
          disabledBackgroundColor: loading ? AppColors.primary : null,
          disabledForegroundColor: loading ? AppColors.onPrimary : null,
        ),
        icon: leading,
        label: text,
      ),
      AppButtonVariant.secondary => OutlinedButton.icon(
        onPressed: callback,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          side: BorderSide(
            color: callback == null && !loading
                ? AppColors.muted
                : AppColors.primary,
          ),
        ),
        icon: leading,
        label: text,
      ),
      AppButtonVariant.text => TextButton.icon(
        onPressed: callback,
        style: TextButton.styleFrom(minimumSize: size),
        icon: leading,
        label: text,
      ),
    };

    return MergeSemantics(
      child: Semantics(
        value: loading ? AppLocalizations.of(context).dsLoading : null,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
