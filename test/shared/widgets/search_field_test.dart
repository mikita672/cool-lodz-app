import 'package:cool_lodz/shared/widgets/search_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('shows the hint, is a button and calls onTap', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(tester, SearchField(onTap: () => taps++));
    expect(find.text('Dokąd idziesz?'), findsOneWidget);
    expect(find.bySemanticsLabel('Dokąd idziesz?'), findsOneWidget);
    expectTapAction(tester, find.byType(SearchField));
    await tester.tap(find.byType(SearchField));
    expect(taps, 1);
    expect(tester.getSize(find.byType(SearchField)).height, greaterThan(48));
    semantics.dispose();
  });
}
