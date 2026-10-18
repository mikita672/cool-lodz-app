import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only (spec: "только портретная ориентация").
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  LicenseRegistry.addLicense(_interLicense);
  runApp(const ProviderScope(child: CoolLodzApp()));
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
