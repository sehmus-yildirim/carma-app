import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/carisma_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAndroidAppCheckIfConfigured();

  runApp(const CaRismaApp());
}

Future<void> _activateAndroidAppCheckIfConfigured() async {
  const enabled = bool.fromEnvironment('CARISMA_ENABLE_APP_CHECK');
  if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  if (kDebugMode) {
    const debugToken = String.fromEnvironment('CARISMA_APP_CHECK_DEBUG_TOKEN');
    if (debugToken.isEmpty) {
      return;
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AndroidDebugProvider(debugToken: debugToken),
    );
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidPlayIntegrityProvider(),
  );
}
