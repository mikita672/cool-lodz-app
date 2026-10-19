import 'dart:async';
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

  /// Account the profile on this device belongs to.
  static const prefsUidKey = 'comfortProfileUid';

  /// Firestore completes a write only after the server confirms it.
  static const saveTimeout = Duration(seconds: 15);

  @override
  ComfortProfile build() => _readLocal() ?? ComfortProfile.fallback;

  /// True once [uid] chose a profile on this device (S04 done here, or the
  /// account's profile was loaded). Another account's profile does not count.
  bool hasLocalFor(String uid) =>
      _readLocal() != null &&
      ref.read(sharedPreferencesProvider).getString(prefsUidKey) == uid;

  /// Uses [profile] right away (also offline) and saves it to the signed-in
  /// account. Offline the write stays queued and is sent later. Throws when
  /// the account rejects it; then the previous profile is restored.
  Future<void> save(ComfortProfile profile) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final previous = state;
    await apply(profile, uid: uid);
    if (uid == null) return;
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .saveComfortProfile(uid, profile)
          .timeout(saveTimeout);
    } on TimeoutException {
      // Offline: Firestore sends it when the network is back.
    } catch (_) {
      await apply(previous, uid: uid);
      rethrow;
    }
  }

  /// Uses [profile] on this device only (e.g. the account's profile was
  /// loaded at sign-in), remembering whose it is.
  Future<void> apply(ComfortProfile profile, {String? uid}) async {
    state = profile;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(prefsKey, jsonEncode(profile.toJson()));
      if (uid != null) await prefs.setString(prefsUidKey, uid);
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
