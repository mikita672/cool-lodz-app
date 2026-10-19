import 'package:cool_lodz/app/app.dart';
import 'package:cool_lodz/app/router.dart';
import 'package:cool_lodz/app/routes.dart';
import 'package:cool_lodz/features/quest/quest_scan_screen.dart';
import 'package:cool_lodz/features/quest/quest_view.dart';
import 'package:cool_lodz/features/route/route_plan_screen.dart';
import 'package:cool_lodz/features/route/route_result_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('a deep link to the QR scanner keeps the Quest tab underneath', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [...appTestOverrides(prefs: await testPrefs())],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    router.go(Routes.questScan);
    await tester.pumpAndSettle();
    expect(find.byType(QuestScanScreen), findsOneWidget);

    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(QuestView), findsOneWidget);
  });

  testWidgets('route result sits on top of route planning', (tester) async {
    final container = ProviderContainer.test(
      overrides: [...appTestOverrides(prefs: await testPrefs())],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    router.go(Routes.routeResult);
    await tester.pumpAndSettle();
    expect(find.byType(RouteResultScreen), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(RoutePlanScreen), findsOneWidget);
  });
}
