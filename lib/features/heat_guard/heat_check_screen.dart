import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'data/heat_guard_platform.dart';

/// Opens `tel:112` (injected in tests).
final dialEmergencyProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await launchUrl(Uri.parse('tel:112'));
  },
);

/// «Wszystko w porządku?» over the lock screen. When the alarm sounds it
/// turns into a screen for passers-by: what to do in heatstroke and a big
/// «Zadzwoń 112».
class HeatCheckScreen extends ConsumerStatefulWidget {
  const HeatCheckScreen({super.key, this.test = false});

  /// Opened by «Przetestuj alarm».
  final bool test;

  /// How often the screen asks the service where the check is.
  static const poll = Duration(seconds: 1);

  /// One check screen at a time (the test and the handler both open it).
  static bool isOpen = false;

  @override
  ConsumerState<HeatCheckScreen> createState() => _HeatCheckScreenState();
}

class _HeatCheckScreenState extends ConsumerState<HeatCheckScreen> {
  HeatGuardStatus _status = const HeatGuardStatus(phase: HeatGuardPhase.ask);
  Timer? _timer;
  bool _seenActive = false;
  bool _helpAsked = false;

  HeatGuardPlatform get _platform => ref.read(heatGuardPlatformProvider);

  @override
  void initState() {
    super.initState();
    HeatCheckScreen.isOpen = true;
    _refresh();
    _timer = Timer.periodic(HeatCheckScreen.poll, (_) => _refresh());
  }

  @override
  void dispose() {
    HeatCheckScreen.isOpen = false;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await _platform.status();
    if (!mounted) return;
    if (status.phase != HeatGuardPhase.idle) _seenActive = true;
    // Answered from the notification, or the alarm ran out.
    if (status.phase == HeatGuardPhase.idle && _seenActive) {
      _close();
      return;
    }
    setState(() => _status = status);
  }

  Future<void> _ok() async {
    await _platform.answer(needHelp: false);
    _close();
  }

  Future<void> _help() async {
    setState(() => _helpAsked = true);
    await _platform.answer(needHelp: true);
  }

  void _close() {
    _timer?.cancel();
    _platform.checkClosed();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final alarm =
        _helpAsked ||
        _status.phase == HeatGuardPhase.half ||
        _status.phase == HeatGuardPhase.full;
    return PopScope(
      canPop: false,
      child: Scaffold(
        // Dark orange: white text stays readable (contrast ≥ 4.5:1).
        backgroundColor: alarm ? AppColors.heat3 : const Color(0xFFC2410C),
        body: SafeArea(
          child: alarm
              ? _Alarm(
                  status: _status,
                  test: widget.test,
                  onStop: _ok,
                  onCall: () => ref.read(dialEmergencyProvider)(),
                )
              : _Question(test: widget.test, onOk: _ok, onHelp: _help),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.test,
    required this.onOk,
    required this.onHelp,
  });

  final bool test;
  final VoidCallback onOk;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const white = Colors.white;
    return ListView(
      key: const Key('heat-check-question'),
      padding: const EdgeInsets.all(AppSizes.s24),
      children: [
        const SizedBox(height: AppSizes.s32),
        const Icon(Icons.wb_sunny_rounded, size: 72, color: white),
        const SizedBox(height: AppSizes.s16),
        Text(
          l10n.heatCheckQuestion,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSizes.s12),
        Text(
          l10n.heatCheckBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: white),
        ),
        if (test) ...[
          const SizedBox(height: AppSizes.s8),
          Text(
            l10n.heatCheckTest,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: white),
          ),
        ],
        const SizedBox(height: AppSizes.s32),
        FilledButton.icon(
          key: const Key('heat-check-ok'),
          onPressed: onOk,
          icon: const Icon(Icons.check_circle_rounded),
          label: Text(l10n.heatCheckOk),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: white,
            minimumSize: const Size.fromHeight(72),
            textStyle: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSizes.s16),
        OutlinedButton.icon(
          key: const Key('heat-check-help'),
          onPressed: onHelp,
          icon: const Icon(Icons.sos_rounded),
          label: Text(l10n.heatCheckHelp),
          style: OutlinedButton.styleFrom(
            foregroundColor: white,
            side: const BorderSide(color: white, width: 2),
            minimumSize: const Size.fromHeight(60),
            textStyle: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _Alarm extends StatelessWidget {
  const _Alarm({
    required this.status,
    required this.test,
    required this.onStop,
    required this.onCall,
  });

  final HeatGuardStatus status;
  final bool test;
  final VoidCallback onStop;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const white = Colors.white;
    final steps = [
      l10n.heatCheckAid1,
      l10n.heatCheckAid2,
      l10n.heatCheckAid3,
      l10n.heatCheckAid4,
      l10n.heatCheckAid5,
    ];
    return ListView(
      key: const Key('heat-check-alarm'),
      padding: const EdgeInsets.all(AppSizes.s24),
      children: [
        const Icon(Icons.warning_amber_rounded, size: 64, color: white),
        const SizedBox(height: AppSizes.s8),
        Text(
          l10n.heatCheckAlarmTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (test)
          Text(
            l10n.heatCheckTest,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: white),
          ),
        const SizedBox(height: AppSizes.s16),
        FilledButton.icon(
          key: const Key('heat-check-call'),
          onPressed: onCall,
          icon: const Icon(Icons.call_rounded),
          label: Text(l10n.heatCheckCall112),
          style: FilledButton.styleFrom(
            backgroundColor: white,
            foregroundColor: AppColors.heat3,
            minimumSize: const Size.fromHeight(72),
            textStyle: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.s16),
        Text(
          l10n.heatCheckAlarmLead,
          style: theme.textTheme.titleMedium?.copyWith(color: white),
        ),
        const SizedBox(height: AppSizes.s8),
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}.',
                  style: theme.textTheme.titleMedium?.copyWith(color: white),
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Text(
                    step,
                    style: theme.textTheme.titleMedium?.copyWith(color: white),
                  ),
                ),
              ],
            ),
          ),
        if (status.smsSentTo.isNotEmpty) ...[
          const SizedBox(height: AppSizes.s8),
          Row(
            children: [
              const Icon(Icons.sms_rounded, color: white),
              const SizedBox(width: AppSizes.s8),
              Expanded(
                child: Text(
                  l10n.heatCheckSmsSent(status.smsSentTo.join(', ')),
                  key: const Key('heat-check-sms'),
                  style: theme.textTheme.bodyLarge?.copyWith(color: white),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSizes.s24),
        OutlinedButton(
          key: const Key('heat-check-stop'),
          onPressed: onStop,
          style: OutlinedButton.styleFrom(
            foregroundColor: white,
            side: const BorderSide(color: white, width: 2),
            minimumSize: const Size.fromHeight(56),
          ),
          child: Text(l10n.heatCheckStop),
        ),
      ],
    );
  }
}
