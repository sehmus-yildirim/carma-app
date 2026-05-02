import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carma_firestore_paths.dart';
import '../../../shared/models/legal_consent.dart';

class LegalConsentRepository {
  LegalConsentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _legalConsentCollection(
    String userId,
  ) {
    return _firestore.collection(CarmaFirestorePaths.userLegalConsents(userId));
  }

  Future<void> saveRegistrationConsents({
    required String userId,
    required List<LegalConsent> consents,
  }) async {
    final collection = _legalConsentCollection(userId);
    final batch = _firestore.batch();

    for (final consent in consents) {
      final document = collection.doc(consent.id);
      final snapshot = await document.get();

      if (snapshot.exists) {
        continue;
      }

      batch.set(document, {
        ...consent.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'registration',
      });
    }

    await batch.commit();
  }
}
