import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/storage/preferences.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile_provider.dart';
import 'package:cool_lodz/features/route/data/address_search.dart';
import 'package:cool_lodz/features/route/data/route_plan.dart';
import 'package:cool_lodz/features/route/endpoint_search_screen.dart';
import 'package:cool_lodz/features/route/route_plan_screen.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:cool_lodz/l10n/app_localizations_pl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

final _now = DateTime(2026, 7, 15, 12, 10);

void main() {
  late SharedPreferences prefs;
  late RecordingApiClient api;
  late FakeLocationService location;
  late FakeAddressSearch addresses;

  setUp(() async {
    prefs = await testPrefs();
    api = RecordingApiClient();
    location = FakeLocationService();
    addresses = FakeAddressSearch();
  });

  /// S06 with a stand-in S07 that reads the route result like S07 does.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/route',
      routes: [
        GoRoute(
          path: '/route',
          builder: (_, _) => RoutePlanScreen(clock: () => _now),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, _) => Consumer(
                builder: (context, ref, _) {
                  final result = ref.watch(routeResultProvider);
                  return Scaffold(
                    body: Text(
                      result.hasValue
                          ? 'variants: ${result.value!.variants.length}'
                          : 'loading',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/profile-select',
          builder: (_, _) => const Scaffold(body: Text('S04')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        locationServiceProvider.overrideWithValue(location),
        addressSearchProvider.overrideWithValue(addresses),
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

  testWidgets('starts with «Moja lokalizacja», «Teraz» and no target', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Moja lokalizacja'), findsOneWidget);
    expect(find.text('Wybierz cel'), findsOneWidget);
    expect(find.text('Profil: Domyślny'), findsOneWidget);
    final show = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-show')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(show.onPressed, isNull);
  });

  testWidgets(
    'a quick route + Senior profile + 18:00 is what goes to module D',
    (tester) async {
      final container = await pump(tester);
      await container
          .read(comfortProfileProvider.notifier)
          .apply(ComfortProfile.preset(ProfileId.senior));
      container
          .read(routePlanProvider.notifier)
          .setDeparture(DateTime(2026, 7, 15, 18));
      await tester.pumpAndSettle();
      expect(find.text('Profil: Senior'), findsOneWidget);
      expect(find.text('Dziś, 18:00'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('route-quick-manufaktura_piotrkowska')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manufaktura'), findsOneWidget);

      await tester.tap(find.byKey(const Key('route-show')));
      await tester.pumpAndSettle();

      expect(find.text('variants: 3'), findsOneWidget);
      final request = api.routeRequests.single;
      expect(request.profile.id, ProfileId.senior);
      expect(request.profile.weights.shade, 90);
      expect(request.datetime, DateTime(2026, 7, 15, 18));
      expect(request.from.label, 'Manufaktura');
      expect(location.currentCalls, 0);
    },
  );

  testWidgets('«Teraz» from my location sends the GPS position and now', (
    tester,
  ) async {
    final container = await pump(tester);
    container
        .read(routePlanProvider.notifier)
        .setTo(
          const PointEndpoint(RoutePoint(lat: 51.76, lon: 19.46, label: 'B')),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('route-show')));
    await tester.pumpAndSettle();

    final request = api.routeRequests.single;
    expect(request.from.lat, location.position.latitude);
    expect(
      request.datetime.difference(DateTime.now()).abs(),
      lessThan(const Duration(minutes: 1)),
    );
    expect(request.profile.id, ProfileId.standard);
  });

  testWidgets('swap exchanges the fields', (tester) async {
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('route-quick-plac_wolnosci_piotrkowska')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('route-swap')));
    await tester.pumpAndSettle();
    final from = tester.getSemantics(find.byKey(const Key('route-from')));
    expect(from.label, 'Skąd: OFF Piotrkowska');
  });

  testWidgets('the profile chip opens S04', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('route-profile')));
    await tester.pumpAndSettle();
    expect(find.text('S04'), findsOneWidget);
  });

  testWidgets('search: a cool place by name without diacritics', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.byKey(const Key('route-to')));
    await tester.pumpAndSettle();
    expect(find.byType(EndpointSearchScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('endpoint-search-field')),
      'manufak',
    );
    await tester.pump();
    await tester.tap(find.text('Manufaktura'));
    await tester.pumpAndSettle();

    final to = container.read(routePlanProvider).to! as PointEndpoint;
    expect(to.place?.id, 'cool-002');
    expect(find.text('Manufaktura'), findsOneWidget);
  });

  testWidgets('search: addresses come after the debounce', (tester) async {
    addresses.results = const [
      RoutePoint(lat: 51.7581, lon: 19.4573, label: 'Piotrkowska 104'),
    ];
    final container = await pump(tester);
    await tester.tap(find.byKey(const Key('route-to')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('endpoint-search-field')),
      'Piotrkowska 1',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(addresses.queries, isEmpty);
    await tester.enterText(
      find.byKey(const Key('endpoint-search-field')),
      'Piotrkowska 104',
    );
    await tester.pump(EndpointSearchScreen.debounce);
    await tester.pumpAndSettle();
    expect(addresses.queries, ['Piotrkowska 104']);

    await tester.tap(find.widgetWithText(ListTile, 'Piotrkowska 104'));
    await tester.pumpAndSettle();
    final to = container.read(routePlanProvider).to! as PointEndpoint;
    expect(to.point.lat, 51.7581);
  });

  testWidgets('search: offline address search shows a message', (tester) async {
    addresses.error = Exception('offline');
    await pump(tester);
    await tester.tap(find.byKey(const Key('route-from')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('endpoint-my-location')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('endpoint-search-field')),
      'Zgierska',
    );
    await tester.pump(EndpointSearchScreen.debounce);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nie udało się wyszukać adresów'),
      findsOneWidget,
    );
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    final container = await pump(
      tester,
      size: const Size(360, 640),
      textScale: 1.25,
    );
    container
        .read(routePlanProvider.notifier)
        .setDeparture(DateTime(2026, 7, 18, 18));
    final quick = find.byKey(
      const Key('route-quick-plac_wolnosci_piotrkowska'),
    );
    await tester.scrollUntilVisible(quick, 100);
    await tester.tap(quick);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('formatDeparture', () async {
    await initializeDateFormatting('pl');
    final l10n = AppLocalizationsPl();
    expect(
      formatDeparture(DateTime(2026, 7, 15, 9, 5), _now, l10n),
      'Dziś, 9:05',
    );
    expect(
      formatDeparture(DateTime(2026, 7, 16, 18), _now, l10n),
      'Jutro, 18:00',
    );
    expect(
      formatDeparture(DateTime(2026, 7, 17, 18), _now, l10n),
      'pt. 17.07, 18:00',
    );
  });

  test('matchPlaces ignores case and Polish letters', () {
    const places = [
      Place(
        id: 'a',
        type: PlaceType.cool,
        name: 'Łódzki Dom Kultury',
        lat: 0,
        lon: 0,
      ),
      Place(
        id: 'b',
        type: PlaceType.cool,
        name: 'Biblioteka',
        address: 'ul. Gdańska 8',
        lat: 0,
        lon: 0,
      ),
    ];
    expect(matchPlaces(places, 'lodzki').single.id, 'a');
    expect(matchPlaces(places, 'GDANSKA').single.id, 'b');
    expect(matchPlaces(places, ''), hasLength(2));
  });
}
