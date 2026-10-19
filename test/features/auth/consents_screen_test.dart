import 'package:cool_lodz/features/auth/consents_screen.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:cool_lodz/features/auth/start_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'fakes.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async => prefs = await testPrefs());

  late FakeUserProfileRepository profiles;
  late FakeSystemPermissions permissions;

  setUp(() {
    profiles = FakeUserProfileRepository();
    permissions = FakeSystemPermissions();
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    const ConsentsScreen(),
    overrides: fakeAuthOverrides(
      prefs: prefs,
      auth: FakeAuthRepository(user: const AppUser(uid: 'u1')),
      profiles: profiles,
      onboarding: FakeOnboardingStore(seen: true),
      permissions: permissions,
    ),
  );

  // On success the button keeps spinning until the router leaves S03, so
  // pump a few frames instead of pumpAndSettle.
  Future<void> accept(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('consents-accept')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  StartFlowState flow(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(ConsentsScreen)),
  ).read(startFlowProvider);

  testWidgets('defaults: location and push on, ranking off', (tester) async {
    await pump(tester);
    await accept(tester);

    expect(profiles.saved.single, (
      'u1',
      const Consents(location: true, push: true, ranking: false),
    ));
    expect(permissions.calls, ['location', 'notifications']);
    expect(flow(tester).consentsAccepted, isTrue);
  });

  testWidgets('saves the switches as set and asks only for enabled ones', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('consent-location')));
    await tester.tap(find.byKey(const Key('consent-ranking')));
    await tester.pump();
    await accept(tester);

    expect(profiles.saved.single, (
      'u1',
      const Consents(location: false, push: true, ranking: true),
    ));
    expect(permissions.calls, ['notifications']);
  });

  testWidgets('recreates a missing users/{uid} before saving', (tester) async {
    await pump(tester);
    await accept(tester);
    expect(profiles.ensured['u1'], 'Gracz'); // the fake user has no e-mail
    expect(profiles.saved, hasLength(1));
  });

  testWidgets('no system dialogs when both are off', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('consent-location')));
    await tester.tap(find.byKey(const Key('consent-push')));
    await tester.pump();
    await accept(tester);

    expect(
      profiles.saved.single.$2,
      const Consents(location: false, push: false, ranking: false),
    );
    expect(permissions.calls, isEmpty);
  });

  testWidgets('a failed save shows a message and asks for nothing', (
    tester,
  ) async {
    profiles.saveError = Exception('offline');
    await pump(tester);
    await accept(tester);

    expect(
      find.text(
        'Nie udało się zapisać zgód. Sprawdź połączenie i spróbuj ponownie.',
      ),
      findsOneWidget,
    );
    expect(permissions.calls, isEmpty);
    expect(flow(tester).consentsAccepted, isNot(true));
  });

  testWidgets('shows the privacy policy link and the system note', (
    tester,
  ) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Polityka prywatności'), 100);
    expect(find.text('Polityka prywatności'), findsOneWidget);
    expect(find.text('Wymagana do questu'), findsOneWidget);
    expect(
      find.text('Po kliknięciu Android zapyta o uprawnienia systemowe.'),
      findsOneWidget,
    );
  });

  testWidgets('fits 360 dp in Senior text', (tester) async {
    await pumpSenior360(
      tester,
      const ConsentsScreen(),
      overrides: fakeAuthOverrides(
        prefs: prefs,
        auth: FakeAuthRepository(user: const AppUser(uid: 'u1')),
      ),
    );
    await tester.scrollUntilVisible(find.text('Polityka prywatności'), 100);
    expect(tester.takeException(), isNull);
  });
}
