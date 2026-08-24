import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/carisma_app.dart';
import 'firebase_options.dart';
import 'features/settings/data/app_runtime_preferences.dart';
import 'shared/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppRuntimePreferences.instance.initialize();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  FirebaseMessaging.onBackgroundMessage(
    plaqaFirebaseMessagingBackgroundHandler,
  );

  runApp(const CaRismaApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(PushNotificationService.instance.initialize());
  });
}

Future<void> _activateAppCheck() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: androidAppCheckProviderForBuild(
        isDebug: kDebugMode,
        debugToken: const String.fromEnvironment('PLAQA_APP_CHECK_DEBUG_TOKEN'),
      ),
      providerApple: appleAppCheckProviderForBuild(
        isDebug: kDebugMode,
        debugToken: const String.fromEnvironment(
          'PLAQA_IOS_APP_CHECK_DEBUG_TOKEN',
        ),
      ),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } on Object {
    if (kDebugMode) {
      debugPrint('App-Sicherheitspruefung konnte nicht gestartet werden.');
    }
  }
}

AppleAppCheckProvider appleAppCheckProviderForBuild({
  required bool isDebug,
  String debugToken = '',
}) {
  if (!isDebug) {
    return const AppleAppAttestWithDeviceCheckFallbackProvider();
  }

  final normalizedToken = debugToken.trim();
  return AppleDebugProvider(
    debugToken: normalizedToken.isEmpty ? null : normalizedToken,
  );
}

AndroidAppCheckProvider androidAppCheckProviderForBuild({
  required bool isDebug,
  String debugToken = '',
}) {
  if (!isDebug) {
    return const AndroidPlayIntegrityProvider();
  }

  final normalizedToken = debugToken.trim();
  return AndroidDebugProvider(
    debugToken: normalizedToken.isEmpty ? null : normalizedToken,
  );
}
