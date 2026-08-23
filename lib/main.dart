import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/carisma_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAndroidAppCheck();

  runApp(const CaRismaApp());
}

Future<void> _activateAndroidAppCheck() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: androidAppCheckProviderForBuild(
        isDebug: kDebugMode,
        debugToken: const String.fromEnvironment(
          'PLAQA_APP_CHECK_DEBUG_TOKEN',
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
