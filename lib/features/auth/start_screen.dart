import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shown for a moment while the start flow reads the onboarding flag, the
/// signed-in user and their consents.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: CircularProgressIndicator(
        semanticsLabel: AppLocalizations.of(context).startLoading,
      ),
    ),
  );
}
