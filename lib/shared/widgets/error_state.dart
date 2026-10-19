import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'empty_state.dart';

/// Load error with a «Spróbuj ponownie» button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.onRetry,
    this.title,
    this.message,
    this.icon = Icons.cloud_off_rounded,
  });

  final VoidCallback onRetry;

  /// Defaults to «Coś poszło nie tak».
  final String? title;

  /// Defaults to «Spróbuj ponownie za chwilę.».
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: icon,
      iconColor: AppColors.error,
      title: title ?? l10n.dsErrorTitle,
      message: message ?? l10n.dsErrorMessage,
      actionLabel: l10n.dsRetry,
      onAction: onRetry,
    );
  }
}
