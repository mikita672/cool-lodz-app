import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/routes.dart';
import '../onboarding/data/onboarding_store.dart';
import 'data/auth_repository.dart';
import 'data/user_profile_repository.dart';

/// Where the user is in the start flow S01 → S02 → S03 → map.
/// A `null` field means "still loading".
@immutable
class StartFlowState {
  const StartFlowState({
    this.onboardingSeen,
    this.authKnown = false,
    this.user,
    this.consentsAccepted,
  });

  /// Everything done: used by tests and demo setups.
  static const complete = StartFlowState(
    onboardingSeen: true,
    authKnown: true,
    user: AppUser(uid: 'complete'),
    consentsAccepted: true,
  );

  final bool? onboardingSeen;

  /// False until the first auth event arrives.
  final bool authKnown;
  final AppUser? user;

  /// Only meaningful while [user] is signed in.
  final bool? consentsAccepted;

  /// The start-flow screen the user must be on, or null when the flow is done.
  String? get requiredRoute {
    if (onboardingSeen == null) return Routes.start;
    if (onboardingSeen == false) return Routes.onboarding;
    if (!authKnown) return Routes.start;
    if (user == null) return Routes.login;
    if (consentsAccepted == null) return Routes.start;
    if (consentsAccepted == false) return Routes.consents;
    // APP-08 inserts S04 (profile selection) here.
    return null;
  }

  StartFlowState _with({
    bool? onboardingSeen,
    bool? authKnown,
    AppUser? Function()? user,
    bool? Function()? consentsAccepted,
  }) => StartFlowState(
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    authKnown: authKnown ?? this.authKnown,
    user: user != null ? user() : this.user,
    consentsAccepted: consentsAccepted != null
        ? consentsAccepted()
        : this.consentsAccepted,
  );

  @override
  bool operator ==(Object other) =>
      other is StartFlowState &&
      other.onboardingSeen == onboardingSeen &&
      other.authKnown == authKnown &&
      other.user == user &&
      other.consentsAccepted == consentsAccepted;

  @override
  int get hashCode =>
      Object.hash(onboardingSeen, authKnown, user, consentsAccepted);

  @override
  String toString() =>
      'StartFlowState(onboardingSeen: $onboardingSeen, authKnown: $authKnown, '
      'user: $user, consentsAccepted: $consentsAccepted)';
}

/// Screens that belong to the start flow; once it is done they go to the map.
const startFlowRoutes = {
  Routes.start,
  Routes.onboarding,
  Routes.login,
  Routes.consents,
};

/// The redirect decision for [path] (a pure function, unit-tested).
String? startFlowRedirect(StartFlowState state, String path) {
  // The privacy policy is readable at any step (linked from S03 and S16).
  if (path == Routes.privacy) return null;
  final required = state.requiredRoute;
  if (required == null) {
    return startFlowRoutes.contains(path) ? Routes.map : null;
  }
  return path == required ? null : required;
}

class StartFlowNotifier extends Notifier<StartFlowState> {
  // Fed directly on every change. The router only `ref.read`s providers, and
  // Riverpod 3 pauses `ref.listen` in providers nobody listens to, so the
  // refresh signal must not depend on a provider subscription.
  final _changes = ValueNotifier<StartFlowState>(const StartFlowState());

  /// Notifies the router when the state changes.
  ValueListenable<StartFlowState> get changes => _changes;

  @override
  StartFlowState build() {
    final auth = ref.watch(authRepositoryProvider);
    final store = ref.watch(onboardingStoreProvider);
    final profiles = ref.watch(userProfileRepositoryProvider);

    final sub = auth.userChanges().listen(
      (user) => _onUser(user, profiles),
      onError: (Object e) {
        debugPrint('Auth state error: $e');
        _update((s) => s._with(authKnown: true, user: () => null));
      },
    );
    ref.onDispose(sub.cancel);
    unawaited(_loadOnboarding(store));

    _changes.value = const StartFlowState();
    return const StartFlowState();
  }

  /// S01 finished or skipped.
  Future<void> completeOnboarding() async {
    try {
      await ref.read(onboardingStoreProvider).markSeen();
    } catch (e) {
      // Showing S01 again next time is better than blocking the user.
      debugPrint('Could not save onboardingSeen: $e');
    }
    _update((s) => s._with(onboardingSeen: true));
  }

  /// S03 saved and the system dialogs were answered.
  void markConsentsAccepted() => _update(
    (s) => s.user == null ? s : s._with(consentsAccepted: () => true),
  );

  Future<void> _loadOnboarding(OnboardingStore store) async {
    bool seen;
    try {
      seen = await store.isSeen();
    } catch (e) {
      debugPrint('Could not read onboardingSeen: $e');
      seen = false;
    }
    _update((s) => s._with(onboardingSeen: seen));
  }

  Future<void> _onUser(AppUser? user, UserProfileRepository profiles) async {
    if (!ref.mounted) return;
    final current = state;
    if (user == null) {
      _emit(
        current._with(
          authKnown: true,
          user: () => null,
          consentsAccepted: () => null,
        ),
      );
      return;
    }
    if (user.uid == current.user?.uid && current.consentsAccepted != null) {
      _emit(current._with(authKnown: true, user: () => user));
      return;
    }
    _emit(
      current._with(
        authKnown: true,
        user: () => user,
        consentsAccepted: () => null,
      ),
    );

    bool accepted;
    try {
      accepted = await profiles.hasAcceptedConsents(user.uid);
    } catch (e) {
      // No network and nothing cached: show S03 again rather than block.
      debugPrint('Could not read consents: $e');
      accepted = false;
    }
    _update((s) {
      // Signed out or switched accounts meanwhile, or S03 already finished.
      if (s.user?.uid != user.uid || s.consentsAccepted == true) return s;
      return s._with(consentsAccepted: () => accepted);
    });
  }

  void _update(StartFlowState Function(StartFlowState current) change) {
    if (!ref.mounted) return;
    _emit(change(state));
  }

  void _emit(StartFlowState next) {
    state = next;
    _changes.value = next;
  }
}

final startFlowProvider = NotifierProvider<StartFlowNotifier, StartFlowState>(
  StartFlowNotifier.new,
);

/// Wires the start flow into the router's hooks ([routerRedirectProvider],
/// [routerRefreshProvider]). Used by main.dart; widget tests that pump
/// `CoolLodzApp` without these overrides see every route unguarded.
final startFlowRouterOverrides = [
  routerRedirectProvider.overrideWith(
    (ref) =>
        (context, state) =>
            startFlowRedirect(ref.read(startFlowProvider), state.uri.path),
  ),
  routerRefreshProvider.overrideWith(
    (ref) => ref.read(startFlowProvider.notifier).changes,
  ),
];
