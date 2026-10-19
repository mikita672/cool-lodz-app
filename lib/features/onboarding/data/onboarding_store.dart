import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that S01 was shown (spec: once after install).
abstract interface class OnboardingStore {
  Future<bool> isSeen();
  Future<void> markSeen();
}

class PrefsOnboardingStore implements OnboardingStore {
  PrefsOnboardingStore(this._prefs);

  static const key = 'onboardingSeen';

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> isSeen() async => await _prefs.getBool(key) ?? false;

  @override
  Future<void> markSeen() => _prefs.setBool(key, true);
}

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => PrefsOnboardingStore(SharedPreferencesAsync()),
);
