import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import 'data/push_service.dart';
import 'data/push_token_sync.dart';

/// Messenger of the whole app, for messages shown outside a screen.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>(
  debugLabel: 'rootMessenger',
);

/// Push handling for the whole app (APP-18):
/// - keeps `users/{uid}.fcmToken` up to date while push is allowed (S03);
/// - a tapped heat notification opens S14;
/// - a push while the app is open shows a banner with «Zobacz».
class PushHandler extends ConsumerStatefulWidget {
  const PushHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushHandler> createState() => _PushHandlerState();
}

class _PushHandlerState extends ConsumerState<PushHandler> {
  final _subs = <StreamSubscription<Object?>>[];
  String? _uid;

  /// A tapped notification that arrived before the start flow finished
  /// (the start-flow redirect would swallow it); opened once it is done.
  bool _pendingAlert = false;
  Listenable? _refresh;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);
    _subs
      ..add(push.opened.listen((_) => _openAlert()))
      ..add(push.foreground.listen(_showBanner))
      ..add(push.tokenRefresh.listen((t) => _saveToken(token: t)))
      ..add(
        ref.read(authRepositoryProvider).userChanges().listen((user) {
          _uid = user?.uid;
          if (user != null) unawaited(_saveToken());
        }),
      );
    unawaited(
      push.initial().then((m) {
        if (m != null) _openAlert();
      }),
    );
  }

  @override
  void dispose() {
    _refresh?.removeListener(_flushPending);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _openAlert() {
    if (!mounted) return;
    if (!ref.read(routerReadyProvider)()) {
      _pendingAlert = true;
      _refresh ??= ref.read(routerRefreshProvider)?..addListener(_flushPending);
      return;
    }
    _pendingAlert = false;
    unawaited(ref.read(routerProvider).push(Routes.alert));
  }

  void _flushPending() {
    if (!_pendingAlert || !mounted || !ref.read(routerReadyProvider)()) return;
    _pendingAlert = false;
    // After the router's own redirect for this change (start → map).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(routerProvider).go(Routes.alert);
    });
  }

  void _showBanner(PushMessage m) {
    final messenger = rootMessengerKey.currentState;
    final context = rootMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    final l10n = AppLocalizations.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(m.body ?? m.title ?? l10n.alertPushFallback),
          action: SnackBarAction(label: l10n.alertSee, onPressed: _openAlert),
        ),
      );
  }

  /// Saves the token only when the user allowed push in S03.
  Future<void> _saveToken({String? token}) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(pushTokenSyncProvider).sync(uid, token: token);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
