import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) {
    return _firestore.doc(CaRismaFirestorePaths.userProfile(uid));
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _profileDocument(uid).snapshots().map((document) {
      if (!document.exists) {
        return null;
      }

      return UserProfile.fromFirestore(document);
    });
  }

  Future<UserProfile?> getProfile(String uid) async {
    final document = await _profileDocument(uid).get();

    if (!document.exists) {
      return null;
    }

    return UserProfile.fromFirestore(document);
  }

  Future<void> createProfileIfMissing(User user) async {
    final document = _profileDocument(user.uid);
    final snapshot = await document.get();

    if (snapshot.exists) {
      final data = snapshot.data() ?? <String, dynamic>{};
      final hasVerificationStatus =
          (data['verificationStatus'] as String?)?.trim().isNotEmpty == true;

      final updateData = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!hasVerificationStatus) {
        updateData.addAll({
          'verificationStatus': 'unverified',
          'verificationSubmittedAt': null,
          'verificationReviewedAt': null,
          'verificationRejectionReason': null,
        });
      }

      await document.set(updateData, SetOptions(merge: true));
      return;
    }

    final profile = UserProfile.empty(uid: user.uid, email: user.email ?? '');

    await document.set({
      ...profile.toFirestore(),
      'displayName': user.displayName ?? profile.displayName,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _profileDocument(profile.uid).set({
      ...profile.toFirestore(),
      'createdAt': profile.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(profile.createdAt!),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfilePreferences({
    required String uid,
    required String? photoUrl,
    required bool allowContactRequests,
    required bool allowAnonymousReports,
  }) async {
    await _profileDocument(uid).set({
      'photoUrl': photoUrl,
      'allowContactRequests': allowContactRequests,
      'allowAnonymousReports': allowAnonymousReports,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
