import 'package:cool_lodz/core/api/live/weather.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/warsaw_time.dart';
import 'package:cool_lodz/features/route/data/departure_advice.dart';
import 'package:cool_lodz/features/route/data/route_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// 08:00 … 20:00 every 30 min.
final _slots = [for (var m = 8 * 60; m <= 20 * 60; m += 30) formatHhMm(m)];

RouteVariant _variant(
  RouteVariantType type, {
  required int durationS,
  required double Function(String slot) sun,
  List<RouteStop> stops = const [],
}) => RouteVariant(
  variant: type,
  geometry: const [LatLng(51.77, 19.45), LatLng(51.76, 19.46)],
  distanceM: durationS,
  durationS: durationS,
  sunShare: 0.5,
  extraTimeVsShortestS: 0,
  stops: stops,
  sunShareByHour: {for (final s in _slots) s: sun(s)},
);

/// The slot [hhmm] on 2026-07-15 (Warsaw) as local time.
DateTime _at(String hhmm) {
  final m = parseHhMm(hhmm);
  return warsawWallClockToUtc(2026, 7, 15, m ~/ 60, m % 60).toLocal();
}

void main() {
  final day = _at('12:00');
  final response = RouteResponse(
    coverage: RouteCoverage.full,
    variants: [
      _variant(
        RouteVariantType.shortest,
        durationS: 900,
        sun: (s) => s == '18:00' ? 0.3 : 0.7,
      ),
      _variant(
        RouteVariantType.shaded,
        durationS: 1200,
        sun: (s) => s == '18:00' ? 0.1 : (s == '18:30' ? 0.15 : 0.6),
      ),
    ],
  );

  test('the shadiest slots, an hour apart, best first; none in the past', () {
    final options = adviseDepartures(
      response: response,
      day: day,
      now: _at('9:10'),
    );
    expect(options, hasLength(3));
    expect(options.first.departAt, _at('18:00'));
    expect(options.first.variant.variant, RouteVariantType.shaded);
    expect(options.first.shadeShare, closeTo(0.9, 1e-9));
    expect(options.first.arriveAt, _at('18:20'));
    // 18:30 is close to 18:00: skipped for variety.
    expect(options.map((o) => o.departAt), isNot(contains(_at('18:30'))));
    for (final o in options) {
      expect(o.departAt.isBefore(_at('9:10')), isFalse);
      for (final p in options) {
        if (!identical(o, p)) {
          expect(
            o.departAt.difference(p.departAt).abs(),
            greaterThanOrEqualTo(const Duration(hours: 1)),
          );
        }
      }
    }
    expect(
      adviseDepartures(response: response, day: day, now: _at('20:30')),
      isEmpty,
    );
  });

  test('rain and heat at the shadiest time move the advice', () {
    final wet = WeatherForecast([
      for (final s in _slots)
        WeatherHour(
          time: _at(s).toUtc().add(const Duration(minutes: 30)),
          temperature: 22,
          weatherCode: s == '18:00' ? 95 : 0,
          precipitationProbability: s == '18:00' ? 90 : 0,
        ),
    ]);
    final options = adviseDepartures(
      response: response,
      day: day,
      now: _at('8:00'),
      forecast: wet,
    );
    expect(options.first.departAt, _at('18:30'));
    expect(options.first.weather?.temperature, 22);
  });

  test('a destination closed on arrival goes to the end', () {
    final closedWednesday = Place(
      id: 'mall',
      type: PlaceType.cool,
      name: 'Manufaktura',
      lat: 51.776,
      lon: 19.448,
      hours: OpeningHours({
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          if (d != DateTime.wednesday) d: [const TimeInterval(0, 24 * 60)],
      }),
    );
    final options = adviseDepartures(
      response: response,
      day: day,
      now: _at('8:00'),
      destination: closedWednesday,
    );
    expect(options, isNotEmpty);
    expect(options.every((o) => o.destinationOpen == false), isTrue);
    expect(options.first.destination, closedWednesday);
  });

  test('open cool places on the way count', () {
    final cafe = const Place(
      id: 'cafe',
      type: PlaceType.cool,
      lat: 51.77,
      lon: 19.45,
    );
    final withStop = RouteResponse(
      coverage: RouteCoverage.full,
      variants: [
        _variant(
          RouteVariantType.shortest,
          durationS: 900,
          sun: (_) => 0.5,
          stops: const [RouteStop(placeId: 'cafe', type: StopType.cool)],
        ),
      ],
    );
    final options = adviseDepartures(
      response: withStop,
      day: day,
      now: _at('8:00'),
      places: {'cafe': cafe},
    );
    expect(options.first.coolOpen, 1);
  });

  test('the destination place: picked, or a cool place within 60 m', () {
    const near = Place(
      id: 'near',
      type: PlaceType.cool,
      lat: 51.7760,
      lon: 19.4480,
    );
    final to = const PointEndpoint(
      RoutePoint(lat: 51.7762, lon: 19.4481, label: 'Manufaktura'),
    );
    expect(destinationPlace(to, [near]), near);
    expect(
      destinationPlace(
        const PointEndpoint(RoutePoint(lat: 51.79, lon: 19.40, label: 'x')),
        [near],
      ),
      isNull,
    );
    expect(destinationPlace(const MyLocation(), [near]), isNull);
  });
}
