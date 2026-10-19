import 'package:cool_lodz/app/app.dart';
import 'package:cool_lodz/features/auth/consents_screen.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/start_flow.dart';
import 'package:cool_lodz/features/settings/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// The whole start flow in the real router: S01 → S02 → S03 → map.
void main() {
  testWidgets('a new user goes from onboarding to the map', (tester) async {
    final auth = FakeAuthRepository();
    final profiles = FakeUserProfileRepository();
    final permissions = FakeSystemPermissions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeAuthOverrides(
            auth: auth,
            profiles: profiles,
            permissions: permissions,
          ),
          ...startFlowRouterOverrides,
        ],
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();

    // S01
    expect(find.text('Idź w cieniu'), findsOneWidget);
    await tester.tap(find.text('Pomiń'));
    await tester.pumpAndSettle();

    // S02: register
    await tester.tap(find.text('Załóż konto').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'ania@example.pl',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hasło'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pseudonim'),
      'cienista_ania',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    // S03: the privacy policy opens on top and comes back.
    expect(find.text('Zanim zaczniesz'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Polityka prywatności'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Polityka prywatności'));
    await tester.pumpAndSettle();
    expect(
      find.text('Wersja robocza — do sprawdzenia przez zespół.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentsScreen), findsOneWidget);
    expect(find.byType(PrivacyScreen), findsNothing);

    await tester.tap(find.byKey(const Key('consents-accept')));
    await tester.pumpAndSettle();

    expect(find.text('S05'), findsOneWidget);
    expect(profiles.saved.single.$1, 'uid-1');
    expect(permissions.calls, ['location', 'notifications']);
  });

  testWidgets('signing out returns to the login screen', (tester) async {
    final auth = FakeAuthRepository(user: const AppUser(uid: 'u1'));
    final profiles = FakeUserProfileRepository()..accepted['u1'] = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeAuthOverrides(
            auth: auth,
            profiles: profiles,
            onboarding: FakeOnboardingStore(seen: true),
          ),
          ...startFlowRouterOverrides,
        ],
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('S05'), findsOneWidget);

    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Nie pamiętam hasła'), findsOneWidget);
  });
}
