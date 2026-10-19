import 'package:cool_lodz/core/api/reference_routes.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile.dart';
import 'package:cool_lodz/features/route/data/route_plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('RoutePlanNotifier', () {
    late ProviderContainer container;
    RoutePlanNotifier notifier() => container.read(routePlanProvider.notifier);
    RoutePlan plan() => container.read(routePlanProvider);

    setUp(() => container = ProviderContainer.test());

    test('starts from my location, leaving now, without a destination', () {
      expect(plan().from, const MyLocation());
      expect(plan().to, isNull);
      expect(plan().departAt, isNull);
      expect(plan().isComplete, isFalse);
    });

    test('a quick route fills both endpoints', () {
      notifier().useReference(ReferenceRoutes.manufakturaPiotrkowska);
      expect((plan().from as PointEndpoint).label, 'Manufaktura');
      expect(
        (plan().to as PointEndpoint).label,
        'ul. Piotrkowska (Pasaż Rubinsteina)',
      );
      expect(plan().isComplete, isTrue);
    });

    test('swap exchanges from and to; nothing to swap without a target', () {
      notifier().swap();
      expect(plan().from, const MyLocation());

      const target = PointEndpoint(RoutePoint(lat: 51.76, lon: 19.46));
      notifier().setTo(target);
      notifier().swap();
      expect(plan().from, target);
      expect(plan().to, const MyLocation());
    });

    test('«Prowadź tam» goes from my location to the place, now', () {
      notifier().setDeparture(DateTime(2026, 7, 15, 18));
      const place = Place(
        id: 'cool-002',
        type: PlaceType.cool,
        name: 'Manufaktura',
        lat: 51.7791,
        lon: 19.4439,
      );
      notifier().navigateTo(place);
      expect(plan().from, const MyLocation());
      expect((plan().to as PointEndpoint).place?.id, 'cool-002');
      expect((plan().to as PointEndpoint).label, 'Manufaktura');
      expect(plan().departAt, isNull);
    });
  });

  group('buildRouteRequest', () {
    final profile = ComfortProfile.preset(ProfileId.senior);
    final now = DateTime(2026, 7, 15, 14, 30);

    test('resolves my location and uses «Teraz»', () async {
      final location = FakeLocationService(
        position: const LatLng(51.77, 19.45),
      );
      final request = await buildRouteRequest(
        plan: const RoutePlan(
          to: PointEndpoint(RoutePoint(lat: 51.76, lon: 19.46, label: 'B')),
        ),
        profile: profile,
        location: location,
        now: now,
      );
      expect(request.from.lat, 51.77);
      expect(request.from.label, 'Moja lokalizacja');
      expect(request.to.label, 'B');
      expect(request.datetime, now);
      expect(request.profile.id, ProfileId.senior);
      expect(request.profile.weights.shade, 90);
    });

    test('sends the chosen departure and does not ask for GPS', () async {
      final location = FakeLocationService();
      final departAt = DateTime(2026, 7, 16, 18);
      final request = await buildRouteRequest(
        plan: RoutePlan(
          from: PointEndpoint(ReferenceRoutes.manufakturaPiotrkowska.from),
          to: PointEndpoint(ReferenceRoutes.manufakturaPiotrkowska.to),
          departAt: departAt,
        ),
        profile: profile,
        location: location,
        now: now,
      );
      expect(request.datetime, departAt);
      expect(location.currentCalls, 0);
      expect(request.toJson()['datetime'], startsWith('2026-07-16T18:00:00'));
      expect(request.toJson()['profile'], {
        'id': 'senior',
        'weights': {'shade': 90, 'time': 20, 'quiet': 60, 'air': 60},
      });
    });

    test('without location it throws LocationUnavailable', () async {
      final location = FakeLocationService()
        ..problem = LocationProblem.deniedForever;
      expect(
        buildRouteRequest(
          plan: const RoutePlan(
            to: PointEndpoint(RoutePoint(lat: 51.76, lon: 19.46)),
          ),
          profile: profile,
          location: location,
          now: now,
        ),
        throwsA(isA<LocationUnavailable>()),
      );
    });
  });
}
