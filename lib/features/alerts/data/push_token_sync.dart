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

  /// Before sign-out: removes `fcmToken` from [uid]'s document and
  /// invalidates the token itself. Firestore keeps an unsent write in the
  /// signed-in user's queue, so offline the field may stay on the server;
  /// the deleted token makes it useless, and the next sign-in gets a new one.
  Future<void> clear(
    String uid, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await _profiles.saveFcmToken(uid, null).timeout(timeout);
    } catch (e) {
      debugPrint('Removing the FCM token from users/$uid failed: $e');
    }
    await _push.deleteToken();
  }
}

final pushTokenSyncProvider = Provider<PushTokenSync>(
  (ref) => PushTokenSync(
    ref.watch(userProfileRepositoryProvider),
    ref.watch(pushServiceProvider),
  ),
);
