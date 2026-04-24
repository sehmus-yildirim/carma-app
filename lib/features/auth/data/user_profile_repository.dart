import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> createProfileForUser(User user) async {
    final userDocument = _firestore.collection('users').doc(user.uid);
    final existingDocument = await userDocument.get();

    if (existingDocument.exists) {
      await userDocument.update({
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await userDocument.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
