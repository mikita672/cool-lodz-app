import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/reference_routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../profile/data/comfort_profile.dart';
import '../../profile/data/comfort_profile_provider.dart';

/// Start or end of a planned route.
@immutable
sealed class RouteEndpoint {
  const RouteEndpoint();
}

/// «Moja lokalizacja»: resolved to the GPS position when routes are asked.
class MyLocation extends RouteEndpoint {
  const MyLocation();

  @override
  bool operator ==(Object other) => other is MyLocation;

  @override
  int get hashCode => 0;
}

/// A searched address, a cool place, or a reference route endpoint.
class PointEndpoint extends RouteEndpoint {
  const PointEndpoint(this.point, {this.place});

  final RoutePoint point;

  /// Set when the endpoint is a place from `/v1/places` (e.g. «Prowadź tam»).
  final Place? place;

  String get label => point.label ?? place?.name ?? '';

  @override
  bool operator ==(Object other) =>
      other is PointEndpoint &&
      other.point.lat == point.lat &&
      other.point.lon == point.lon &&
      other.point.label == point.label &&
      other.place?.id == place?.id;

  @override
  int get hashCode => Object.hash(point.lat, point.lon, point.label, place?.id);
}

/// What S06 collected: from, to and the departure time (null = «Teraz»).
@immutable
class RoutePlan {
  const RoutePlan({this.from = const MyLocation(), this.to, this.departAt});

  final RouteEndpoint from;
  final RouteEndpoint? to;
  final DateTime? departAt;

  bool get isComplete => to != null;

  RoutePlan copyWith({
    RouteEndpoint? from,
    RouteEndpoint? Function()? to,
    DateTime? Function()? departAt,
  }) => RoutePlan(
    from: from ?? this.from,
    to: to != null ? to() : this.to,
    departAt: departAt != null ? departAt() : this.departAt,
  );

  @override
  bool operator ==(Object other) =>
      other is RoutePlan &&
      other.from == from &&
      other.to == to &&
      other.departAt == departAt;

  @override
  int get hashCode => Object.hash(from, to, departAt);
}

class RoutePlanNotifier extends Notifier<RoutePlan> {
  @override
  RoutePlan build() => const RoutePlan();

  void setFrom(RouteEndpoint from) => state = state.copyWith(from: from);

  void setTo(RouteEndpoint? to) => state = state.copyWith(to: () => to);

  void setDeparture(DateTime? departAt) =>
      state = state.copyWith(departAt: () => departAt);

  /// «Zamień»: swaps from and to. Without a destination there is nothing to
  /// swap with.
  void swap() {
    final to = state.to;
    if (to == null) return;
    state = state.copyWith(from: to, to: () => state.from);
  }

  /// One of the two demo routes (S06 quick picks).
  void useReference(ReferenceRoute route) => state = state.copyWith(
    from: PointEndpoint(route.from),
    to: () => PointEndpoint(route.to),
  );

  /// «Prowadź tam» (S08): from my location to [place], leaving now.
  void navigateTo(Place place) => state = RoutePlan(
    to: PointEndpoint(
      RoutePoint(lat: place.lat, lon: place.lon, label: place.name),
      place: place,
    ),
  );
}

final routePlanProvider = NotifierProvider<RoutePlanNotifier, RoutePlan>(
  RoutePlanNotifier.new,
);

/// Turns [plan] into the `POST /v1/routes` body. «Moja lokalizacja» is read
/// from [location] (throws [LocationUnavailable]); «Teraz» is [now].
Future<RouteRequest> buildRouteRequest({
  required RoutePlan plan,
  required ComfortProfile profile,
  required LocationService location,
  required DateTime now,
  String myLocationLabel = 'Moja lokalizacja',
}) async {
  final to = plan.to;
  if (to == null) throw StateError('No destination');
  Future<RoutePoint> resolve(RouteEndpoint endpoint) async =>
      switch (endpoint) {
        PointEndpoint(:final point) => point,
        MyLocation() => RoutePoint.fromLatLng(
          await location.current(),
          label: myLocationLabel,
        ),
      };
  return RouteRequest(
    from: await resolve(plan.from),
    to: await resolve(to),
    datetime: plan.departAt ?? now,
    profile: profile.routeProfile,
  );
}

/// No automatic retries: S07 shows the error and a button instead (a
/// missing route or location does not fix itself; the API client already
/// falls back to demo data).
Duration? noRetry(int retryCount, Object error) => null;

/// The request S07 shows, built from the plan and the comfort profile.
final routeRequestProvider = FutureProvider<RouteRequest>((ref) {
  return buildRouteRequest(
    plan: ref.watch(routePlanProvider),
    profile: ref.watch(comfortProfileProvider),
    location: ref.watch(locationServiceProvider),
    now: DateTime.now(),
  );
}, retry: noRetry);

/// The three variants for [routeRequestProvider]. Remote with fallback to
/// cache/demo after 8 s (see `apiClientProvider`).
final routeResultProvider = FutureProvider<RouteResponse>((ref) async {
  final request = await ref.watch(routeRequestProvider.future);
  return ref.watch(apiClientProvider).getRoutes(request);
}, retry: noRetry);
