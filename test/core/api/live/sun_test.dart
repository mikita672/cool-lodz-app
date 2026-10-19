import 'package:cool_lodz/core/api/live/sun.dart';
import 'package:flutter_test/flutter_test.dart';

const lat = 51.77;
const lon = 19.46;

void main() {
  test('summer solstice noon: about 61.7° high, due south', () {
    // Solar noon in Łódź is about 10:43 UTC (12:43 CEST).
    final sun = sunPosition(lat, lon, DateTime.utc(2026, 6, 21, 10, 43));
    expect(sun.elevation, closeTo(90 - lat + 23.44, 0.6));
    expect(sun.azimuth, closeTo(180, 2));
  });

  test('equinox noon: about 38° high', () {
    final sun = sunPosition(lat, lon, DateTime.utc(2026, 3, 20, 10, 50));
    expect(sun.elevation, closeTo(90 - lat, 1));
  });

  test('morning in the east, afternoon in the west, night below', () {
    final morning = sunPosition(lat, lon, DateTime.utc(2026, 7, 15, 6));
    final afternoon = sunPosition(lat, lon, DateTime.utc(2026, 7, 15, 15));
    final night = sunPosition(lat, lon, DateTime.utc(2026, 7, 15, 23));
    expect(morning.azimuth, inInclusiveRange(60, 120));
    expect(afternoon.azimuth, inInclusiveRange(220, 290));
    expect(morning.elevation, greaterThan(15));
    expect(night.elevation, lessThan(0));
  });

  test('local DateTime gives the same answer as UTC', () {
    final utc = DateTime.utc(2026, 7, 15, 12, 30);
    final a = sunPosition(lat, lon, utc);
    final b = sunPosition(lat, lon, utc.toLocal());
    expect(a.elevation, b.elevation);
    expect(a.azimuth, b.azimuth);
  });
}
