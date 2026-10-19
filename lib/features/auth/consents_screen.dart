import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/data/push_token_sync.dart';
import 'data/auth_repository.dart';
import 'data/system_permissions.dart';
import 'data/user_profile_repository.dart';
import 'start_flow.dart';

/// S03 Zgody. Saves the choices to `users/{uid}`, then shows the Android
/// permission dialogs for the switches that are on. The start flow then
/// opens the map.
class ConsentsScreen extends ConsumerStatefulWidget {
  const ConsentsScreen({super.key});

  /// Firestore only completes a write once the server confirms it.
  static const saveTimeout = Duration(seconds: 15);

  @override
  ConsumerState<ConsentsScreen> createState() => _ConsentsScreenState();
}

class _ConsentsScreenState extends ConsumerState<ConsentsScreen> {
  // Defaults follow the Figma frame: the OS dialog is the real choice for
  // location and push; ranking publishes the nickname, so it is opt-in.
  bool _location = true;
  bool _push = true;
  bool _ranking = false;
  bool _saving = false;

  Future<void> _accept() async {
    final uid =
        ref.read(startFlowProvider).user?.uid ??
        ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final consents = Consents(
      location: _location,
      push: _push,
      ranking: _ranking,
    );
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .saveConsents(uid, consents)
          .timeout(ConsentsScreen.saveTimeout);
    } catch (e) {
      debugPrint('Saving consents failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.consentsSaveError)));
      return;
    }

    final permissions = ref.read(systemPermissionsProvider);
    if (consents.location) await permissions.requestLocation();
    if (consents.push) {
      await permissions.requestNotifications();
      unawaited(ref.read(pushTokenSyncProvider).sync(uid));
    }
    if (!mounted) return;
    ref.read(startFlowProvider.notifier).markConsentsAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  const SizedBox(height: AppSizes.s16),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.consentsTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s8),
                  Text(
                    l10n.consentsIntro,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s16),
                  _ConsentTile(
                    key: const Key('consent-location'),
                    icon: Icons.location_on_rounded,
                    title: l10n.consentsLocationTitle,
                    body: l10n.consentsLocationBody,
                    tag: l10n.consentsLocationRequired,
                    value: _location,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _location = v),
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _ConsentTile(
                    key: const Key('consent-push'),
                    icon: Icons.notifications_rounded,
                    title: l10n.consentsPushTitle,
                    body: l10n.consentsPushBody,
                    value: _push,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _push = v),
                  ),
                  const SizedBox(height: AppSizes.s12),
                  _ConsentTile(
                    key: const Key('consent-ranking'),
                    icon: Icons.leaderboard_rounded,
                    title: l10n.consentsRankingTitle,
                    body: l10n.consentsRankingBody,
                    value: _ranking,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _ranking = v),
                  ),
                  const SizedBox(height: AppSizes.s16),
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
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.s8,
                AppSizes.screenPadding,
                AppSizes.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.consentsSystemNote,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  FilledButton(
                    key: const Key('consents-accept'),
                    onPressed: _saving ? null : _accept,
                    child: _saving
                        ? SizedBox.square(
                            dimension: AppSizes.s24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              semanticsLabel: l10n.authLoading,
                            ),
                          )
                        : Text(l10n.consentsAccept),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? tag;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s16,
          vertical: AppSizes.s8,
        ),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.s4),
            Text(body, style: theme.textTheme.bodySmall),
            if (tag != null) ...[
              const SizedBox(height: AppSizes.s4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSizes.radiusChip),
                ),
                child: Text(tag!, style: theme.textTheme.labelSmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
