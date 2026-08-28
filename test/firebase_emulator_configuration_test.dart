import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/firebase/firebase_emulator_configuration.dart';

void main() {
  group('firebaseEmulatorHost', () {
    test('uses the Android host bridge for an Android emulator', () {
      expect(
        firebaseEmulatorHost(platform: TargetPlatform.android),
        '10.0.2.2',
      );
    });

    test('uses loopback for desktop platforms', () {
      expect(
        firebaseEmulatorHost(platform: TargetPlatform.windows),
        '127.0.0.1',
      );
    });

    test('prefers an explicit host override', () {
      expect(
        firebaseEmulatorHost(
          platform: TargetPlatform.android,
          configuredHost: '192.0.2.10',
        ),
        '192.0.2.10',
      );
    });
  });
}
