import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';
import '../../../shared/plate/german_plate_region_codes.dart';
import '../domain/report_draft.dart';

class ReportRepository {
  ReportRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Stream<List<ReportNotificationRecord>> watchReportNotifications({
    required String userId,
  }) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<List<ReportNotificationRecord>>.value(
        const <ReportNotificationRecord>[],
      );
    }

    return _firestore
        .collection(
          CaRismaFirestorePaths.userReportNotifications(trimmedUserId),
        )
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(ReportNotificationRecord.fromSnapshot)
              .where(_isVisibleOneDayNotification)
              .toList(growable: false);
        });
  }

  Future<void> markReportNotificationRead({
    required String userId,
    required String reportId,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedReportId = reportId.trim();

    if (trimmedUserId.isEmpty || trimmedReportId.isEmpty) {
      return;
    }

    await _firestore
        .doc(
          CaRismaFirestorePaths.userReportNotification(
            trimmedUserId,
            trimmedReportId,
          ),
        )
        .update({
          'status': FirestoreReportNotificationStatus.read,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<String> reportEvidenceDownloadUrl(
    ReportNotificationRecord notification,
  ) async {
    final imagePath = notification.imagePath?.trim();

    if (imagePath == null || imagePath.isEmpty) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'not-found',
        message: 'Zu diesem Hinweis ist kein Foto hinterlegt.',
      );
    }

    return _storage.ref(imagePath).getDownloadURL();
  }

  Stream<List<ReportNotificationRecord>> watchSentReportNotifications({
    required String userId,
  }) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<List<ReportNotificationRecord>>.value(
        const <ReportNotificationRecord>[],
      );
    }

    return _firestore
        .collection(
          CaRismaFirestorePaths.userSentReportNotifications(trimmedUserId),
        )
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(ReportNotificationRecord.fromSnapshot)
              .where(_isVisibleOneDayNotification)
              .toList(growable: false);
        });
  }

  Future<String> submitPlateHint(ReportDraft draft) async {
    final reporter = _auth.currentUser;

    if (reporter == null) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'unauthenticated',
        message: 'Bitte melde dich an, um einen Hinweis zu senden.',
      );
    }

    if (!draft.canSubmit || draft.category == null) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-argument',
        message: 'Der Hinweis ist noch nicht vollständig.',
      );
    }

    final countryCode = draft.countryCode.trim().toUpperCase();
    final plateRegion = _normalizePlate(draft.region);
    final plateLetters = _normalizePlate(draft.letters);
    final plateNumbers = _normalizePlate(draft.numbers);
    final plateKey = _normalizePlate('$plateRegion$plateLetters$plateNumbers');

    if (!const {'DE', 'AT', 'CH'}.contains(countryCode) || plateKey.isEmpty) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-argument',
        message: 'Bitte prüfe das Kennzeichen.',
      );
    }

    final plateSnapshot = await _firestore
        .doc(CaRismaFirestorePaths.plate(countryCode, plateKey))
        .get();
    final plateData = plateSnapshot.data();

    if (plateData == null ||
        plateData['isActive'] != true ||
        plateData['isDeleted'] == true) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'not-found',
        message: 'Für dieses Kennzeichen wurde kein aktiver Nutzer gefunden.',
      );
    }

    if (plateData['allowAnonymousReports'] != true) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'permission-denied',
        message: 'Dieser Nutzer nimmt aktuell keine anonymen Hinweise an.',
      );
    }

    final targetUserId = (plateData['ownerUserId'] as String? ?? '').trim();
    if (targetUserId.isEmpty) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'not-found',
        message: 'Für dieses Kennzeichen wurde kein aktiver Nutzer gefunden.',
      );
    }

    if (targetUserId == reporter.uid) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-argument',
        message: 'Du kannst dir nicht selbst einen Hinweis senden.',
      );
    }

    final locationData = _validatedLocationData(draft);
    final reportDocument = _firestore
        .collection(CaRismaFirestoreCollections.reports)
        .doc();
    Reference? uploadedImageReference;

    try {
      uploadedImageReference = await _uploadEvidenceImage(
        draft: draft,
        reportId: reportDocument.id,
        reporterUserId: reporter.uid,
      );
      final imagePath = uploadedImageReference?.fullPath;
      final now = FieldValue.serverTimestamp();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      final reportData = <String, Object?>{
        'reportId': reportDocument.id,
        'type': 'plate_hint',
        'reporterUserId': reporter.uid,
        'targetUserId': targetUserId,
        'countryCode': countryCode,
        'plateKey': plateKey,
        'plateRegion': plateRegion,
        'plateLetters': plateLetters,
        'plateNumbers': plateNumbers,
        'category': draft.category!.name,
        'message': draft.normalizedMessage.substring(
          0,
          draft.normalizedMessage.length.clamp(0, 160),
        ),
        ...locationData,
        'status': FirestoreReportStatus.submitted,
        'hasImage': imagePath != null,
        'imagePath': ?imagePath,
        'anonymousToTarget': true,
        'createdAt': now,
        'updatedAt': now,
        'expiresAt': expiresAt,
        'isDeleted': false,
      };
      final targetNotificationDocument = _firestore.doc(
        CaRismaFirestorePaths.userReportNotification(
          targetUserId,
          reportDocument.id,
        ),
      );
      final targetNotificationData = <String, Object?>{
        'reportId': reportDocument.id,
        'type': 'plate_hint',
        'targetUserId': targetUserId,
        'countryCode': countryCode,
        'plateKey': plateKey,
        'plateRegion': plateRegion,
        'plateLetters': plateLetters,
        'plateNumbers': plateNumbers,
        'category': draft.category!.name,
        'message': draft.normalizedMessage.substring(
          0,
          draft.normalizedMessage.length.clamp(0, 160),
        ),
        ...locationData,
        'status': FirestoreReportNotificationStatus.unread,
        'hasImage': imagePath != null,
        'imagePath': ?imagePath,
        'anonymousToTarget': true,
        'createdAt': now,
        'updatedAt': now,
        'expiresAt': expiresAt,
        'isDeleted': false,
      };
      final senderHistoryDocument = _firestore.doc(
        CaRismaFirestorePaths.userSentReportNotification(
          reporter.uid,
          reportDocument.id,
        ),
      );
      final senderHistoryData = <String, Object?>{
        'reportId': reportDocument.id,
        'type': 'plate_hint',
        'countryCode': countryCode,
        'plateKey': plateKey,
        'plateRegion': plateRegion,
        'plateLetters': plateLetters,
        'plateNumbers': plateNumbers,
        'category': draft.category!.name,
        'message': draft.normalizedMessage.substring(
          0,
          draft.normalizedMessage.length.clamp(0, 160),
        ),
        ...locationData,
        'status': FirestoreReportStatus.submitted,
        'hasImage': imagePath != null,
        'imagePath': ?imagePath,
        'anonymousToTarget': true,
        'createdAt': now,
        'updatedAt': now,
        'expiresAt': expiresAt,
        'isDeleted': false,
      };

      final batch = _firestore.batch();
      batch.set(reportDocument, reportData);
      batch.set(targetNotificationDocument, targetNotificationData);
      batch.set(senderHistoryDocument, senderHistoryData);
      await batch.commit();
    } catch (_) {
      if (uploadedImageReference != null) {
        try {
          await uploadedImageReference.delete();
        } catch (_) {
          // Der ursprüngliche Upload-/Firestore-Fehler bleibt maßgeblich.
        }
      }

      rethrow;
    }

    return reportDocument.id;
  }

  Future<Reference?> _uploadEvidenceImage({
    required ReportDraft draft,
    required String reportId,
    required String reporterUserId,
  }) async {
    final localPath = draft.imageLocalPath?.trim() ?? '';
    if (localPath.isEmpty) {
      return null;
    }

    final lowerPath = localPath.toLowerCase();
    if (!lowerPath.endsWith('.jpg') && !lowerPath.endsWith('.jpeg')) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-image',
        message: 'Das Beweisfoto muss ein JPEG-Bild sein.',
      );
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-image',
        message: 'Das ausgewählte Foto wurde nicht gefunden.',
      );
    }

    final size = await file.length();
    if (size <= 0 || size >= 10 * 1024 * 1024) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-image',
        message: 'Das Beweisfoto darf höchstens 10 MB groß sein.',
      );
    }

    final reference = _storage.ref(
      'report_images/$reportId/$reporterUserId/evidence.jpg',
    );
    await reference.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'reportId': reportId},
      ),
    );

    return reference;
  }

  Map<String, Object> _validatedLocationData(ReportDraft draft) {
    if (draft.useGpsLocation) {
      final latitude = draft.latitude;
      final longitude = draft.longitude;

      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        throw FirebaseException(
          plugin: 'carisma',
          code: 'invalid-argument',
          message: 'Der Standort ist ungültig.',
        );
      }

      return {
        'locationMode': 'gps',
        'latitude': latitude,
        'longitude': longitude,
        'locationLabel': _limitedText(
          draft.locationLabel ?? 'GPS-Standort erfasst',
          160,
        ),
      };
    }

    final manualAddress = draft.manualAddress?.trim() ?? '';
    if (manualAddress.length < 3 || manualAddress.length > 160) {
      throw FirebaseException(
        plugin: 'carisma',
        code: 'invalid-argument',
        message: 'Bitte gib eine gültige Adresse ein.',
      );
    }

    return {
      'locationMode': 'manual',
      'manualAddress': manualAddress,
      'locationLabel': manualAddress,
    };
  }

  String _normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');
  }

  String _limitedText(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }

    return trimmed.substring(0, maxLength).trimRight();
  }

  bool _isVisibleOneDayNotification(ReportNotificationRecord notification) {
    if (notification.isDeleted) {
      return false;
    }

    final createdAt = notification.createdAt;
    if (createdAt == null) {
      return true;
    }

    return createdAt.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }
}

class ReportNotificationRecord {
  const ReportNotificationRecord({
    required this.id,
    required this.reportId,
    required this.countryCode,
    required this.plateKey,
    required this.plateRegion,
    required this.plateLetters,
    required this.plateNumbers,
    required this.category,
    required this.message,
    required this.locationMode,
    required this.manualAddress,
    required this.rawLocationLabel,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.hasImage,
    required this.imagePath,
    required this.isDeleted,
    required this.createdAt,
  });

  final String id;
  final String reportId;
  final String countryCode;
  final String plateKey;
  final String plateRegion;
  final String plateLetters;
  final String plateNumbers;
  final String category;
  final String message;
  final String locationMode;
  final String? manualAddress;
  final String? rawLocationLabel;
  final double? latitude;
  final double? longitude;
  final String status;
  final bool hasImage;
  final String? imagePath;
  final bool isDeleted;
  final DateTime? createdAt;

  bool get isUnread {
    return status == FirestoreReportNotificationStatus.unread;
  }

  String get formattedPlate {
    if (plateRegion.isNotEmpty &&
        plateLetters.isNotEmpty &&
        plateNumbers.isNotEmpty) {
      return '$plateRegion-$plateLetters $plateNumbers';
    }

    if (countryCode == 'DE' && plateKey.length >= 4) {
      final formattedFromRegion = _formatGermanPlateFromKey(plateKey);
      if (formattedFromRegion != plateKey) {
        return formattedFromRegion;
      }

      final match = RegExp(
        r'^([A-Z]{1,3})([A-Z]{1,2})([0-9]{1,4})$',
      ).firstMatch(plateKey);
      if (match != null) {
        return '${match.group(1)}-${match.group(2)} ${match.group(3)}';
      }
    }

    return plateKey;
  }

  String get locationLabel {
    if (locationMode == 'manual') {
      final address = manualAddress?.trim();
      if (address != null && address.isNotEmpty) {
        return address;
      }
    }

    final label = rawLocationLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }

    if (latitude != null && longitude != null) {
      return 'GPS-Standort erfasst';
    }

    return 'Standort nicht verfügbar';
  }

  factory ReportNotificationRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return ReportNotificationRecord(
      id: snapshot.id,
      reportId: _stringValue(data['reportId'], fallback: snapshot.id),
      countryCode: _stringValue(data['countryCode'], fallback: 'DE'),
      plateKey: _stringValue(data['plateKey']),
      plateRegion: _stringValue(data['plateRegion']),
      plateLetters: _stringValue(data['plateLetters']),
      plateNumbers: _stringValue(data['plateNumbers']),
      category: _stringValue(data['category']),
      message: _stringValue(data['message']),
      locationMode: _stringValue(data['locationMode']),
      manualAddress: data['manualAddress'] as String?,
      rawLocationLabel: _nullableStringValue(data['locationLabel']),
      latitude: _numberValue(data['latitude']),
      longitude: _numberValue(data['longitude']),
      status: _stringValue(
        data['status'],
        fallback: FirestoreReportNotificationStatus.unread,
      ),
      hasImage: data['hasImage'] == true,
      imagePath: _nullableStringValue(data['imagePath']),
      isDeleted: data['isDeleted'] == true,
      createdAt: _dateTimeValue(data['createdAt']),
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static String? _nullableStringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  static String _formatGermanPlateFromKey(String value) {
    final normalized = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final regionCodes = germanPlateRegionCodesBySpeechKey.values.toSet();

    for (var regionLength = 3; regionLength >= 1; regionLength--) {
      if (normalized.length <= regionLength + 1) {
        continue;
      }

      final region = normalized.substring(0, regionLength);
      if (!regionCodes.contains(region)) {
        continue;
      }

      final rest = normalized.substring(regionLength);
      final match = RegExp(r'^([A-Z]{1,2})([0-9]{1,4})$').firstMatch(rest);
      if (match != null) {
        return '$region-${match.group(1)} ${match.group(2)}';
      }
    }

    return value;
  }

  static double? _numberValue(Object? value) {
    if (value is int) {
      return value.toDouble();
    }

    if (value is double) {
      return value;
    }

    return null;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
