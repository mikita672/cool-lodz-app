import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'emulator_config.dart';

/// Starts Firebase before `runApp`. Called only from main.dart, so widget
/// tests can pump `CoolLodzApp` without a Firebase app.
abstract final class FirebaseBootstrap {
  static Future<void> init({FirebaseEmulatorConfig? emulators}) async {
    // Options come from android/app/google-services.json.
    await Firebase.initializeApp();
    await connectEmulators(
      emulators ?? FirebaseEmulatorConfig.fromEnvironment(),
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
    if (kDebugMode) unawaited(logFcmToken(FirebaseMessaging.instance));
  }

  /// Points Auth and Firestore at the Emulator Suite. Must run before any
  /// other Auth or Firestore call.
  static Future<void> connectEmulators(
    FirebaseEmulatorConfig config, {
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) async {
    if (!config.enabled) return;
    debugPrint('Firebase: using emulators, $config');
    await auth.useAuthEmulator(config.host, config.authPort);
    firestore.useFirestoreEmulator(config.host, config.firestorePort);
  }

  /// Debug only: prints the FCM token so a test push can be sent from the
  /// Firebase console. Saving it to `users/{uid}` is APP-18.
  ///
  /// `getToken` is deprecated in firebase_messaging 17 in favour of the FID
  /// from `register()`, but the console test message still asks for a
  /// registration token, and the spec stores `fcmToken`.
  static Future<String?> logFcmToken(FirebaseMessaging messaging) async {
    try {
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      debugPrint('FCM token: $token');
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(
        (token) => debugPrint('FCM token refreshed: $token'),
        onError: (Object e) => debugPrint('FCM token refresh failed: $e'),
      );
      return token;
    } catch (e) {
      // No Play services or no network: the app works without push.
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }
}
