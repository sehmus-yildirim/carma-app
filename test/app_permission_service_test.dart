import 'package:plaqa/features/settings/data/app_permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPermissionSnapshot', () {
    test('maps known platform states without treating unknown as granted', () {
      final snapshot = AppPermissionSnapshot.fromPlatformMap({
        'platform': 'android',
        'sdkInt': 35,
        'camera': 'granted',
        'microphone': 'denied',
        'location': 'permanentlyDenied',
        'media': 'restricted',
        'contacts': 'notRequired',
      });

      expect(snapshot.isAndroid, isTrue);
      expect(snapshot.sdkInt, 35);
      expect(
        snapshot.stateOf(AppPermissionKind.camera),
        AppPermissionState.granted,
      );
      expect(
        snapshot.stateOf(AppPermissionKind.microphone),
        AppPermissionState.denied,
      );
      expect(
        snapshot.stateOf(AppPermissionKind.location),
        AppPermissionState.permanentlyDenied,
      );
      expect(
        snapshot.stateOf(AppPermissionKind.media),
        AppPermissionState.restricted,
      );
      expect(
        snapshot.stateOf(AppPermissionKind.contacts),
        AppPermissionState.notRequired,
      );
    });

    test('maps missing and unknown values to unavailable', () {
      final snapshot = AppPermissionSnapshot.fromPlatformMap({
        'platform': 'android',
        'camera': 'unexpected',
      });

      expect(
        snapshot.stateOf(AppPermissionKind.camera),
        AppPermissionState.unavailable,
      );
      expect(
        snapshot.stateOf(AppPermissionKind.microphone),
        AppPermissionState.unavailable,
      );
    });
  });

  group('AppPermissionService', () {
    const channel = MethodChannel('plaqa/test_app_permissions');

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'opens Android settings through the existing platform channel',
      () async {
        var openedSettings = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'openAppSettings') {
                openedSettings = true;
                return true;
              }
              return null;
            });

        await AppPermissionService(channel: channel).openAndroidSettings();

        expect(openedSettings, isTrue);
      },
    );

    test('loading status does not request a permission', () async {
      final calledMethods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calledMethods.add(call.method);
            return <String, Object>{
              'platform': 'android',
              'sdkInt': 35,
              'camera': 'denied',
              'microphone': 'denied',
              'location': 'denied',
              'media': 'restricted',
              'contacts': 'notRequired',
            };
          });

      await AppPermissionService(channel: channel).loadStatus();

      expect(calledMethods, <String>['getAppPermissionStatuses']);
    });
  });
}
