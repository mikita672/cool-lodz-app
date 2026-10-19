import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current local time (Europe/Warsaw on the phone). Tests override it to
/// check opening hours, heat hours and quest days.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
