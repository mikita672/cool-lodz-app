import 'package:cool_lodz/app/app.dart';
import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/features/cool_places/cool_places_screen.dart';
import 'package:cool_lodz/features/map/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('starts on the map tab and switches between the 4 tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...appTestOverrides(prefs: await testPrefs())],
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mapa'), findsWidgets);
    expect(find.byType(MapScreen), findsOneWidget);

    await tester.tap(find.text('Chłód'));
    await tester.pumpAndSettle();
    expect(find.byType(CoolPlacesScreen), findsOneWidget);

    await tester.tap(find.text('Quest').last);
    await tester.pumpAndSettle();
    expect(find.text('S10'), findsOneWidget);
    await tester.tap(find.text('Odznaki'));
    await tester.pumpAndSettle();
    expect(find.text('S12'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('S16'), findsOneWidget);
  });

  testWidgets('theme uses the spec tokens', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) {
            theme = AppTheme.light();
            return const SizedBox();
          },
        ),
      ),
    );
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.textTheme.displaySmall!.fontSize, 32);
    expect(theme.textTheme.displaySmall!.fontFamily, 'Inter');
    expect(theme.extension<AppPalette>()!.buttonHeight, 52);
    expect(
      AppTheme.light(senior: true).extension<AppPalette>()!.buttonHeight,
      60,
    );
  });

  testWidgets('senior mode scales text by 1.25', (tester) async {
    final container = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(prefs: await testPrefs()),
        seniorModeProvider.overrideWithValue(true),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MapScreen));
    expect(MediaQuery.textScalerOf(context).scale(16), closeTo(20, 0.01));
  });
}
