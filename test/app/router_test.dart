import 'package:cool_lodz/app/app.dart';
import 'package:cool_lodz/app/router.dart';
import 'package:cool_lodz/app/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a deep link to the QR scanner keeps the Quest tab underneath', (
    tester,
  ) async {
    final container = ProviderContainer.test();
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
    expect(find.text('S11'), findsOneWidget);

    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('S10'), findsOneWidget);
  });

  testWidgets('route result sits on top of route planning', (tester) async {
    final container = ProviderContainer.test();
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
    expect(find.text('S07'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('S06'), findsOneWidget);
  });
}
