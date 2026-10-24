import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/firestore/collections.dart';
import '../../core/storage/offline_cache.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../alerts/data/push_token_sync.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/system_permissions.dart';
import '../auth/data/user_profile_repository.dart';
import '../game/game_service.dart';
import '../heat_guard/data/heat_guard_settings.dart';
import '../heat_risk/data/heat_risk_providers.dart';
import '../leaderboard/data/ranking_repository.dart';
import '../profile/data/comfort_profile_provider.dart';
import '../profile/profile_select_screen.dart';
import 'data/account_repository.dart';
import 'data/settings_providers.dart';

/// S16 Profil i ustawienia: nickname, district, points; comfort profile,
/// Senior mode, heat notifications, consents, privacy policy, about,
/// sign out and account removal.
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  Future<void> _pickDistrict(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  0,
                  AppSizes.screenPadding,
                  AppSizes.s4,
                ),
                child: Text(
                  l10n.settingsDistrictTitle,
                  style: AppTextStyles.titleM,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenPadding,
                ),
                child: Text(
                  l10n.settingsDistrictHint,
                  style: AppTextStyles.bodyS,
                ),
              ),
              RadioGroup<String>(
                groupValue: current,
                onChanged: (v) => Navigator.of(context).pop(v),
                child: Column(
                  children: [
                    for (final id in FirestoreDistricts.ids)
                      RadioListTile<String>(
                        key: Key('district-$id'),
                        value: id,
                        title: Text(districtName(id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == current || !context.mounted) return;
    await _guard(context, () async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid == null) return;
      await ref.read(accountRepositoryProvider).setDistrict(uid, picked);
      ref.invalidate(playerProvider);
    });
  }

  Future<void> _setPush(BuildContext context, WidgetRef ref, bool on) async {
    final consents = ref.read(consentsProvider).value;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (consents == null || uid == null) return;
    await _guard(context, () async {
      if (on) await ref.read(systemPermissionsProvider).requestNotifications();
      await ref
          .read(accountRepositoryProvider)
          .setConsents(
            uid,
            Consents(
              location: consents.location,
              push: on,
              ranking: consents.ranking,
            ),
          );
      ref.invalidate(consentsProvider);
    });
  }

  Future<void> _setSenior(BuildContext context, WidgetRef ref, bool on) =>
      _guard(context, () async {
        final notifier = ref.read(comfortProfileProvider.notifier);
        await notifier.save(
          ref.read(comfortProfileProvider).copyWith(seniorMode: on),
        );
      });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted == true && context.mounted) {
      showAppToast(
        context,
        AppLocalizations.of(context).settingsDeleted,
        kind: ToastKind.success,
      );
    }
  }

  /// Removes this phone's push token and the user's cached route first:
  /// both belong to the account, not the device.
  static Future<void> _signOut(WidgetRef ref) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid != null) await ref.read(pushTokenSyncProvider).clear(uid);
    await ref.read(offlineCacheProvider).clearPersonal();
    await ref.read(authRepositoryProvider).signOut();
  }

  static Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      debugPrint('Settings change failed: $e');
      if (context.mounted) {
        showAppToast(context, l10n.settingsSaveError, kind: ToastKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = ref.watch(playerProvider).value;
    final consents = ref.watch(consentsProvider).value;
    final profile = ref.watch(comfortProfileProvider);
    final (_, profileName, _) = profileLabels(profile.id, l10n);
    final nickname = player?.nickname ?? '';
    final district = player?.district;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.s24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
            ),
            child: Card(
              color: AppColors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        nickname.isEmpty
                            ? '?'
                            : nickname.characters.first.toUpperCase(),
                        style: AppTextStyles.titleM.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nickname,
                            key: const Key('settings-nickname'),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            l10n.dsPoints(player?.points ?? 0),
                            key: const Key('settings-points'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          ListTile(
            key: const Key('settings-district'),
            leading: const Icon(Icons.location_city_rounded),
            title: Text(l10n.settingsDistrict),
            subtitle: Text(
              district == null
                  ? l10n.settingsDistrictNone
                  : districtName(district),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickDistrict(context, ref, district),
          ),
          ListTile(
            key: const Key('settings-comfort'),
            leading: const Icon(Icons.tune_rounded),
            title: Text(l10n.settingsComfort),
            subtitle: Text(profileName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.profileSelect),
          ),
          ListTile(
            key: const Key('settings-heat-guard'),
            leading: const Icon(Icons.health_and_safety_rounded),
            title: Text(l10n.heatGuardTitle),
            subtitle: Text(
              ref.watch(heatGuardSettingsProvider).enabled
                  ? l10n.heatGuardSettingsSubtitleOn
                  : l10n.heatGuardSettingsSubtitleOff,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.heatGuard),
          ),
          ListTile(
            key: const Key('settings-cool-walk'),
            leading: const Icon(Icons.loop_rounded),
            title: Text(l10n.settingsCoolWalk),
            subtitle: Text(l10n.settingsCoolWalkBody),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.coolWalk),
          ),
          ListTile(
            key: const Key('settings-day-plan'),
            leading: const Icon(Icons.event_note_rounded),
            title: Text(l10n.settingsDayPlan),
            subtitle: Text(l10n.settingsDayPlanBody),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.dayPlan),
          ),
          ListTile(
            key: const Key('settings-guide'),
            leading: const Icon(Icons.school_rounded),
            title: Text(l10n.settingsGuide),
            subtitle: Text(l10n.settingsGuideBody),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.guide),
          ),
          ListTile(
            key: const Key('settings-heat-symptoms'),
            leading: const Icon(Icons.medical_information_rounded),
            title: Text(l10n.settingsSymptoms),
            subtitle: Text(l10n.settingsSymptomsBody),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.heatSymptoms),
          ),
          SwitchListTile(
            key: const Key('settings-senior'),
            secondary: const Icon(Icons.text_increase_rounded),
            title: Text(l10n.settingsSenior),
            value: profile.seniorMode,
            onChanged: (v) => _setSenior(context, ref, v),
          ),
          SwitchListTile(
            key: const Key('settings-dog'),
            secondary: const Icon(Icons.pets_rounded),
            title: Text(l10n.settingsDog),
            subtitle: Text(l10n.settingsDogBody),
            value: ref.watch(walksWithDogProvider),
            onChanged: (v) => ref.read(walksWithDogProvider.notifier).set(v),
          ),
          SwitchListTile(
            key: const Key('settings-push'),
            secondary: const Icon(Icons.notifications_rounded),
            title: Text(l10n.settingsNotifications),
            subtitle: Text(l10n.settingsNotificationsBody),
            value: consents?.push ?? false,
            onChanged: consents == null
                ? null
                : (v) => _setPush(context, ref, v),
          ),
          const Divider(),
          ListTile(
            key: const Key('settings-consents'),
            leading: const Icon(Icons.verified_user_rounded),
            title: Text(l10n.settingsConsents),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.consentsSettings),
          ),
          ListTile(
            leading: const Icon(Icons.policy_rounded),
            title: Text(l10n.settingsPrivacy),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.privacy),
          ),
          ListTile(
            key: const Key('settings-about'),
            leading: const Icon(Icons.info_rounded),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.about),
          ),
          const Divider(),
          ListTile(
            key: const Key('settings-sign-out'),
            leading: const Icon(Icons.logout_rounded),
            title: Text(l10n.settingsSignOut),
            onTap: () => _guard(context, () => _signOut(ref)),
          ),
          ListTile(
            key: const Key('settings-delete'),
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
            ),
            title: Text(
              l10n.settingsDelete,
              style: const TextStyle(color: AppColors.error),
            ),
            onTap: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Confirmation with the password; deletes the documents, then the user.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .deleteAccount(
            password: _password.text,
            deleteData: ref.read(accountRepositoryProvider).deleteUserData,
          );
      await ref.read(offlineCacheProvider).clearPersonal();
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.failure == AuthFailure.wrongCredentials
            ? l10n.settingsDeleteWrongPassword
            : l10n.settingsDeleteError;
      });
    } catch (e) {
      debugPrint('Account removal failed: $e');
      setState(() {
        _busy = false;
        _error = l10n.settingsDeleteError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsDeleteTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsDeleteBody),
            const SizedBox(height: AppSizes.s16),
            TextField(
              key: const Key('delete-password'),
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settingsDeletePassword,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.settingsDeleteCancel),
        ),
        TextButton(
          key: const Key('delete-confirm'),
          onPressed: _busy ? null : _confirm,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.settingsDeleteConfirm),
        ),
      ],
    );
  }
}
