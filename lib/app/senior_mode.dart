import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// Senior mode: text ×1.25, 60 dp buttons, labels on all icons.
/// Turned on by the Senior comfort profile (S04) or separately in settings.
/// APP-08 connects it to the saved profile.
class SeniorMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool enabled) => state = enabled;
}

final seniorModeProvider = NotifierProvider<SeniorMode, bool>(SeniorMode.new);

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
