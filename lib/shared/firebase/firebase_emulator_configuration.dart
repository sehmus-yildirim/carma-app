import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const bool kPlaqaUseFirebaseEmulators = bool.fromEnvironment(
  'PLAQA_USE_FIREBASE_EMULATORS',
);

const String _configuredEmulatorHost = String.fromEnvironment(
  'PLAQA_FIREBASE_EMULATOR_HOST',
);

String firebaseEmulatorHost({
  TargetPlatform? platform,
  String configuredHost = _configuredEmulatorHost,
}) {
  final override = configuredHost.trim();
  if (override.isNotEmpty) {
    return override;
  }

  return (platform ?? defaultTargetPlatform) == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
}

Future<void> connectToFirebaseEmulators() async {
  final host = firebaseEmulatorHost();

  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
  FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  ).useFunctionsEmulator(host, 5001);
}
