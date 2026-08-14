import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class ProfileVerificationReminderRegistration {
  ProfileVerificationReminderRegistration({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore,
       _messaging = messaging;

  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenSubscription;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;
  FirebaseMessaging get _push => _messaging ?? FirebaseMessaging.instance;

  Future<void> register(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || Firebase.apps.isEmpty || kIsWeb) return;
    try {
      final permission = await _push.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _push.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _saveToken(normalizedUserId, token);
      }
      await _tokenSubscription?.cancel();
      _tokenSubscription = _push.onTokenRefresh.listen(
        (nextToken) => _saveToken(normalizedUserId, nextToken),
      );
    } catch (_) {
      // Push registration must never block the verification workflow. The
      // private in-app reminders remain available through Firestore.
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) return;
    final tokenId = sha256.convert(utf8.encode(normalizedToken)).toString();
    await _database.doc('users/$userId/notification_devices/$tokenId').set({
      'deviceId': tokenId,
      'userId': userId,
      'token': normalizedToken,
      'platform': defaultTargetPlatform.name,
      'purpose': 'verification-reminders',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
  }
}
