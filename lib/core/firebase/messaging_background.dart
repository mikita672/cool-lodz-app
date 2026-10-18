import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM background handler. Runs in its own isolate when a message arrives
/// while the app is in the background or killed; it cannot touch app state.
/// Call `Firebase.initializeApp()` here before using other Firebase services.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('FCM background message: ${message.messageId}');
}
