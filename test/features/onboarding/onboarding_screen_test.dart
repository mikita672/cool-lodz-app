import 'package:cool_lodz/features/auth/start_flow.dart';
import 'package:cool_lodz/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../auth/fakes.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async => prefs = await testPrefs());

  late FakeOnboardingStore store;

  setUp(() => store = FakeOnboardingStore());

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    const OnboardingScreen(),
    overrides: fakeAuthOverrides(
      prefs: prefs,
      auth: FakeAuthRepository(),
      onboarding: store,
    ),
  );

  bool seenInState(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(OnboardingScreen)),
  ).read(startFlowProvider).onboardingSeen!;

  testWidgets('Dalej walks through every feature, then finishes', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Idź w cieniu'), findsOneWidget);
    expect(find.text('Pomiń'), findsOneWidget);
    expect(find.bySemanticsLabel('Slajd 1 z 7'), findsOneWidget);

    for (final title in [
      'Trasy w cieniu',
      'Znajdź miejsce chłodu',
      'Ryzyko upałowe',
      'Alarm upałowy',
      'Zbieraj litery i punkty',
      'Wymieniaj punkty',
    ]) {
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Pomiń').hitTestable(), findsNothing);
    expect(store.markSeenCalls, 0);

    await tester.tap(find.text('Zaczynamy'));
    await tester.pumpAndSettle();
    expect(store.markSeenCalls, 1);
    expect(seenInState(tester), isTrue);
  });

  testWidgets('from Profil: a guide that stores nothing and goes back', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OnboardingScreen(replay: true),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: fakeAuthOverrides(
        prefs: prefs,
        auth: FakeAuthRepository(),
        onboarding: store,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomiń'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(store.markSeenCalls, 0);
  });

  testWidgets('Pomiń stores the flag from the first slide', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Pomiń'));
    await tester.pumpAndSettle();
    expect(store.markSeenCalls, 1);
    expect(seenInState(tester), isTrue);
  });

  testWidgets('fits a 360 dp screen in Senior text size', (tester) async {
    await pumpSenior360(
      tester,
      const OnboardingScreen(),
      overrides: fakeAuthOverrides(prefs: prefs, auth: FakeAuthRepository()),
    );
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
