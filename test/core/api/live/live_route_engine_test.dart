import 'dart:convert';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/live/live_route_engine.dart';
import 'package:cool_lodz/core/api/live/osrm_client.dart';
import 'package:cool_lodz/core/api/live/shade_model.dart';
import 'package:cool_lodz/core/api/live/weather.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

Matcher apiError(ApiErrorKind kind) =>
    isA<ApiException>().having((e) => e.kind, 'kind', kind);

const senior = RouteProfile(
  id: ProfileId.senior,
  weights: ProfileWeights(shade: 90, time: 20, quiet: 60, air: 60),
);

RouteRequest request(
  LatLng from,
  LatLng to, {
  String at = '2026-07-15T14:30:00+02:00',
}) => RouteRequest(
  from: RoutePoint.fromLatLng(from),
  to: RoutePoint.fromLatLng(to),
  datetime: DateTime.parse(at),
  profile: senior,
);

/// Number of points in an OSRM route URL.
int pointCount(RequestOptions o) => o.uri.pathSegments.last.split(';').length;

String lineJson(List<LatLng> points, {required double distance}) =>
    '{"code":"Ok","routes":[{"geometry":{"type":"LineString","coordinates":'
    '[${points.map((p) => '[${p.longitude},${p.latitude}]').join(',')}]},'
    '"distance":$distance,"duration":${distance / 1.3}}]}';

void main() {
  final bundled = DemoApiClient(loadAsset: readAssetFile);
  final when = DateTime(2026, 7, 15, 14, 30);
  late ShadeModel realModel;

  setUpAll(() async {
    realModel = ShadeModel.fromLayers(
      shade: await bundled.getLayer(LayerKind.shade, datetime: when),
      green: await bundled.getLayer(LayerKind.green, datetime: when),
    );
  });

  LiveRouteEngine engine(
    FakeAdapter adapter, {
    ShadeModel? model,
    WeatherForecast? weather,
  }) => LiveRouteEngine(
    osrm: OsrmClient(fakeDio(adapter)),
    shadeModel: () async => model ?? realModel,
    places: () => bundled.getPlaces(types: {PlaceType.cool, PlaceType.water}),
    weather: weather == null ? null : () async => weather,
  );

  group('with the real OSRM answers (Manufaktura → Piotrkowska)', () {
    const from = LatLng(51.7794, 19.4466);
    const to = LatLng(51.7676, 19.4568);

    FakeAdapter osrm() => FakeAdapter(
      (o) => pointCount(o) == 2
          ? jsonBody(fixture('live/osrm_route_alternatives.json'))
          : jsonBody(fixture('live/osrm_route_via.json')),
    );

    test('three variants following the contract', () async {
      final adapter = osrm();
      final response = await engine(adapter).route(request(from, to));

      expect(response.coverage, RouteCoverage.full);
      expect(response.variants.map((v) => v.variant), [
        RouteVariantType.shortest,
        RouteVariantType.shaded,
        RouteVariantType.compromise,
      ]);
      final shortest = response.shortest!;
      expect(shortest.distanceM, closeTo(1874, 30));
      expect(shortest.extraTimeVsShortestS, 0);
      expect(shortest.geometry.first, const LatLng(51.779419, 19.446817));
      for (final v in response.variants) {
        expect(v.durationS, greaterThanOrEqualTo(shortest.durationS));
        expect(v.extraTimeVsShortestS, v.durationS - shortest.durationS);
        expect(v.sunShare, inInclusiveRange(0, 1));
        expect(v.sunShare, lessThanOrEqualTo(shortest.sunShare));
        // 08:00 … 20:00 every 30 min; the 14:30 slot is the departure.
        expect(v.sunShareByHour.keys.first, '08:00');
        expect(v.sunShareByHour.keys.last, '20:00');
        expect(v.sunShareByHour, hasLength(25));
        expect(v.sunShareByHour['14:30'], v.sunShare);
        // Segments cover the line without gaps.
        expect(v.segments.first.from, 0);
        expect(v.segments.last.to, v.geometry.length - 1);
        for (var i = 1; i < v.segments.length; i++) {
          expect(v.segments[i].from, v.segments[i - 1].to);
        }
        expect(v.segments.length, inInclusiveRange(1, 12));
      }
      // The shaded variant is the alternative through the old town.
      expect(response.variant(RouteVariantType.shaded)!.distanceM, 1934);
      // Biblioteka Wolność (cool-007) is on the shortest line.
      expect(shortest.stops.map((s) => s.placeId), contains('cool-007'));

      // One direct request with alternatives, then the detours.
      final direct = adapter.requests.where((o) => pointCount(o) == 2);
      expect(direct.single.uri.queryParameters['alternatives'], '2');
      expect(
        adapter.requests.where((o) => pointCount(o) == 3),
        hasLength(
          LiveRouteEngine.viaPoints(
            from,
            to,
            parks: realModel.parkCentres,
          ).length,
        ),
      );
    });

    test('the profile of the request is the same JSON as the demo', () async {
      final response = await engine(osrm()).route(request(from, to));
      final json = response.toJson();
      final parsed = RouteResponse.fromJson(
        Map<String, dynamic>.from(
          // Round-trip like the cache does.
          json,
        ),
      );
      expect(parsed.variants, hasLength(3));
    });

    test('failing detours are just dropped', () async {
      final adapter = FakeAdapter(
        (o) => pointCount(o) == 2
            ? jsonBody(fixture('live/osrm_route_alternatives.json'))
            : jsonBody('{}', 503),
      );
      final response = await engine(adapter).route(request(from, to));
      // The two distinct OSRM walks: the fastest and the shadier one.
      expect(response.variants.map((v) => v.variant), [
        RouteVariantType.shortest,
        RouteVariantType.shaded,
      ]);
    });

    test('a direct failure is the answer', () async {
      await expectLater(
        engine(
          FakeAdapter((o) => jsonBody('{"code":"NoRoute"}', 400)),
        ).route(request(from, to)),
        throwsA(apiError(ApiErrorKind.notFound)),
      );
      await expectLater(
        engine(
          FakeAdapter(
            (o) => throw DioException.connectionError(
              requestOptions: o,
              reason: 'offline',
            ),
          ),
        ).route(request(from, to)),
        throwsA(apiError(ApiErrorKind.network)),
      );
    });

    test('too far for a walk → route_not_found without a request', () async {
      final adapter = osrm();
      await expectLater(
        engine(adapter).route(request(from, const LatLng(52.23, 21.01))),
        throwsA(apiError(ApiErrorKind.notFound)),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('choosing the variants', () {
    // A 1 km E–W walk; the detour goes one block north, under trees.
    const a = LatLng(51.7700, 19.4500);
    const b = LatLng(51.7700, 19.4645);
    const n1 = LatLng(51.7709, 19.4500);
    const n2 = LatLng(51.7709, 19.4645);
    final model = ShadeModel(
      canopy: [
        const GeoFeature(
          geometry: GeoPolygons([
            GeoPolygon([
              LatLng(51.7707, 19.4490),
              LatLng(51.7707, 19.4655),
              LatLng(51.7711, 19.4655),
              LatLng(51.7711, 19.4490),
              LatLng(51.7707, 19.4490),
            ]),
          ]),
          properties: {'shade': 0.9},
        ),
      ],
      parks: const [],
    );

    test('the detour under trees is the shaded variant', () async {
      final adapter = FakeAdapter(
        (o) => pointCount(o) == 2
            ? jsonBody(lineJson(const [a, b], distance: 1000))
            : jsonBody(lineJson(const [a, n1, n2, b], distance: 1200)),
      );
      final response = await engine(
        adapter,
        model: model,
      ).route(request(a, b, at: '2026-07-15T12:00:00+02:00'));
      final shortest = response.shortest!;
      final shaded = response.variant(RouteVariantType.shaded)!;
      expect(shortest.geometry, hasLength(2));
      expect(shaded.geometry, hasLength(4));
      expect(shaded.sunShare, lessThan(shortest.sunShare - 0.3));
      expect(shaded.extraTimeVsShortestS, greaterThan(0));
      // Two distinct walks → two variants: the compromise would repeat one.
      expect(response.variants, hasLength(2));
      expect(response.variant(RouteVariantType.compromise), isNull);
    });

    test('a shared walk keeps the profile default name', () async {
      final adapter = FakeAdapter(
        (o) => pointCount(o) == 2
            ? jsonBody(lineJson(const [a, b], distance: 1000))
            : jsonBody(lineJson(const [a, n1, n2, b], distance: 1200)),
      );
      final response = await engine(adapter, model: model).route(
        RouteRequest(
          from: RoutePoint.fromLatLng(a),
          to: RoutePoint.fromLatLng(b),
          datetime: DateTime.parse('2026-07-15T12:00:00+02:00'),
          profile: const RouteProfile(
            id: ProfileId.standard,
            weights: ProfileWeights(shade: 60, time: 60, quiet: 30, air: 30),
          ),
        ),
      );
      // Standard opens on «compromise»: the shady detour keeps that name.
      expect(response.variants.map((v) => v.variant), [
        RouteVariantType.shortest,
        RouteVariantType.compromise,
      ]);
      expect(
        response.variant(RouteVariantType.compromise)!.geometry,
        hasLength(4),
      );
    });

    /// The same sky all day on 15 July 2026 (UTC hours).
    WeatherForecast sky({required double direct, double temp = 22}) =>
        WeatherForecast([
          for (var h = 0; h < 24; h++)
            WeatherHour(
              time: DateTime.utc(2026, 7, 15, h),
              directRadiation: direct,
              temperature: temp,
              cloudCover: direct > 300 ? 10 : 100,
            ),
        ]);

    FakeAdapter detour() => FakeAdapter(
      (o) => pointCount(o) == 2
          ? jsonBody(lineJson(const [a, b], distance: 1000))
          : jsonBody(lineJson(const [a, n1, n2, b], distance: 1200)),
    );

    test('overcast: little sun everywhere, no shaded detour', () async {
      final response = await engine(
        detour(),
        model: model,
        weather: sky(direct: 0, temp: 14),
      ).route(request(a, b, at: '2026-07-15T12:00:00+02:00'));
      expect(response.weather!.sunStrength, 0);
      expect(response.weather!.littleSun, isTrue);
      expect(response.weather!.temperature, 14);
      expect(response.shortest!.sunShare, 0);
      // No sun to avoid: the longer walk is not worth offering.
      expect(response.variants.single.variant, RouteVariantType.shortest);
    });

    test('clear sky: the forecast keeps the full sun', () async {
      final clear = await engine(
        detour(),
        model: model,
        weather: sky(direct: 850),
      ).route(request(a, b, at: '2026-07-15T12:00:00+02:00'));
      final geometryOnly = await engine(
        detour(),
        model: model,
      ).route(request(a, b, at: '2026-07-15T12:00:00+02:00'));
      expect(clear.weather!.littleSun, isFalse);
      expect(geometryOnly.weather, isNull);
      expect(
        clear.shortest!.sunShare,
        closeTo(geometryOnly.shortest!.sunShare, 0.05),
      );
      expect(clear.variant(RouteVariantType.shaded), isNotNull);
    });

    test('at night only the walks themselves differ', () async {
      final response = await engine(
        detour(),
        model: model,
      ).route(request(a, b, at: '2026-07-15T23:30:00+02:00'));
      expect(response.shortest!.sunShare, 0);
      expect(response.variants, hasLength(1));
      // The hourly chart still shows the day.
      expect(response.shortest!.sunShareByHour['13:00'], greaterThan(0));
    });

    test('heat makes shade weigh more, cool weather less', () {
      expect(LiveRouteEngine.heatWeight(32), greaterThan(1));
      expect(LiveRouteEngine.heatWeight(10), lessThan(1));
      expect(LiveRouteEngine.heatWeight(null), 1);
      expect(LiveRouteEngine.heatWeight(20), 1);
    });

    test('a single possible walk → a single variant', () async {
      final adapter = FakeAdapter(
        (o) => jsonBody(lineJson(const [a, b], distance: 1000)),
      );
      final response = await engine(
        adapter,
        model: model,
      ).route(request(a, b, at: '2026-07-15T12:00:00+02:00'));
      expect(response.variants.single.variant, RouteVariantType.shortest);
    });

    test('more distinct walks → alternatives after the named ones', () async {
      // Each via request gets its own walk through a different latitude.
      var n = 0;
      final adapter = FakeAdapter((o) {
        if (pointCount(o) == 2) {
          // The direct answer with two alternatives further south.
          final routes = [
            for (final (i, lat) in [(0, 51.7700), (1, 51.7691), (2, 51.7682)])
              (jsonDecode(
                    lineJson([
                      a,
                      LatLng(lat, 19.4500),
                      LatLng(lat, 19.4645),
                      b,
                    ], distance: 1000 + 50.0 * i),
                  )
                  as Map)['routes'][0],
          ];
          return jsonBody(jsonEncode({'code': 'Ok', 'routes': routes}));
        }
        n++;
        final lat = 51.7700 + 0.0009 * n;
        return jsonBody(
          lineJson([
            a,
            LatLng(lat, 19.4500),
            LatLng(lat, 19.4645),
            b,
          ], distance: 1000 + 60.0 * n),
        );
      });
      // Trees along every street except the direct one.
      GeoFeature trees(double south, double north) => GeoFeature(
        geometry: GeoPolygons([
          GeoPolygon([
            LatLng(south, 19.4490),
            LatLng(south, 19.4655),
            LatLng(north, 19.4655),
            LatLng(north, 19.4490),
            LatLng(south, 19.4490),
          ]),
        ]),
        properties: const {'shade': 0.9},
      );
      final leafy = ShadeModel(
        canopy: [trees(51.7678, 51.7695), trees(51.7705, 51.7722)],
        parks: const [],
      );
      final response = await engine(
        adapter,
        model: leafy,
      ).route(request(a, b, at: '2026-07-15T12:00:00+02:00'));
      final types = response.variants.map((v) => v.variant).toList();
      expect(types.length, greaterThan(3));
      expect(types.length, lessThanOrEqualTo(LiveRouteEngine.maxVariants));
      expect(types.first, RouteVariantType.shortest);
      expect(types.last, RouteVariantType.alternative);
      // Every walk is offered once.
      final middles = {
        for (final v in response.variants)
          v.geometry[v.geometry.length ~/ 2].latitude,
      };
      expect(middles, hasLength(types.length));
    });

    test('a time-first profile keeps the short walk as compromise', () async {
      final adapter = FakeAdapter(
        (o) => pointCount(o) == 2
            ? jsonBody(lineJson(const [a, b], distance: 1000))
            : jsonBody(lineJson(const [a, n1, n2, b], distance: 1450)),
      );
      final response = await engine(adapter, model: model).route(
        RouteRequest(
          from: RoutePoint.fromLatLng(a),
          to: RoutePoint.fromLatLng(b),
          datetime: DateTime.parse('2026-07-15T12:00:00+02:00'),
          profile: const RouteProfile(
            id: ProfileId.standard,
            weights: ProfileWeights(shade: 10, time: 100, quiet: 0, air: 0),
          ),
        ),
      );
      // The compromise is the short walk itself, so only the detour keeps
      // its own name (had the compromise chosen the detour, the standard
      // profile would keep «compromise» for it instead of «shaded»).
      expect(response.variants.map((v) => v.variant), [
        RouteVariantType.shortest,
        RouteVariantType.shaded,
      ]);
      expect(response.shortest!.geometry, hasLength(2));
    });

    test('outside the bundled layers → approximate', () async {
      const far = LatLng(51.73, 19.40);
      const far2 = LatLng(51.73, 19.41);
      final adapter = FakeAdapter(
        (o) => jsonBody(lineJson(const [far, far2], distance: 700)),
      );
      final response = await engine(adapter).route(request(far, far2));
      expect(response.coverage, RouteCoverage.approximate);
    });
  });

  group('helpers', () {
    test('removeSpurs drops loops and out-and-back spurs', () {
      const p = [
        LatLng(1, 1),
        LatLng(1, 2),
        LatLng(1, 3),
        LatLng(1, 2),
        LatLng(1, 4),
      ];
      expect(removeSpurs(p), const [LatLng(1, 1), LatLng(1, 2), LatLng(1, 4)]);
      expect(removeSpurs(const [LatLng(1, 1), LatLng(2, 2), LatLng(1, 1)]), [
        const LatLng(1, 1),
      ]);
    });

    test('makeSegments: two halves, short blips merged, at most maxRuns', () {
      final lengths = List.filled(40, 10.0);
      final sun = [for (var i = 0; i < 40; i++) i < 20 ? 0.9 : 0.1];
      final two = makeSegments(lengths, sun);
      expect(two.map((s) => (s.from, s.to, s.sunShare)), [
        (0, 20, 0.9),
        (20, 40, 0.1),
      ]);
      sun[10] = 0.1; // 10 m of shade inside the sunny half
      expect(makeSegments(lengths, sun), hasLength(2));

      final striped = [for (var i = 0; i < 40; i++) (i ~/ 8).isEven ? 1.0 : 0];
      final capped = makeSegments(
        lengths,
        striped.map((v) => v.toDouble()).toList(),
        maxRuns: 3,
      );
      expect(capped, hasLength(3));
      expect(capped.first.from, 0);
      expect(capped.last.to, 40);
      expect(makeSegments(const [], const []), isEmpty);
    });

    test('daySlots: Warsaw wall clock in summer and winter', () {
      final summer = LiveRouteEngine.daySlots(
        DateTime.parse('2026-07-15T23:30:00+02:00'),
      );
      expect(summer, hasLength(25));
      expect(summer.first.$1, '08:00');
      expect(summer.first.$2, DateTime.utc(2026, 7, 15, 6));
      expect(summer.last.$1, '20:00');
      final winter = LiveRouteEngine.daySlots(DateTime.utc(2026, 1, 10, 23));
      // 00:00 on 11 January in Łódź.
      expect(winter.first.$2, DateTime.utc(2026, 1, 11, 7));
    });

    test('viaPoints: both sides of the middle, parks along the way', () {
      const from = LatLng(51.770, 19.440);
      const to = LatLng(51.770, 19.470); // ~2 km east
      expect(
        LiveRouteEngine.viaPoints(from, const LatLng(51.770, 19.442)),
        isEmpty,
      );
      final vias = LiveRouteEngine.viaPoints(
        from,
        to,
        parks: const [
          LatLng(51.772, 19.455), // on the way
          LatLng(51.800, 19.455), // 3 km off
          LatLng(51.7701, 19.4405), // at the start
        ],
      );
      expect(vias, hasLength(3));
      final mid = const LatLng(51.770, 19.455);
      expect(distanceMeters(mid, vias[0]), closeTo(414, 5));
      expect(distanceMeters(mid, vias[1]), closeTo(414, 5));
      expect(vias[0].latitude, greaterThan(51.770)); // north side first
      expect(vias[2], const LatLng(51.772, 19.455));
    });

    test('findStops: radius per type, walking order, not at the start', () {
      const line = [LatLng(51.770, 19.440), LatLng(51.770, 19.460)];
      Place place(String id, PlaceType type, double lat, double lon) =>
          Place(id: id, type: type, lat: lat, lon: lon);
      final stops = LiveRouteEngine.findStops(line, [
        place('far-cool', PlaceType.cool, 51.7710, 19.450), // 111 m
        place('cool-b', PlaceType.cool, 51.7705, 19.455), // 56 m
        place('cool-a', PlaceType.cool, 51.7705, 19.445), // 56 m
        place('water', PlaceType.water, 51.7701, 19.450), // 11 m
        place('far-water', PlaceType.water, 51.7704, 19.450), // 44 m
        place('start', PlaceType.cool, 51.7700, 19.4405),
        place('bench', PlaceType.bench, 51.7700, 19.450),
      ]);
      expect(stops.map((s) => s.placeId), ['cool-a', 'water', 'cool-b']);
      expect(stops[1].type, StopType.water);
    });
  });

  test('loop vias: six triangles of about a third of the length', () {
    const from = LatLng(51.77, 19.45);
    final loops = LiveRouteEngine.loopVias(from, 3300);
    expect(loops, hasLength(6));
    for (final vias in loops) {
      expect(vias, hasLength(2));
      for (final v in vias) {
        expect(distanceMeters(from, v), closeTo(1000, 30));
      }
    }
  });

  test('loop vias move to a park on the way', () {
    const from = LatLng(51.77, 19.45);
    // 1 km north, 100 m off.
    const park = LatLng(51.779, 19.4515);
    final loops = LiveRouteEngine.loopVias(from, 3300, parks: [park]);
    expect(loops.first.first, park);
  });
}
