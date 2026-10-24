import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Polityka prywatności (decision #44, Q-07): an in-app Polish draft based
/// on the spec's RODO requirements, opened from S03 and S16. The team must
/// review it before submission, hence the visible draft note.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sections = [
      (l10n.privacyDataTitle, l10n.privacyDataBody),
      (l10n.privacyLocationTitle, l10n.privacyLocationBody),
      (l10n.privacyStorageTitle, l10n.privacyStorageBody),
      (l10n.privacyRankingTitle, l10n.privacyRankingBody),
      (l10n.privacyMedicalTitle, l10n.privacyMedicalBody),
      (l10n.privacyRightsTitle, l10n.privacyRightsBody),
      (l10n.privacyContactTitle, l10n.privacyContactBody),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Container(
              key: const Key('privacy-draft-note'),
              padding: const EdgeInsets.all(AppSizes.s12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Text(
                      l10n.privacyDraftNote,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Text(l10n.privacyIntro, style: theme.textTheme.bodyLarge),
            for (final (title, body) in sections) ...[
              const SizedBox(height: AppSizes.s24),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: AppSizes.s8),
              Text(body, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSizes.s16),
          ],
        ),
      ),
    );
  }
}
