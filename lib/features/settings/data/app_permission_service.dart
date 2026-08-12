import 'package:flutter/services.dart';

enum AppPermissionKind { camera, microphone, location, media, contacts }

enum AppPermissionState {
  granted,
  denied,
  restricted,
  permanentlyDenied,
  notDetermined,
  notRequired,
  unavailable,
}

class AppPermissionSnapshot {
  const AppPermissionSnapshot({
    required this.isAndroid,
    required this.sdkInt,
    required this.states,
  });

  final bool isAndroid;
  final int? sdkInt;
  final Map<AppPermissionKind, AppPermissionState> states;

  AppPermissionState stateOf(AppPermissionKind kind) {
    return states[kind] ?? AppPermissionState.unavailable;
  }

  factory AppPermissionSnapshot.fromPlatformMap(Map<Object?, Object?> data) {
    final isAndroid = data['platform'] == 'android';
    final sdkValue = data['sdkInt'];

    return AppPermissionSnapshot(
      isAndroid: isAndroid,
      sdkInt: sdkValue is int ? sdkValue : null,
      states: {
        for (final kind in AppPermissionKind.values)
          kind: _stateFromCode(data[kind.name]),
      },
    );
  }

  static AppPermissionState _stateFromCode(Object? value) {
    return switch (value) {
      'granted' => AppPermissionState.granted,
      'denied' => AppPermissionState.denied,
      'restricted' => AppPermissionState.restricted,
      'permanentlyDenied' => AppPermissionState.permanentlyDenied,
      'notDetermined' => AppPermissionState.notDetermined,
      'notRequired' => AppPermissionState.notRequired,
      _ => AppPermissionState.unavailable,
    };
  }
}

class AppPermissionService {
  AppPermissionService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('carisma/chat_tools');

  final MethodChannel _channel;

  Future<AppPermissionSnapshot> loadStatus() async {
    try {
      final result = await _channel.invokeMethod<Object?>(
        'getAppPermissionStatuses',
      );
      if (result is! Map) {
        return _unavailableSnapshot();
      }

      return AppPermissionSnapshot.fromPlatformMap(
        Map<Object?, Object?>.from(result),
      );
    } on MissingPluginException {
      return _unavailableSnapshot();
    } on PlatformException catch (error) {
      throw AppPermissionServiceException(
        error.message ?? 'Berechtigungsstatus konnte nicht geladen werden.',
      );
    }
  }

  Future<void> openAndroidSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openAppSettings');
      if (opened != true) {
        throw const AppPermissionServiceException(
          'Die Android-Einstellungen konnten nicht geöffnet werden.',
        );
      }
    } on MissingPluginException {
      throw const AppPermissionServiceException(
        'Die Android-Einstellungen sind auf diesem Gerät nicht verfügbar.',
      );
    } on PlatformException catch (error) {
      throw AppPermissionServiceException(
        error.message ??
            'Die Android-Einstellungen konnten nicht geöffnet werden.',
      );
    }
  }

  AppPermissionSnapshot _unavailableSnapshot() {
    return AppPermissionSnapshot(
      isAndroid: false,
      sdkInt: null,
      states: {
        for (final kind in AppPermissionKind.values)
          kind: AppPermissionState.unavailable,
      },
    );
  }
}

class AppPermissionServiceException implements Exception {
  const AppPermissionServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
