import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum ToastKind { info, success, warning }

/// Shows a short message as a floating SnackBar styled by the theme.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: AppToastContent(message: message, kind: kind),
    ),
  );
}

/// Icon + text inside the toast; also used on the showcase page.
class AppToastContent extends StatelessWidget {
  const AppToastContent({
    super.key,
    required this.message,
    this.kind = ToastKind.info,
  });

  final String message;
  final ToastKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      ToastKind.info => (Icons.info_rounded, AppColors.cool),
      ToastKind.success => (Icons.check_circle_rounded, AppColors.green),
      ToastKind.warning => (Icons.warning_rounded, AppColors.sun),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.onPrimary),
          ),
        ),
      ],
    );
  }
}
