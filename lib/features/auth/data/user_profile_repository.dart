import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/firebase/carma_firestore_paths.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) {
    return _firestore.doc(CarmaFirestorePaths.user(userId));
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
      'isDeleted': false,
    });
  }
}
