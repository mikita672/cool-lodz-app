import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/cool_places/place_sheet.dart';
import 'package:cool_lodz/features/map/data/map_layers_style.dart';
import 'package:cool_lodz/features/map/data/map_providers.dart';
import 'package:cool_lodz/features/map/map_screen.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:cool_lodz/shared/widgets/heat_banner.dart';
import 'package:cool_lodz/shared/widgets/map_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  late SharedPreferences prefs;
  late FakeLocationService location;

  setUp(() async {
    // Demo scenarios (July alerts, demo badge thresholds): demo mode on.
    prefs = await testPrefs({DemoMode.prefsKey: true});
    location = FakeLocationService();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    DemoAlertScenario alerts = DemoAlertScenario.level2,
    Size size = const Size(400, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          builder: (_, _) => const MapScreen(),
          routes: [
            GoRoute(
              path: 'alert',
              builder: (_, _) => const Scaffold(body: Text('S14')),
            ),
          ],
        ),
        GoRoute(
          path: '/route',
          builder: (_, _) => const Scaffold(body: Text('S06')),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, _) => const Scaffold(body: Text('S07')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: prefs,
          location: location,
          api: RecordingApiClient(
            demo: DemoApiClient(
              loadAsset: readAssetFile,
              alertScenario: alerts,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('pl'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  List<Polygon> polygons(WidgetTester tester) => [
    for (final layer in tester.widgetList<PolygonLayer>(
      find.byType(PolygonLayer),
    ))
      ...layer.polygons,
  ];

  /// Markers of [type] in the layers (flutter_map only builds the visible
  /// ones).
  int pins(WidgetTester tester, MapPinType type) => [
    for (final layer in tester.widgetList<MarkerLayer>(
      find.byType(MarkerLayer),
    ))
      for (final m in layer.markers)
        if (m.child case MapPin(type: final t) when t == type) m,
  ].length;

  testWidgets('starts with shade and cool places on, «Cień o 14:30»', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Cień o 14:30'), findsOneWidget);
    expect(polygons(tester), isNotEmpty);
    expect(pins(tester, MapPinType.cool), 19);
    expect(pins(tester, MapPinType.water), 0);
    expect(pins(tester, MapPinType.bench), 0); // only from zoom 17
  });

  testWidgets('all six filters switch their layers', (tester) async {
    final container = await pump(tester);
    Future<void> tap(MapLayer l) async {
      final chip = find.byKey(Key('map-layer-${l.name}'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    // Shade off: no fills.
    await tap(MapLayer.shade);
    expect(find.byType(PolygonLayer), findsNothing);
    expect(find.text('Cień o 14:30'), findsNothing);

    await tap(MapLayer.green);
    expect(polygons(tester).first.color, AppColors.greenLayer);

    await tap(MapLayer.quiet);
    expect(container.read(mapLayersProvider), contains(MapLayer.quiet));
    expect(find.text('Ciemniej = głośniej'), findsOneWidget);

    // A third fill switches off the oldest one (green) with a message.
    await tap(MapLayer.air);
    expect(container.read(mapLayersProvider), isNot(contains(MapLayer.green)));
    expect(find.textContaining('Wyłączyliśmy: Zieleń'), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.text('Dobry'), findsWidgets); // GIOŚ index as text

    await tap(MapLayer.water);
    expect(pins(tester, MapPinType.water), 48);

    await tap(MapLayer.cool);
    expect(pins(tester, MapPinType.cool), 0);
  });

  testWidgets('benches appear from zoom 17', (tester) async {
    await pump(tester);
    MapController.of(
      tester.element(find.byType(MarkerLayer).first),
    ).move(lodzCenter, 17.5);
    await tester.pumpAndSettle();
    expect(pins(tester, MapPinType.bench), greaterThan(0));
  });

  testWidgets('heat banner level 2 opens S14', (tester) async {
    await pump(tester);
    final banner = tester.widget<HeatBanner>(
      find.byKey(const Key('map-heat-banner')),
    );
    expect(banner.level, 2);
    expect(find.text('Ostrzeżenie przed upałem, stopień 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-heat-banner')));
    await tester.pumpAndSettle();
    expect(find.text('S14'), findsOneWidget);
  });

  testWidgets('no alert, no banner', (tester) async {
    await pump(tester, alerts: DemoAlertScenario.none);
    expect(find.byType(HeatBanner), findsNothing);
  });

  testWidgets('heat mode (level 3) keeps cool places on and shows a hint', (
    tester,
  ) async {
    final container = await pump(tester, alerts: DemoAlertScenario.level3);
    expect(find.textContaining('Tryb upału'), findsOneWidget);
    expect(container.read(mapLayersProvider), contains(MapLayer.cool));
    final coolPins = tester
        .widgetList<MapPin>(find.byType(MapPin))
        .where((p) => p.type == MapPinType.cool);
    expect(coolPins, isNotEmpty);
    expect(coolPins.every((p) => p.size == 40), isTrue);
  });

  testWidgets('without location: Śródmieście and «Włącz lokalizację»', (
    tester,
  ) async {
    location.problem = LocationProblem.denied;
    await pump(tester);
    expect(find.byKey(const Key('map-no-location')), findsOneWidget);
    expect(
      MapCamera.of(tester.element(find.byType(MarkerLayer).first)).center,
      lodzCenter,
    );

    await tester.tap(find.text('Włącz lokalizację'));
    await tester.pumpAndSettle();
    expect(location.enableCalls, 1);
    expect(find.byKey(const Key('map-no-location')), findsNothing);
  });

  testWidgets('the search field opens S06', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('map-search')));
    await tester.pumpAndSettle();
    expect(find.text('S06'), findsOneWidget);
  });

  testWidgets('a cool place pin opens S08, «Prowadź tam» opens S07', (
    tester,
  ) async {
    await pump(tester);
    MapController.of(
      tester.element(find.byType(MarkerLayer).first),
    ).move(const LatLng(51.7791, 19.4439), 16);
    await tester.pumpAndSettle();
    final manufaktura = find.byKey(const ValueKey('pin-cool-002'));
    await tester.tap(
      find.descendant(of: manufaktura, matching: find.byType(MapPin)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlaceSheet), findsOneWidget);
    expect(find.text('Manufaktura'), findsOneWidget);

    await tester.tap(find.text('Prowadź tam'));
    await tester.pumpAndSettle();
    expect(find.text('S07'), findsOneWidget);
  });

  testWidgets('shade time picker offers only 14:30 with bundled layers', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('map-shade-time')));
    await tester.pumpAndSettle();
    expect(find.text('Mapa cienia jest policzona dla 14:30.'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsOneWidget);
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    await pump(tester, size: const Size(360, 640), textScale: 1.25);
    expect(tester.takeException(), isNull);
  });

  group('MapLayers', () {
    test('at most 2 fills; points do not count', () {
      final container = ProviderContainer.test();
      final layers = container.read(mapLayersProvider.notifier);
      expect(container.read(mapLayersProvider), MapLayers.initial);
      expect(layers.toggle(MapLayer.water), isNull);
      expect(layers.toggle(MapLayer.green), isNull);
      expect(layers.toggle(MapLayer.quiet), MapLayer.shade);
      expect(container.read(mapLayersProvider), [
        MapLayer.cool,
        MapLayer.water,
        MapLayer.green,
        MapLayer.quiet,
      ]);
      expect(layers.toggle(MapLayer.quiet), isNull);
      expect(
        container.read(mapLayersProvider),
        isNot(contains(MapLayer.quiet)),
      );
    });

    test('shade slots: 8:00–20:00 every 30 min, demo only 14:30', () {
      expect(ShadeTime.slots(demo: true), ['14:30']);
      final all = ShadeTime.slots(demo: false);
      expect(all.first, '8:00');
      expect(all.last, '20:00');
      expect(all, hasLength(25));
      expect(ShadeTime.slotFor(DateTime(2026, 7, 15, 14, 47)), '14:30');
      expect(ShadeTime.slotFor(DateTime(2026, 7, 15, 6)), '8:00');
      expect(ShadeTime.slotFor(DateTime(2026, 7, 15, 22)), '20:00');
    });

    test('GIOŚ colours and noise shades', () {
      expect(airColor(0), const Color(0xFF57B108));
      expect(airColor(null), AppColors.muted);
      expect(noiseColor(75).a, greaterThan(noiseColor(45).a));
    });
  });

  test('places without data still render', () {
    expect(polygonsFor(null, MapLayer.shade), isEmpty);
    expect(PlaceType.values, hasLength(3));
  });
}
