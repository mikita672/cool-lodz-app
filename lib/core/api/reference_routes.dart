import '../models/models.dart';

/// The two demo routes (S06 quick picks). Single source of truth for their
/// endpoints and demo files.
class ReferenceRoute {
  const ReferenceRoute({
    required this.id,
    required this.from,
    required this.to,
    required this.asset,
  });

  final String id;
  final RoutePoint from;
  final RoutePoint to;

  /// `assets/demo/` file: `{"departures": {"HH:mm": <RouteResponse>, …}}`.
  final String asset;

  /// Both endpoints within [matchRadiusMeters] of this route's endpoints.
  bool matches(RouteRequest request) =>
      distanceMeters(request.from.latLng, from.latLng) <= matchRadiusMeters &&
      distanceMeters(request.to.latLng, to.latLng) <= matchRadiusMeters;
}

const matchRadiusMeters = 300.0;

abstract final class ReferenceRoutes {
  static const manufakturaPiotrkowska = ReferenceRoute(
    id: 'manufaktura_piotrkowska',
    from: RoutePoint(lat: 51.7794, lon: 19.4466, label: 'Manufaktura'),
    to: RoutePoint(
      lat: 51.7720,
      lon: 19.4570,
      label: 'ul. Piotrkowska (Pasaż Rubinsteina)',
    ),
    asset: 'assets/demo/routes_manufaktura_piotrkowska.json',
  );

  static const placWolnosciPiotrkowska = ReferenceRoute(
    id: 'plac_wolnosci_piotrkowska',
    from: RoutePoint(lat: 51.7768, lon: 19.4547, label: 'Plac Wolności'),
    to: RoutePoint(lat: 51.7596, lon: 19.4577, label: 'OFF Piotrkowska'),
    asset: 'assets/demo/routes_plac_wolnosci_piotrkowska.json',
  );

  static const all = [manufakturaPiotrkowska, placWolnosciPiotrkowska];

  /// The reference route [request] matches, if any (same direction only).
  static ReferenceRoute? match(RouteRequest request) {
    for (final route in all) {
      if (route.matches(request)) return route;
    }
    return null;
  }
}
