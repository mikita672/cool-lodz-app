import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import 'user_profile_repository.dart';

/// The signed-in user as the app sees it. Firebase's `User` stays in the
/// data layer.
@immutable
class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);

  @override
  String toString() => 'AppUser($uid)';
}

/// What went wrong, in terms the UI can show (strings live in the ARB).
enum AuthFailure {
  wrongCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  network,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

/// Maps Firebase Auth (and Firestore) error codes to [AuthFailure].
/// With e-mail enumeration protection (default since 2023) a wrong e-mail or
/// password comes back as `invalid-credential`.
AuthFailure authFailureFromCode(String code) => switch (code) {
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'INVALID_LOGIN_CREDENTIALS' ||
  'wrong-password' ||
  'user-not-found' => AuthFailure.wrongCredentials,
  'email-already-in-use' => AuthFailure.emailInUse,
  'weak-password' => AuthFailure.weakPassword,
  'invalid-email' || 'missing-email' => AuthFailure.invalidEmail,
  'network-request-failed' ||
  'unavailable' ||
  'deadline-exceeded' => AuthFailure.network,
  _ => AuthFailure.unknown,
};

/// E-mail and password accounts. Every method throws [AuthException].
abstract interface class AuthRepository {
  /// Emits the current user right away, then on every sign-in and sign-out.
  Stream<AppUser?> userChanges();

  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  /// Creates the account and its `users/{uid}` document with [nickname].
  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._profiles);

  final FirebaseAuth _auth;
  final UserProfileRepository _profiles;

  static AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email);

  @override
  Stream<AppUser?> userChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _profiles.createProfile(
      uid: credential.user!.uid,
      nickname: nickname.trim(),
    );
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      // FirebaseAuthException is a FirebaseException too.
      throw AuthException(authFailureFromCode(e.code));
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(userProfileRepositoryProvider),
  ),
);

/// The signed-in user, or null when signed out.
final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);
