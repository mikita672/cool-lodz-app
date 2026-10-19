import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/firebase/firebase_providers.dart';

/// Android runtime permission dialogs shown after S03. The result is not
/// needed here: features check the permission again when they use it.
abstract interface class SystemPermissions {
  Future<void> requestLocation();
  Future<void> requestNotifications();
}

class DeviceSystemPermissions implements SystemPermissions {
  DeviceSystemPermissions(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<void> requestLocation() async {
    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Location permission request failed: $e');
    }
  }

  @override
  Future<void> requestNotifications() async {
    try {
      await _messaging.requestPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }
}

final systemPermissionsProvider = Provider<SystemPermissions>(
  (ref) => DeviceSystemPermissions(ref.watch(firebaseMessagingProvider)),
);
