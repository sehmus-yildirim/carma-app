import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../firebase/carisma_firestore_paths.dart';

class PushTokenRepository {
  PushTokenRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> save({
    required String userId,
    required String token,
    required String platform,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedToken = token.trim();
    if (normalizedUserId.isEmpty || normalizedToken.isEmpty) return;

    await _document(normalizedUserId, normalizedToken).set({
      'userId': normalizedUserId,
      'token': normalizedToken,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> remove({
    required String userId,
    required String token,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedToken = token.trim();
    if (normalizedUserId.isEmpty || normalizedToken.isEmpty) return;
    await _document(normalizedUserId, normalizedToken).delete();
  }

  DocumentReference<Map<String, dynamic>> _document(
    String userId,
    String token,
  ) {
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    return _firestore.doc(
      CaRismaFirestorePaths.userPushToken(userId, tokenHash),
    );
  }
}
