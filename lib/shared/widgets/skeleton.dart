import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Grey placeholder block that pulses while data loads. The pulse stops
/// when the system asks to reduce animations.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppSizes.s4,
    this.animate = true,
  });

  final double? width;
  final double height;
  final double radius;

  /// `false` when a parent already pulses (see [SkeletonCard]).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return animate ? SkeletonPulse(child: box) : box;
  }
}

/// Placeholder for a card or list item: a square and three lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).dsLoading,
      excludeSemantics: true,
      child: SkeletonPulse(
        child: Container(
          padding: const EdgeInsets.all(AppSizes.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 40, height: 40, radius: 20, animate: false),
              SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 14, animate: false),
                    SizedBox(height: AppSizes.s8),
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      alignment: Alignment.centerLeft,
                      child: SkeletonBox(height: 12, animate: false),
                    ),
                    SizedBox(height: AppSizes.s8),
                    FractionallySizedBox(
                      widthFactor: 0.4,
                      alignment: Alignment.centerLeft,
                      child: SkeletonBox(height: 12, animate: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades its child between 40 % and 100 % opacity.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.4,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
}

/// Placeholder for a [RouteVariantCard] while routes are computed (S07).
class SkeletonRouteCard extends StatelessWidget {
  const SkeletonRouteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).dsLoading,
      excludeSemantics: true,
      child: SkeletonPulse(
        child: Container(
          padding: const EdgeInsets.all(AppSizes.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.5,
                          alignment: Alignment.centerLeft,
                          child: SkeletonBox(height: 16, animate: false),
                        ),
                        SizedBox(height: AppSizes.s8),
                        FractionallySizedBox(
                          widthFactor: 0.7,
                          alignment: Alignment.centerLeft,
                          child: SkeletonBox(height: 12, animate: false),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSizes.s16),
                  SkeletonBox(width: 72, height: 40, animate: false),
                ],
              ),
              SizedBox(height: AppSizes.s12),
              SkeletonBox(height: 8, animate: false),
              SizedBox(height: AppSizes.s12),
              FractionallySizedBox(
                widthFactor: 0.6,
                alignment: Alignment.centerLeft,
                child: SkeletonBox(height: 12, animate: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
