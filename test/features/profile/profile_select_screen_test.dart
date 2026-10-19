import 'dart:async';

import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/core/models/route_request.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile_provider.dart';
import 'package:cool_lodz/features/profile/profile_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../auth/fakes.dart';

void main() {
  late SharedPreferences prefs;
  late FakeUserProfileRepository profiles;

  setUp(() async {
    prefs = await testPrefs();
    profiles = FakeUserProfileRepository();
  });

  /// S04 opened from Profil (pushed on top of a page, so it can pop).
  Future<ProviderContainer> pumpFromProfile(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profil tab')),
          routes: [
            GoRoute(
              path: 'select',
              builder: (_, _) => const ProfileSelectScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpScreen(
      tester,
      Router.withConfig(config: router),
      overrides: fakeAuthOverrides(
        prefs: prefs,
        auth: FakeAuthRepository(user: const AppUser(uid: 'u1')),
        profiles: profiles,
      ),
    );
    unawaited(router.push('/profile/select'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ProfileSelectScreen)),
    );
  }

  testWidgets('shows 3 working profiles and 5 «Wkrótce» cards', (tester) async {
    await pumpFromProfile(tester, size: const Size(400, 2400));
    expect(find.text('Senior'), findsOneWidget);
    expect(find.text('Turysta'), findsOneWidget);
    expect(find.text('Domyślny'), findsOneWidget);
    expect(find.text('Wkrótce'), findsNWidgets(6)); // header + 5 tags
    expect(find.text('Z psem'), findsOneWidget);
    expect(find.text('Wrażliwy na hałas i smog'), findsOneWidget);
    // Nothing chosen yet: the default profile is preselected.
    expect(
      tester.getSemantics(find.text('Domyślny')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.text('Senior')),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('choosing Senior saves its preset with Senior mode on', (
    tester,
  ) async {
    final container = await pumpFromProfile(tester);
    await tester.tap(find.byKey(const Key('profile-senior')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    final saved = profiles.comfortProfiles['u1']!;
    expect(saved, ComfortProfile.preset(ProfileId.senior));
    expect(saved.seniorMode, isTrue);
    expect(container.read(seniorModeProvider), isTrue);
    expect(
      prefs.getString(ComfortProfileNotifier.prefsKey),
      contains('senior'),
    );
    // Back on the Profil tab, with a confirmation.
    expect(find.text('Profil tab'), findsOneWidget);
    expect(find.text('Profil zapisany'), findsOneWidget);
  });

  testWidgets('«Dostosuj» sliders change the saved weights', (tester) async {
    await pumpFromProfile(tester, size: const Size(400, 1600));
    await tester.tap(find.byKey(const Key('profile-tourist')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-weight-shade')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-adjust')));
    await tester.pumpAndSettle();
    expect(find.text('Cień'), findsOneWidget);
    expect(find.text('Powietrze'), findsOneWidget);

    // Drag the shade slider to the right end: 100.
    final slider = find.byKey(const Key('profile-weight-shade'));
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    final saved = profiles.comfortProfiles['u1']!;
    expect(saved.id, ProfileId.tourist);
    expect(saved.weights.shade, 100);
    expect(saved.weights.time, 40);
    expect(saved.seniorMode, isFalse);
  });

  testWidgets('the Senior switch previews big text before saving', (
    tester,
  ) async {
    final container = await pumpFromProfile(
      tester,
      size: const Size(400, 1600),
    );
    double scale() => MediaQuery.textScalerOf(
      tester.element(find.text('Profil komfortu')),
    ).scale(16);
    expect(scale(), 16);

    await tester.tap(find.byKey(const Key('profile-senior-mode')));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(20, 0.01));
    // Not applied to the app until saved.
    expect(container.read(seniorModeProvider), isFalse);
  });

  testWidgets('a failed save keeps the screen and shows an error', (
    tester,
  ) async {
    profiles.profileSaveError = Exception('offline');
    final container = await pumpFromProfile(tester);
    await tester.tap(find.byKey(const Key('profile-senior')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSelectScreen), findsOneWidget);
    expect(
      find.textContaining('Nie udało się zapisać profilu'),
      findsOneWidget,
    );
    expect(container.read(comfortProfileProvider).id, ProfileId.standard);
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    await pumpSenior360(
      tester,
      const ProfileSelectScreen(),
      overrides: fakeAuthOverrides(
        prefs: prefs,
        auth: FakeAuthRepository(user: const AppUser(uid: 'u1')),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-adjust')),
      200,
    );
    await tester.tap(find.byKey(const Key('profile-adjust')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Wrażliwy na hałas i smog'), 200);
    expect(tester.takeException(), isNull);
  });

  group('ComfortProfile', () {
    test('json uses the API ids', () {
      final json = ComfortProfile.preset(ProfileId.standard).toJson();
      expect(json, {
        'id': 'default',
        'weights': {'shade': 60, 'time': 60, 'quiet': 30, 'air': 30},
        'seniorMode': false,
      });
      expect(
        ComfortProfile.fromJson(json),
        ComfortProfile.preset(ProfileId.standard),
      );
    });

    test('only the Senior preset turns on Senior mode', () {
      for (final id in ProfileId.values) {
        expect(
          ComfortProfile.preset(id).seniorMode,
          id == ProfileId.senior,
          reason: id.name,
        );
      }
    });

    test('withValue changes one weight and clamps to 0..100', () {
      const w = ProfileWeights(shade: 10, time: 20, quiet: 30, air: 40);
      final changed = w.withValue(WeightKind.quiet, 130);
      expect(changed.quiet, 100);
      expect(changed.shade, 10);
      expect(changed.time, 20);
      expect(changed.air, 40);
      expect(w.withValue(WeightKind.air, -5).air, 0);
    });
  });
}
