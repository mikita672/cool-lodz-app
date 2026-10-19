import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/reference_routes.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/storage/offline_cache.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile_provider.dart';
import 'package:cool_lodz/features/route/data/google_maps.dart';
import 'package:cool_lodz/features/route/data/route_plan.dart';
import 'package:cool_lodz/features/route/route_result_screen.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:cool_lodz/shared/widgets/route_variant_card.dart' as ds;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Module D without `sunShareByHour` (DEP-03 not agreed).
class _NoHourlyApi extends RecordingApiClient {
  @override
  Future<RouteResponse> getRoutes(RouteRequest request) async {
    final full = await super.getRoutes(request);
    return RouteResponse(
      coverage: full.coverage,
      variants: [
        for (final v in full.variants)
          RouteVariant(
            variant: v.variant,
            geometry: v.geometry,
            segments: v.segments,
            distanceM: v.distanceM,
            durationS: v.durationS,
            sunShare: v.sunShare,
            extraTimeVsShortestS: v.extraTimeVsShortestS,
            stops: v.stops,
          ),
      ],
    );
  }
}

void main() {
  late SharedPreferences prefs;
  late RecordingApiClient api;
  late FakeLocationService location;
  late FakeGameRepository history;
  late List<Uri> launched;

  setUp(() async {
    prefs = await testPrefs();
    api = RecordingApiClient();
    location = FakeLocationService();
    history = FakeGameRepository();
    launched = [];
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    ProfileId profile = ProfileId.standard,
    RoutePlan? plan,
    bool senior = false,
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: prefs,
          api: api,
          location: location,
          game: history,
        ),
      ],
    );
    await container
        .read(comfortProfileProvider.notifier)
        .apply(ComfortProfile.preset(profile).copyWith(seniorMode: senior));
    final notifier = container.read(routePlanProvider.notifier);
    if (plan == null) {
      notifier
        ..useReference(ReferenceRoutes.manufakturaPiotrkowska)
        ..setDeparture(DateTime(2026, 7, 15, 14, 30));
    } else {
      notifier
        ..setFrom(plan.from)
        ..setTo(plan.to)
        ..setDeparture(plan.departAt);
    }
    final router = GoRouter(
      initialLocation: '/route/result',
      routes: [
        GoRoute(
          path: '/route',
          builder: (_, _) => const Scaffold(body: Text('S06')),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, _) => RouteResultScreen(
                launch: (url) async {
                  launched.add(url);
                  return true;
                },
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final isSenior = ref.watch(seniorModeProvider);
            return MaterialApp.router(
              theme: AppTheme.light(senior: isSenior),
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
                  textScaler: TextScaler.linear(isSenior ? 1.25 : 1),
                  disableAnimations: true,
                ),
                child: child!,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  bool isSelected(WidgetTester tester, RouteVariantType type) =>
      isSemantics(isSelected: true).matches(
        tester.getSemantics(find.byKey(Key('route-card-${type.name}'))),
        {},
      );

  testWidgets('a reference route shows 3 variants, Kompromis selected', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Najkrótsza'), findsOneWidget);
    expect(find.text('Zacieniona'), findsOneWidget);
    expect(find.text('Kompromis'), findsOneWidget);
    expect(isSelected(tester, RouteVariantType.compromise), isTrue);
    expect(isSelected(tester, RouteVariantType.shaded), isFalse);
    expect(find.textContaining('Manufaktura →'), findsOneWidget);
    expect(find.textContaining('Wyjście: '), findsOneWidget);
    expect(find.byKey(const Key('route-approximate')), findsNothing);
    expect(api.routeRequests.single.profile.id, ProfileId.standard);
  });

  testWidgets('Senior profile selects Zacieniona by default', (tester) async {
    final container = await pump(tester, profile: ProfileId.senior);
    expect(isSelected(tester, RouteVariantType.shaded), isTrue);

    // Changing the profile changes the default (and asks again).
    await container
        .read(comfortProfileProvider.notifier)
        .apply(ComfortProfile.preset(ProfileId.tourist));
    await tester.pumpAndSettle();
    expect(isSelected(tester, RouteVariantType.compromise), isTrue);
    expect(api.routeRequests.last.profile.id, ProfileId.tourist);
  });

  testWidgets('tapping a card selects it', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('route-card-shortest')));
    await tester.pumpAndSettle();
    expect(isSelected(tester, RouteVariantType.shortest), isTrue);
    expect(isSelected(tester, RouteVariantType.compromise), isFalse);
  });

  testWidgets('«Prowadź» opens Google Maps walking and records the route', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('route-card-shaded')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('route-go')));
    await tester.pumpAndSettle();

    final url = launched.single;
    expect(url.host, 'www.google.com');
    expect(url.queryParameters['travelmode'], 'walking');
    expect(url.queryParameters['origin'], startsWith('51.77'));

    // Back from Google Maps: +10 for the shaded route, Pierwszy krok.
    expect(find.text('+10 pkt za trasę w cieniu'), findsOneWidget);
    expect(find.text('Pierwszy krok'), findsOneWidget);
    expect(history.state.points, 40);

    final (uid, route) = history.routes.single;
    expect(uid, 'u1');
    expect(route.variant, RouteVariantType.shaded);
    expect(route.departAt, DateTime(2026, 7, 15, 14, 30));
    expect(route.to.label, 'ul. Piotrkowska (Pasaż Rubinsteina)');
    expect(route.toFirestore().keys, {
      'from',
      'to',
      'departAt',
      'variant',
      'sunShare',
      'distance_m',
      'endPlaceType',
      'createdAt',
    });
  });

  testWidgets('«Zapisz» keeps the route for offline use', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byKey(const Key('route-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trasa zapisana'), findsOneWidget);
    final cached = container.read(offlineCacheProvider).lastRoute()!;
    expect(cached.response.variants, hasLength(3));
    expect(history.routes, isEmpty); // «Zapisz» does not count (Q-08)
    expect(history.log, isEmpty);
  });

  testWidgets('a synthetic route says shade is approximate', (tester) async {
    await pump(
      tester,
      plan: const RoutePlan(
        from: PointEndpoint(RoutePoint(lat: 51.75, lon: 19.40, label: 'A')),
        to: PointEndpoint(RoutePoint(lat: 51.76, lon: 19.41, label: 'B')),
      ),
    );
    expect(find.text('Dla tego obszaru cień jest przybliżony'), findsOneWidget);
  });

  testWidgets('no location: enable it or choose a start point', (tester) async {
    location.problem = LocationProblem.denied;
    await pump(
      tester,
      plan: const RoutePlan(
        to: PointEndpoint(RoutePoint(lat: 51.76, lon: 19.46, label: 'B')),
      ),
    );
    expect(find.text('Nie znamy Twojej lokalizacji'), findsOneWidget);
    await tester.tap(find.text('Włącz lokalizację'));
    await tester.pumpAndSettle();
    expect(location.enableCalls, 1);
    expect(find.text('Kompromis'), findsOneWidget);
  });

  testWidgets('route not found offers to change the points', (tester) async {
    api.routeError = const ApiException(ApiErrorKind.notFound);
    await pump(tester);
    expect(find.text('Nie znaleźliśmy trasy'), findsOneWidget);
    await tester.tap(find.text('Zmień punkty'));
    await tester.pumpAndSettle();
    expect(find.text('S06'), findsOneWidget);
  });

  testWidgets('other errors can be retried', (tester) async {
    api.routeError = const ApiException(ApiErrorKind.server);
    await pump(tester);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
    api.routeError = null;
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(find.text('Kompromis'), findsOneWidget);
  });

  testWidgets('Senior: one card at a time, arrows switch variants', (
    tester,
  ) async {
    await pump(
      tester,
      profile: ProfileId.senior,
      senior: true,
      size: const Size(360, 800),
    );
    expect(find.text('Zacieniona'), findsOneWidget);
    expect(find.text('Kompromis'), findsNothing);
    expect(find.text('Wariant 2 z 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Następny wariant'));
    await tester.pumpAndSettle();
    expect(find.text('Kompromis'), findsOneWidget);
    expect(find.text('Wariant 3 z 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Najlepsza pora wyjścia (APP-22)', () {
    int shadeOf(WidgetTester tester, String variant) => tester
        .widget<ds.RouteVariantCard>(find.byKey(Key('route-card-$variant')))
        .shadePercent;

    testWidgets('moving the slider changes the shade on the cards', (
      tester,
    ) async {
      await pump(tester, size: const Size(400, 1400));
      expect(find.byKey(const Key('route-best-time')), findsOneWidget);
      expect(find.textContaining('Najwięcej cienia o'), findsOneWidget);
      final before = shadeOf(tester, 'shaded');
      // 14:30 is in the middle; drag to the right end (20:00).
      await tester.drag(
        find.byKey(const Key('route-time-slider')),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();
      final after = shadeOf(tester, 'shaded');
      expect(after, isNot(before));
      expect(find.textContaining('20:00'), findsWidgets);
      // No new request: the hourly shares come with the first answer.
      expect(api.routeRequests, hasLength(1));

      // «Prowadź» now uses 20:00 as the departure.
      await tester.tap(find.byKey(const Key('route-go')));
      await tester.pumpAndSettle();
      expect(history.routes.single.$2.departAt.hour, 20);
    });

    testWidgets('hidden without sunShareByHour (DEP-03)', (tester) async {
      api = _NoHourlyApi();
      await pump(tester);
      expect(find.byKey(const Key('route-best-time')), findsNothing);
      expect(find.text('Kompromis'), findsOneWidget);
    });
  });

  group('routePolylines', () {
    RouteVariant variant(
      RouteVariantType type, {
      List<RouteSegment> segments = const [],
    }) => RouteVariant(
      variant: type,
      geometry: const [
        LatLng(51.0, 19.0),
        LatLng(51.1, 19.1),
        LatLng(51.2, 19.2),
        LatLng(51.3, 19.3),
      ],
      segments: segments,
      distanceM: 1000,
      durationS: 600,
      sunShare: 0.3,
      extraTimeVsShortestS: 0,
    );

    test('selected line split by segments, others muted underneath', () {
      final response = RouteResponse(
        coverage: RouteCoverage.full,
        variants: [
          variant(RouteVariantType.shortest),
          variant(
            RouteVariantType.shaded,
            segments: const [
              RouteSegment(from: 0, to: 1, sunShare: 0.1),
              RouteSegment(from: 1, to: 3, sunShare: 0.8),
            ],
          ),
          variant(RouteVariantType.compromise),
        ],
      );
      final lines = routePolylines(response, RouteVariantType.shaded);
      expect(lines, hasLength(4));
      expect(lines[0].color, AppColors.muted);
      expect(lines[0].strokeWidth, 4);
      expect(lines[2].color, AppColors.primary);
      expect(lines[2].points, hasLength(2));
      expect(lines[3].color, AppColors.sun);
      expect(lines[3].points, hasLength(3));
      expect(lines[3].strokeWidth, 6);
    });

    test('without segments the selected line has one colour', () {
      final response = RouteResponse(
        coverage: RouteCoverage.full,
        variants: [variant(RouteVariantType.compromise)],
      );
      final lines = routePolylines(response, RouteVariantType.compromise);
      expect(lines.single.color, AppColors.primary);
      expect(lines.single.points, hasLength(4));
    });
  });

  test('default variant per profile', () {
    expect(defaultVariant(ProfileId.senior), RouteVariantType.shaded);
    expect(defaultVariant(ProfileId.tourist), RouteVariantType.compromise);
    expect(defaultVariant(ProfileId.standard), RouteVariantType.compromise);
  });

  test('Google Maps link: walking, at most 8 waypoints', () {
    final line = [
      for (var i = 0; i < 100; i++) LatLng(51.7 + i / 1000, 19.4 + i / 1000),
    ];
    final url = GoogleMapsLink.walking(line);
    expect(url.queryParameters['origin'], '51.700000,19.400000');
    expect(url.queryParameters['destination'], '51.799000,19.499000');
    expect(url.queryParameters['waypoints']!.split('|'), hasLength(8));

    final short = GoogleMapsLink.walking(const [
      LatLng(51, 19),
      LatLng(52, 20),
    ]);
    expect(short.queryParameters.containsKey('waypoints'), isFalse);
  });
}
