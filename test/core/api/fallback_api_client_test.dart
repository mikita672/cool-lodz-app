import 'dart:async';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/fallback_api_client.dart';
import 'package:cool_lodz/core/api/reference_routes.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/storage/offline_cache.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

const _profile = RouteProfile(
  id: ProfileId.senior,
  weights: ProfileWeights(shade: 90, time: 20, quiet: 60, air: 50),
);

final _request = RouteRequest(
  from: ReferenceRoutes.manufakturaPiotrkowska.from,
  to: ReferenceRoutes.manufakturaPiotrkowska.to,
  datetime: DateTime(2026, 7, 15, 14, 30),
  profile: _profile,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_request);
    registerFallbackValue(LayerKind.shade);
    registerFallbackValue(DateTime(2026));
  });

  late MockApiClient remote;
  late DemoApiClient demo;
  late List<bool> flags;

  FallbackApiClient client({OfflineCache? cache}) => FallbackApiClient(
    remote: remote,
    demo: demo,
    cache: cache,
    onFallback: flags.add,
  );

  setUp(() {
    remote = MockApiClient();
    demo = DemoApiClient(loadAsset: FixtureAssetLoader().call);
    flags = [];
  });

  test('no answer in 8 s → demo data and the flag flips', () {
    fakeAsync((async) {
      when(() => remote.getRoutes(any())).thenAnswer(
        (_) => Completer<RouteResponse>().future, // never answers
      );
      RouteResponse? result;
      client().getRoutes(_request).then((r) => result = r);

      async.elapse(const Duration(milliseconds: 7900));
      expect(result, isNull);
      expect(flags, isEmpty);

      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(result, isNotNull);
      expect(flags, [true]);
      expect(result!.variants, hasLength(3));
      expect(result!.coverage, RouteCoverage.full); // the reference file
    });
  });

  test(
    'network and server errors fall back; success clears the flag',
    () async {
      when(
        () => remote.getAir(bbox: any(named: 'bbox')),
      ).thenThrow(const ApiException(ApiErrorKind.network));
      final api = client();
      final offline = await api.getAir();
      // The demo stations, but no made-up index.
      expect(offline.map((s) => s.id), (await demo.getAir()).map((s) => s.id));
      expect(offline.every((s) => s.indexLevel == null), isTrue);
      expect(flags, [true]);

      when(
        () => remote.getAir(bbox: any(named: 'bbox')),
      ).thenThrow(const ApiException(ApiErrorKind.server, 'boom', 502));
      await api.getAir();
      expect(flags, [true, true]);

      when(
        () => remote.getAir(bbox: any(named: 'bbox')),
      ).thenAnswer((_) async => const []);
      expect(await api.getAir(), isEmpty);
      expect(flags, [true, true, false]);
    },
  );

  test('the flag stays while any kind of call is failing', () async {
    when(
      () => remote.getAir(bbox: any(named: 'bbox')),
    ).thenThrow(const ApiException(ApiErrorKind.network));
    when(
      () => remote.getLayer(
        any(),
        bbox: any(named: 'bbox'),
        datetime: any(named: 'datetime'),
      ),
    ).thenAnswer((_) async => const GeoLayer(features: []));
    final api = client();
    await api.getAir();
    // Another source answering does not hide the air fallback.
    await api.getLayer(LayerKind.green, datetime: DateTime(2026));
    expect(flags, [true, true]);

    when(
      () => remote.getAir(bbox: any(named: 'bbox')),
    ).thenAnswer((_) async => const []);
    await api.getAir();
    expect(flags, [true, true, false]);
  });

  test('notFound is a real answer: rethrown, no fallback', () async {
    when(() => remote.getRoutes(any())).thenThrow(
      const ApiException(ApiErrorKind.notFound, 'route_not_found', 404),
    );
    await expectLater(
      client().getRoutes(_request),
      throwsA(isA<ApiException>()),
    );
    expect(flags, isEmpty);
  });

  test('quest places always come from the bundled seed', () async {
    final quest = await client().getQuestPlaces();
    expect(quest, hasLength(2));
    verifyNever(() => remote.getQuestPlaces());
    expect(flags, isEmpty);
  });

  group('with offline cache', () {
    late OfflineCache cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cache = OfflineCache(await SharedPreferences.getInstance());
    });

    RouteResponse remoteRoute() => RouteResponse(
      coverage: RouteCoverage.full,
      variants: [
        RouteVariant(
          variant: RouteVariantType.shortest,
          geometry: [_request.from.latLng, _request.to.latLng],
          distanceM: 999,
          durationS: 777,
          sunShare: 0.5,
          extraTimeVsShortestS: 0,
        ),
      ],
    );

    test('last route is saved and served when offline', () async {
      when(
        () => remote.getRoutes(any()),
      ).thenAnswer((_) async => remoteRoute());
      final api = client(cache: cache);
      await api.getRoutes(_request);
      expect(cache.lastRoute()!.response.shortest!.distanceM, 999);

      when(
        () => remote.getRoutes(any()),
      ).thenThrow(const ApiException(ApiErrorKind.network));
      // Same trip 20 min later → cached remote answer.
      final again = await api.getRoutes(
        RouteRequest(
          from: _request.from,
          to: _request.to,
          datetime: DateTime(2026, 7, 15, 14, 50),
          profile: _profile,
        ),
      );
      expect(again.shortest!.distanceM, 999);
      expect(flags, [false, true]);

      // Another time of day → demo file.
      final evening = await api.getRoutes(
        RouteRequest(
          from: _request.from,
          to: _request.to,
          datetime: DateTime(2026, 7, 15, 18),
          profile: _profile,
        ),
      );
      expect(evening.variants, hasLength(3));
    });

    test('cool places are merged into the cache and served offline', () async {
      const a = Place(
        id: 'cool-a',
        type: PlaceType.cool,
        lat: 51.77,
        lon: 19.45,
      );
      const b = Place(
        id: 'cool-b',
        type: PlaceType.cool,
        lat: 51.70,
        lon: 19.40,
      );
      const w = Place(id: 'w', type: PlaceType.water, lat: 51.77, lon: 19.45);
      final api = client(cache: cache);

      when(
        () => remote.getPlaces(
          types: any(named: 'types'),
          bbox: any(named: 'bbox'),
        ),
      ).thenAnswer((_) async => [a, w]);
      await api.getPlaces(types: {PlaceType.cool, PlaceType.water});
      when(
        () => remote.getPlaces(
          types: any(named: 'types'),
          bbox: any(named: 'bbox'),
        ),
      ).thenAnswer((_) async => [b]);
      await api.getPlaces(types: {PlaceType.cool});
      expect(cache.coolPlaces()!.map((p) => p.id), ['cool-a', 'cool-b']);

      when(
        () => remote.getPlaces(
          types: any(named: 'types'),
          bbox: any(named: 'bbox'),
        ),
      ).thenThrow(const ApiException(ApiErrorKind.timeout));
      const bbox = GeoBounds(
        minLon: 19.44,
        minLat: 51.76,
        maxLon: 19.46,
        maxLat: 51.78,
      );
      final offline = await api.getPlaces(
        types: {PlaceType.cool, PlaceType.water},
        bbox: bbox,
      );
      // Cool from cache (bbox-filtered), water from demo.
      expect(offline.map((p) => p.id), ['cool-a', 'water-003']);
      expect(flags.last, isTrue);
    });
  });
}
