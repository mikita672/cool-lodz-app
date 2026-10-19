import 'package:cool_lodz/app/routes.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/start_flow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = AppUser(uid: 'u1', email: 'a@b.pl');

void main() {
  group('startFlowRedirect', () {
    // Every combination of the three inputs and the screen each one needs.
    final cases = <(StartFlowState, String?)>[];
    for (final seen in [null, false, true]) {
      for (final (authKnown, user) in [
        (false, null),
        (true, null),
        (true, _user),
      ]) {
        for (final consents in [null, false, true]) {
          final state = StartFlowState(
            onboardingSeen: seen,
            authKnown: authKnown,
            user: user,
            consentsAccepted: consents,
          );
          final String? expected = switch ((seen, authKnown, user, consents)) {
            (null, _, _, _) => Routes.start,
            (false, _, _, _) => Routes.onboarding,
            (true, false, _, _) => Routes.start,
            (true, true, null, _) => Routes.login,
            (true, true, _, null) => Routes.start,
            (true, true, _, false) => Routes.consents,
            _ => null,
          };
          cases.add((state, expected));
        }
      }
    }
    const paths = [
      Routes.start,
      Routes.onboarding,
      Routes.login,
      Routes.consents,
      Routes.map,
      Routes.questScan,
      Routes.profile,
      Routes.privacy,
    ];

    for (final (state, required) in cases) {
      test('$state → ${required ?? 'done'}', () {
        expect(state.requiredRoute, required);
        for (final path in paths) {
          final String? expected;
          if (path == Routes.privacy) {
            expected = null; // always readable
          } else if (required == null) {
            expected = startFlowRoutes.contains(path) ? Routes.map : null;
          } else {
            expected = path == required ? null : required;
          }
          expect(startFlowRedirect(state, path), expected, reason: path);
        }
      });
    }

    test('the complete state lets the app through', () {
      expect(startFlowRedirect(StartFlowState.complete, Routes.map), isNull);
      expect(
        startFlowRedirect(StartFlowState.complete, Routes.login),
        Routes.map,
      );
    });
  });

  group('StartFlowNotifier', () {
    late FakeAuthRepository auth;
    late FakeUserProfileRepository profiles;
    late FakeOnboardingStore onboarding;
    late ProviderContainer container;

    // Starts the notifier right away, as the router's first redirect does.
    ProviderContainer create() {
      final container = ProviderContainer.test(
        overrides: fakeAuthOverrides(
          auth: auth,
          profiles: profiles,
          onboarding: onboarding,
        ),
      );
      container.listen(startFlowProvider, (_, _) {});
      return container;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      auth = FakeAuthRepository();
      profiles = FakeUserProfileRepository();
      onboarding = FakeOnboardingStore();
    });

    test('new install: loading, then onboarding, then login', () async {
      container = create();
      expect(container.read(startFlowProvider).requiredRoute, Routes.start);
      await settle();
      expect(
        container.read(startFlowProvider).requiredRoute,
        Routes.onboarding,
      );

      await container.read(startFlowProvider.notifier).completeOnboarding();
      expect(onboarding.markSeenCalls, 1);
      expect(container.read(startFlowProvider).requiredRoute, Routes.login);
    });

    test('registration goes to consents, then done', () async {
      onboarding.seen = true;
      container = create();
      await settle();

      auth.emit(_user);
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, Routes.consents);

      container.read(startFlowProvider.notifier).markConsentsAccepted();
      expect(container.read(startFlowProvider).requiredRoute, isNull);
    });

    test('a returning user with consents goes straight through', () async {
      onboarding.seen = true;
      profiles.accepted['u1'] = true;
      auth = FakeAuthRepository(user: _user);
      container = create();
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, isNull);

      auth.emit(null);
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, Routes.login);
      expect(container.read(startFlowProvider).consentsAccepted, isNull);
    });

    test('an unreadable profile asks for consents again', () async {
      onboarding.seen = true;
      profiles.readError = Exception('offline');
      auth = FakeAuthRepository(user: _user);
      container = create();
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, Routes.consents);
    });

    test('the refresh listenable follows every change', () async {
      container = create();
      final changes = container.read(startFlowProvider.notifier).changes;
      var notified = 0;
      changes.addListener(() => notified++);

      await settle();
      expect(notified, greaterThan(0));
      expect(changes.value, container.read(startFlowProvider));

      final before = notified;
      await container.read(startFlowProvider.notifier).completeOnboarding();
      expect(notified, before + 1);
      expect(changes.value.onboardingSeen, isTrue);
    });
  });
}
