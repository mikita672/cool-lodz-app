import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fresh in-memory SharedPreferences with [values].
Future<SharedPreferences> testPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Pumps [child] inside the app theme and Polish localisations.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pl'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
  await tester.pump();
}

/// Pumps [child] on a 360 × 640 dp screen with Senior text (×1.25), to catch
/// overflows (spec: Senior mode must not break layouts at 360 dp).
Future<void> pumpSenior360(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  const size = Size(360, 640);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    MediaQuery(
      data: const MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(1.25),
      ),
      child: child,
    ),
    overrides: overrides,
  );
}
