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

  /// «Usuń konto» (S16): checks [password] again, runs [deleteData] for the
  /// user's documents, then deletes the Auth user. A wrong password throws
  /// [AuthFailure.wrongCredentials] before anything is deleted.
  Future<void> deleteAccount({
    required String password,
    required Future<void> Function(String uid) deleteData,
  });
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
      _guard(() async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final user = credential.user;
        if (user == null) return;
        try {
          await _profiles
              .ensureProfile(
                uid: user.uid,
                nickname: nicknameFromEmail(user.email ?? email),
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          // Signed in anyway; the next sign-in tries again.
          debugPrint('Could not check users/${user.uid}: $e');
        }
      });

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
    final user = credential.user!;
    try {
      await _profiles.createProfile(uid: user.uid, nickname: nickname.trim());
    } catch (_) {
      // No half-made account: the user can register again with this e-mail.
      try {
        await user.delete();
      } catch (e) {
        debugPrint('Could not undo the sign-up: $e');
      }
      rethrow;
    }
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> deleteAccount({
    required String password,
    required Future<void> Function(String uid) deleteData,
  }) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email ?? '', password: password),
    );
    await deleteData(user.uid);
    await user.delete();
  });

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      // FirebaseAuthException is a FirebaseException too.
      throw AuthException(authFailureFromCode(e.code));
    }
  }
}

/// A ranking nickname from the e-mail's local part (2–24 characters), for
/// an account whose `users/{uid}` is missing.
String nicknameFromEmail(String email) {
  final local = email.split('@').first.replaceAll(RegExp(r'[^\w.\-]'), '');
  if (local.length < 2) return 'Gracz';
  return local.length > 24 ? local.substring(0, 24) : local;
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

/// The signed-in user's id, following sign-in and sign-out. Providers that
/// read per-user data watch this, so they rebuild for another account
/// instead of keeping the previous user's data (RODO).
final currentUidProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.hasValue
      ? user.value?.uid
      : ref.read(authRepositoryProvider).currentUser?.uid;
});
