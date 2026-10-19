import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// A push as the app needs it (title and body of the notification).
@immutable
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// Firebase Cloud Messaging behind an interface (tests replace it).
abstract interface class PushService {
  /// Registration token for `users/{uid}.fcmToken`; null without Play
  /// services or network.
  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// Pushes that arrive while the app is open (FCM shows nothing then).
  Stream<PushMessage> get foreground;

  /// Notifications tapped while the app was in the background.
  Stream<PushMessage> get opened;

  /// The notification that started the app, if any.
  Future<PushMessage?> initial();

  /// Invalidates this phone's token on the FCM server (sign-out), so a copy
  /// left in Firestore no longer delivers anything.
  Future<void> deleteToken();
}

class FirebasePushService implements PushService {
  FirebasePushService(this._messaging);

  final FirebaseMessaging _messaging;

  static PushMessage _map(RemoteMessage m) => PushMessage(
    title: m.notification?.title,
    body: m.notification?.body,
    data: m.data,
  );

  @override
  Future<String?> token() async {
    try {
      // `getToken` is deprecated in favour of the FID, but the console's
      // test message and the spec's `fcmToken` use the registration token.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get foreground => FirebaseMessaging.onMessage.map(_map);

  @override
  Stream<PushMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(_map);

  @override
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM token not deleted: $e');
    }
  }

  @override
  Future<PushMessage?> initial() async {
    try {
      final m = await _messaging.getInitialMessage();
      return m == null ? null : _map(m);
    } catch (e) {
      debugPrint('FCM initial message failed: $e');
      return null;
    }
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => FirebasePushService(ref.watch(firebaseMessagingProvider)),
);
