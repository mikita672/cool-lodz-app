import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/messaging_background.dart';
import 'features/auth/start_flow.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only (spec: "только портретная ориентация").
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  LicenseRegistry.addLicense(_interLicense);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Debug builds use the Emulator Suite, see docs/dev.md#firebase.
  await FirebaseBootstrap.init();
  runApp(
    ProviderScope(
      // Onboarding → login → consents redirects, see start_flow.dart.
      overrides: startFlowRouterOverrides,
      child: const CoolLodzApp(),
    ),
  );
}

/// The bundled Inter font is under the SIL Open Font License 1.1.
Stream<LicenseEntry> _interLicense() async* {
  yield const LicenseEntryWithLineBreaks(
    ['Inter'],
    'Copyright 2016 The Inter Project Authors (https://github.com/rsms/inter)\n\n'
    'This Font Software is licensed under the SIL Open Font License, '
    'Version 1.1. This license is available with a FAQ at: '
    'https://openfontlicense.org',
  );
}
