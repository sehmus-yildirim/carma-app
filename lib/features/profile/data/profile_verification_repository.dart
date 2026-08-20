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
      final currentDocumentStatus = ProfileVerificationDocumentStatus.fromValue(
        _stringMap(data['documentStatuses'])[documentKey],
      );
      if (currentDocumentStatus == ProfileVerificationDocumentStatus.verified ||
          currentDocumentStatus == ProfileVerificationDocumentStatus.inReview) {
        throw const ProfileVerificationException(
          'Ein bereits bestätigter Nachweis kann nicht ersetzt werden.',
        );
      }
      final paths = _stringMap(data['documentStoragePaths']);
      final statuses = _stringMap(data['documentStatuses']);
      final rejectionReasons = _stringMap(data['documentRejectionReasons']);
      final documentExpiresAt = _timestampMap(data['documentExpiresAt']);
      paths[documentKey] = normalizedPath;
      statuses[documentKey] = ProfileVerificationDocumentStatus.uploaded.name;

      transaction.set(
        reference,
        _draftPayload(
          userId: normalizedUserId,
          existing: data,
          paths: paths,
          statuses: statuses,
          rejectionReasons: rejectionReasons,
          expirations: documentExpiresAt,
          authorizationConfirmed: false,
        ),
        SetOptions(merge: false),
      );
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
      final currentDocumentStatus = ProfileVerificationDocumentStatus.fromValue(
        _stringMap(data['documentStatuses'])[documentKey],
      );
      if (currentDocumentStatus == ProfileVerificationDocumentStatus.verified ||
          currentDocumentStatus == ProfileVerificationDocumentStatus.inReview) {
        throw const ProfileVerificationException(
          'Ein bereits bestätigter Nachweis kann nicht entfernt werden.',
        );
      }
      final paths = _stringMap(data['documentStoragePaths'])
        ..remove(documentKey);
      final statuses = _stringMap(data['documentStatuses']);
      statuses[documentKey] = ProfileVerificationDocumentStatus.missing.name;
      final rejectionReasons = _stringMap(data['documentRejectionReasons']);
      transaction.set(
        reference,
        _draftPayload(
          userId: normalizedUserId,
          existing: data,
          paths: paths,
          statuses: statuses,
          rejectionReasons: rejectionReasons,
          authorizationConfirmed: false,
        ),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveDraftExpiration({
    required String userId,
    required String expirationKey,
    required DateTime expiresAt,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty ||
        !ProfileVerificationDocumentKeys.requiredExpirationKeys.contains(
          expirationKey,
        )) {
      throw const ProfileVerificationException(
        'Das Ablaufdatum konnte nicht eindeutig zugeordnet werden.',
      );
    }
    final expirationDay = DateTime(
      expiresAt.year,
      expiresAt.month,
      expiresAt.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!expirationDay.isAfter(today)) {
      throw const ProfileVerificationException(
        'Bitte gib ein gültiges zukünftiges Ablaufdatum ein.',
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
          'Während der Prüfung kann das Ablaufdatum nicht geändert werden.',
        );
      }
      final groupKey =
          expirationKey == ProfileVerificationDocumentKeys.identityExpiration
          ? ProfileVerificationDocumentKeys.identityGroup
          : ProfileVerificationDocumentKeys.driverLicenseGroup;
      final identityType = ProfileVerificationIdentityDocumentType.fromValue(
        data['identityDocumentType'],
      );
      final statuses = _stringMap(data['documentStatuses']);
      final groupIsVerified =
          ProfileVerificationDocumentKeys.keysForGroup(
            groupKey,
            identityType,
          ).every(
            (key) =>
                ProfileVerificationDocumentStatus.fromValue(statuses[key]) ==
                ProfileVerificationDocumentStatus.verified,
          );
      if (groupIsVerified) {
        throw const ProfileVerificationException(
          'Das Ablaufdatum eines bestätigten Nachweises kann nicht geändert werden.',
        );
      }
      final expirations = _timestampMap(data['documentExpiresAt']);
      expirations[expirationKey] = Timestamp.fromDate(expirationDay);
      transaction.set(
        reference,
        _draftPayload(
          userId: normalizedUserId,
          existing: data,
          expirations: expirations,
          authorizationConfirmed: false,
        ),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveDraftIdentityDocumentType({
    required String userId,
    required ProfileVerificationIdentityDocumentType identityDocumentType,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    final reference = _currentRequest(normalizedUserId);
    await _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final status = ProfileVerificationStatus.fromValue(data['status']);
      if (status == ProfileVerificationStatus.pending ||
          status == ProfileVerificationStatus.verified) {
        throw const ProfileVerificationException(
          'Während der Prüfung kann der Dokumenttyp nicht geändert werden.',
        );
      }
      final previousType = ProfileVerificationIdentityDocumentType.fromValue(
        data['identityDocumentType'],
      );
      if (previousType == identityDocumentType) return;
      final currentStatuses = _stringMap(data['documentStatuses']);
      if (_groupHasProtectedStatus(
        currentStatuses,
        ProfileVerificationDocumentKeys.identityGroup,
        previousType,
      )) {
        throw const ProfileVerificationException(
          'Der Typ eines bestätigten oder laufend geprüften Nachweises kann nicht geändert werden.',
        );
      }
      final paths = _stringMap(data['documentStoragePaths'])
        ..remove(ProfileVerificationDocumentKeys.identityFront)
        ..remove(ProfileVerificationDocumentKeys.identityBack);
      final statuses = _stringMap(data['documentStatuses']);
      statuses[ProfileVerificationDocumentKeys.identityFront] =
          ProfileVerificationDocumentStatus.missing.name;
      statuses[ProfileVerificationDocumentKeys.identityBack] =
          ProfileVerificationDocumentStatus.missing.name;
      final reasons = _stringMap(data['documentRejectionReasons']);
      final expirations = _timestampMap(data['documentExpiresAt'])
        ..remove(ProfileVerificationDocumentKeys.identityExpiration);
      transaction.set(
        reference,
        _draftPayload(
          userId: normalizedUserId,
          existing: data,
          paths: paths,
          statuses: statuses,
          rejectionReasons: reasons,
          expirations: expirations,
          identityDocumentType: identityDocumentType,
          authorizationConfirmed: false,
        ),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveDraftConfirmations({
    required String userId,
    required bool authorizationConfirmed,
    required bool vehicleAssignmentConfirmed,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    final reference = _currentRequest(normalizedUserId);
    await _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final status = ProfileVerificationStatus.fromValue(data['status']);
      if (status == ProfileVerificationStatus.pending ||
          status == ProfileVerificationStatus.verified) {
        return;
      }
      transaction.set(
        reference,
        _draftPayload(
          userId: normalizedUserId,
          existing: data,
          authorizationConfirmed: authorizationConfirmed,
          vehicleAssignmentConfirmed: vehicleAssignmentConfirmed,
        ),
        SetOptions(merge: false),
      );
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
    final reference = _currentRequest(normalizedUserId);
    await _database.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final status = ProfileVerificationStatus.fromValue(data['status']);
      if (status == ProfileVerificationStatus.pending ||
          status == ProfileVerificationStatus.verified) {
        throw const ProfileVerificationException(
          'Während der Prüfung kann die Fahrzeugzuordnung nicht geändert werden.',
        );
      }
      final identityType = ProfileVerificationIdentityDocumentType.fromValue(
        data['identityDocumentType'],
      );
      if (_groupHasProtectedStatus(
        _stringMap(data['documentStatuses']),
        ProfileVerificationDocumentKeys.vehicleGroup,
        identityType,
      )) {
        throw const ProfileVerificationException(
          'Ein bereits bestätigtes oder laufend geprüftes Fahrzeug kann nicht neu zugeordnet werden.',
        );
      }
      final vehicleChanged =
          (data['vehicleId'] as String?)?.trim() != normalizedVehicleId;
      final paths = _stringMap(data['documentStoragePaths']);
      final statuses = _stringMap(data['documentStatuses']);
      final reasons = _stringMap(data['documentRejectionReasons']);
      if (vehicleChanged) {
        for (final key in const [
          ProfileVerificationDocumentKeys.vehicleFront,
          ProfileVerificationDocumentKeys.vehicleBack,
        ]) {
          paths.remove(key);
          statuses[key] = ProfileVerificationDocumentStatus.missing.name;
        }
      }
      transaction.set(
        reference,
        _draftPayload(
          userId: normalizedUserId,
          existing: data,
          paths: paths,
          statuses: statuses,
          rejectionReasons: reasons,
          vehicleId: normalizedVehicleId,
          relationship: relationship,
          authorizationConfirmed: false,
          vehicleAssignmentConfirmed: false,
        ),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> submitVerification({
    required String userId,
    required String? vehicleId,
    required ProfileVehicleRelationship relationship,
    required bool authorizationConfirmed,
    required bool vehicleAssignmentConfirmed,
    required ProfileVerificationIdentityDocumentType identityDocumentType,
    required List<String> documentGroups,
  }) async {
    if (!authorizationConfirmed) {
      throw const ProfileVerificationException(
        'Bitte bestätige zuerst deine Berechtigung und die Datenschutzhinweise.',
      );
    }
    final normalizedGroups = documentGroups
        .where(ProfileVerificationDocumentKeys.groupKeys.contains)
        .toSet()
        .toList(growable: false);
    if (normalizedGroups.isEmpty) {
      throw const ProfileVerificationException(
        'Bitte vervollständige mindestens einen Nachweis.',
      );
    }
    if (normalizedGroups.contains(
          ProfileVerificationDocumentKeys.vehicleGroup,
        ) &&
        !vehicleAssignmentConfirmed) {
      throw const ProfileVerificationException(
        'Bitte bestätige, welches Fahrzeug geprüft werden soll.',
      );
    }
    try {
      await _cloudFunctions.httpsCallable('submitProfileVerification').call({
        'requestId': userId.trim(),
        'vehicleId': vehicleId?.trim(),
        'vehicleRelationship': relationship.name,
        'authorizationConfirmed': true,
        'vehicleAssignmentConfirmed': true,
        'identityDocumentType': identityDocumentType.name,
        'documentGroups': normalizedGroups,
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

  static Map<String, Timestamp> _timestampMap(Object? value) {
    if (value is! Map) return <String, Timestamp>{};
    return {
      for (final entry in value.entries)
        if (entry.value is Timestamp)
          entry.key.toString(): entry.value as Timestamp,
    };
  }

  static bool _groupHasProtectedStatus(
    Map<String, String> statuses,
    String groupKey,
    ProfileVerificationIdentityDocumentType identityType,
  ) {
    return ProfileVerificationDocumentKeys.keysForGroup(
      groupKey,
      identityType,
    ).any((key) {
      final status = ProfileVerificationDocumentStatus.fromValue(statuses[key]);
      return status == ProfileVerificationDocumentStatus.verified ||
          status == ProfileVerificationDocumentStatus.inReview;
    });
  }

  static Map<String, dynamic> _draftPayload({
    required String userId,
    required Map<String, dynamic> existing,
    Map<String, String>? paths,
    Map<String, String>? statuses,
    Map<String, String>? rejectionReasons,
    Map<String, Timestamp>? expirations,
    ProfileVerificationIdentityDocumentType? identityDocumentType,
    String? vehicleId,
    ProfileVehicleRelationship? relationship,
    bool? authorizationConfirmed,
    bool? vehicleAssignmentConfirmed,
  }) {
    return <String, dynamic>{
      'requestId': userId,
      'userId': userId,
      'profilePath': CaRismaFirestorePaths.userProfile(userId),
      'status': ProfileVerificationStatus.draft.name,
      'displayName': existing['displayName'] ?? '',
      'identityDocumentType':
          identityDocumentType?.name ??
          ProfileVerificationIdentityDocumentType.fromValue(
            existing['identityDocumentType'],
          ).name,
      'documentStoragePaths':
          paths ?? _stringMap(existing['documentStoragePaths']),
      'documentStatuses': statuses ?? _stringMap(existing['documentStatuses']),
      'documentRejectionReasons':
          rejectionReasons ?? _stringMap(existing['documentRejectionReasons']),
      'documentExpiresAt':
          expirations ?? _timestampMap(existing['documentExpiresAt']),
      'vehicleId': vehicleId ?? existing['vehicleId'],
      'vehicleRelationship':
          relationship?.name ??
          existing['vehicleRelationship'] ??
          ProfileVehicleRelationship.owner.name,
      'vehicleAssignmentConfirmed':
          vehicleAssignmentConfirmed ??
          existing['vehicleAssignmentConfirmed'] ??
          false,
      'authorizationConfirmed':
          authorizationConfirmed ?? existing['authorizationConfirmed'] ?? false,
      'consentVersion': null,
      'consentAcceptedAt': null,
      'submittedAt': null,
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
      'retentionUntil': null,
      'createdAt': existing['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
