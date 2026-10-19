import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/data/comfort_profile_provider.dart';
import 'theme.dart';

/// Senior mode: text ×1.25, 60 dp buttons, labels on all icons.
/// Part of the comfort profile: the Senior profile turns it on (S04) and the
/// user can switch it separately (S04, settings).
final seniorModeProvider = Provider<bool>(
  (ref) => ref.watch(comfortProfileProvider).seniorMode,
);

/// Scales text by [factor] on top of the system text scaler.
class SeniorTextScaler extends TextScaler {
  const SeniorTextScaler(this.base, [this.factor = AppSizes.seniorTextScale]);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(1) * factor;

  @override
  bool operator ==(Object other) =>
      other is SeniorTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
