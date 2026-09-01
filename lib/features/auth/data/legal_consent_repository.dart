import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/models/legal_consent.dart';

class LegalConsentRepository {
  LegalConsentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _legalConsentCollection(
    String userId,
  ) {
    return _firestore.collection(
      CaRismaFirestorePaths.userLegalConsents(userId),
    );
  }

  Future<List<LegalConsent>> loadConsents(String userId) async {
    final snapshot = await _legalConsentCollection(userId).get();
    return snapshot.docs
        .map((document) => LegalConsent.fromMap(document.data()))
        .where((consent) => consent.userId == userId)
        .toList(growable: false);
  }

  Future<void> saveConsents({
    required String userId,
    required List<LegalConsent> consents,
    required String source,
  }) async {
    if (!const {'registration', 'renewal'}.contains(source)) {
      throw ArgumentError.value(source, 'source', 'Ungültige Quelle.');
    }
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
        'source': source,
      });
    }

    await batch.commit();
  }

  Future<void> saveRegistrationConsents({
    required String userId,
    required List<LegalConsent> consents,
  }) {
    return saveConsents(
      userId: userId,
      consents: consents,
      source: 'registration',
    );
  }
}
