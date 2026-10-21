import 'package:cool_lodz/app/routes.dart';
import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/core/models/route_request.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/start_flow.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'fakes.dart';

const _user = AppUser(uid: 'u1', email: 'a@b.pl');

void main() {
  late SharedPreferences prefs;
  setUp(() async => prefs = await testPrefs());

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
          for (final profile in [null, false, true]) {
            final state = StartFlowState(
              onboardingSeen: seen,
              authKnown: authKnown,
              user: user,
              consentsAccepted: consents,
              profileChosen: profile,
            );
            final String? expected = switch ((
              seen,
              authKnown,
              user,
              consents,
              profile,
            )) {
              (null, _, _, _, _) => Routes.start,
              (false, _, _, _, _) => Routes.onboarding,
              (true, false, _, _, _) => Routes.start,
              (true, true, null, _, _) => Routes.login,
              (true, true, _, null, _) => Routes.start,
              (true, true, _, false, _) => Routes.consents,
              (true, true, _, true, null) => Routes.start,
              (true, true, _, true, false) => Routes.profileSelect,
              _ => null,
            };
            cases.add((state, expected));
          }
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
      Routes.profileSelect,
      Routes.privacy,
      Routes.heatCheck,
    ];

    for (final (state, required) in cases) {
      test('$state → ${required ?? 'done'}', () {
        expect(state.requiredRoute, required);
        for (final path in paths) {
          final String? expected;
          if (path == Routes.privacy || path == Routes.heatCheck) {
            expected = null; // always reachable
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
          prefs: prefs,
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

    test('registration goes to consents, then profile, then done', () async {
      onboarding.seen = true;
      container = create();
      await settle();

      auth.emit(_user);
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, Routes.consents);

      container.read(startFlowProvider.notifier).markConsentsAccepted();
      expect(
        container.read(startFlowProvider).requiredRoute,
        Routes.profileSelect,
      );

      container.read(startFlowProvider.notifier).markProfileChosen();
      expect(container.read(startFlowProvider).requiredRoute, isNull);
    });

    test('consents without a profile go to S04', () async {
      onboarding.seen = true;
      profiles.accepted['u1'] = true;
      auth = FakeAuthRepository(user: _user);
      container = create();
      await settle();
      expect(
        container.read(startFlowProvider).requiredRoute,
        Routes.profileSelect,
      );
    });

    test('the account profile is loaded and applied on sign-in', () async {
      onboarding.seen = true;
      profiles.accepted['u1'] = true;
      profiles.comfortProfiles['u1'] = ComfortProfile.preset(ProfileId.senior);
      auth = FakeAuthRepository(user: _user);
      container = create();
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, isNull);
      expect(container.read(comfortProfileProvider).id, ProfileId.senior);
      expect(container.read(seniorModeProvider), isTrue);
    });

    test('offline: S04 is skipped only when chosen on this device', () async {
      onboarding.seen = true;
      profiles.accepted['u1'] = true;
      profiles.profileReadError = Exception('offline');
      auth = FakeAuthRepository(user: _user);
      container = create();
      await settle();
      expect(
        container.read(startFlowProvider).requiredRoute,
        Routes.profileSelect,
      );

      prefs = await testPrefs({
        ComfortProfileNotifier.prefsKey:
            '{"id":"tourist","weights":{"shade":70,"time":40,"quiet":30,"air":40},"seniorMode":false}',
        ComfortProfileNotifier.prefsUidKey: 'u1',
      });
      container = create();
      await settle();
      expect(container.read(startFlowProvider).requiredRoute, isNull);
      expect(container.read(comfortProfileProvider).id, ProfileId.tourist);
    });

    test(
      'a returning user with consents and a profile goes straight through',
      () async {
        onboarding.seen = true;
        profiles.accepted['u1'] = true;
        profiles.comfortProfiles['u1'] = ComfortProfile.preset(
          ProfileId.standard,
        );
        auth = FakeAuthRepository(user: _user);
        container = create();
        await settle();
        expect(container.read(startFlowProvider).requiredRoute, isNull);

        auth.emit(null);
        await settle();
        expect(container.read(startFlowProvider).requiredRoute, Routes.login);
        expect(container.read(startFlowProvider).consentsAccepted, isNull);
      },
    );

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
