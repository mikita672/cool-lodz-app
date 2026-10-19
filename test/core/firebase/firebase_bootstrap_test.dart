// getToken/onTokenRefresh are deprecated but still what the app uses.
// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cool_lodz/core/firebase/emulator_config.dart';
import 'package:cool_lodz/core/firebase/firebase_bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockMessaging extends Mock implements FirebaseMessaging {}

void main() {
  late _MockAuth auth;
  late _MockFirestore firestore;

  setUp(() {
    auth = _MockAuth();
    firestore = _MockFirestore();
    when(() => auth.useAuthEmulator(any(), any())).thenAnswer((_) async {});
  });

  group('connectEmulators', () {
    test('connects Auth and Firestore to the configured ports', () async {
      await FirebaseBootstrap.connectEmulators(
        const FirebaseEmulatorConfig(enabled: true),
        auth: auth,
        firestore: firestore,
      );
      verify(() => auth.useAuthEmulator('localhost', 9099)).called(1);
      verify(() => firestore.useFirestoreEmulator('localhost', 8080)).called(1);
    });

    test('does nothing when emulators are disabled', () async {
      await FirebaseBootstrap.connectEmulators(
        FirebaseEmulatorConfig.disabled,
        auth: auth,
        firestore: firestore,
      );
      verifyZeroInteractions(auth);
      verifyZeroInteractions(firestore);
    });
  });

  group('logFcmToken', () {
    late _MockMessaging messaging;

    setUp(() {
      messaging = _MockMessaging();
      when(
        () => messaging.onTokenRefresh,
      ).thenAnswer((_) => const Stream.empty());
    });

    test('returns the token', () async {
      when(() => messaging.getToken()).thenAnswer((_) async => 'token-1');
      expect(await FirebaseBootstrap.logFcmToken(messaging), 'token-1');
    });

    test('returns null instead of throwing when FCM is unavailable', () async {
      when(() => messaging.getToken()).thenThrow(Exception('no services'));
      expect(await FirebaseBootstrap.logFcmToken(messaging), isNull);
    });
  });
}
