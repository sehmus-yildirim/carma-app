import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';

class NotificationSettings {
  const NotificationSettings({
    this.contactRequests = true,
    this.chats = true,
    this.reports = true,
    this.verification = true,
  });

  final bool contactRequests;
  final bool chats;
  final bool reports;
  final bool verification;

  factory NotificationSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      return const NotificationSettings();
    }

    return NotificationSettings(
      contactRequests: data['contactRequests'] as bool? ?? true,
      chats: data['chats'] as bool? ?? true,
      reports: data['reports'] as bool? ?? true,
      verification: data['verification'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore({required String userId}) {
    return {
      'userId': userId,
      'contactRequests': contactRequests,
      'chats': chats,
      'reports': reports,
      'verification': verification,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class NotificationSettingsRepository {
  NotificationSettingsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<NotificationSettings> load(String userId) async {
    final document = await _document(userId).get();
    return NotificationSettings.fromFirestore(document);
  }

  Future<void> save({
    required String userId,
    required NotificationSettings settings,
  }) {
    return _document(
      userId,
    ).set(settings.toFirestore(userId: userId), SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _document(String userId) {
    return _firestore.doc(
      CaRismaFirestorePaths.userNotificationSettings(userId),
    );
  }
}
