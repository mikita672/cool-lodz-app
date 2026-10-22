import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cool_lodz/features/community/data/crowd_points.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('documents parse; unknown kinds are skipped', () {
    final p = CrowdPoint.fromDoc('a', {
      'uid': 'u1',
      'kind': 'tap',
      'lat': 51.77,
      'lon': 19.45,
      'votes': 3,
      'note': 'Kawiarnia nalewa wodę',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 1)),
    })!;
    expect(p.kind, CrowdKind.tap);
    expect(p.votes, 3);
    expect(p.point, const LatLng(51.77, 19.45));
    expect(
      CrowdPoint.fromDoc('b', {'kind': 'bench', 'lat': 1, 'lon': 2}),
      isNull,
    );
  });

  test('GeoJSON export: lon, lat and the votes', () {
    final json =
        jsonDecode(
              crowdGeoJson([
                const CrowdPoint(
                  id: 'a',
                  kind: CrowdKind.tree,
                  point: LatLng(51.7592, 19.456),
                  uid: 'u1',
                  votes: 7,
                ),
              ]),
            )
            as Map<String, dynamic>;
    final f = (json['features'] as List).single as Map<String, dynamic>;
    expect(f['geometry'], {
      'type': 'Point',
      'coordinates': [19.456, 51.7592],
    });
    expect(f['properties'], {'kind': 'tree', 'votes': 7});
    // No user ids leave the app.
    expect(jsonEncode(json), isNot(contains('u1')));
  });

  test('only Łódź', () {
    expect(inLodz(const LatLng(51.77, 19.46)), isTrue);
    expect(inLodz(const LatLng(52.23, 21.01)), isFalse);
  });
}
