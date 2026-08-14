import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'profile_verification_request.dart';

class ProfileVerificationException implements Exception {
  const ProfileVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileVerificationRepository {
  ProfileVerificationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore,
       _functions = functions;

  static const consentVersion = 'verification-consent-1.0';

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _cloudFunctions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  DocumentReference<Map<String, dynamic>> _currentRequest(String userId) {
    return _database.doc(
      CaRismaFirestorePaths.verificationRequest(userId.trim()),
    );
  }

  CollectionReference<Map<String, dynamic>> _notifications(String userId) {
    return _database.collection(
      CaRismaFirestorePaths.userVerificationNotifications(userId.trim()),
    );
  }

  Stream<ProfileVerificationRequest?> watchCurrentRequest(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<ProfileVerificationRequest?>.value(null);
    }
    return _currentRequest(normalizedUserId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return ProfileVerificationRequest.fromFirestore(snapshot);
    });
  }

  Stream<List<ProfileVerificationHistoryEntry>> watchHistory(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<List<ProfileVerificationHistoryEntry>>.value(const []);
    }
    return _currentRequest(normalizedUserId)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProfileVerificationHistoryEntry.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<ProfileVerificationNotification>> watchNotifications(
    String userId,
  ) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<List<ProfileVerificationNotification>>.value(const []);
    }
    return _notifications(normalizedUserId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProfileVerificationNotification.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedNotificationId = notificationId.trim();
    if (normalizedUserId.isEmpty || normalizedNotificationId.isEmpty) return;
    await _notifications(
      normalizedUserId,
    ).doc(normalizedNotificationId).update({'isRead': true});
  }

  Future<ProfileVerificationRequest?> getCurrentRequest(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;
    final snapshot = await _currentRequest(normalizedUserId).get();
    if (!snapshot.exists) return null;
    return ProfileVerificationRequest.fromFirestore(snapshot);
  }

  Future<void> saveDraftDocument({
    required String userId,
    required String documentKey,
    required String storagePath,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedPath = storagePath.trim();
    final canonicalPrefix =
        'profile_documents/$normalizedUserId/$documentKey/$documentKey.';
    if (normalizedUserId.isEmpty ||
        !ProfileVerificationDocumentKeys.required.contains(documentKey) ||
        !const [
          'png',
          'jpg',
        ].any((extension) => normalizedPath == '$canonicalPrefix$extension')) {
      throw const ProfileVerificationException(
        'Der Nachweis konnte nicht eindeutig zugeordnet werden.',
      );
    }

    final reference = _currentRequest(normalizedUserId);
    await _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final status = ProfileVerificationStatus.fromValue(data['status']);
      if (status == ProfileVerificationStatus.pending ||
          status == ProfileVerificationStatus.verified) {
        throw const ProfileVerificationException(
          'Während der Prüfung können Nachweise nicht geändert werden.',
        );
      }
      final paths = _stringMap(data['documentStoragePaths']);
      final statuses = _stringMap(data['documentStatuses']);
      final rejectionReasons = _stringMap(data['documentRejectionReasons']);
      paths[documentKey] = normalizedPath;
      statuses[documentKey] = ProfileVerificationDocumentStatus.uploaded.name;
      rejectionReasons.remove(documentKey);

      transaction.set(reference, {
        'requestId': normalizedUserId,
        'userId': normalizedUserId,
        'profilePath': CaRismaFirestorePaths.userProfile(normalizedUserId),
        'status': ProfileVerificationStatus.draft.name,
        'displayName': '',
        'documentStoragePaths': paths,
        'documentStatuses': statuses,
        'documentRejectionReasons': rejectionReasons,
        'vehicleId': data['vehicleId'],
        'vehicleRelationship':
            data['vehicleRelationship'] ??
            ProfileVehicleRelationship.owner.name,
        'authorizationConfirmed': false,
        'consentVersion': null,
        'consentAcceptedAt': null,
        'submittedAt': null,
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
        'retentionUntil': null,
        'createdAt': snapshot.exists
            ? data['createdAt'] ?? FieldValue.serverTimestamp()
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    });
  }

  Future<void> removeDraftDocument({
    required String userId,
    required String documentKey,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty ||
        !ProfileVerificationDocumentKeys.required.contains(documentKey)) {
      return;
    }
    final reference = _currentRequest(normalizedUserId);
    await _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final status = ProfileVerificationStatus.fromValue(data['status']);
      if (status == ProfileVerificationStatus.pending ||
          status == ProfileVerificationStatus.verified) {
        throw const ProfileVerificationException(
          'Während der Prüfung können Nachweise nicht entfernt werden.',
        );
      }
      final paths = _stringMap(data['documentStoragePaths'])
        ..remove(documentKey);
      final statuses = _stringMap(data['documentStatuses']);
      statuses[documentKey] = ProfileVerificationDocumentStatus.missing.name;
      final rejectionReasons = _stringMap(data['documentRejectionReasons'])
        ..remove(documentKey);
      transaction.update(reference, {
        'status': ProfileVerificationStatus.draft.name,
        'documentStoragePaths': paths,
        'documentStatuses': statuses,
        'documentRejectionReasons': rejectionReasons,
        'authorizationConfirmed': false,
        'consentVersion': null,
        'consentAcceptedAt': null,
        'submittedAt': null,
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
        'retentionUntil': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveDraftRelationship({
    required String userId,
    required String vehicleId,
    required ProfileVehicleRelationship relationship,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedUserId.isEmpty || normalizedVehicleId.isEmpty) {
      throw const ProfileVerificationException(
        'Bitte wähle zuerst ein Fahrzeug aus.',
      );
    }
    final request = await getCurrentRequest(normalizedUserId);
    if (request?.isLocked == true) {
      throw const ProfileVerificationException(
        'Während der Prüfung kann die Fahrzeugzuordnung nicht geändert werden.',
      );
    }
    await _currentRequest(normalizedUserId).set({
      'requestId': normalizedUserId,
      'userId': normalizedUserId,
      'profilePath': CaRismaFirestorePaths.userProfile(normalizedUserId),
      'status': ProfileVerificationStatus.draft.name,
      'displayName': request?.displayName ?? '',
      'documentStoragePaths': request?.documentStoragePaths ?? const {},
      'documentStatuses': {
        for (final entry
            in (request?.documentStatuses ??
                    const <String, ProfileVerificationDocumentStatus>{})
                .entries)
          entry.key: entry.value.name,
      },
      'documentRejectionReasons': request?.documentRejectionReasons ?? const {},
      'vehicleId': normalizedVehicleId,
      'vehicleRelationship': relationship.name,
      'authorizationConfirmed': false,
      'consentVersion': null,
      'consentAcceptedAt': null,
      'submittedAt': null,
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
      'retentionUntil': null,
      'createdAt': request?.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(request!.createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  Future<void> submitVerification({
    required String userId,
    required String vehicleId,
    required ProfileVehicleRelationship relationship,
    required bool authorizationConfirmed,
  }) async {
    if (!authorizationConfirmed) {
      throw const ProfileVerificationException(
        'Bitte bestätige zuerst deine Berechtigung und die Datenschutzhinweise.',
      );
    }
    try {
      await _cloudFunctions.httpsCallable('submitProfileVerification').call({
        'requestId': userId.trim(),
        'vehicleId': vehicleId.trim(),
        'vehicleRelationship': relationship.name,
        'authorizationConfirmed': true,
        'consentVersion': consentVersion,
      });
    } on FirebaseFunctionsException catch (error) {
      throw ProfileVerificationException(_functionsErrorMessage(error));
    }
  }

  Stream<List<ProfileVerificationRequest>> watchPendingRequests({
    int limit = 50,
  }) {
    return _database
        .collection(CaRismaFirestoreCollections.verificationRequests)
        .where('status', isEqualTo: ProfileVerificationStatus.pending.name)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(ProfileVerificationRequest.fromFirestore)
              .toList();
          requests.sort((left, right) {
            final leftTime = left.submittedAt ?? left.createdAt;
            final rightTime = right.submittedAt ?? right.createdAt;
            if (leftTime == null && rightTime == null) {
              return left.requestId.compareTo(right.requestId);
            }
            if (leftTime == null) return 1;
            if (rightTime == null) return -1;
            return leftTime.compareTo(rightTime);
          });
          return requests;
        });
  }

  Future<void> approveRequest({
    required ProfileVerificationRequest request,
    required String adminUserId,
  }) {
    return _reviewRequest(request: request, decision: 'verified');
  }

  Future<void> rejectRequest({
    required ProfileVerificationRequest request,
    required String adminUserId,
    required String reason,
  }) {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw const ProfileVerificationException(
        'Bitte gib einen verständlichen Ablehnungsgrund an.',
      );
    }
    return _reviewRequest(
      request: request,
      decision: 'rejected',
      reason: normalizedReason,
    );
  }

  Future<void> _reviewRequest({
    required ProfileVerificationRequest request,
    required String decision,
    String? reason,
  }) async {
    try {
      await _cloudFunctions.httpsCallable('reviewProfileVerification').call({
        'requestId': request.requestId,
        'decision': decision,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (error) {
      throw ProfileVerificationException(_functionsErrorMessage(error));
    }
  }

  String _functionsErrorMessage(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    return switch (error.code) {
      'unauthenticated' => 'Bitte melde dich erneut an.',
      'permission-denied' => 'Du hast keine Berechtigung für diese Aktion.',
      'failed-precondition' =>
        'Die Verifizierung ist noch nicht vollständig vorbereitet.',
      'invalid-argument' => 'Bitte prüfe deine Angaben.',
      _ =>
        'Die Verifizierung konnte gerade nicht gespeichert werden. Bitte versuche es erneut.',
    };
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return <String, String>{};
    return {
      for (final entry in value.entries)
        if (entry.value is String) entry.key.toString(): entry.value as String,
    };
  }
}
