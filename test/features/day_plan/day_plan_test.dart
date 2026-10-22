import 'package:cool_lodz/core/heat/heat_risk.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/day_plan/day_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 7, 15, 8);
  Place place(String id, PlaceCategory c, {OpeningHours? hours}) => Place(
    id: id,
    type: PlaceType.cool,
    name: id,
    category: c,
    lat: 51.77,
    lon: 19.45,
    hours: hours,
  );

  test('around the hot hours, indoor places open the whole midday', () {
    final risk = HeatRisk(
      level: HeatRiskLevel.high,
      riskFrom: DateTime(2026, 7, 15, 12),
      riskTo: DateTime(2026, 7, 15, 18),
    );
    final plan = dayPlan(
      day: day,
      risk: risk,
      places: [
        place('park', PlaceCategory.park),
        place('muzeum', PlaceCategory.museum),
        place('galeria', PlaceCategory.mall),
      ],
    );
    expect(plan.map((s) => s.part), DayPart.values);
    expect(plan.first.to, DateTime(2026, 7, 15, 12));
    expect(plan[1].from, DateTime(2026, 7, 15, 12));
    expect(plan.last.from, DateTime(2026, 7, 15, 18));
    // Museums first, parks are not «indoors».
    expect(plan[1].places.map((p) => p.id), ['muzeum', 'galeria']);
  });

  test('without a forecast: 12–17', () {
    final plan = dayPlan(day: day);
    expect(plan[1].from.hour, 12);
    expect(plan.last.from.hour, 17);
  });
}
