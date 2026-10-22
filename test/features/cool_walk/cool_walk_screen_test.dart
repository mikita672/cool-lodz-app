import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/cool_walk/cool_walk_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

RouteVariant _loop(RouteVariantType type, double sun, int minutes) =>
    RouteVariant(
      variant: type,
      geometry: const [
        LatLng(51.77, 19.45),
        LatLng(51.775, 19.452),
        LatLng(51.772, 19.456),
        LatLng(51.77, 19.45),
      ],
      distanceM: minutes * 75,
      durationS: minutes * 60,
      sunShare: sun,
      extraTimeVsShortestS: 0,
    );

void main() {
  testWidgets('picks a length, finds loops, «Prowadź» opens Google Maps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <int>[];
    final launched = <Uri>[];
    final prefs = await testPrefs();
    await pumpScreen(
      tester,
      CoolWalkScreen(
        launch: (url) async {
          launched.add(url);
          return true;
        },
      ),
      overrides: [
        ...appTestOverrides(prefs: prefs, location: FakeLocationService()),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 9)),
        coolWalkFinderProvider.overrideWithValue((
          from, {
          required minutes,
          required departure,
        }) async {
          asked.add(minutes);
          return RouteResponse(
            coverage: RouteCoverage.full,
            variants: [
              _loop(RouteVariantType.shaded, 0.2, minutes),
              _loop(RouteVariantType.alternative, 0.4, minutes),
            ],
          );
        }),
      ],
    );
    await tester.tap(find.byKey(const Key('cool-walk-45')));
    await tester.tap(find.byKey(const Key('cool-walk-find')));
    await tester.pumpAndSettle();
    expect(asked, [45]);
    expect(find.text('Najchłodniejsza pętla'), findsOneWidget);
    expect(find.text('45 min · 3.4 km · 80% w cieniu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cool-walk-option-1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('cool-walk-go')));
    await tester.tap(find.byKey(const Key('cool-walk-go')));
    await tester.pumpAndSettle();
    expect(launched.single.host, 'www.google.com');
  });

  testWidgets('no loop: says so', (tester) async {
    final prefs = await testPrefs();
    await pumpScreen(
      tester,
      const CoolWalkScreen(),
      overrides: [
        ...appTestOverrides(prefs: prefs, location: FakeLocationService()),
        coolWalkFinderProvider.overrideWithValue(
          (from, {required minutes, required departure}) =>
              Future.error(Exception('offline')),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('cool-walk-find')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nie udało się wyznaczyć'), findsOneWidget);
  });
}
