import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/main.dart';

void main() {
  group('androidAppCheckProviderForBuild', () {
    test('uses Play Integrity outside debug builds', () {
      final provider = androidAppCheckProviderForBuild(isDebug: false);

      expect(provider, isA<AndroidPlayIntegrityProvider>());
    });

    test('uses an automatically generated token for debug builds', () {
      final provider = androidAppCheckProviderForBuild(isDebug: true);

      expect(provider, isA<AndroidDebugProvider>());
      expect((provider as AndroidDebugProvider).debugToken, isNull);
    });

    test('accepts a local debug-token override without changing release', () {
      final provider = androidAppCheckProviderForBuild(
        isDebug: true,
        debugToken: '  local-debug-token  ',
      );

      expect(provider, isA<AndroidDebugProvider>());
      expect(
        (provider as AndroidDebugProvider).debugToken,
        'local-debug-token',
      );
    });
  });

  group('appleAppCheckProviderForBuild', () {
    test('uses the Apple debug provider for debug builds', () {
      final provider = appleAppCheckProviderForBuild(
        isDebug: true,
        debugToken: '  ios-debug-token  ',
      );

      expect(provider, isA<AppleDebugProvider>());
      expect((provider as AppleDebugProvider).debugToken, 'ios-debug-token');
    });

    test('uses App Attest with DeviceCheck fallback for release builds', () {
      final provider = appleAppCheckProviderForBuild(isDebug: false);

      expect(provider, isA<AppleAppAttestWithDeviceCheckFallbackProvider>());
    });
  });

  test('renders the app before optional push initialization starts', () {
    final source = File('lib/main.dart').readAsStringSync();
    final runAppIndex = source.indexOf('runApp(const CaRismaApp())');
    final pushInitializationIndex = source.indexOf(
      'PushNotificationService.instance.initialize()',
    );

    expect(runAppIndex, greaterThanOrEqualTo(0));
    expect(pushInitializationIndex, greaterThan(runAppIndex));
    expect(source, contains('addPostFrameCallback'));
  });
}
