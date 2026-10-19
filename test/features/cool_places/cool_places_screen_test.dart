import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/features/cool_places/cool_places_screen.dart';
import 'package:cool_lodz/features/cool_places/place_screen.dart';
import 'package:cool_lodz/features/cool_places/place_sheet.dart';
import 'package:cool_lodz/features/route/data/route_plan.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:cool_lodz/shared/widgets/place_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Monday 2026-07-13, 9:00: most places are still closed.
final _monday9 = DateTime(2026, 7, 13, 9);

/// Wednesday 2026-07-15, 12:00.
final _wednesday12 = DateTime(2026, 7, 15, 12);

void main() {
  late SharedPreferences prefs;
  late FakeLocationService location;

  setUp(() async {
    prefs = await testPrefs();
    // Manufaktura.
    location = FakeLocationService(position: const LatLng(51.7791, 19.4439));
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    DateTime? now,
    String initial = '/cool',
    Size size = const Size(400, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/cool', builder: (_, _) => const CoolPlacesScreen()),
        GoRoute(
          path: '/place/:id',
          builder: (_, s) => PlaceScreen(placeId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/route/result',
          builder: (_, _) => const Scaffold(body: Text('S07')),
        ),
        GoRoute(
          path: '/report',
          builder: (_, _) => const Scaffold(body: Text('S15')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(prefs: prefs, location: location),
        clockProvider.overrideWithValue(() => now ?? _wednesday12),
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
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapChip(WidgetTester tester, String key) async {
    final chip = find.byKey(Key(key));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
  }

  List<String> listedNames(WidgetTester tester) => [
    for (final item in tester.widgetList<PlaceListItem>(
      find.byType(PlaceListItem),
    ))
      item.name,
  ];

  testWidgets('list is sorted by distance from the user', (tester) async {
    await pump(tester);
    final names = listedNames(tester);
    expect(names.first, 'Manufaktura');
    expect(find.textContaining('Odległości od centrum'), findsNothing);
  });

  testWidgets('item shows type, distance, today hours and status', (
    tester,
  ) async {
    await pump(tester);
    final item = tester.widget<PlaceListItem>(
      find.byKey(const Key('cool-item-cool-002')),
    );
    expect(item.subtitle, startsWith('Centrum handlowe · '));
    expect(item.subtitle, contains('Dziś 10:00–22:00'));
    expect(item.statusText, 'Otwarte teraz · do 22:00');
  });

  testWidgets('«W queście» shows the 7 quest places', (tester) async {
    await pump(tester, size: const Size(400, 4000));
    await tapChip(tester, 'cool-filter-quest');
    await tester.pumpAndSettle();
    expect(listedNames(tester), hasLength(7));
  });

  testWidgets('«Otwarte teraz» uses the hours', (tester) async {
    // Monday 3:00: only the station and the parks (always open).
    await pump(
      tester,
      now: DateTime(2026, 7, 13, 3),
      size: const Size(400, 4000),
    );
    expect(listedNames(tester), hasLength(19));
    await tapChip(tester, 'cool-filter-openNow');
    await tester.pumpAndSettle();
    expect(listedNames(tester), hasLength(6));
    expect(listedNames(tester), contains('Dworzec Łódź Fabryczna'));
    expect(listedNames(tester), isNot(contains('Manufaktura')));
  });

  testWidgets('nothing matches → «Pokaż wszystkie» clears the filters', (
    tester,
  ) async {
    await pump(tester, size: const Size(400, 4000));
    // No place in the demo list declares drinking water.
    await tapChip(tester, 'cool-filter-water');
    await tester.pumpAndSettle();
    expect(find.text('Brak otwartych miejsc w pobliżu'), findsOneWidget);
    await tester.tap(find.text('Pokaż wszystkie'));
    await tester.pumpAndSettle();
    expect(listedNames(tester), hasLength(19));
  });

  testWidgets('without location distances are from the centre', (tester) async {
    location.problem = LocationProblem.denied;
    await pump(tester);
    expect(find.textContaining('Odległości od centrum'), findsOneWidget);
  });

  testWidgets('Lista / Mapa switch', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cool-map')), findsOneWidget);
    expect(find.byKey(const Key('cool-list')), findsNothing);
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cool-list')), findsOneWidget);
  });

  testWidgets('tap → S08 sheet; «Prowadź tam» → S07 with the place as B', (
    tester,
  ) async {
    final container = await pump(
      tester,
      now: _monday9,
      size: const Size(400, 4000),
    );
    await tester.tap(find.byKey(const Key('cool-item-cool-001')));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceSheet), findsOneWidget);
    final sheet = find.byType(PlaceSheet);
    Finder inSheet(String text) => find.descendant(
      of: sheet,
      matching: find.textContaining(text, findRichText: true),
    );
    expect(inSheet('Zamknięte, otwarcie jutro o 10:00'), findsWidgets);
    expect(inSheet('Dziś nieczynne'), findsWidgets);
    expect(inSheet('Litera do zdobycia'), findsOneWidget);

    await tester.tap(find.text('Prowadź tam'));
    await tester.pumpAndSettle();
    expect(find.text('S07'), findsOneWidget);
    final to = container.read(routePlanProvider).to! as PointEndpoint;
    expect(to.place?.id, 'cool-001');
    expect(container.read(routePlanProvider).from, const MyLocation());
  });

  testWidgets('«Zgłoś problem» opens S15', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('cool-item-cool-002')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zgłoś problem'));
    await tester.pumpAndSettle();
    expect(find.text('S15'), findsOneWidget);
  });

  testWidgets('a link to one place opens it full screen', (tester) async {
    await pump(tester, initial: '/place/cool-002');
    expect(find.text('Manufaktura'), findsOneWidget);
    expect(find.text('Prowadź tam'), findsOneWidget);
  });

  testWidgets('an unknown place id says so', (tester) async {
    await pump(tester, initial: '/place/nope');
    expect(find.text('Nie znaleźliśmy tego miejsca'), findsOneWidget);
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    await pump(tester, size: const Size(360, 640), textScale: 1.25);
    await tester.tap(find.byKey(const Key('cool-item-cool-002')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
