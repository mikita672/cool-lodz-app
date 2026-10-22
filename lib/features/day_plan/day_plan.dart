import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/heat/heat_risk.dart';
import '../../core/models/models.dart';
import '../cool_places/place_format.dart';

/// One part of «Dzień w upale».
enum DayPart { morning, midday, afternoon, evening }

@immutable
class DayPlanStep {
  const DayPlanStep(this.part, this.from, this.to, {this.places = const []});

  final DayPart part;
  final DateTime from;
  final DateTime to;

  /// Cool places open through the step, nearest first (midday only).
  final List<Place> places;
}

/// Indoor places first at midday: museums, galleries, libraries, malls.
const _middayOrder = [
  PlaceCategory.museum,
  PlaceCategory.culture,
  PlaceCategory.library,
  PlaceCategory.mall,
  PlaceCategory.church,
];

/// The plan of [day]: a shaded walk before the hot hours, indoors through
/// them (cool places open the whole time), water in the afternoon and the
/// evening out. The hot hours come from [risk] (12–17 when it has none).
List<DayPlanStep> dayPlan({
  required DateTime day,
  HeatRisk? risk,
  List<Place> places = const [],
  LatLng? near,
}) {
  DateTime at(int h) => DateTime(day.year, day.month, day.day, h);
  var hotFrom = risk?.riskFrom ?? at(12);
  var hotTo = risk?.riskTo ?? at(17);
  // Keep the steps in a sensible day.
  if (hotFrom.hour < 10) hotFrom = at(10);
  if (hotTo.hour > 19 || hotTo.day != day.day) hotTo = at(19);
  if (!hotTo.isAfter(hotFrom.add(const Duration(hours: 1)))) {
    hotTo = hotFrom.add(const Duration(hours: 3));
  }
  final midEnd = hotFrom.add(hotTo.difference(hotFrom) * 0.6);
  final open = [
    for (final p in places)
      if (p.category != null &&
          _middayOrder.contains(p.category) &&
          p.isOpenAt(hotFrom.add(const Duration(minutes: 30))) &&
          p.isOpenAt(midEnd.subtract(const Duration(minutes: 30))))
        p,
  ];
  if (near != null) {
    open.sort((a, b) => distanceTo(a, near).compareTo(distanceTo(b, near)));
  } else {
    open.sort(
      (a, b) => _middayOrder
          .indexOf(a.category!)
          .compareTo(_middayOrder.indexOf(b.category!)),
    );
  }
  return [
    DayPlanStep(DayPart.morning, at(7), hotFrom),
    DayPlanStep(DayPart.midday, hotFrom, midEnd, places: open.take(3).toList()),
    DayPlanStep(DayPart.afternoon, midEnd, hotTo),
    DayPlanStep(DayPart.evening, hotTo, at(22)),
  ];
}
