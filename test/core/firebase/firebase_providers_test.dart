import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cool_lodz/core/firebase/firebase_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockUser extends Mock implements User {}

void main() {
  test('Firebase clients can be overridden', () {
    final auth = _MockAuth();
    final firestore = _MockFirestore();
    final messaging = _MockMessaging();
    final container = ProviderContainer.test(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(firestore),
        firebaseMessagingProvider.overrideWithValue(messaging),
      ],
    );
    expect(container.read(firebaseAuthProvider), same(auth));
    expect(container.read(firestoreProvider), same(firestore));
    expect(container.read(firebaseMessagingProvider), same(messaging));
  });

  test('authStateProvider follows authStateChanges', () async {
    final auth = _MockAuth();
    final changes = StreamController<User?>();
    addTearDown(changes.close);
    when(auth.authStateChanges).thenAnswer((_) => changes.stream);
    final container = ProviderContainer.test(
      overrides: [firebaseAuthProvider.overrideWithValue(auth)],
    );
    final sub = container.listen(authStateProvider, (_, _) {});
    addTearDown(sub.close);

    expect(container.read(authStateProvider).isLoading, isTrue);

    changes.add(null);
    expect(await container.read(authStateProvider.future), isNull);

    final user = _MockUser();
    changes.add(user);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authStateProvider).value, same(user));
  });

  test('authStateProvider can be overridden without FirebaseAuth', () async {
    final user = _MockUser();
    final container = ProviderContainer.test(
      overrides: [authStateProvider.overrideWithValue(AsyncData(user))],
    );
    expect(container.read(authStateProvider).value, same(user));
  });
}
