import 'package:cool_lodz/core/api/live/air_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> json(List<num?> aqi, List<num?> grass) => {
    'hourly': {
      'time': [
        for (var h = 0; h < aqi.length; h++)
          '2026-07-15T${h.toString().padLeft(2, '0')}:00',
      ],
      'european_aqi': aqi,
      'grass_pollen': grass,
      'birch_pollen': List.filled(aqi.length, 0),
    },
  };

  test('the rest of today: AQI now and worst, pollen highest', () {
    final air = parseAirQuality(
      json([10, 20, 30, 70, 40], [5, 80, 10, 10, 3]),
      DateTime(2026, 7, 15, 2, 30),
    );
    expect(air.aqiNow, 30);
    expect(air.aqiMax, 70);
    // The 80 at 1:00 is gone; 10 is low.
    expect(air.pollen[PollenKind.grass], 10);
    expect(air.pollenLevels, [(PollenKind.grass, PollenLevel.low)]);
    expect(air.allergyWarning, isTrue); // AQI 70
  });

  test('levels and bands', () {
    expect(pollenLevel(PollenKind.grass, 0.5), PollenLevel.none);
    expect(pollenLevel(PollenKind.grass, 30), PollenLevel.moderate);
    expect(pollenLevel(PollenKind.grass, 64), PollenLevel.high);
    expect(pollenLevel(PollenKind.birch, 64), PollenLevel.moderate);
    expect(aqiBand(15), 0);
    expect(aqiBand(58), 2);
    expect(aqiBand(120), 5);
  });

  test('a bad answer is empty, the demo has grass in bloom', () {
    expect(parseAirQuality('x', DateTime(2026)).pollen, isEmpty);
    expect(demoAirToday.allergyWarning, isTrue);
  });
}
