import 'package:cool_lodz/features/map/data/street_modes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('surfaces, steps, fountains and heat cells parse', () {
    final m = StreetModes.fromJson({
      'origin': [19.425, 51.745],
      'scale': 100000,
      'streets': [],
      'surfaces': [
        [3, 100, 200, 10, 0, 10, 0],
      ],
      'steps': [
        [100, 200, 1],
        [110, 210, 0],
      ],
      'fountains': [
        [300, 400, 1],
      ],
      'heat': {
        'cell': 200,
        'cells': [
          [0, 0, 3],
        ],
      },
    });
    expect(m.surfaces.single.surface, 3);
    expect(m.surfaces.single.points, hasLength(3));
    expect(m.surfaces.single.points.last.longitude, closeTo(19.4262, 1e-9));
    expect(m.steps.map((s) => s.ramp), [true, false]);
    expect(m.fountains.single.splash, isTrue);
    final cell = m.heat.single;
    expect(cell.level, 3);
    expect(cell.southWest.latitude, 51.745);
    // 200 m north and east.
    expect(cell.northEast.latitude - 51.745, closeTo(0.0018, 0.0001));
    expect(cell.northEast.longitude - 19.425, closeTo(0.0029, 0.0001));
  });

  test('older files without the new keys still parse', () {
    final m = StreetModes.fromJson({
      'origin': [19.425, 51.745],
      'scale': 100000,
    });
    expect(m.surfaces, isEmpty);
    expect(m.heat, isEmpty);
  });
}
