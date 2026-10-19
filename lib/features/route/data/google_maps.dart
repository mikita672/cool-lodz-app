import 'package:latlong2/latlong.dart';

/// Google Maps walking directions for «Prowadź» (navigation inside the app is
/// out of scope). Intermediate points of the chosen line keep Google close to
/// our shaded path.
abstract final class GoogleMapsLink {
  /// Google Maps accepts up to 9 waypoints on mobile.
  static const maxWaypoints = 8;

  static Uri walking(List<LatLng> line) {
    if (line.length < 2) throw ArgumentError('A line needs 2 points');
    final inner = line.sublist(1, line.length - 1);
    final waypoints = <LatLng>[];
    if (inner.isNotEmpty) {
      final count = inner.length < maxWaypoints ? inner.length : maxWaypoints;
      for (var i = 0; i < count; i++) {
        // Evenly spread over the inner points.
        waypoints.add(inner[((i + 1) * inner.length) ~/ (count + 1)]);
      }
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': _p(line.first),
      'destination': _p(line.last),
      'travelmode': 'walking',
      if (waypoints.isNotEmpty) 'waypoints': waypoints.map(_p).join('|'),
    });
  }

  static String _p(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
}
