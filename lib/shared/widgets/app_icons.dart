import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The three custom icons from the spec. Everything else uses
/// `Icons.*_rounded`. Like [Icon], they are hidden from TalkBack unless a
/// [semanticLabel] is given.

/// Miejsce chłodu: a snowflake inside a house.
class CoolPlaceIcon extends StatelessWidget {
  const CoolPlaceIcon({
    super.key,
    this.size = 24,
    this.color,
    this.innerColor = AppColors.surface,
    this.semanticLabel,
  });

  final double size;
  final Color? color;

  /// Colour of the snowflake cut into the house.
  final Color innerColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final houseColor =
        color ?? IconTheme.of(context).color ?? AppColors.primary;
    return _labelled(
      semanticLabel,
      SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: const Alignment(0, 0.4),
          children: [
            Icon(Icons.home_rounded, size: size, color: houseColor),
            Icon(Icons.ac_unit_rounded, size: size * 0.38, color: innerColor),
          ],
        ),
      ),
    );
  }
}

/// Poidełko: a drop falling from a tap.
class WaterTapIcon extends StatelessWidget {
  const WaterTapIcon({
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? AppColors.water;
    return _labelled(
      semanticLabel,
      CustomPaint(size: Size.square(size), painter: _WaterTapPainter(c)),
    );
  }
}

class _WaterTapPainter extends CustomPainter {
  _WaterTapPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Tap: a vertical pipe on the left, then a spout turning down.
    final tap = Path()
      ..moveTo(5 * u, 21 * u)
      ..lineTo(5 * u, 5 * u)
      ..lineTo(15 * u, 5 * u)
      ..quadraticBezierTo(18 * u, 5 * u, 18 * u, 8 * u)
      ..lineTo(18 * u, 10 * u);
    canvas.drawPath(tap, paint);
    // Handle on top of the pipe.
    canvas.drawLine(Offset(9 * u, 2.5 * u), Offset(9 * u, 5 * u), paint);
    // Drop under the spout.
    final drop = Path()
      ..moveTo(18 * u, 12.5 * u)
      ..cubicTo(18 * u, 12.5 * u, 14.8 * u, 16.4 * u, 14.8 * u, 18.4 * u)
      ..arcToPoint(
        Offset(21.2 * u, 18.4 * u),
        radius: Radius.circular(3.2 * u),
        clockwise: false,
      )
      ..cubicTo(21.2 * u, 16.4 * u, 18 * u, 12.5 * u, 18 * u, 12.5 * u)
      ..close();
    canvas.drawPath(drop, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WaterTapPainter old) => old.color != color;
}

/// Litera questu: a letter on a rounded square.
class QuestLetterIcon extends StatelessWidget {
  const QuestLetterIcon({
    super.key,
    this.letter = 'L',
    this.size = 24,
    this.color = AppColors.primary,
    this.letterColor = AppColors.onPrimary,
    this.semanticLabel,
  });

  final String letter;
  final double size;
  final Color color;
  final Color letterColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _labelled(
      semanticLabel,
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        // Icon-sized glyph: does not follow the text scaler.
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: AppTextStyles.label.copyWith(
            fontSize: size * 0.6,
            height: 1,
            fontWeight: FontWeight.w700,
            color: letterColor,
          ),
        ),
      ),
    );
  }
}

Widget _labelled(String? label, Widget child) => label == null
    ? ExcludeSemantics(child: child)
    : Semantics(
        label: label,
        image: true,
        excludeSemantics: true,
        child: child,
      );
