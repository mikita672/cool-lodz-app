import 'package:cool_lodz/features/auth/start_flow.dart';
import 'package:cool_lodz/features/onboarding/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../auth/fakes.dart';

void main() {
  late FakeOnboardingStore store;

  setUp(() => store = FakeOnboardingStore());

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    const OnboardingScreen(),
    overrides: fakeAuthOverrides(auth: FakeAuthRepository(), onboarding: store),
  );

  bool seenInState(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(OnboardingScreen)),
  ).read(startFlowProvider).onboardingSeen!;

  testWidgets('Dalej walks through the three slides, then finishes', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Idź w cieniu'), findsOneWidget);
    expect(find.text('Pomiń'), findsOneWidget);
    expect(find.bySemanticsLabel('Slajd 1 z 3'), findsOneWidget);

    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
    expect(find.text('Znajdź miejsce chłodu'), findsOneWidget);

    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
    expect(find.text('Zbieraj litery'), findsOneWidget);
    expect(find.text('Pomiń').hitTestable(), findsNothing);
    expect(store.markSeenCalls, 0);

    await tester.tap(find.text('Zaczynamy'));
    await tester.pumpAndSettle();
    expect(store.markSeenCalls, 1);
    expect(seenInState(tester), isTrue);
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
      overrides: fakeAuthOverrides(auth: FakeAuthRepository()),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
