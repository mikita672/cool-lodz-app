import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/live/weather.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';
import '../../../core/warsaw_time.dart';
import '../../../shared/widgets/weather_icon.dart';
import '../../cool_places/data/places_providers.dart';
import '../../profile/data/comfort_profile_provider.dart';
import 'route_plan.dart';

/// One suggested departure («Kiedy najlepiej iść?»).
class DepartureOption {
  const DepartureOption({
    required this.departAt,
    required this.variant,
    required this.sunShare,
    required this.score,
    this.weather,
    this.coolOpen = 0,
    this.destination,
    this.destinationOpen,
    this.destinationClosesAt,
  });

  /// Local time.
  final DateTime departAt;

  /// The shadiest walk at that time.
  final RouteVariant variant;
  final double sunShare;

  /// Higher is better.
  final double score;
  final WeatherHour? weather;

  /// Cool places along the walk that are open on the way.
  final int coolOpen;

  /// The destination when it is a place with opening hours.
  final Place? destination;
  final bool? destinationOpen;
  final DateTime? destinationClosesAt;

  DateTime get arriveAt => departAt.add(variant.duration);

  double get shadeShare => 1 - sunShare;
}

/// Points subtracted when the destination is closed on arrival.
const _closedPenalty = 200.0;

/// Ranks the response's `sunShareByHour` slots on [day] that are not
/// before [now] and returns the best [count] departures, at least an hour
/// apart, best first.
///
/// Score: percent of the walk in shade, plus a little for open cool places
/// on the way; minus heat above 26 °C, rain, storms, wind, darkness, and a
/// lot when the destination is closed when you get there.
List<DepartureOption> adviseDepartures({
  required RouteResponse response,
  required DateTime day,
  required DateTime now,
  WeatherForecast? forecast,
  Map<String, Place> places = const {},
  Place? destination,
  int count = 3,
}) {
  final keys = <String>{
    for (final v in response.variants) ...v.sunShareByHour.keys,
  }.toList()..sort();
  final wall = warsawWallClock(day);
  final options = <DepartureOption>[];
  for (final key in keys) {
    final m = parseHhMm(key);
    final at = warsawWallClockToUtc(
      wall.year,
      wall.month,
      wall.day,
      m ~/ 60,
      m % 60,
    ).toLocal();
    if (at.isBefore(now.subtract(const Duration(minutes: 1)))) continue;

    // The shadiest walk at that time.
    RouteVariant? best;
    var bestSun = 2.0;
    for (final v in response.variants) {
      final sun = v.sunShareByHour[key] ?? v.sunShare;
      if (sun < bestSun - 0.005 ||
          (best != null &&
              (sun - bestSun).abs() <= 0.005 &&
              v.durationS < best.durationS)) {
        best = v;
        bestSun = sun;
      }
    }
    if (best == null) continue;

    final arrive = at.add(best.duration);
    final halfway = at.add(best.duration ~/ 2);
    final coolOpen = best.stops
        .where((s) => s.type == StopType.cool)
        .where((s) => places[s.placeId]?.isOpenAt(halfway) ?? false)
        .length;
    final hours = destination?.hours;
    final destOpen = hours?.isOpenAt(arrive);
    final weather = forecast?.at(at);

    var score = (1 - bestSun) * 100 + 3 * math.min(coolOpen, 3);
    if (weather != null) {
      final t = weather.temperature;
      if (t != null && t > 26) score -= (t - 26) * 4;
      score -= (weather.precipitationProbability ?? 0) * 0.4;
      if (WeatherKind.of(weather) == WeatherKind.storm) score -= 40;
      if (weatherTags(weather).contains(WeatherTag.windy)) score -= 8;
    }
    if (isNight(at)) score -= 15;
    if (destOpen == false) score -= _closedPenalty;

    options.add(
      DepartureOption(
        departAt: at,
        variant: best,
        sunShare: bestSun,
        score: score,
        weather: weather,
        coolOpen: coolOpen,
        destination: hours == null ? null : destination,
        destinationOpen: destOpen,
        destinationClosesAt: destOpen == true
            ? hours!.closingTime(arrive)
            : null,
      ),
    );
  }
  options.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.departAt.compareTo(b.departAt);
  });
  final picked = <DepartureOption>[];
  for (final o in options) {
    if (picked.length == count) break;
    if (picked.any(
      (p) => p.departAt.difference(o.departAt).abs() < const Duration(hours: 1),
    )) {
      continue;
    }
    picked.add(o);
  }
  return picked;
}

/// The cool place the destination is (picked from the list, or within
/// 60 m of the searched point).
Place? destinationPlace(RouteEndpoint? to, Iterable<Place> places) {
  if (to is! PointEndpoint) return null;
  if (to.place case final p?) return p;
  final point = to.point.latLng;
  Place? best;
  var bestD = 60.0;
  for (final p in places) {
    final d = distanceMeters(point, p.latLng);
    if (d <= bestD) {
      best = p;
      bestD = d;
    }
  }
  return best;
}

/// The advice's clock (tests fix it).
final adviceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// «Kiedy najlepiej iść?» for the current plan: on the planned day (today
/// when leaving now), or tomorrow when today has no slot left.
final departureAdviceProvider =
    FutureProvider.autoDispose<List<DepartureOption>>((ref) async {
      final plan = ref.watch(routePlanProvider);
      final api = ref.watch(apiClientProvider);
      final now = ref.watch(adviceClockProvider)();
      WeatherForecast? forecast;
      try {
        forecast = await ref.watch(forecastProvider.future);
      } catch (_) {
        // Advice without weather.
      }
      var cool = const <Place>[];
      try {
        cool = await ref.watch(coolPlacesProvider.future);
      } catch (_) {
        // Advice without opening hours.
      }
      final places = {for (final p in cool) p.id: p};
      final destination = destinationPlace(plan.to, cool);

      Future<List<DepartureOption>> on(DateTime day) async {
        final request = await buildRouteRequest(
          plan: plan.copyWith(departAt: () => day),
          profile: ref.read(comfortProfileProvider),
          location: ref.read(locationServiceProvider),
          now: now,
        );
        final response = await api.getRoutes(request);
        return adviseDepartures(
          response: response,
          day: day,
          now: now,
          forecast: forecast,
          places: places,
          destination: destination,
        );
      }

      final planned = plan.departAt;
      final today = planned == null || !planned.isAfter(now) ? now : planned;
      final options = await on(today);
      if (options.isNotEmpty ||
          today.day != now.day ||
          today.month != now.month) {
        return options;
      }
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 12);
      return on(tomorrow);
    });
