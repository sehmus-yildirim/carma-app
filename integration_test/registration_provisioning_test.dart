import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plaqa/features/auth/data/legal_consent_repository.dart';
import 'package:plaqa/features/auth/data/search_credit_repository.dart';
import 'package:plaqa/features/auth/data/user_profile_repository.dart';
import 'package:plaqa/features/auth/domain/registration_legal_consent_builder.dart';
import 'package:plaqa/features/profile/data/profile_repository.dart';
import 'package:plaqa/main.dart' as app;
import 'package:plaqa/shared/firebase/carisma_firestore_paths.dart';
import 'package:plaqa/shared/firebase/firebase_emulator_configuration.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registration provisions every required Firestore document', (
    WidgetTester tester,
  ) async {
    expect(
      kPlaqaUseFirebaseEmulators,
      isTrue,
      reason: 'Der Provisioning-Test darf nur gegen Emulatoren laufen.',
    );

    await app.main();
    await tester.pump();

    final suffix = DateTime.now().microsecondsSinceEpoch;
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: 'integration.provisioning.$suffix@plaqa.test',
          password: 'Plaqa-Test-2026!',
        )
        .timeout(const Duration(seconds: 15));
    final user = credential.user;
    expect(user, isNotNull);

    final userId = user!.uid;
    final consents = RegistrationLegalConsentBuilder.buildLocalConsents(
      userId: userId,
    );

    await UserProfileRepository()
        .createProfileForUser(user)
        .timeout(const Duration(seconds: 30));
    await ProfileRepository()
        .createProfileIfMissing(user)
        .timeout(const Duration(seconds: 30));
    await SearchCreditRepository()
        .createSearchCreditIfMissing(userId: userId)
        .timeout(const Duration(seconds: 30));
    await LegalConsentRepository()
        .saveRegistrationConsents(userId: userId, consents: consents)
        .timeout(const Duration(seconds: 30));

    final firestore = FirebaseFirestore.instance;
    expect(
      await _documentExists(firestore, CaRismaFirestorePaths.user(userId)),
      isTrue,
    );
    expect(
      await _documentExists(
        firestore,
        CaRismaFirestorePaths.userProfile(userId),
      ),
      isTrue,
    );
    expect(
      await _documentExists(
        firestore,
        CaRismaFirestorePaths.publicProfile(userId),
      ),
      isTrue,
    );
    expect(
      await _documentExists(
        firestore,
        CaRismaFirestorePaths.userSearchCredit(userId),
      ),
      isTrue,
    );

    final consentSnapshot = await _readCollection(
      firestore.collection(CaRismaFirestorePaths.userLegalConsents(userId)),
    );
    expect(consentSnapshot.docs, hasLength(consents.length));

    await FirebaseAuth.instance.signOut();
  });
}

Future<bool> _documentExists(FirebaseFirestore firestore, String path) async {
  for (var attempt = 0; attempt < 3; attempt += 1) {
    try {
      final snapshot = await firestore
          .doc(path)
          .get()
          .timeout(const Duration(seconds: 15));
      return snapshot.exists;
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' || attempt == 2) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  return false;
}

Future<QuerySnapshot<Map<String, dynamic>>> _readCollection(
  CollectionReference<Map<String, dynamic>> collection,
) async {
  for (var attempt = 0; attempt < 3; attempt += 1) {
    try {
      return await collection.get().timeout(const Duration(seconds: 15));
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' || attempt == 2) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  throw StateError('Firestore-Emulator konnte nicht gelesen werden.');
}
