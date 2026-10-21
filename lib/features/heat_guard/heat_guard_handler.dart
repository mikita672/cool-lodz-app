import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/routes.dart';
import 'data/heat_guard_platform.dart';
import 'data/heat_guard_settings.dart';
import 'data/heat_guard_sync.dart';
import 'heat_check_screen.dart';

/// Keeps «Alarm upałowy» running with the current settings and opens the
/// check screen when the service asks (full-screen alarm, or a check that
/// started while the app was open).
class HeatGuardHandler extends ConsumerStatefulWidget {
  const HeatGuardHandler({super.key, required this.child});

  final Widget child;

  /// While the app is open and the alarm is on, the service is asked this
  /// often whether a check started.
  static const poll = Duration(seconds: 5);

  @override
  ConsumerState<HeatGuardHandler> createState() => _HeatGuardHandlerState();
}

class _HeatGuardHandlerState extends ConsumerState<HeatGuardHandler>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _checks;
  Timer? _poll;
  bool _open = false;

  HeatGuardPlatform get _platform => ref.read(heatGuardPlatformProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checks = _platform.checks.listen((_) => _show());
    _pending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checks?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pending();
      _schedulePoll();
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _pending() async {
    if (await _platform.pendingCheck()) unawaited(_show());
  }

  void _schedulePoll() {
    final enabled = ref.read(heatGuardSettingsProvider).enabled;
    if (!enabled) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(HeatGuardHandler.poll, (_) async {
      final status = await _platform.status();
      if (status.phase != HeatGuardPhase.idle) unawaited(_show());
    });
  }

  Future<void> _show() async {
    if (_open || HeatCheckScreen.isOpen || !mounted) return;
    _open = true;
    try {
      await ref.read(routerProvider).push<void>(Routes.heatCheck);
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(heatGuardSyncProvider);
    ref.listen(heatGuardSettingsProvider, (_, _) => _schedulePoll());
    return widget.child;
  }
}
