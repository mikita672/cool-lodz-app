import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_button.dart';

/// Opens the «Nowa odznaka!» modal. Completes when the user closes it.
Future<void> showBadgeUnlockedDialog(
  BuildContext context, {
  required IconData icon,
  required String name,
  required String description,
  required int points,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => BadgeUnlockedDialog(
      icon: icon,
      name: name,
      description: description,
      points: points,
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

/// Modal shown when a badge is earned, with a one-shot confetti burst.
class BadgeUnlockedDialog extends StatelessWidget {
  const BadgeUnlockedDialog({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    required this.points,
    required this.onClose,
  });

  final IconData icon;
  final String name;
  final String description;
  final int points;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.s24,
        vertical: AppSizes.s24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSheet),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(child: ConfettiBurst()),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                    child: Icon(icon, size: 48, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              l10n.dsBadgeNew,
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSizes.s8),
            Semantics(
              header: true,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleL,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s12,
                vertical: AppSizes.s4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              child: Text(
                l10n.dsPointsGained(points),
                style: AppTextStyles.bodyS.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            AppButton(
              label: l10n.dsBadgeDialogOk,
              onPressed: onClose,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Confetti that bursts out once and falls. Decorative, hidden from
/// TalkBack; frozen mid-burst when animations are disabled.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final List<_Piece> _pieces = _Piece.generate(36);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.5;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(painter: _ConfettiPainter(_pieces, _controller)),
      ),
    );
  }
}

class _Piece {
  const _Piece(this.angle, this.speed, this.spin, this.color, this.size);

  final double angle;
  final double speed;
  final double spin;
  final Color color;
  final Size size;

  static const _colors = [
    AppColors.cool,
    AppColors.water,
    AppColors.green,
    AppColors.sun,
    AppColors.primary,
    AppColors.heat1,
  ];

  /// Fixed seed: the same burst every time (and in golden-free tests).
  static List<_Piece> generate(int count) {
    final random = math.Random(7);
    return List.generate(count, (i) {
      return _Piece(
        -math.pi * random.nextDouble(), // upwards half-circle
        90 + random.nextDouble() * 80,
        (random.nextDouble() - 0.5) * 12,
        _colors[i % _colors.length],
        Size(4 + random.nextDouble() * 4, 7 + random.nextDouble() * 5),
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress) : super(repaint: progress);

  final List<_Piece> pieces;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0) return;
    final center = size.center(Offset.zero);
    final burst = Curves.easeOutCubic.transform(t);
    final opacity = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    for (final p in pieces) {
      final offset =
          center +
          Offset(math.cos(p.angle), math.sin(p.angle)) * p.speed * burst +
          Offset(0, 120 * t * t); // gravity
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..rotate(p.spin * t)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size.width,
            height: p.size.height,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.pieces != pieces;
}
