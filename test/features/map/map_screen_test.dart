import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/demo_weather.dart';
import 'package:cool_lodz/core/api/live/weather.dart';
import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/community/community_sheet.dart';
import 'package:cool_lodz/features/community/data/crowd_points.dart';
import 'package:cool_lodz/features/cool_places/place_sheet.dart';
import 'package:cool_lodz/features/heat_risk/data/heat_risk_providers.dart';
import 'package:cool_lodz/features/map/data/map_layers_style.dart';
import 'package:cool_lodz/features/map/data/map_providers.dart';
import 'package:cool_lodz/features/map/map_screen.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:cool_lodz/shared/share.dart';
import 'package:cool_lodz/shared/widgets/heat_banner.dart';
import 'package:cool_lodz/shared/widgets/map_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
    WeatherForecast? forecast,
    List<Override> extra = const [],
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
        forecastProvider.overrideWith((ref) => forecast),
        ...extra,
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
    // Like a traffic light: green where it is quiet, red along loud roads.
    expect(find.text('Głośno: ruch uliczny'), findsOneWidget);
    expect(find.text('Cicho'), findsOneWidget);
    expect(
      polygons(tester).map((p) => p.color),
      containsAll([quietColor(0), quietColor(1), quietColor(2)]),
    );

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

  testWidgets('«Ławki» is its own layer, shown from zoom 16', (tester) async {
    final container = await pump(tester);
    final controller = MapController.of(
      tester.element(find.byType(MarkerLayer).first),
    );
    controller.move(lodzCenter, 16.5);
    await tester.pumpAndSettle();
    expect(pins(tester, MapPinType.bench), 0); // off by default
    final chip = find.byKey(const Key('map-layer-benches'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(container.read(mapLayersProvider), contains(MapLayer.benches));
    expect(pins(tester, MapPinType.bench), greaterThan(0));
    // Further out: a hint instead of the pins.
    controller.move(lodzCenter, 14);
    await tester.pumpAndSettle();
    expect(find.text('Przybliż mapę, aby zobaczyć ławki'), findsOneWidget);
  });

  testWidgets('trees under the shadows from zoom 16', (tester) async {
    await pump(tester);
    expect(tester.widgetList<CircleLayer>(find.byType(CircleLayer)), isEmpty);
    MapController.of(
      tester.element(find.byType(MarkerLayer).first),
    ).move(lodzCenter, 16.5);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final trees = [
      for (final l in tester.widgetList<CircleLayer>(find.byType(CircleLayer)))
        ...l.circles,
    ];
    expect(trees, isNotEmpty);
    expect(trees.first.useRadiusInMeter, isTrue);
    expect(find.text('Drzewa'), findsOneWidget);
  });

  testWidgets('«Nocą» and «Zima» draw street lines, one at a time', (
    tester,
  ) async {
    final container = await pump(tester, size: const Size(400, 1000));
    Future<void> tap(MapLayer l) async {
      final chip = find.byKey(Key('map-layer-${l.name}'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await tap(MapLayer.night);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('Najwięcej ludzi wieczorem'), findsOneWidget);
    final night = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(night.polylines.map((p) => p.color), contains(nightColor(3)));

    await tap(MapLayer.winter);
    expect(container.read(mapLayersProvider), isNot(contains(MapLayer.night)));
    expect(find.text('Odśnieżane najpierw'), findsOneWidget);
    final winter = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(winter.polylines.map((p) => p.color), contains(winterColor(1)));

    await tap(MapLayer.toilets);
    expect(find.byIcon(Icons.wc_rounded), findsWidgets);
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

  testWidgets('dragging the map moves it', (tester) async {
    await pump(tester);
    LatLng centre() =>
        MapCamera.of(tester.element(find.byType(MarkerLayer).first)).center;
    final before = centre();
    await tester.dragFrom(const Offset(200, 600), const Offset(-150, -150));
    await tester.pumpAndSettle();
    expect(centre(), isNot(before));
  });

  testWidgets('live shadows: a zoom-in hint, then shadows of the area', (
    tester,
  ) async {
    await prefs.setBool(DemoMode.prefsKey, false); // the on-phone API
    await pump(tester);
    expect(find.text('Przybliż mapę, aby zobaczyć cienie'), findsOneWidget);
    await tester.tap(find.text('Przybliż mapę, aby zobaczyć cienie'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Przybliż mapę, aby zobaczyć cienie'), findsNothing);
    expect(find.byType(PolygonLayer), findsOneWidget);
  });

  testWidgets('a turned map shows the compass; a tap turns it north', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('map-compass')), findsNothing);
    final controller = MapController.of(
      tester.element(find.byType(MarkerLayer).first),
    );
    controller.rotate(40);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-compass')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-compass')));
    await tester.pumpAndSettle();
    expect(controller.camera.rotation, 0);
    expect(find.byKey(const Key('map-compass')), findsNothing);
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

  testWidgets('live: a wheel picker with the weather sets any time', (
    tester,
  ) async {
    await prefs.setBool(DemoMode.prefsKey, false);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final forecast = WeatherForecast([
      for (var h = 0; h <= 48; h++)
        WeatherHour(
          time: day.add(Duration(hours: h)).toUtc(),
          temperature: 20.0 + h % 24 / 2,
          weatherCode: h % 24 == 16 ? 61 : 0,
          windSpeed: h % 24 == 16 ? 40 : 10,
          precipitationProbability: h % 24 == 16 ? 80 : 0,
        ),
    ]);
    final container = await pump(tester, forecast: forecast);
    await tester.tap(find.byKey(const Key('map-shade-time')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('time-wheel-hour')), findsOneWidget);
    expect(find.byKey(const Key('time-wheel-minute')), findsOneWidget);
    expect(find.byKey(const Key('time-wheel-strip')), findsOneWidget);

    // Tomorrow, then 15:00 from the hourly strip (rain, wind).
    await tester.tap(find.byKey(const Key('time-wheel-day-1')));
    await tester.pumpAndSettle();
    // The strip opens near the current hour: back to midnight first.
    await tester.drag(
      find.byKey(const Key('time-wheel-strip')),
      const Offset(3000, 0),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('time-wheel-strip-15')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('time-wheel-strip')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('time-wheel-strip-15')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('time-wheel-strip-15')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deszcz'), findsWidgets);
    expect(find.text('Wietrznie, 40 km/h'), findsOneWidget);
    expect(find.byIcon(Icons.air_rounded), findsWidgets);
    await tester.tap(find.byKey(const Key('time-wheel-done')));
    await tester.pumpAndSettle();
    expect(
      container.read(shadeTimeProvider),
      DateTime(day.year, day.month, day.day + 1, 15),
    );
    expect(find.textContaining('jutro 15:00'), findsOneWidget);
  });

  testWidgets('heat risk: the chip opens the details, with paws for dogs', (
    tester,
  ) async {
    await prefs.setBool(WalksWithDog.prefsKey, true);
    // A summer noon: the sun is high, the asphalt hot.
    final noon = DateTime(2026, 7, 15, 12);
    await pump(
      tester,
      size: const Size(400, 1000),
      forecast: DemoWeather.forecast(noon),
      extra: [clockProvider.overrideWithValue(() => noon)],
    );
    // 37 °C feels like at the peak; the demo alert is level 2.
    expect(find.text('Upał: wysokie · 37°C'), findsOneWidget);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('heat-risk-chip')));
    await tester.pumpAndSettle();
    expect(find.text('WYSOKIE'), findsOneWidget);
    expect(find.text('Odczuwalna teraz: 35°C'), findsOneWidget);
    expect(find.text('UV do 8: bardzo wysoki'), findsOneWidget);
    expect(find.byKey(const Key('heat-risk-paws')), findsOneWidget);
    expect(find.textContaining('Za gorąco dla łap psa'), findsOneWidget);
    expect(find.text('Źle się czujesz? Sprawdź objawy'), findsOneWidget);
    // Demo air: grass in bloom, ozone.
    expect(
      find.text('Pyłki: trawy – wysokie, ambrozja – niskie'),
      findsOneWidget,
    );
    expect(
      find.text('Powietrze dziś: umiarkowane (europejski indeks 58)'),
      findsOneWidget,
    );
    expect(find.textContaining('Alergikom i astmatykom'), findsOneWidget);
    expect(find.byKey(const Key('read-aloud')), findsOneWidget);
    expect(find.byKey(const Key('heat-risk-day-plan')), findsOneWidget);
  });

  testWidgets('heat risk without a forecast follows the warning', (
    tester,
  ) async {
    await pump(tester, alerts: DemoAlertScenario.none);
    expect(find.byKey(const Key('heat-risk-chip')), findsNothing);
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    await pump(tester, size: const Size(360, 640), textScale: 1.25);
    expect(tester.takeException(), isNull);
  });

  group('MapLayers', () {
    test('at most 2 fills; points do not count', () {
      final container = ProviderContainer.test(
        overrides: [seniorModeProvider.overrideWithValue(false)],
      );
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

    test('seniors start with benches; street modes replace each other', () {
      final container = ProviderContainer.test(
        overrides: [seniorModeProvider.overrideWithValue(true)],
      );
      final layers = container.read(mapLayersProvider.notifier);
      expect(container.read(mapLayersProvider), MapLayers.initialSenior);
      expect(layers.toggle(MapLayer.night), isNull);
      expect(layers.toggle(MapLayer.winter), MapLayer.night);
      expect(container.read(mapLayersProvider), [
        MapLayer.shade,
        MapLayer.cool,
        MapLayer.benches,
        MapLayer.winter,
      ]);
      // Lines are not fills: two fills still fit next to them.
      expect(layers.toggle(MapLayer.green), isNull);
    });

    test('shade time: demo 14:30, otherwise now in 5-minute steps', () {
      expect(
        ShadeTime.demoTime(DateTime(2026, 7, 15, 9, 7)),
        DateTime(2026, 7, 15, 14, 30),
      );
      expect(
        ShadeTime.roundDown(DateTime(2026, 7, 15, 22, 47, 30)),
        DateTime(2026, 7, 15, 22, 45),
      );
    });

    test('shade time label: today, tomorrow, later', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('pl'));
      final now = DateTime(2026, 10, 21, 10);
      expect(shadeTimeLabel(DateTime(2026, 10, 21, 9, 5), now, l10n), '9:05');
      expect(
        shadeTimeLabel(DateTime(2026, 10, 22, 18), now, l10n),
        'jutro 18:00',
      );
      expect(
        shadeTimeLabel(DateTime(2026, 10, 24, 7, 30), now, l10n),
        'sob. 24.10 7:30',
      );
    });

    test('GIOŚ colours and quiet shades', () {
      expect(airColor(0), const Color(0xFF57B108));
      expect(airColor(null), AppColors.muted);
      expect(quietColor(2).a, greaterThan(quietColor(1).a));
    });
  });

  test('places without data still render', () {
    expect(polygonsFor(null, MapLayer.shade), isEmpty);
    expect(PlaceType.values, hasLength(3));
  });

  testWidgets('«Wyspy ciepła», «Nawierzchnia» with steps, fountains', (
    tester,
  ) async {
    final container = await pump(tester, size: const Size(400, 1000));
    Future<void> tap(MapLayer l) async {
      final chip = find.byKey(Key('map-layer-${l.name}'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await tap(MapLayer.heat);
    expect(
      polygons(tester).map((p) => p.color),
      containsAll([heatIslandColor(3), heatIslandColor(0)]),
    );
    expect(find.text('Najgoręcej: dachy i bruk'), findsOneWidget);

    await tap(MapLayer.surface);
    final lines = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(lines.polylines.map((p) => p.color), contains(surfaceColor(3)));
    expect(find.text('Kocie łby'), findsOneWidget);
    expect(find.text('Przybliż, aby zobaczyć schody'), findsOneWidget);
    MapController.of(
      tester.element(find.byType(MarkerLayer).first),
    ).move(const LatLng(51.7595, 19.4575), 17);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stairs_rounded), findsWidgets);

    await tap(MapLayer.water);
    expect(container.read(mapLayersProvider), contains(MapLayer.water));
    final fountains = [
      for (final l in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)))
        for (final m in l.markers)
          if (m.key case ValueKey<String>(
            :final value,
          ) when value.startsWith('fountain-'))
            m,
    ];
    expect(fountains, isNotEmpty);
  });

  testWidgets('«Społeczność»: add at the map centre, vote, export', (
    tester,
  ) async {
    final crowd = _FakeCrowd([
      const CrowdPoint(
        id: 'p1',
        kind: CrowdKind.tap,
        point: lodzCenter,
        uid: 'other',
        votes: 2,
      ),
    ]);
    final shared = <String>[];
    await pump(
      tester,
      size: const Size(400, 1000),
      extra: [
        crowdRepositoryProvider.overrideWithValue(crowd),
        shareTextProvider.overrideWithValue((text, {title}) async {
          shared.add(text);
          return true;
        }),
      ],
    );
    final chip = find.byKey(const Key('map-layer-community'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byType(CrowdPin), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-crowd-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crowd-kind-tree')));
    await tester.enterText(find.byKey(const Key('crowd-note')), 'Bez cienia');
    await tester.tap(find.byKey(const Key('crowd-save')));
    await tester.pumpAndSettle();
    expect(crowd.added, [(CrowdKind.tree, 'Bez cienia')]);

    // Cool place pins lie on top here: open it as a tap would.
    tester.widget<CrowdPin>(find.byType(CrowdPin).first).onTap();
    await tester.pumpAndSettle();
    expect(find.text('Potwierdziły 2 osoby.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('crowd-vote')));
    await tester.pumpAndSettle();
    expect(crowd.votes, ['p1']);

    await tester.tap(find.byKey(const Key('map-crowd-export')));
    await tester.pumpAndSettle();
    expect(shared.single, contains('FeatureCollection'));
  });
}

class _FakeCrowd implements CrowdRepository {
  _FakeCrowd(this.points);

  final List<CrowdPoint> points;
  final added = <(CrowdKind, String)>[];
  final votes = <String>[];

  @override
  Stream<List<CrowdPoint>> watch({int limit = 500}) => Stream.value(points);

  @override
  Future<void> add(
    String uid,
    CrowdKind kind,
    LatLng point, {
    String note = '',
  }) async => added.add((kind, note));

  @override
  Future<void> vote(String uid, CrowdPoint point) async => votes.add(point.id);

  @override
  Future<void> remove(CrowdPoint point) async {}
}
