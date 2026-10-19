import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// One letter of the quest password: found (filled) or empty (dashed).
class LetterTile extends StatelessWidget {
  const LetterTile({super.key, this.letter, this.onTap});

  /// `null` means the letter is not found yet.
  final String? letter;
  final VoidCallback? onTap;

  bool get found => letter != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(AppSizes.radiusChip);
    final tile = SizedBox(
      width: 40,
      height: AppSizes.minTouchTarget,
      child: found
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: radius,
              ),
              child: Center(
                child: Text(
                  letter!,
                  style: AppTextStyles.titleM.copyWith(
                    color: AppColors.onPrimary,
                    height: 1,
                  ),
                ),
              ),
            )
          : const CustomPaint(painter: _DashedBorderPainter()),
    );
    return Semantics(
      label: found ? l10n.dsLetterFound(letter!) : l10n.dsLetterEmpty,
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null
          ? tile
          : InkWell(onTap: onTap, borderRadius: radius, child: tile),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(AppSizes.radiusChip),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.surface);
    final paint = Paint()
      ..color = AppColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 4.0, gap = 3.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
