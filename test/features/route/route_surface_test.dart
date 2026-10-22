import 'package:cool_lodz/features/map/data/street_modes.dart';
import 'package:cool_lodz/features/route/data/route_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // A 400 m walk east along a street.
  const lat = 51.76;
  final route = [const LatLng(lat, 19.45), const LatLng(lat, 19.4558)];

  test('cobbles along the route and steps beside it count', () {
    const modes = StreetModes(
      surfaces: [
        // 100 m of cobbles on the route, 100 m of paving further on.
        SurfaceLine([LatLng(lat, 19.451), LatLng(lat, 19.45245)], 3),
        SurfaceLine([LatLng(lat, 19.453), LatLng(lat, 19.45445)], 1),
        // Cobbles 200 m north: not on the way.
        SurfaceLine([
          LatLng(lat + 0.0018, 19.451),
          LatLng(lat + 0.0018, 19.453),
        ], 3),
      ],
      steps: [
        Steps(LatLng(lat + 0.00005, 19.452), ramp: false),
        Steps(LatLng(lat - 0.00005, 19.454), ramp: true),
        Steps(LatLng(lat + 0.001, 19.452), ramp: false),
      ],
    );
    final s = routeSurface(route, modes);
    expect(s.cobblesM, closeTo(110, 20));
    expect(s.pavingM, closeTo(110, 20));
    expect(s.steps, 1);
    expect(s.stepsWithRamp, 1);
    expect(s.notable, isTrue);
  });

  test('a smooth route is not notable', () {
    final s = routeSurface(route, const StreetModes());
    expect(s.cobblesM, 0);
    expect(s.notable, isFalse);
  });
}
