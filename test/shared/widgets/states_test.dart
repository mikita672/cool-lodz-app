import 'package:cool_lodz/shared/widgets/app_toast.dart';
import 'package:cool_lodz/shared/widgets/empty_state.dart';
import 'package:cool_lodz/shared/widgets/error_state.dart';
import 'package:cool_lodz/shared/widgets/offline_banner.dart';
import 'package:cool_lodz/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('EmptyState shows texts and fires the action', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      EmptyState(
        icon: Icons.home_rounded,
        title: 'Brak miejsc',
        message: 'Spróbuj później.',
        actionLabel: 'Pokaż wszystkie',
        onAction: () => taps++,
      ),
    );
    expect(find.text('Brak miejsc'), findsOneWidget);
    expect(find.text('Spróbuj później.'), findsOneWidget);
    expect(find.bySemanticsLabel('Brak miejsc'), findsOneWidget);
    expectTapAction(tester, find.text('Pokaż wszystkie'));
    await tester.tap(find.text('Pokaż wszystkie'));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('ErrorState has default texts and a retry button', (
    tester,
  ) async {
    var retries = 0;
    await pumpComponent(tester, ErrorState(onRetry: () => retries++));
    expect(find.text('Coś poszło nie tak'), findsOneWidget);
    expect(find.text('Spróbuj ponownie za chwilę.'), findsOneWidget);
    await tester.tap(find.text('Spróbuj ponownie'));
    expect(retries, 1);
  });

  testWidgets('SkeletonCard is announced as loading', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const Column(children: [SkeletonCard(), SkeletonBox(height: 40)]),
    );
    expect(find.bySemanticsLabel('Ładowanie'), findsOneWidget);
    expect(find.byType(SkeletonBox), findsNWidgets(5));
    semantics.dispose();
  });

  testWidgets('SkeletonPulse animates when animations are allowed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SkeletonBox(width: 40, height: 40)),
    );
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(SkeletonPulse),
        matching: find.byType(FadeTransition),
      ),
    );
    final before = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 450));
    expect(fade.opacity.value, isNot(before));
  });

  testWidgets('showAppToast shows a SnackBar with icon and text', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showAppToast(context, 'Trasa zapisana', kind: ToastKind.success),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Trasa zapisana'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('OfflineBanner shows and announces the default text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(tester, const OfflineBanner());
    const text = 'Brak połączenia z serwerem, pokazujemy ostatnie dane';
    expect(find.text(text), findsOneWidget);
    expect(find.bySemanticsLabel(text), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('error toast and route card skeleton', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const Column(
        children: [
          AppToastContent(message: 'Kod nieważny', kind: ToastKind.error),
          SkeletonRouteCard(),
        ],
      ),
    );
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Ładowanie'), findsOneWidget);
    semantics.dispose();
  });
}
