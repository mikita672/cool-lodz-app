import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../core/location/location_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import 'data/heat_guard_platform.dart';
import 'data/heat_guard_settings.dart';
import 'data/heat_guard_sync.dart';

/// «Alarm upałowy» settings (Profil): on/off, only in heat, how long to
/// wait, the people who get the SMS, home, permissions and a test.
class HeatGuardScreen extends ConsumerStatefulWidget {
  const HeatGuardScreen({super.key});

  @override
  ConsumerState<HeatGuardScreen> createState() => _HeatGuardScreenState();
}

class _HeatGuardScreenState extends ConsumerState<HeatGuardScreen>
    with WidgetsBindingObserver {
  HeatGuardPermissions? _permissions;
  HeatGuardStatus _status = const HeatGuardStatus();
  Timer? _timer;

  HeatGuardPlatform get _platform => ref.read(heatGuardPlatformProvider);
  HeatGuardSettings get _settings => ref.read(heatGuardSettingsProvider);

  Future<void> _save(HeatGuardSettings s) =>
      ref.read(heatGuardSettingsProvider.notifier).update(s);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final permissions = await _platform.permissions();
    final status = await _platform.status();
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _status = status;
    });
  }

  /// Asks for what the alarm needs, in order; true when it can watch.
  Future<bool> _askPermissions() async {
    for (final kind in ['location', 'backgroundLocation', 'notifications']) {
      if (!await _platform.request(kind)) break;
    }
    if (_settings.contacts.isNotEmpty) await _platform.request('sms');
    final p = await _platform.permissions();
    if (mounted) setState(() => _permissions = p);
    return p.canWatch;
  }

  Future<void> _enable(bool on) async {
    final l10n = AppLocalizations.of(context);
    if (!on) {
      await _save(_settings.copyWith(enabled: false));
      return;
    }
    if (!await _askPermissions()) {
      if (mounted) {
        showAppToast(
          context,
          l10n.heatGuardNeedPermissions,
          kind: ToastKind.warning,
        );
      }
      return;
    }
    var s = _settings.copyWith(enabled: true);
    // Senior: ask sooner, unless the user already chose a time.
    if (ref.read(seniorModeProvider) &&
        s.waitMinutes == HeatGuardSettings.defaultWait) {
      s = s.copyWith(waitMinutes: HeatGuardSettings.seniorWait);
    }
    await _save(s);
    unawaited(_refresh());
  }

  Future<void> _addContact() async {
    final contact = await showDialog<TrustedContact>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (contact == null) return;
    await _save(_settings.copyWith(contacts: [..._settings.contacts, contact]));
    await _platform.request('sms');
    unawaited(_refresh());
  }

  Future<void> _setHome() async {
    final l10n = AppLocalizations.of(context);
    try {
      final here = await ref.read(locationServiceProvider).current();
      await _save(_settings.copyWith(home: () => here));
    } catch (_) {
      if (mounted) {
        showAppToast(context, l10n.heatGuardHomeError, kind: ToastKind.error);
      }
    }
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    // The service runs with location (Android 14) and shows a notification.
    for (final kind in ['location', 'notifications']) {
      if (!await _platform.request(kind)) {
        if (mounted) {
          showAppToast(
            context,
            l10n.heatGuardNeedPermissions,
            kind: ToastKind.warning,
          );
        }
        return;
      }
    }
    // Not on yet: the service needs the texts for the test.
    if (!_settings.enabled) {
      await _platform.configure(
        heatGuardConfigJson(_settings, texts: heatGuardTexts(l10n)),
      );
    }
    await _platform.test();
    if (mounted) await context.push(Routes.heatCheck, extra: true);
  }

  String _statusText(AppLocalizations l10n, HeatGuardSettings s) {
    if (!s.enabled) return l10n.heatGuardStatusOff;
    if (!s.heatOnly) return l10n.heatGuardStatusAlways;
    final t = _status.temperature?.round().toString() ?? '–';
    return _status.hot
        ? l10n.heatGuardStatusWatching(t)
        : l10n.heatGuardStatusWaiting(t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(heatGuardSettingsProvider);
    final p = _permissions;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.heatGuardTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.s32),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Text(l10n.heatGuardIntro, style: theme.textTheme.bodyMedium),
          ),
          SwitchListTile(
            key: const Key('heat-guard-enable'),
            secondary: const Icon(Icons.health_and_safety_rounded),
            title: Text(l10n.heatGuardEnable),
            subtitle: Text(_statusText(l10n, s)),
            value: s.enabled,
            onChanged: _enable,
          ),
          SwitchListTile(
            key: const Key('heat-guard-heat-only'),
            secondary: const Icon(Icons.thermostat_rounded),
            title: Text(l10n.heatGuardHeatOnly),
            subtitle: Text(l10n.heatGuardHeatOnlyHint),
            value: s.heatOnly,
            onChanged: (v) => _save(s.copyWith(heatOnly: v)),
          ),
          ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: Text(l10n.heatGuardWait(s.waitMinutes)),
            subtitle: Slider(
              key: const Key('heat-guard-wait'),
              value: s.waitMinutes.toDouble(),
              min: HeatGuardSettings.minWait.toDouble(),
              max: HeatGuardSettings.maxWait.toDouble(),
              divisions: HeatGuardSettings.maxWait - HeatGuardSettings.minWait,
              label: '${s.waitMinutes} min',
              onChanged: (v) => _save(s.copyWith(waitMinutes: v.round())),
            ),
          ),
          SwitchListTile(
            key: const Key('heat-guard-fall'),
            secondary: const Icon(Icons.personal_injury_rounded),
            title: Text(l10n.heatGuardFall),
            subtitle: Text(l10n.heatGuardFallHint),
            value: s.fallDetection,
            onChanged: (v) => _save(s.copyWith(fallDetection: v)),
          ),
          const Divider(),
          _Header(l10n.dailyHeader),
          SwitchListTile(
            key: const Key('daily-imgw'),
            secondary: const Icon(Icons.warning_amber_rounded),
            title: Text(l10n.dailyImgw),
            subtitle: Text(l10n.dailyImgwHint),
            value: s.imgwAuto,
            onChanged: (v) async {
              if (v) await _platform.request('notifications');
              await _save(s.copyWith(imgwAuto: v));
            },
          ),
          SwitchListTile(
            key: const Key('daily-morning'),
            secondary: const Icon(Icons.wb_twilight_rounded),
            title: Text(l10n.dailyMorning),
            subtitle: Text(l10n.dailyMorningHint),
            value: s.morning,
            onChanged: (v) async {
              if (v) await _platform.request('notifications');
              await _save(s.copyWith(morning: v));
            },
          ),
          SwitchListTile(
            key: const Key('daily-checkin'),
            secondary: const Icon(Icons.how_to_reg_rounded),
            title: Text(l10n.dailyCheckin),
            subtitle: Text(
              s.contacts.isEmpty
                  ? l10n.dailyCheckinNoContacts
                  : l10n.dailyCheckinHint(
                      '${s.checkinHour}:00',
                      '${s.deadlineHour}:00',
                    ),
            ),
            value: s.checkin,
            onChanged: (v) async {
              if (v) {
                await _platform.request('notifications');
                await _platform.request('sms');
              }
              await _save(s.copyWith(checkin: v));
              unawaited(_refresh());
            },
          ),
          if (s.checkin)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
              ),
              child: Wrap(
                spacing: AppSizes.s12,
                runSpacing: AppSizes.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.dailyCheckinAsk),
                  DropdownButton<int>(
                    key: const Key('daily-checkin-hour'),
                    value: s.checkinHour,
                    items: [
                      for (final h in HeatGuardSettings.checkinHours)
                        DropdownMenuItem(value: h, child: Text('$h:00')),
                    ],
                    onChanged: (h) {
                      if (h == null) return;
                      _save(
                        s.copyWith(
                          checkinHour: h,
                          deadlineHour:
                              s.deadlineHour > h && s.deadlineHour <= h + 4
                              ? s.deadlineHour
                              : h + 2,
                        ),
                      );
                    },
                  ),
                  Text(l10n.dailyCheckinDeadline),
                  DropdownButton<int>(
                    key: const Key('daily-deadline-hour'),
                    value: s.deadlineHour,
                    items: [
                      for (
                        var h = s.checkinHour + 1;
                        h <= s.checkinHour + 4;
                        h++
                      )
                        DropdownMenuItem(value: h, child: Text('$h:00')),
                    ],
                    onChanged: (h) {
                      if (h != null) _save(s.copyWith(deadlineHour: h));
                    },
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.s4,
              AppSizes.screenPadding,
              0,
            ),
            child: Text(l10n.dailyWidgetHint, style: theme.textTheme.bodySmall),
          ),
          const Divider(),
          _Header(l10n.heatGuardContacts),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
            ),
            child: Text(
              s.contacts.isEmpty
                  ? l10n.heatGuardContactsEmpty
                  : l10n.heatGuardContactsHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final c in s.contacts)
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(c.name.isEmpty ? c.phone : c.name),
              subtitle: c.name.isEmpty ? null : Text(c.phone),
              trailing: IconButton(
                tooltip: l10n.heatGuardContactRemove(
                  c.name.isEmpty ? c.phone : c.name,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () =>
                    _save(s.copyWith(contacts: [...s.contacts]..remove(c))),
              ),
            ),
          if (s.contacts.length < HeatGuardSettings.maxContacts)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.s8),
                child: TextButton.icon(
                  key: const Key('heat-guard-add-contact'),
                  onPressed: _addContact,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(l10n.heatGuardAddContact),
                ),
              ),
            ),
          const Divider(),
          ListTile(
            key: const Key('heat-guard-home'),
            leading: const Icon(Icons.home_rounded),
            title: Text(l10n.heatGuardHome),
            subtitle: Text(
              s.home == null ? l10n.heatGuardHomeNone : l10n.heatGuardHomeSet,
            ),
            trailing: s.home == null
                ? TextButton(
                    onPressed: _setHome,
                    child: Text(l10n.heatGuardHomeHere),
                  )
                : IconButton(
                    tooltip: l10n.heatGuardHomeClear,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _save(s.copyWith(home: () => null)),
                  ),
          ),
          if (p != null) ...[
            const Divider(),
            _Header(l10n.heatGuardPermissions),
            _Permission(
              label: l10n.heatGuardPermLocation,
              ok: p.location && p.backgroundLocation,
              onFix: () async {
                await _platform.request('location');
                await _platform.request('backgroundLocation');
                await _refresh();
              },
            ),
            _Permission(
              label: l10n.heatGuardPermNotifications,
              ok: p.notifications,
              onFix: () async {
                if (!await _platform.request('notifications')) {
                  await _platform.openSettings('app');
                }
                await _refresh();
              },
            ),
            _Permission(
              label: p.telephony
                  ? l10n.heatGuardPermSms
                  : l10n.heatGuardPermNoSms,
              ok: p.sms || !p.telephony,
              onFix: p.telephony
                  ? () async {
                      await _platform.request('sms');
                      await _refresh();
                    }
                  : null,
            ),
            _Permission(
              label: l10n.heatGuardPermFullScreen,
              ok: p.fullScreen,
              onFix: () => _platform.openSettings('fullScreen'),
            ),
            _Permission(
              label: l10n.heatGuardPermBattery,
              ok: p.battery,
              onFix: () => _platform.openSettings('battery'),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const Key('heat-guard-test'),
                  onPressed: _test,
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(l10n.heatGuardTest),
                ),
                const SizedBox(height: AppSizes.s4),
                Text(l10n.heatGuardTestHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSizes.s16),
                Text(
                  l10n.heatGuardDisclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      AppSizes.s8,
      AppSizes.screenPadding,
      AppSizes.s4,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _Permission extends StatelessWidget {
  const _Permission({required this.label, required this.ok, this.onFix});

  final String label;
  final bool ok;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.error_rounded,
        color: ok ? AppColors.success : AppColors.heat2,
      ),
      title: Text(label),
      trailing: ok || onFix == null
          ? null
          : TextButton(onPressed: onFix, child: Text(l10n.heatGuardFix)),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _bad = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final phone = normalizePhone(_phone.text);
    if (phone == null) {
      setState(() => _bad = true);
      return;
    }
    Navigator.of(
      context,
    ).pop(TrustedContact(name: _name.text.trim(), phone: phone));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.heatGuardAddContact),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('heat-guard-contact-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.heatGuardContactName),
          ),
          const SizedBox(height: AppSizes.s8),
          TextField(
            key: const Key('heat-guard-contact-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.heatGuardContactPhone,
              errorText: _bad ? l10n.heatGuardContactPhoneError : null,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.heatGuardCancel),
        ),
        FilledButton(
          key: const Key('heat-guard-contact-save'),
          onPressed: _save,
          child: Text(l10n.heatGuardSave),
        ),
      ],
    );
  }
}
