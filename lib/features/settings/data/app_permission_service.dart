import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;

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
    required this.platform,
    required this.sdkInt,
    required this.states,
  });

  final String platform;
  final int? sdkInt;
  final Map<AppPermissionKind, AppPermissionState> states;

  bool get isAndroid => platform == 'android';
  bool get isIos => platform == 'ios';

  AppPermissionState stateOf(AppPermissionKind kind) {
    return states[kind] ?? AppPermissionState.unavailable;
  }

  factory AppPermissionSnapshot.fromPlatformMap(Map<Object?, Object?> data) {
    final platform = data['platform'] as String? ?? 'unknown';
    final sdkValue = data['sdkInt'];

    return AppPermissionSnapshot(
      platform: platform,
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
    : _channel = channel ?? const MethodChannel('plaqa/chat_tools');

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
    } on PlatformException {
      throw const AppPermissionServiceException(
        'Berechtigungsstatus konnte nicht geladen werden.',
      );
    }
  }

  Future<void> openSystemSettings() async {
    try {
      final openedByHost = await _channel.invokeMethod<bool>('openAppSettings');
      if (openedByHost == true) return;
    } on MissingPluginException {
      // The plugin fallback below supports iOS and newer host integrations.
    } on PlatformException {
      // Keep the platform-neutral fallback available when the host rejects it.
    }

    try {
      final opened = await geo.Geolocator.openAppSettings();
      if (opened != true) {
        throw const AppPermissionServiceException(
          'Die App-Einstellungen konnten nicht geöffnet werden.',
        );
      }
    } on MissingPluginException {
      throw const AppPermissionServiceException(
        'Die App-Einstellungen sind auf diesem Gerät nicht verfügbar.',
      );
    } on PlatformException {
      throw const AppPermissionServiceException(
        'Die App-Einstellungen konnten nicht geöffnet werden.',
      );
    }
  }

  Future<void> openAndroidSettings() => openSystemSettings();

  AppPermissionSnapshot _unavailableSnapshot() {
    return AppPermissionSnapshot(
      platform: switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => 'unknown',
      },
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
