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
}
