import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/user_profile_repository.dart';
import 'data/push_service.dart';

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
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _openAlert() {
    if (!mounted) return;
    unawaited(ref.read(routerProvider).push(Routes.alert));
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
    final profiles = ref.read(userProfileRepositoryProvider);
    try {
      final consents = await profiles.loadConsents(uid);
      if (consents == null || !consents.push) return;
      final value = token ?? await ref.read(pushServiceProvider).token();
      if (value != null) await profiles.saveFcmToken(uid, value);
    } catch (e) {
      debugPrint('Saving the FCM token failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
