import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_profile_repository.dart';
import 'push_service.dart';

/// Keeps `users/{uid}.fcmToken` in step with the S03 push consent.
class PushTokenSync {
  PushTokenSync(this._profiles, this._push);

  final UserProfileRepository _profiles;
  final PushService _push;

  /// Saves [token] (or the current one) when push is allowed for [uid].
  /// Never throws: a missing token only means no heat alerts.
  Future<void> sync(String uid, {String? token}) async {
    try {
      final consents = await _profiles.loadConsents(uid);
      if (consents == null || !consents.push) return;
      final value = token ?? await _push.token();
      if (value != null) await _profiles.saveFcmToken(uid, value);
    } catch (e) {
      debugPrint('Saving the FCM token failed: $e');
    }
  }

  /// Removes the token before sign-out, so this phone gets no alerts for an
  /// account that is not signed in. Waits at most [timeout] (offline the
  /// write stays queued).
  Future<void> clear(
    String uid, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await _profiles.saveFcmToken(uid, null).timeout(timeout);
    } on TimeoutException {
      // Queued; sent when the network is back.
    } catch (e) {
      debugPrint('Removing the FCM token failed: $e');
    }
  }
}

final pushTokenSyncProvider = Provider<PushTokenSync>(
  (ref) => PushTokenSync(
    ref.watch(userProfileRepositoryProvider),
    ref.watch(pushServiceProvider),
  ),
);
