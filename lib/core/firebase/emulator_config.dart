import 'package:flutter/foundation.dart';

/// Where the app finds the Firebase Emulator Suite (ports match firebase.json).
@immutable
class FirebaseEmulatorConfig {
  const FirebaseEmulatorConfig({
    required this.enabled,
    this.host = defaultHost,
    this.authPort = defaultAuthPort,
    this.firestorePort = defaultFirestorePort,
  });

  /// `localhost` works on the Android emulator: FlutterFire maps it to
  /// 10.0.2.2 (the host machine) automatically.
  static const defaultHost = 'localhost';
  static const defaultAuthPort = 9099;
  static const defaultFirestorePort = 8080;

  /// Off: the app talks to the real `coollodz` project.
  static const disabled = FirebaseEmulatorConfig(enabled: false);

  final bool enabled;
  final String host;
  final int authPort;
  final int firestorePort;

  /// Reads `--dart-define=USE_FIREBASE_EMULATORS` and
  /// `--dart-define=FIREBASE_EMULATOR_HOST` for the current build mode.
  factory FirebaseEmulatorConfig.fromEnvironment() => resolve(
    isDebugBuild: kDebugMode,
    useEmulatorsDefine: const String.fromEnvironment('USE_FIREBASE_EMULATORS'),
    hostDefine: const String.fromEnvironment('FIREBASE_EMULATOR_HOST'),
  );

  /// Pure decision logic.
  ///
  /// Only debug builds can use the emulators (cleartext HTTP is allowed only
  /// in the debug manifest), so profile and release always use the real
  /// project. In debug the default is on; `USE_FIREBASE_EMULATORS=false`
  /// switches to the real project. An empty define means "not set".
  static FirebaseEmulatorConfig resolve({
    required bool isDebugBuild,
    String useEmulatorsDefine = '',
    String hostDefine = '',
  }) {
    // Release and profile builds never use the emulators, whatever the define.
    if (!isDebugBuild) return disabled;
    final requested = switch (useEmulatorsDefine.trim().toLowerCase()) {
      '' || 'true' => true,
      'false' => false,
      _ => throw ArgumentError.value(
        useEmulatorsDefine,
        'USE_FIREBASE_EMULATORS',
        'must be true or false',
      ),
    };
    if (!requested) return disabled;
    final host = hostDefine.trim();
    return FirebaseEmulatorConfig(
      enabled: true,
      host: host.isEmpty ? defaultHost : host,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FirebaseEmulatorConfig &&
      other.enabled == enabled &&
      other.host == host &&
      other.authPort == authPort &&
      other.firestorePort == firestorePort;

  @override
  int get hashCode => Object.hash(enabled, host, authPort, firestorePort);

  @override
  String toString() => enabled
      ? 'FirebaseEmulatorConfig($host, auth: $authPort, '
            'firestore: $firestorePort)'
      : 'FirebaseEmulatorConfig(disabled)';
}
