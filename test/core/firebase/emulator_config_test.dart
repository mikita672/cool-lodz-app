import 'package:cool_lodz/core/firebase/emulator_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseEmulatorConfig.resolve', () {
    test('debug build without a define uses localhost emulators', () {
      final config = FirebaseEmulatorConfig.resolve(isDebugBuild: true);
      expect(config.enabled, isTrue);
      expect(config.host, 'localhost');
      expect(config.authPort, 9099);
      expect(config.firestorePort, 8080);
    });

    test('debug build with USE_FIREBASE_EMULATORS=true uses emulators', () {
      expect(
        FirebaseEmulatorConfig.resolve(
          isDebugBuild: true,
          useEmulatorsDefine: 'true',
        ).enabled,
        isTrue,
      );
    });

    test('debug build with USE_FIREBASE_EMULATORS=false uses real project', () {
      expect(
        FirebaseEmulatorConfig.resolve(
          isDebugBuild: true,
          useEmulatorsDefine: 'false',
        ),
        FirebaseEmulatorConfig.disabled,
      );
    });

    test('release/profile never use emulators, even with the define', () {
      for (final define in ['', 'true', 'false']) {
        expect(
          FirebaseEmulatorConfig.resolve(
            isDebugBuild: false,
            useEmulatorsDefine: define,
          ).enabled,
          isFalse,
          reason: 'define="$define"',
        );
      }
    });

    test('define is case-insensitive and trimmed', () {
      expect(
        FirebaseEmulatorConfig.resolve(
          isDebugBuild: true,
          useEmulatorsDefine: ' FALSE ',
        ).enabled,
        isFalse,
      );
    });

    test('invalid define fails loudly', () {
      expect(
        () => FirebaseEmulatorConfig.resolve(
          isDebugBuild: true,
          useEmulatorsDefine: 'yes',
        ),
        throwsArgumentError,
      );
    });

    test('release ignores an invalid define instead of crashing', () {
      expect(
        FirebaseEmulatorConfig.resolve(
          isDebugBuild: false,
          useEmulatorsDefine: 'yes',
        ),
        FirebaseEmulatorConfig.disabled,
      );
    });

    test('FIREBASE_EMULATOR_HOST overrides the host (physical phone)', () {
      final config = FirebaseEmulatorConfig.resolve(
        isDebugBuild: true,
        hostDefine: '192.168.1.20',
      );
      expect(config.host, '192.168.1.20');
      expect(config.authPort, 9099);
    });
  });

  test('fromEnvironment in tests (debug, no defines) enables emulators', () {
    expect(
      FirebaseEmulatorConfig.fromEnvironment(),
      const FirebaseEmulatorConfig(enabled: true),
    );
  });
}
