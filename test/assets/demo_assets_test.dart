// Shape checks for the demo files in assets/demo/ against
// docs/api-contract.md. Plain jsonDecode for now; switch to the core/models
// parsers once APP-03 lands.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const _dir = 'assets/demo';

dynamic _load(String name) =>
    jsonDecode(File('$_dir/$name').readAsStringSync());

Map<String, dynamic> _map(Object? v) => v as Map<String, dynamic>;
List<dynamic> _list(Object? v) => v as List<dynamic>;

/// Łódź city bounds, generous.
void _expectInLodz(num lon, num lat) {
  expect(lon, inInclusiveRange(19.30, 19.66));
  expect(lat, inInclusiveRange(51.66, 51.88));
}

void _expectShare(Object? v) {
  expect(v, isA<num>());
  expect(v! as num, inInclusiveRange(0, 1));
}

double _metres(List<dynamic> a, List<dynamic> b) {
  const r = 6371008.8;
  final lat = ((a[1] as num) + (b[1] as num)) / 2 * math.pi / 180;
  final dx = ((b[0] as num) - (a[0] as num)) * math.pi / 180 * math.cos(lat);
  final dy = ((b[1] as num) - (a[1] as num)) * math.pi / 180;
  return r * math.sqrt(dx * dx + dy * dy);
}

final _hours = [
  for (var h = 8; h <= 20; h++)
    for (final m in ['00', '30'])
      if (h < 20 || m == '00') '${h.toString().padLeft(2, '0')}:$m',
];

void _checkVariant(Map<String, dynamic> v) {
  expect(v['variant'], isIn(['shortest', 'shaded', 'compromise']));

  final geometry = _map(v['geometry']);
  expect(geometry['type'], 'LineString');
  final coords = _list(geometry['coordinates']);
  expect(coords.length, greaterThan(10));
  for (final c in coords) {
    final p = _list(c);
    expect(p.length, 2);
    _expectInLodz(p[0] as num, p[1] as num);
  }

  final segments = _list(v['segments']).map(_map).toList();
  expect(segments.length, inInclusiveRange(6, 12));
  expect(segments.first['from'], 0);
  expect(segments.last['to'], coords.length - 1);
  var weighted = 0.0;
  var total = 0.0;
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    final from = s['from'] as int;
    final to = s['to'] as int;
    expect(from, lessThan(to));
    expect(to, lessThanOrEqualTo(coords.length - 1));
    if (i > 0) expect(from, segments[i - 1]['to']);
    _expectShare(s['sunShare']);
    for (var k = from; k < to; k++) {
      final d = _metres(_list(coords[k]), _list(coords[k + 1]));
      weighted += d * (s['sunShare'] as num);
      total += d;
    }
  }

  expect(v['distance_m'], isA<int>());
  expect(v['duration_s'], isA<int>());
  expect(v['extraTimeVsShortest_s'], isA<int>());
  // geometry length matches the router distance within 5 %
  expect(
    total,
    closeTo(v['distance_m'] as int, (v['distance_m'] as int) * .05),
  );
  _expectShare(v['sunShare']);
  // sunShare is the length-weighted mean of the segments
  expect(v['sunShare'] as num, closeTo(weighted / total, 0.02));

  for (final stop in _list(v['stops']).map(_map)) {
    expect(stop['placeId'], isA<String>());
    expect(stop['type'], isIn(['cool', 'water']));
  }

  final byHour = _map(v['sunShareByHour']);
  expect(byHour.keys.toList(), _hours);
  byHour.values.forEach(_expectShare);
}

void _checkRoutes(String name) {
  final departures = _map(_map(_load(name))['departures']);
  expect(departures.keys, containsAll(['10:00', '14:30', '18:00']));
  for (final entry in departures.entries) {
    final response = _map(entry.value);
    expect(response['coverage'], isIn(['full', 'approximate']));
    final variants = _list(response['variants']).map(_map).toList();
    expect(variants.length, 3);
    expect(variants.map((v) => v['variant']).toSet(), {
      'shortest',
      'shaded',
      'compromise',
    });
    variants.forEach(_checkVariant);

    final byName = {for (final v in variants) v['variant']: v};
    expect(byName['shortest']!['extraTimeVsShortest_s'], 0);
    // never sunnier than the shortest (in the evening all streets are shaded)
    expect(
      byName['shaded']!['sunShare'] as num,
      lessThanOrEqualTo(byName['shortest']!['sunShare'] as num),
    );
    for (final v in variants) {
      // the slider value at the departure time matches the card
      expect(_map(v['sunShareByHour'])[entry.key], v['sunShare']);
    }
  }

  // demo scenario: at 14:30 Zacieniona is clearly shadier for a few minutes
  final at1430 = _list(_map(departures['14:30'])['variants']).map(_map);
  final shortest = at1430.firstWhere((v) => v['variant'] == 'shortest');
  final shaded = at1430.firstWhere((v) => v['variant'] == 'shaded');
  expect(
    (shortest['sunShare'] as num) - (shaded['sunShare'] as num),
    greaterThan(0.3),
  );
  expect(shaded['extraTimeVsShortest_s'] as int, inInclusiveRange(120, 480));
  // ... and at 18:00 there is more shade than at 14:30
  final hours = _map(shaded['sunShareByHour']);
  expect(hours['18:00'] as num, lessThan(hours['14:30'] as num));
}

void _checkPolygons(String name, void Function(Map<String, dynamic>) props) {
  expect(File('$_dir/$name').lengthSync(), lessThan(400 * 1024));
  final fc = _map(_load(name));
  expect(fc['type'], 'FeatureCollection');
  final features = _list(fc['features']).map(_map).toList();
  expect(features, isNotEmpty);
  for (final f in features) {
    expect(f['type'], 'Feature');
    final g = _map(f['geometry']);
    expect(g['type'], 'Polygon');
    for (final ring in _list(g['coordinates'])) {
      final r = _list(ring);
      expect(r.length, greaterThanOrEqualTo(4));
      expect(r.first, r.last);
      for (final c in r) {
        final p = _list(c);
        _expectInLodz(p[0] as num, p[1] as num);
      }
    }
    props(_map(f['properties']));
  }
}

void _checkPlaces(String name, String type, {int? max}) {
  final places = _list(_map(_load(name))['places']).map(_map).toList();
  expect(places, isNotEmpty);
  if (max != null) expect(places.length, lessThanOrEqualTo(max));
  final ids = <String>{};
  for (final p in places) {
    expect(p['id'], startsWith('$type-'));
    expect(ids.add(p['id'] as String), isTrue, reason: 'duplicate ${p['id']}');
    expect(p['type'], type);
    _expectInLodz(p['lon'] as num, p['lat'] as num);
  }
}

void main() {
  group('demo routes', () {
    test('Manufaktura → Piotrkowska', () {
      _checkRoutes('routes_manufaktura_piotrkowska.json');
    });
    test('Plac Wolności → OFF Piotrkowska', () {
      _checkRoutes('routes_plac_wolnosci_piotrkowska.json');
    });
  });

  group('demo alerts', () {
    test('no alert is an empty list', () {
      expect(_list(_map(_load('alerts_none.json'))['alerts']), isEmpty);
    });

    for (final level in [2, 3]) {
      test('level $level', () {
        final alerts = _list(_map(_load('alerts_level$level.json'))['alerts']);
        expect(alerts.length, 1);
        final a = _map(alerts.single);
        expect(a['level'], level);
        expect(a['title'], 'Ostrzeżenie przed upałem $level. stopnia');
        for (final key in ['id', 'area', 'source']) {
          expect(a[key], isA<String>());
        }
        expect(a['source'], 'IMGW-PIB');
        final from = DateTime.parse(a['validFrom'] as String);
        final to = DateTime.parse(a['validTo'] as String);
        expect(from.isBefore(to), isTrue);
        final tips = _list(a['recommendations']);
        expect(tips.length, 3);
        for (final t in tips) {
          expect(t, isA<String>());
          expect((t as String).length, lessThan(120));
        }
        expect(Uri.parse(a['officialUrl'] as String).scheme, 'https');
      });
    }
  });

  test('air stations', () {
    final stations = _list(_map(_load('air.json'))['stations']).map(_map);
    expect(stations, isNotEmpty);
    for (final s in stations) {
      expect(s['id'], startsWith('gios-'));
      expect(s['name'], startsWith('Łódź'));
      _expectInLodz(s['lon'] as num, s['lat'] as num);
      expect(s['indexLevel'], isA<int>());
      expect(s['indexLevel'] as int, inInclusiveRange(0, 5));
      DateTime.parse(s['updatedAt'] as String);
    }
  });

  group('demo layers', () {
    test('shade at 14:30', () {
      _checkPolygons(
        'layer_shade_1430.geojson',
        (p) => _expectShare(p['shade']),
      );
    });
    test('green', () {
      _checkPolygons('layer_green.geojson', (p) {
        expect(p['kind'], isIn(['park', 'garden', 'forest', 'grass']));
      });
    });
    test('noise', () {
      _checkPolygons('layer_noise.geojson', (p) {
        expect(p['db'], isA<int>());
        expect(p['db'] as int, inInclusiveRange(55, 75));
      });
    });
  });

  group('demo places', () {
    test('drinking water', () => _checkPlaces('places_water.json', 'water'));
    test('benches', () => _checkPlaces('places_bench.json', 'bench', max: 500));
  });
}
