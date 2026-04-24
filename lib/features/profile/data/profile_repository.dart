import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) {
    return _firestore.collection('profiles').doc(uid);
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
      await document.update({
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final profile = UserProfile.empty(
      uid: user.uid,
      email: user.email ?? '',
    );

    await document.set({
      ...profile.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _profileDocument(profile.uid).set(
      {
        ...profile.toFirestore(),
        'createdAt': profile.createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(profile.createdAt!),
      },
      SetOptions(merge: true),
    );
  }
}