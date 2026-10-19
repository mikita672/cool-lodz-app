import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

class _MockProfiles extends Mock implements UserProfileRepository {}

void main() {
  group('authFailureFromCode', () {
    const cases = {
      'invalid-credential': AuthFailure.wrongCredentials,
      'invalid-login-credentials': AuthFailure.wrongCredentials,
      'INVALID_LOGIN_CREDENTIALS': AuthFailure.wrongCredentials,
      'wrong-password': AuthFailure.wrongCredentials,
      'user-not-found': AuthFailure.wrongCredentials,
      'email-already-in-use': AuthFailure.emailInUse,
      'weak-password': AuthFailure.weakPassword,
      'invalid-email': AuthFailure.invalidEmail,
      'missing-email': AuthFailure.invalidEmail,
      'network-request-failed': AuthFailure.network,
      'unavailable': AuthFailure.network,
      'deadline-exceeded': AuthFailure.network,
      'too-many-requests': AuthFailure.unknown,
      'user-disabled': AuthFailure.unknown,
      'something-new': AuthFailure.unknown,
    };
    for (final MapEntry(key: code, value: failure) in cases.entries) {
      test('$code → ${failure.name}', () {
        expect(authFailureFromCode(code), failure);
      });
    }
  });

  group('FirebaseAuthRepository', () {
    late _MockAuth auth;
    late _MockProfiles profiles;
    late FirebaseAuthRepository repo;

    setUp(() {
      auth = _MockAuth();
      profiles = _MockProfiles();
      repo = FirebaseAuthRepository(auth, profiles);
    });

    test('maps FirebaseAuthException to AuthException', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      await expectLater(
        repo.signIn(email: 'a@b.pl', password: 'secret12'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.wrongCredentials,
          ),
        ),
      );
    });

    test('register creates users/{uid} with the trimmed nickname', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('u1');
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(user);
      when(
        () => auth.createUserWithEmailAndPassword(
          email: 'ania@example.pl',
          password: 'secret12',
        ),
      ).thenAnswer((_) async => credential);
      when(
        () => profiles.createProfile(
          uid: any(named: 'uid'),
          nickname: any(named: 'nickname'),
        ),
      ).thenAnswer((_) async {});

      await repo.register(
        email: ' ania@example.pl ',
        password: 'secret12',
        nickname: ' cienista_ania ',
      );

      verify(
        () => profiles.createProfile(uid: 'u1', nickname: 'cienista_ania'),
      ).called(1);
    });

    test('register reports a taken e-mail', () async {
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      await expectLater(
        repo.register(email: 'a@b.pl', password: 'secret12', nickname: 'ab'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.emailInUse,
          ),
        ),
      );
      verifyNever(
        () => profiles.createProfile(
          uid: any(named: 'uid'),
          nickname: any(named: 'nickname'),
        ),
      );
    });

    test('userChanges exposes AppUser, not the Firebase User', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('u1');
      when(() => user.email).thenReturn('a@b.pl');
      when(
        auth.authStateChanges,
      ).thenAnswer((_) => Stream.fromIterable([null, user]));

      expect(await repo.userChanges().toList(), [
        null,
        const AppUser(uid: 'u1', email: 'a@b.pl'),
      ]);
    });

    test('sendPasswordReset maps a network error', () async {
      when(
        () => auth.sendPasswordResetEmail(email: 'a@b.pl'),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      await expectLater(
        repo.sendPasswordReset('a@b.pl'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.network,
          ),
        ),
      );
    });
  });
}
