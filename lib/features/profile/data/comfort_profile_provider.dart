import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_profile_repository.dart';
import 'comfort_profile.dart';

/// The current comfort profile (S04). Kept on the device too, so Senior mode
/// is on from the first frame and works without network; the account copy
/// lives in `users/{uid}.profile`.
class ComfortProfileNotifier extends Notifier<ComfortProfile> {
  static const prefsKey = 'comfortProfile';

  /// Firestore completes a write only after the server confirms it.
  static const saveTimeout = Duration(seconds: 15);

  @override
  ComfortProfile build() => _readLocal() ?? ComfortProfile.fallback;

  /// True once a profile was chosen on this device (S04 done here, or the
  /// account's profile was loaded).
  bool get hasLocal => _readLocal() != null;

  /// Saves [profile] to the signed-in account, then uses it. Throws when the
  /// account write fails, so S04 can show an error.
  Future<void> save(ComfortProfile profile) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid != null) {
      await ref
          .read(userProfileRepositoryProvider)
          .saveComfortProfile(uid, profile)
          .timeout(saveTimeout);
    }
    await apply(profile);
  }

  /// Uses [profile] on this device only (e.g. the account's profile was
  /// loaded at sign-in).
  Future<void> apply(ComfortProfile profile) async {
    state = profile;
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(prefsKey, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('Could not keep the comfort profile on device: $e');
    }
  }

  ComfortProfile? _readLocal() {
    final raw = ref.read(sharedPreferencesProvider).getString(prefsKey);
    if (raw == null) return null;
    try {
      return ComfortProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Unreadable saved comfort profile: $e');
      return null;
    }
  }
}

final comfortProfileProvider =
    NotifierProvider<ComfortProfileNotifier, ComfortProfile>(
      ComfortProfileNotifier.new,
    );
