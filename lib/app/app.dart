import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alerts/push_handler.dart';
import '../features/heat_guard/heat_guard_handler.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'senior_mode.dart';
import 'theme.dart';

class CoolLodzApp extends ConsumerWidget {
  const CoolLodzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senior = ref.watch(seniorModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(senior: senior),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: rootMessengerKey,
      locale: const Locale('pl'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Senior mode scales all text ×1.25 on top of the system font size.
      // Always the same tree, so toggling Senior does not rebuild the app
      // (and the push handler) from scratch.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: senior
              ? media.copyWith(textScaler: SeniorTextScaler(media.textScaler))
              : media,
          child: PushHandler(child: HeatGuardHandler(child: child!)),
        );
      },
    );
  }
}
