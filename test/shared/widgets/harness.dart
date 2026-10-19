import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] in a themed, Polish MaterialApp at 360 dp width.
/// Animations are disabled so pulsing skeletons settle.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  bool senior = false,
  bool scroll = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(senior: senior),
      locale: const Locale('pl'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, app) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: true,
            textScaler: senior
                ? SeniorTextScaler(media.textScaler)
                : media.textScaler,
          ),
          child: app!,
        );
      },
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              )
            : child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Asserts that TalkBack can activate [finder] (needs `ensureSemantics`).
void expectTapAction(WidgetTester tester, Finder finder) {
  final data = tester.getSemantics(finder).getSemanticsData();
  expect(
    data.hasAction(SemanticsAction.tap),
    isTrue,
    reason: 'no tap action on ${finder.describeMatch(Plurality.one)}',
  );
}
