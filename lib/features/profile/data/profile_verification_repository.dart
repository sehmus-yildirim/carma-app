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
      if (statuses[documentKey] ==
          ProfileVerificationDocumentStatus.verified.name) {
        throw const ProfileVerificationException(
          'Ein bereits bestätigter Nachweis kann nicht ersetzt werden.',
        );
      }
      final rejectionReasons = _stringMap(data['documentRejectionReasons']);
      final documentExpiresAt = _timestampMap(data['documentExpiresAt']);
      paths[documentKey] = normalizedPath;
      statuses[documentKey] = ProfileVerificationDocumentStatus.uploaded.name;
      rejectionReasons.remove(documentKey);

      transaction.set(
        reference,
        _draftData(
          userId: normalizedUserId,
          data: data,
          paths: paths,
          statuses: statuses,
          rejectionReasons: rejectionReasons,
          expirations: documentExpiresAt,
          lastEditedDocumentKey: documentKey,
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
      final existingStatuses = _stringMap(data['documentStatuses']);
      if (existingStatuses[documentKey] ==
          ProfileVerificationDocumentStatus.verified.name) {
        throw const ProfileVerificationException(
          'Ein bereits bestätigter Nachweis kann nicht entfernt werden.',
        );
      }
      final paths = _stringMap(data['documentStoragePaths'])
        ..remove(documentKey);
      final statuses = existingStatuses;
      statuses[documentKey] = ProfileVerificationDocumentStatus.missing.name;
      final rejectionReasons = _stringMap(data['documentRejectionReasons'])
        ..remove(documentKey);
      transaction.set(
        reference,
        _draftData(
          userId: normalizedUserId,
          data: data,
          paths: paths,
          statuses: statuses,
          rejectionReasons: rejectionReasons,
          expirations: _timestampMap(data['documentExpiresAt']),
          lastEditedDocumentKey: documentKey,
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
      final statuses = _stringMap(data['documentStatuses']);
      final identityType = ProfileIdentityDocumentType.fromValue(
        data['identityDocumentType'],
      );
      final protectedDocumentKeys = switch (expirationKey) {
        ProfileVerificationDocumentKeys.identityExpiration => <String>[
          ProfileVerificationDocumentKeys.identityFront,
          if (identityType.requiresBack)
            ProfileVerificationDocumentKeys.identityBack,
        ],
        ProfileVerificationDocumentKeys.driverLicenseExpiration => <String>[
          ProfileVerificationDocumentKeys.driverLicenseFront,
          ProfileVerificationDocumentKeys.driverLicenseBack,
        ],
        _ => const <String>[],
      };
      if (protectedDocumentKeys.isNotEmpty &&
          protectedDocumentKeys.every(
            (key) =>
                ProfileVerificationDocumentStatus.fromValue(statuses[key]) ==
                ProfileVerificationDocumentStatus.verified,
          )) {
        throw const ProfileVerificationException(
          'Das Ablaufdatum eines bestätigten Nachweises kann nicht geändert werden.',
        );
      }
      final expirations = _timestampMap(data['documentExpiresAt']);
      expirations[expirationKey] = Timestamp.fromDate(expirationDay);
      transaction.set(
        reference,
        _draftData(
          userId: normalizedUserId,
          data: data,
          paths: _stringMap(data['documentStoragePaths']),
          statuses: statuses,
          rejectionReasons: _stringMap(data['documentRejectionReasons']),
          expirations: expirations,
          lastEditedDocumentKey: expirationKey,
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
    if (request != null &&
        request.vehicleId != null &&
        request.vehicleId != normalizedVehicleId &&
        const [
          ProfileVerificationDocumentKeys.vehicleFront,
          ProfileVerificationDocumentKeys.vehicleBack,
        ].any((key) => request.documentStoragePaths[key]?.isNotEmpty == true)) {
      throw const ProfileVerificationException(
        'Entferne zuerst die Fahrzeugnachweise, bevor du das Fahrzeug wechselst.',
      );
    }
    final data = request == null
        ? const <String, dynamic>{}
        : <String, dynamic>{
            'displayName': request.displayName,
            'identityDocumentType': request.identityDocumentType.name,
            'createdAt': request.createdAt == null
                ? FieldValue.serverTimestamp()
                : Timestamp.fromDate(request.createdAt!),
          };
    await _currentRequest(normalizedUserId).set(
      _draftData(
        userId: normalizedUserId,
        data: data,
        paths: {
          for (final entry
              in (request?.documentStoragePaths ?? const <String, String?>{})
                  .entries)
            if (entry.value?.trim().isNotEmpty == true)
              entry.key: entry.value!.trim(),
        },
        statuses: {
          for (final entry
              in (request?.documentStatuses ??
                      const <String, ProfileVerificationDocumentStatus>{})
                  .entries)
            entry.key: entry.value.name,
        },
        rejectionReasons: {
          for (final entry
              in (request?.documentRejectionReasons ??
                      const <String, String?>{})
                  .entries)
            if (entry.value != null) entry.key: entry.value!,
        },
        expirations: {
          for (final entry
              in (request?.documentExpiresAt ?? const <String, DateTime?>{})
                  .entries)
            if (entry.value != null)
              entry.key: Timestamp.fromDate(entry.value!),
        },
        vehicleId: normalizedVehicleId,
        vehicleRelationship: relationship.name,
        lastEditedDocumentKey: request?.lastEditedDocumentKey,
      ),
      SetOptions(merge: false),
    );
  }

  Future<void> saveDraftIdentityDocumentType({
    required String userId,
    required ProfileIdentityDocumentType identityDocumentType,
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
      final paths = _stringMap(data['documentStoragePaths']);
      if (const [
        ProfileVerificationDocumentKeys.identityFront,
        ProfileVerificationDocumentKeys.identityBack,
      ].any((key) => paths[key]?.isNotEmpty == true)) {
        throw const ProfileVerificationException(
          'Entferne zuerst den vorhandenen Identitätsnachweis.',
        );
      }
      transaction.set(
        reference,
        _draftData(
          userId: normalizedUserId,
          data: data,
          paths: paths,
          statuses: _stringMap(data['documentStatuses']),
          rejectionReasons: _stringMap(data['documentRejectionReasons']),
          expirations: _timestampMap(data['documentExpiresAt']),
          identityDocumentType: identityDocumentType.name,
          lastEditedDocumentKey: ProfileVerificationDocumentKeys.identityFront,
        ),
        SetOptions(merge: false),
      );
    });
  }

  Future<void> saveDraftProgress({
    required String userId,
    required String documentKey,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty ||
        !<String>{
          ...ProfileVerificationDocumentKeys.required,
          ...ProfileVerificationDocumentKeys.requiredExpirationKeys,
        }.contains(documentKey)) {
      return;
    }
    final reference = _currentRequest(normalizedUserId);
    final snapshot = await reference.get();
    if (!snapshot.exists) return;
    final status = ProfileVerificationStatus.fromValue(
      snapshot.data()?['status'],
    );
    if (status != ProfileVerificationStatus.draft) {
      return;
    }
    await reference.update({
      'lastEditedDocumentKey': documentKey,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  Future<void> reviewDocuments({
    required ProfileVerificationRequest request,
    required Map<String, ProfileVerificationDocumentStatus> decisions,
    Map<String, String> rejectionReasons = const {},
  }) async {
    final openKeys = request.requiredDocumentKeys.where(
      (key) =>
          request.documentStatusFor(key) ==
          ProfileVerificationDocumentStatus.inReview,
    );
    if (openKeys.isEmpty ||
        openKeys.any(
          (key) =>
              decisions[key] != ProfileVerificationDocumentStatus.verified &&
              decisions[key] != ProfileVerificationDocumentStatus.rejected,
        )) {
      throw const ProfileVerificationException(
        'Bitte entscheide über jeden offenen Nachweis.',
      );
    }
    for (final key in openKeys) {
      if (decisions[key] == ProfileVerificationDocumentStatus.rejected &&
          (rejectionReasons[key]?.trim().length ?? 0) < 5) {
        throw const ProfileVerificationException(
          'Bitte gib für jeden abgelehnten Nachweis einen konkreten Grund an.',
        );
      }
    }
    final hasRejection = openKeys.any(
      (key) => decisions[key] == ProfileVerificationDocumentStatus.rejected,
    );
    try {
      await _cloudFunctions.httpsCallable('reviewProfileVerification').call({
        'requestId': request.requestId,
        'decision': hasRejection ? 'rejected' : 'verified',
        'reason': hasRejection
            ? 'Mindestens ein Nachweis muss erneut eingereicht werden.'
            : null,
        'documentDecisions': {
          for (final key in openKeys) key: decisions[key]!.name,
        },
        'documentReasons': {
          for (final key in openKeys)
            if (rejectionReasons[key]?.trim().isNotEmpty == true)
              key: rejectionReasons[key]!.trim(),
        },
      });
    } on FirebaseFunctionsException catch (error) {
      throw ProfileVerificationException(_functionsErrorMessage(error));
    }
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

  static Map<String, dynamic> _draftData({
    required String userId,
    required Map<String, dynamic> data,
    required Map<String, String> paths,
    required Map<String, String> statuses,
    required Map<String, String> rejectionReasons,
    required Map<String, Timestamp> expirations,
    String? identityDocumentType,
    String? vehicleId,
    String? vehicleRelationship,
    String? lastEditedDocumentKey,
  }) {
    return <String, dynamic>{
      'requestId': userId,
      'userId': userId,
      'profilePath': CaRismaFirestorePaths.userProfile(userId),
      'status': ProfileVerificationStatus.draft.name,
      'displayName': data['displayName'] is String ? data['displayName'] : '',
      'identityDocumentType':
          identityDocumentType ??
          data['identityDocumentType'] ??
          ProfileIdentityDocumentType.identityCard.name,
      'documentStoragePaths': paths,
      'documentStatuses': statuses,
      'documentRejectionReasons': rejectionReasons,
      'documentExpiresAt': expirations,
      'vehicleId': vehicleId ?? data['vehicleId'],
      'vehicleRelationship':
          vehicleRelationship ??
          data['vehicleRelationship'] ??
          ProfileVehicleRelationship.owner.name,
      'lastEditedDocumentKey':
          lastEditedDocumentKey ?? data['lastEditedDocumentKey'],
      'authorizationConfirmed': false,
      'consentVersion': null,
      'consentAcceptedAt': null,
      'submittedAt': null,
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
      'retentionUntil': null,
      'verificationExpiresAt': null,
      'documentsCleanedAt': data['documentsCleanedAt'],
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
