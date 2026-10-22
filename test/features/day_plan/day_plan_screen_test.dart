import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/heat/heat_risk.dart';
import 'package:cool_lodz/features/day_plan/day_plan_screen.dart';
import 'package:cool_lodz/features/heat_risk/data/heat_risk_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('four parts around the hot hours', (tester) async {
    await initializeDateFormatting('pl');
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await testPrefs();
    await pumpScreen(
      tester,
      const DayPlanScreen(),
      overrides: [
        ...appTestOverrides(prefs: prefs, location: FakeLocationService()),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 8)),
        heatRiskProvider.overrideWith(
          (ref) => HeatRisk(
            level: HeatRiskLevel.high,
            peakFeelsLike: 35,
            riskFrom: DateTime(2026, 7, 15, 11),
            riskTo: DateTime(2026, 7, 15, 18),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    for (final part in ['morning', 'midday', 'afternoon', 'evening']) {
      expect(find.byKey(Key('day-plan-$part')), findsOneWidget);
    }
    expect(find.text('7:00–11:00'), findsOneWidget);
    expect(find.textContaining('odczuwalna do 35°C'), findsOneWidget);
    expect(find.byKey(const Key('read-aloud')), findsOneWidget);
  });
}
