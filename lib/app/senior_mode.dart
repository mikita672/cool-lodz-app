import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Senior mode: text ×1.25, 60 dp buttons, labels on all icons.
/// Turned on by the Senior comfort profile (S04) or separately in settings.
/// APP-08 connects it to the saved profile.
class SeniorMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool enabled) => state = enabled;
}

final seniorModeProvider = NotifierProvider<SeniorMode, bool>(SeniorMode.new);
