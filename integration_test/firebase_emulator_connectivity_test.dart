import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/main.dart' as app;
import 'package:plaqa/shared/firebase/firebase_emulator_configuration.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auth and firestore answer through the local emulator bridge', (
    WidgetTester tester,
  ) async {
    expect(
      kPlaqaUseFirebaseEmulators,
      isTrue,
      reason: 'Der Connectivity-Test darf nur gegen Emulatoren laufen.',
    );

    await app.main();
    await tester.pump();

    final email =
        'integration.connectivity.${DateTime.now().microsecondsSinceEpoch}'
        '@plaqa.test';
    const password = 'Plaqa-Test-2026!';
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));
    final user = credential.user;
    expect(user, isNotNull);

    final snapshot = await _readUserDocument(user!.uid);
    expect(snapshot.exists, isFalse);

    await FirebaseAuth.instance.signOut();
  });
}

Future<DocumentSnapshot<Map<String, dynamic>>> _readUserDocument(
  String userId,
) async {
  for (var attempt = 0; attempt < 3; attempt += 1) {
    try {
      return await FirebaseFirestore.instance
          .doc('users/$userId')
          .get()
          .timeout(const Duration(seconds: 15));
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' || attempt == 2) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  throw StateError('Firestore-Emulator konnte nicht gelesen werden.');
}
