import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../alerts/data/push_token_sync.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/system_permissions.dart';
import '../auth/data/user_profile_repository.dart';
import '../game/game_service.dart';
import 'data/account_repository.dart';
import 'data/settings_providers.dart';

/// S16 «Zgody i prywatność»: the three S03 switches, changeable any time.
/// Withdrawing the ranking consent removes the user from the ranking.
class ConsentsSettingsScreen extends ConsumerStatefulWidget {
  const ConsentsSettingsScreen({super.key});

  @override
  ConsumerState<ConsentsSettingsScreen> createState() =>
      _ConsentsSettingsScreenState();
}

class _ConsentsSettingsScreenState
    extends ConsumerState<ConsentsSettingsScreen> {
  Consents? _draft;
  bool _saving = false;

  Future<void> _save() async {
    final draft = _draft;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (draft == null || uid == null) return;
    final l10n = AppLocalizations.of(context);
    final before = ref.read(consentsProvider).value;
    setState(() => _saving = true);
    try {
      final permissions = ref.read(systemPermissionsProvider);
      if (draft.location && before?.location != true) {
        await permissions.requestLocation();
      }
      if (draft.push && before?.push != true) {
        await permissions.requestNotifications();
      }
      await ref.read(accountRepositoryProvider).setConsents(uid, draft);
      if (draft.push) unawaited(ref.read(pushTokenSyncProvider).sync(uid));
      ref
        ..invalidate(consentsProvider)
        ..invalidate(playerProvider);
      if (!mounted) return;
      showAppToast(
        context,
        l10n.settingsConsentsSaved,
        kind: ToastKind.success,
      );
      context.pop();
    } catch (e) {
      debugPrint('Saving consents failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, l10n.settingsSaveError, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saved = ref.watch(consentsProvider).value;
    final c =
        _draft ??
        saved ??
        const Consents(location: false, push: false, ranking: false);

    void update(Consents next) => setState(() => _draft = next);

    Widget tile(
      Key key,
      IconData icon,
      String title,
      String body,
      bool value,
      ValueChanged<bool> onChanged,
    ) => Card(
      margin: const EdgeInsets.only(bottom: AppSizes.s12),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        key: key,
        value: value,
        onChanged: _saving ? null : onChanged,
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(body, style: theme.textTheme.bodySmall),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsConsents)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  tile(
                    const Key('settings-consent-location'),
                    Icons.location_on_rounded,
                    l10n.consentsLocationTitle,
                    l10n.consentsLocationBody,
                    c.location,
                    (v) => update(
                      Consents(location: v, push: c.push, ranking: c.ranking),
                    ),
                  ),
                  tile(
                    const Key('settings-consent-push'),
                    Icons.notifications_rounded,
                    l10n.consentsPushTitle,
                    l10n.consentsPushBody,
                    c.push,
                    (v) => update(
                      Consents(
                        location: c.location,
                        push: v,
                        ranking: c.ranking,
                      ),
                    ),
                  ),
                  tile(
                    const Key('settings-consent-ranking'),
                    Icons.leaderboard_rounded,
                    l10n.consentsRankingTitle,
                    l10n.consentsRankingBody,
                    c.ranking,
                    (v) => update(
                      Consents(location: c.location, push: c.push, ranking: v),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push(Routes.privacy),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(l10n.consentsPrivacyLink),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              child: AppButton(
                key: const Key('settings-consents-save'),
                label: l10n.settingsConsentsSave,
                loading: _saving,
                expand: true,
                onPressed: _draft == null || _draft == saved ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
