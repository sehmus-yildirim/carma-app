import 'package:cloud_firestore/cloud_firestore.dart';

enum ProfileVerificationStatus {
  draft,
  pending,
  verified,
  rejected,
  expired;

  static ProfileVerificationStatus fromValue(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == 'approved') return ProfileVerificationStatus.verified;
    return values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => ProfileVerificationStatus.draft,
    );
  }
}

enum ProfileVerificationDocumentStatus {
  missing,
  uploading,
  uploaded,
  inReview,
  verified,
  rejected,
  expired;

  static ProfileVerificationDocumentStatus fromValue(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == 'pendingReview') {
      return ProfileVerificationDocumentStatus.inReview;
    }
    if (normalized == 'approved') {
      return ProfileVerificationDocumentStatus.verified;
    }
    return values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => ProfileVerificationDocumentStatus.missing,
    );
  }
}

enum ProfileVehicleRelationship {
  owner,
  leasingCompany,
  authorizedUser;

  static ProfileVehicleRelationship fromValue(Object? value) {
    final raw = value?.toString().trim();
    final normalized = raw == 'leasingCompanyFamily'
        ? ProfileVehicleRelationship.leasingCompany.name
        : raw;
    return values.firstWhere(
      (relationship) => relationship.name == normalized,
      orElse: () => ProfileVehicleRelationship.owner,
    );
  }
}

abstract final class ProfileVerificationDocumentKeys {
  static const identityFront = 'identityFront';
  static const identityBack = 'identityBack';
  static const driverLicenseFront = 'driverLicenseFront';
  static const driverLicenseBack = 'driverLicenseBack';
  static const vehicleFront = 'vehicleFront';
  static const vehicleBack = 'vehicleBack';

  static const identityExpiration = 'identity';
  static const driverLicenseExpiration = 'driverLicense';

  static const requiredExpirationKeys = <String>[
    identityExpiration,
    driverLicenseExpiration,
  ];

  static const required = <String>[
    identityFront,
    identityBack,
    driverLicenseFront,
    driverLicenseBack,
    vehicleFront,
    vehicleBack,
  ];

  static const groups = <ProfileVerificationDocumentGroup>[
    ProfileVerificationDocumentGroup(
      title: 'Identität bestätigen',
      subtitle: 'Amtlicher Lichtbildausweis, vollständig und gut lesbar.',
      iconName: 'identity',
      frontKey: identityFront,
      backKey: identityBack,
      expirationKey: identityExpiration,
    ),
    ProfileVerificationDocumentGroup(
      title: 'Führerschein',
      subtitle: 'Gültiger Führerschein als zusätzlicher Identitätsnachweis.',
      iconName: 'driverLicense',
      frontKey: driverLicenseFront,
      backKey: driverLicenseBack,
      expirationKey: driverLicenseExpiration,
    ),
    ProfileVerificationDocumentGroup(
      title: 'Fahrzeugbezug bestätigen',
      subtitle: 'Fahrzeugschein oder geeigneter Berechtigungsnachweis.',
      iconName: 'vehicle',
      frontKey: vehicleFront,
      backKey: vehicleBack,
      includesVehicleAssignment: true,
    ),
  ];

  static String labelFor(String key) => switch (key) {
    identityFront || identityBack => 'Identität',
    driverLicenseFront || driverLicenseBack => 'Führerschein',
    vehicleFront || vehicleBack => 'Fahrzeugbezug',
    _ => 'Nachweis',
  };

  static String sideLabelFor(String key) => switch (key) {
    identityFront || driverLicenseFront || vehicleFront => 'Vorderseite',
    identityBack || driverLicenseBack || vehicleBack => 'Rückseite',
    _ => 'Dokument',
  };
}

class ProfileVerificationDocumentGroup {
  const ProfileVerificationDocumentGroup({
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.frontKey,
    required this.backKey,
    this.expirationKey,
    this.includesVehicleAssignment = false,
  });

  final String title;
  final String subtitle;
  final String iconName;
  final String frontKey;
  final String backKey;
  final String? expirationKey;
  final bool includesVehicleAssignment;
}

class ProfileVerificationRequest {
  const ProfileVerificationRequest({
    required this.requestId,
    required this.userId,
    required this.profilePath,
    required this.status,
    required this.displayName,
    required this.documentStoragePaths,
    required this.documentStatuses,
    this.documentExpiresAt = const {},
    this.documentRejectionReasons = const {},
    this.vehicleId,
    this.vehicleRelationship = ProfileVehicleRelationship.owner,
    this.authorizationConfirmed = false,
    this.consentVersion,
    this.consentAcceptedAt,
    this.countryCode,
    this.plateRegion,
    this.plateLetters,
    this.plateNumbers,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.photoUrl,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.retentionUntil,
    this.legacyDocumentRemoteUrls = const {},
  });

  final String requestId;
  final String userId;
  final String profilePath;
  final ProfileVerificationStatus status;
  final String displayName;
  final Map<String, String?> documentStoragePaths;
  final Map<String, ProfileVerificationDocumentStatus> documentStatuses;
  final Map<String, DateTime?> documentExpiresAt;
  final Map<String, String?> documentRejectionReasons;
  final String? vehicleId;
  final ProfileVehicleRelationship vehicleRelationship;
  final bool authorizationConfirmed;
  final String? consentVersion;
  final DateTime? consentAcceptedAt;
  final String? countryCode;
  final String? plateRegion;
  final String? plateLetters;
  final String? plateNumbers;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? photoUrl;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final DateTime? retentionUntil;

  // Read-only migration support. New requests never write download URLs.
  final Map<String, String?> legacyDocumentRemoteUrls;

  bool get isLocked =>
      status == ProfileVerificationStatus.pending ||
      status == ProfileVerificationStatus.verified;

  int get completedDocumentCount =>
      ProfileVerificationDocumentKeys.required.where((key) {
        final status = documentStatusFor(key);
        return status != ProfileVerificationDocumentStatus.missing &&
            status != ProfileVerificationDocumentStatus.uploading &&
            status != ProfileVerificationDocumentStatus.rejected &&
            status != ProfileVerificationDocumentStatus.expired;
      }).length;

  bool get hasAllRequiredDocuments =>
      completedDocumentCount == ProfileVerificationDocumentKeys.required.length;

  DateTime? expirationFor(String key) => documentExpiresAt[key];

  bool hasValidRequiredExpirationsAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return ProfileVerificationDocumentKeys.requiredExpirationKeys.every((key) {
      final expiration = documentExpiresAt[key];
      if (expiration == null) return false;
      final expirationDay = DateTime(
        expiration.year,
        expiration.month,
        expiration.day,
      );
      return expirationDay.isAfter(today);
    });
  }

  ProfileVerificationDocumentStatus documentStatusFor(String key) {
    return documentStatuses[key] ??
        (documentStoragePaths[key]?.trim().isNotEmpty == true
            ? ProfileVerificationDocumentStatus.uploaded
            : ProfileVerificationDocumentStatus.missing);
  }

  factory ProfileVerificationRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    final storagePaths = _nullableStringMap(data['documentStoragePaths']);
    final legacyUrls = _nullableStringMap(data['documentRemoteUrls']);

    return ProfileVerificationRequest(
      requestId: data['requestId'] as String? ?? document.id,
      userId: data['userId'] as String? ?? '',
      profilePath: data['profilePath'] as String? ?? '',
      status: ProfileVerificationStatus.fromValue(data['status']),
      displayName: data['displayName'] as String? ?? '',
      documentStoragePaths: storagePaths,
      documentStatuses: _documentStatusMap(data['documentStatuses']),
      documentExpiresAt: _dateTimeMap(data['documentExpiresAt']),
      documentRejectionReasons: _nullableStringMap(
        data['documentRejectionReasons'],
      ),
      vehicleId: data['vehicleId'] as String?,
      vehicleRelationship: ProfileVehicleRelationship.fromValue(
        data['vehicleRelationship'],
      ),
      authorizationConfirmed: data['authorizationConfirmed'] as bool? ?? false,
      consentVersion: data['consentVersion'] as String?,
      consentAcceptedAt: _dateTimeFromValue(data['consentAcceptedAt']),
      countryCode: data['countryCode'] as String?,
      plateRegion: data['plateRegion'] as String?,
      plateLetters: data['plateLetters'] as String?,
      plateNumbers: data['plateNumbers'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      photoUrl: data['photoUrl'] as String?,
      submittedAt: _dateTimeFromValue(data['submittedAt']),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
      reviewedAt: _dateTimeFromValue(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      retentionUntil: _dateTimeFromValue(data['retentionUntil']),
      legacyDocumentRemoteUrls: legacyUrls,
    );
  }

  String get plateLabel {
    final region = plateRegion?.trim().toUpperCase() ?? '';
    final letters = plateLetters?.trim().toUpperCase() ?? '';
    final numbers = plateNumbers?.trim().toUpperCase() ?? '';
    if (region.isEmpty && letters.isEmpty && numbers.isEmpty) return '';
    final cityPart = letters.isEmpty ? region : '$region-$letters';
    return numbers.isEmpty ? cityPart : '$cityPart $numbers';
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, String?> _nullableStringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, mapValue) {
      return MapEntry(key.toString(), mapValue is String ? mapValue : null);
    });
  }

  static Map<String, ProfileVerificationDocumentStatus> _documentStatusMap(
    Object? value,
  ) {
    if (value is! Map) return const {};
    return value.map((key, mapValue) {
      return MapEntry(
        key.toString(),
        ProfileVerificationDocumentStatus.fromValue(mapValue),
      );
    });
  }

  static Map<String, DateTime?> _dateTimeMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, mapValue) {
      return MapEntry(key.toString(), _dateTimeFromValue(mapValue));
    });
  }
}

class ProfileVerificationHistoryEntry {
  const ProfileVerificationHistoryEntry({
    required this.id,
    required this.status,
    this.reason,
    this.createdAt,
  });

  final String id;
  final ProfileVerificationStatus status;
  final String? reason;
  final DateTime? createdAt;

  factory ProfileVerificationHistoryEntry.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ProfileVerificationHistoryEntry(
      id: document.id,
      status: ProfileVerificationStatus.fromValue(data['status']),
      reason: data['reason'] as String?,
      createdAt: ProfileVerificationRequest._dateTimeFromValue(
        data['createdAt'],
      ),
    );
  }
}

class ProfileVerificationNotification {
  const ProfileVerificationNotification({
    required this.id,
    required this.requestId,
    required this.status,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String requestId;
  final ProfileVerificationStatus status;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  factory ProfileVerificationNotification.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ProfileVerificationNotification(
      id: document.id,
      requestId: data['requestId'] as String? ?? '',
      status: ProfileVerificationStatus.fromValue(data['status']),
      message:
          data['message'] as String? ??
          'Der Status deiner Verifizierung wurde aktualisiert.',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: ProfileVerificationRequest._dateTimeFromValue(
        data['createdAt'],
      ),
    );
  }
}
