import 'dart:async';

import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/data/system_permissions.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:cool_lodz/features/onboarding/data/onboarding_store.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user}) : _user = user;

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();

  /// Thrown by the next sign-in / register / reset call, if set.
  AuthFailure? failure;

  /// Completes sign-in / register; tests can hold it to see loading state.
  Completer<void>? gate;

  final signIns = <({String email, String password})>[];
  final registrations = <({String email, String password, String nickname})>[];
  final resets = <String>[];
  var uidCounter = 0;

  void emit(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Stream<AppUser?> userChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  AppUser? get currentUser => _user;

  Future<void> _maybeFail() async {
    if (gate != null) await gate!.future;
    final f = failure;
    if (f != null) throw AuthException(f);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add((email: email, password: password));
    await _maybeFail();
    emit(AppUser(uid: 'uid-${++uidCounter}', email: email));
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    registrations.add((email: email, password: password, nickname: nickname));
    await _maybeFail();
    emit(AppUser(uid: 'uid-${++uidCounter}', email: email));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resets.add(email);
    await _maybeFail();
  }

  @override
  Future<void> signOut() async => emit(null);
}

class FakeUserProfileRepository implements UserProfileRepository {
  /// uid → consents already accepted.
  final accepted = <String, bool>{};
  final saved = <(String, Consents)>[];
  final created = <({String uid, String nickname})>[];
  Object? saveError;
  Object? readError;

  /// uid → saved comfort profile (S04).
  final comfortProfiles = <String, ComfortProfile>{};
  Object? profileSaveError;
  Object? profileReadError;

  @override
  Future<void> createProfile({
    required String uid,
    required String nickname,
  }) async => created.add((uid: uid, nickname: nickname));

  @override
  Future<void> saveConsents(String uid, Consents consents) async {
    if (saveError != null) throw saveError!;
    saved.add((uid, consents));
    accepted[uid] = true;
  }

  @override
  Future<bool> hasAcceptedConsents(String uid) async {
    if (readError != null) throw readError!;
    return accepted[uid] ?? false;
  }

  /// uid → saved token.
  final tokens = <String, String?>{};

  @override
  Future<Consents?> loadConsents(String uid) async {
    if (readError != null) throw readError!;
    return consents[uid] ??
        (accepted[uid] == true
            ? const Consents(location: true, push: true, ranking: false)
            : null);
  }

  /// Explicit consents per uid (default: push on when [accepted]).
  final consents = <String, Consents>{};

  @override
  Future<void> saveFcmToken(String uid, String? token) async =>
      tokens[uid] = token;

  @override
  Future<void> saveComfortProfile(String uid, ComfortProfile profile) async {
    if (profileSaveError != null) throw profileSaveError!;
    comfortProfiles[uid] = profile;
  }

  @override
  Future<ComfortProfile?> loadComfortProfile(String uid) async {
    if (profileReadError != null) throw profileReadError!;
    return comfortProfiles[uid];
  }
}

class FakeOnboardingStore implements OnboardingStore {
  FakeOnboardingStore({this.seen = false});

  bool seen;
  var markSeenCalls = 0;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async {
    markSeenCalls++;
    seen = true;
  }
}

class FakeSystemPermissions implements SystemPermissions {
  final calls = <String>[];

  @override
  Future<void> requestLocation() async => calls.add('location');

  @override
  Future<void> requestNotifications() async => calls.add('notifications');
}

/// Overrides for every repository the start flow and S01–S03 touch.
List<Override> fakeAuthOverrides({
  required FakeAuthRepository auth,
  required SharedPreferences prefs,
  FakeUserProfileRepository? profiles,
  FakeOnboardingStore? onboarding,
  FakeSystemPermissions? permissions,
}) => [
  ...appTestOverrides(
    prefs: prefs,
    auth: auth,
    profiles: profiles ?? FakeUserProfileRepository(),
  ),
  onboardingStoreProvider.overrideWithValue(
    onboarding ?? FakeOnboardingStore(),
  ),
  systemPermissionsProvider.overrideWithValue(
    permissions ?? FakeSystemPermissions(),
  ),
];
