import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) {
    return _firestore.doc(CaRismaFirestorePaths.user(userId));
  }

  Future<void> createProfileForUser(User user) async {
    final userDocument = _userDocument(user.uid);
    final existingDocument = await userDocument.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existingDocument.exists) {
      await userDocument.set(data, SetOptions(merge: true));
      return;
    }

    await userDocument.set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'accountState': 'active',
      'onboardingCompleted': false,
      'isDeleted': false,
    });
  }

  Future<bool> isOnboardingCompleted(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;

    final snapshot = await _userDocument(normalizedUserId).get();
    return onboardingCompletedFromData(snapshot.data());
  }

  Future<void> completeOnboarding(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('Nutzer-ID darf nicht leer sein.');
    }

    await _userDocument(normalizedUserId).set({
      'onboardingCompleted': true,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static bool onboardingCompletedFromData(Map<String, dynamic>? data) {
    return data?['onboardingCompleted'] == true ||
        data?['onboardingCompletedAt'] != null;
  }
}
