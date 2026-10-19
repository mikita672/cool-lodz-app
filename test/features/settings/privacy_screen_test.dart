import 'package:cool_lodz/features/settings/privacy_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('shows the draft note and the RODO sections', (tester) async {
    await pumpScreen(tester, const PrivacyScreen());
    expect(find.text('Polityka prywatności'), findsOneWidget);
    expect(
      find.text('Wersja robocza — do sprawdzenia przez zespół.'),
      findsOneWidget,
    );
    expect(find.text('Jakie dane zbieramy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kontakt'), 200);
    expect(find.textContaining('europe-central2'), findsOneWidget);
  });
}
