import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Temporary screen used by the scaffold until a feature ticket fills it in.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.code,
    required this.title,
    this.showAppBar = true,
  });

  /// Screen code from the spec, e.g. `S05`.
  final String code;
  final String title;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSizes.s8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.s8),
            Text(
              AppLocalizations.of(context).placeholderInProgress,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
