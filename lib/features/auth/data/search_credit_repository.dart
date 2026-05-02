import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carma_firestore_paths.dart';
import '../../../shared/models/search_credit.dart';

class SearchCreditRepository {
  SearchCreditRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _searchCreditDocument(String userId) {
    return _firestore.doc(CarmaFirestorePaths.userSearchCredit(userId));
  }

  Future<void> createSearchCreditIfMissing({required String userId}) async {
    final document = _searchCreditDocument(userId);
    final snapshot = await document.get();

    if (snapshot.exists) {
      return;
    }

    final searchCredit = SearchCredit.freeDefault(userId: userId);

    await document.set({
      ...searchCredit.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
