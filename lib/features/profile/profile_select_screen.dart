import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../core/models/route_request.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../auth/start_flow.dart';
import 'data/comfort_profile.dart';
import 'data/comfort_profile_provider.dart';

/// S04 Wybór profilu. Shown once after S03 (start flow) and from
/// Profil → «Mój profil komfortu». Changes are a draft until «Zapisz»/«Dalej»;
/// the Senior switch previews the bigger text on this screen right away.
class ProfileSelectScreen extends ConsumerStatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  ConsumerState<ProfileSelectScreen> createState() =>
      _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends ConsumerState<ProfileSelectScreen> {
  late ComfortProfile _draft = ref.read(comfortProfileProvider);
  bool _adjustOpen = false;
  bool _saving = false;

  void _select(ProfileId id) {
    if (id == _draft.id) return;
    setState(() {
      _draft = ComfortProfile.preset(id);
      _adjustOpen = false;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final fromProfile = router.canPop();
    setState(() => _saving = true);
    try {
      await ref.read(comfortProfileProvider.notifier).save(_draft);
    } catch (e) {
      debugPrint('Saving the comfort profile failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, l10n.profileSaveError, kind: ToastKind.error);
      return;
    }
    if (!mounted) return;
    if (fromProfile) {
      showAppToast(context, l10n.profileSaved, kind: ToastKind.success);
      router.pop();
    } else {
      // Start flow: S04 done, the redirect lets the map through now.
      ref.read(startFlowProvider.notifier).markProfileChosen();
      router.go(Routes.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fromProfile = GoRouter.maybeOf(context)?.canPop() ?? false;
    final appSenior = ref.watch(seniorModeProvider);

    final content = Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        automaticallyImplyLeading: fromProfile,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  0,
                  AppSizes.screenPadding,
                  AppSizes.screenPadding,
                ),
                children: [
                  Text(
                    l10n.profileIntro,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s16),
                  for (final id in ProfileId.values) ...[
                    _ProfileCard(
                      key: Key('profile-${id.name}'),
                      id: id,
                      selected: _draft.id == id,
                      onTap: _saving ? null : () => _select(id),
                      adjust: _draft.id == id
                          ? _AdjustSection(
                              open: _adjustOpen,
                              weights: _draft.weights,
                              onToggle: () =>
                                  setState(() => _adjustOpen = !_adjustOpen),
                              onChanged: _saving
                                  ? null
                                  : (kind, value) => setState(
                                      () => _draft = _draft.copyWith(
                                        weights: _draft.weights.withValue(
                                          kind,
                                          value,
                                        ),
                                      ),
                                    ),
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSizes.s12),
                  ],
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      key: const Key('profile-senior-mode'),
                      value: _draft.seniorMode,
                      onChanged: _saving
                          ? null
                          : (v) => setState(
                              () => _draft = _draft.copyWith(seniorMode: v),
                            ),
                      secondary: const _IconCircle(Icons.text_increase_rounded),
                      title: Text(
                        l10n.profileSeniorModeTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        l10n.profileSeniorModeBody,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s24),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.profileSoonTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s12),
                  for (final (icon, name, body) in _soonProfiles(l10n)) ...[
                    _SoonCard(icon: icon, name: name, body: body),
                    const SizedBox(height: AppSizes.s8),
                  ],
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
              child: AppButton(
                key: const Key('profile-save'),
                label: fromProfile ? l10n.profileSave : l10n.profileContinue,
                onPressed: _save,
                loading: _saving,
                expand: true,
              ),
            ),
          ],
        ),
      ),
    );

    // Preview the draft's Senior setting on this screen only. Always the
    // same wrappers, so the list keeps its scroll position on toggle.
    final media = MediaQuery.of(context);
    final base = media.textScaler is SeniorTextScaler
        ? (media.textScaler as SeniorTextScaler).base
        : media.textScaler;
    final preview = _draft.seniorMode != appSenior;
    return Theme(
      data: preview
          ? AppTheme.light(senior: _draft.seniorMode)
          : Theme.of(context),
      child: MediaQuery(
        data: preview
            ? media.copyWith(
                textScaler: _draft.seniorMode ? SeniorTextScaler(base) : base,
              )
            : media,
        child: content,
      ),
    );
  }

  static List<(IconData, String, String)> _soonProfiles(
    AppLocalizations l10n,
  ) => [
    (Icons.pets_rounded, l10n.profileDogName, l10n.profileDogBody),
    (
      Icons.child_friendly_rounded,
      l10n.profileStrollerName,
      l10n.profileStrollerBody,
    ),
    (Icons.work_rounded, l10n.profileCommuteName, l10n.profileCommuteBody),
    (
      Icons.directions_run_rounded,
      l10n.profileActiveName,
      l10n.profileActiveBody,
    ),
    (Icons.air_rounded, l10n.profileSensitiveName, l10n.profileSensitiveBody),
  ];
}

/// Name, one-line description and icon of a working profile.
(IconData, String, String) profileLabels(ProfileId id, AppLocalizations l10n) =>
    switch (id) {
      ProfileId.senior => (
        Icons.elderly_rounded,
        l10n.profileSeniorName,
        l10n.profileSeniorBody,
      ),
      ProfileId.tourist => (
        Icons.photo_camera_rounded,
        l10n.profileTouristName,
        l10n.profileTouristBody,
      ),
      ProfileId.standard => (
        Icons.directions_walk_rounded,
        l10n.profileStandardName,
        l10n.profileStandardBody,
      ),
    };

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    super.key,
    required this.id,
    required this.selected,
    required this.onTap,
    this.adjust,
  });

  final ProfileId id;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? adjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, name, body) = profileLabels(id, l10n);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? AppColors.primaryContainer : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            selected: selected,
            inMutuallyExclusiveGroup: true,
            button: true,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s16),
                child: Row(
                  children: [
                    _IconCircle(icon, filled: selected),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSizes.s4),
                          Text(body, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? AppColors.primary : AppColors.muted,
                      semanticLabel: selected ? l10n.profileSelected : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ?adjust,
        ],
      ),
    );
  }
}

/// «Dostosuj» under the selected card: 4 weights from 0 to 100.
class _AdjustSection extends StatelessWidget {
  const _AdjustSection({
    required this.open,
    required this.weights,
    required this.onToggle,
    required this.onChanged,
  });

  final bool open;
  final ProfileWeights weights;
  final VoidCallback onToggle;
  final void Function(WeightKind kind, int value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        TextButton.icon(
          key: const Key('profile-adjust'),
          onPressed: onToggle,
          icon: Icon(open ? Icons.expand_less_rounded : Icons.tune_rounded),
          label: Text(l10n.profileAdjust),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.s16,
              0,
              AppSizes.s16,
              AppSizes.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profileAdjustHint, style: theme.textTheme.bodySmall),
                for (final kind in WeightKind.values)
                  _WeightSlider(
                    kind: kind,
                    value: weights.valueOf(kind),
                    onChanged: onChanged == null
                        ? null
                        : (v) => onChanged!(kind, v),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.kind,
    required this.value,
    required this.onChanged,
  });

  final WeightKind kind;
  final int value;
  final ValueChanged<int>? onChanged;

  static String label(WeightKind kind, AppLocalizations l10n) => switch (kind) {
    WeightKind.shade => l10n.profileWeightShade,
    WeightKind.time => l10n.profileWeightTime,
    WeightKind.quiet => l10n.profileWeightQuiet,
    WeightKind.air => l10n.profileWeightAir,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = label(kind, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSizes.s12),
        Row(
          children: [
            Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
            Text('$value', style: theme.textTheme.titleSmall),
          ],
        ),
        Slider(
          key: Key('profile-weight-${kind.name}'),
          value: value.toDouble(),
          max: 100,
          divisions: 10,
          label: '$value',
          semanticFormatterCallback: (v) => '$name ${v.round()}',
          onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
        ),
      ],
    );
  }
}

class _SoonCard extends StatelessWidget {
  const _SoonCard({required this.icon, required this.name, required this.body});

  final IconData icon;
  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return Semantics(
      enabled: false,
      child: Card(
        color: AppColors.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    Text(body, style: muted),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusChip),
                ),
                child: Text(
                  l10n.profileSoon,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle(this.icon, {this.filled = false});

  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: filled ? AppColors.primary : AppColors.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      color: filled ? AppColors.onPrimary : AppColors.primary,
      size: 24,
    ),
  );
}
