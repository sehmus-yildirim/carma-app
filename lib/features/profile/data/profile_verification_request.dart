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

enum ProfileVerificationIdentityDocumentType {
  identityCard,
  passport,
  residencePermit;

  static ProfileVerificationIdentityDocumentType fromValue(Object? value) {
    final normalized = value?.toString().trim();
    return values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => ProfileVerificationIdentityDocumentType.identityCard,
    );
  }

  String get label => switch (this) {
    ProfileVerificationIdentityDocumentType.identityCard => 'Personalausweis',
    ProfileVerificationIdentityDocumentType.passport => 'Reisepass',
    ProfileVerificationIdentityDocumentType.residencePermit =>
      'Aufenthaltstitel',
  };

  bool get requiresBackSide =>
      this != ProfileVerificationIdentityDocumentType.passport;
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

  static const identityGroup = 'identity';
  static const driverLicenseGroup = 'driverLicense';
  static const vehicleGroup = 'vehicle';

  static const groupKeys = <String>[
    identityGroup,
    driverLicenseGroup,
    vehicleGroup,
  ];

  static const groups = <ProfileVerificationDocumentGroup>[
    ProfileVerificationDocumentGroup(
      groupKey: identityGroup,
      title: 'Identität bestätigen',
      subtitle: 'Amtlicher Lichtbildausweis, vollständig und gut lesbar.',
      iconName: 'identity',
      frontKey: identityFront,
      backKey: identityBack,
      expirationKey: identityExpiration,
    ),
    ProfileVerificationDocumentGroup(
      groupKey: driverLicenseGroup,
      title: 'Führerschein',
      subtitle: 'Gültiger Führerschein als zusätzlicher Identitätsnachweis.',
      iconName: 'driverLicense',
      frontKey: driverLicenseFront,
      backKey: driverLicenseBack,
      expirationKey: driverLicenseExpiration,
    ),
    ProfileVerificationDocumentGroup(
      groupKey: vehicleGroup,
      title: 'Fahrzeugbezug bestätigen',
      subtitle: 'Fahrzeugschein oder geeigneter Berechtigungsnachweis.',
      iconName: 'vehicle',
      frontKey: vehicleFront,
      backKey: vehicleBack,
      includesVehicleAssignment: true,
    ),
  ];

  static List<String> requiredFor(
    ProfileVerificationIdentityDocumentType identityType,
  ) {
    return <String>[
      identityFront,
      if (identityType.requiresBackSide) identityBack,
      driverLicenseFront,
      driverLicenseBack,
      vehicleFront,
      vehicleBack,
    ];
  }

  static List<String> keysForGroup(
    String groupKey,
    ProfileVerificationIdentityDocumentType identityType,
  ) {
    return switch (groupKey) {
      identityGroup => <String>[
        identityFront,
        if (identityType.requiresBackSide) identityBack,
      ],
      driverLicenseGroup => const <String>[
        driverLicenseFront,
        driverLicenseBack,
      ],
      vehicleGroup => const <String>[vehicleFront, vehicleBack],
      _ => const <String>[],
    };
  }

  static String groupFor(String key) => switch (key) {
    identityFront || identityBack => identityGroup,
    driverLicenseFront || driverLicenseBack => driverLicenseGroup,
    vehicleFront || vehicleBack => vehicleGroup,
    _ => '',
  };

  static String groupLabel(String groupKey) => switch (groupKey) {
    identityGroup => 'Identität',
    driverLicenseGroup => 'Führerschein',
    vehicleGroup => 'Fahrzeug',
    _ => 'Nachweis',
  };

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
    required this.groupKey,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.frontKey,
    required this.backKey,
    this.expirationKey,
    this.includesVehicleAssignment = false,
  });

  final String groupKey;
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
    this.identityDocumentType =
        ProfileVerificationIdentityDocumentType.identityCard,
    this.documentExpiresAt = const {},
    this.documentRejectionReasons = const {},
    this.vehicleId,
    this.vehicleRelationship = ProfileVehicleRelationship.owner,
    this.authorizationConfirmed = false,
    this.vehicleAssignmentConfirmed = false,
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
    this.documentsCleanedAt,
    this.submittedDocumentGroups = const [],
    this.legacyDocumentRemoteUrls = const {},
  });

  final String requestId;
  final String userId;
  final String profilePath;
  final ProfileVerificationStatus status;
  final String displayName;
  final Map<String, String?> documentStoragePaths;
  final Map<String, ProfileVerificationDocumentStatus> documentStatuses;
  final ProfileVerificationIdentityDocumentType identityDocumentType;
  final Map<String, DateTime?> documentExpiresAt;
  final Map<String, String?> documentRejectionReasons;
  final String? vehicleId;
  final ProfileVehicleRelationship vehicleRelationship;
  final bool authorizationConfirmed;
  final bool vehicleAssignmentConfirmed;
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
  final DateTime? documentsCleanedAt;
  final List<String> submittedDocumentGroups;

  // Read-only migration support. New requests never write download URLs.
  final Map<String, String?> legacyDocumentRemoteUrls;

  bool get isLocked =>
      status == ProfileVerificationStatus.pending ||
      status == ProfileVerificationStatus.verified;

  List<String> get requiredDocumentKeys =>
      ProfileVerificationDocumentKeys.requiredFor(identityDocumentType);

  int get completedDocumentCount => requiredDocumentKeys.where((key) {
    final status = documentStatusFor(key);
    return status != ProfileVerificationDocumentStatus.missing &&
        status != ProfileVerificationDocumentStatus.uploading &&
        status != ProfileVerificationDocumentStatus.rejected &&
        status != ProfileVerificationDocumentStatus.expired;
  }).length;

  bool get hasAllRequiredDocuments =>
      completedDocumentCount == requiredDocumentKeys.length;

  bool canEditDocument(String key) {
    if (!requiredDocumentKeys.contains(key) &&
        key != ProfileVerificationDocumentKeys.identityBack) {
      return false;
    }
    if (status == ProfileVerificationStatus.pending ||
        status == ProfileVerificationStatus.verified) {
      return false;
    }
    final documentStatus = documentStatusFor(key);
    return documentStatus != ProfileVerificationDocumentStatus.inReview &&
        documentStatus != ProfileVerificationDocumentStatus.verified;
  }

  bool isGroupVerified(String groupKey) {
    final keys = ProfileVerificationDocumentKeys.keysForGroup(
      groupKey,
      identityDocumentType,
    );
    return keys.isNotEmpty &&
        keys.every(
          (key) =>
              documentStatusFor(key) ==
              ProfileVerificationDocumentStatus.verified,
        );
  }

  bool isGroupProtected(String groupKey) {
    final keys = ProfileVerificationDocumentKeys.keysForGroup(
      groupKey,
      identityDocumentType,
    );
    return keys.any((key) {
      final status = documentStatusFor(key);
      return status == ProfileVerificationDocumentStatus.verified ||
          status == ProfileVerificationDocumentStatus.inReview;
    });
  }

  ProfileVerificationDocumentStatus groupStatus(String groupKey) {
    final statuses = ProfileVerificationDocumentKeys.keysForGroup(
      groupKey,
      identityDocumentType,
    ).map(documentStatusFor).toList(growable: false);
    for (final status in const [
      ProfileVerificationDocumentStatus.rejected,
      ProfileVerificationDocumentStatus.expired,
      ProfileVerificationDocumentStatus.inReview,
      ProfileVerificationDocumentStatus.uploading,
      ProfileVerificationDocumentStatus.uploaded,
      ProfileVerificationDocumentStatus.missing,
    ]) {
      if (statuses.contains(status)) return status;
    }
    return ProfileVerificationDocumentStatus.verified;
  }

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
      identityDocumentType: ProfileVerificationIdentityDocumentType.fromValue(
        data['identityDocumentType'],
      ),
      documentExpiresAt: _dateTimeMap(data['documentExpiresAt']),
      documentRejectionReasons: _nullableStringMap(
        data['documentRejectionReasons'],
      ),
      vehicleId: data['vehicleId'] as String?,
      vehicleRelationship: ProfileVehicleRelationship.fromValue(
        data['vehicleRelationship'],
      ),
      authorizationConfirmed: data['authorizationConfirmed'] as bool? ?? false,
      vehicleAssignmentConfirmed:
          data['vehicleAssignmentConfirmed'] as bool? ?? false,
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
      documentsCleanedAt: _dateTimeFromValue(data['documentsCleanedAt']),
      submittedDocumentGroups: _stringList(data['submittedDocumentGroups']),
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

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}

class ProfileVerificationHistoryEntry {
  const ProfileVerificationHistoryEntry({
    required this.id,
    required this.status,
    this.reason,
    this.createdAt,
    this.documentGroups = const [],
    this.validUntil,
    this.eventType,
  });

  final String id;
  final ProfileVerificationStatus status;
  final String? reason;
  final DateTime? createdAt;
  final List<String> documentGroups;
  final DateTime? validUntil;
  final String? eventType;

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
      documentGroups: ProfileVerificationRequest._stringList(
        data['documentGroups'],
      ),
      validUntil: ProfileVerificationRequest._dateTimeFromValue(
        data['validUntil'],
      ),
      eventType: data['eventType'] as String?,
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
    this.documentGroup,
    this.expiresAt,
    this.daysRemaining,
  });

  final String id;
  final String requestId;
  final ProfileVerificationStatus status;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? documentGroup;
  final DateTime? expiresAt;
  final int? daysRemaining;

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
      documentGroup: data['documentGroup'] as String?,
      expiresAt: ProfileVerificationRequest._dateTimeFromValue(
        data['expiresAt'],
      ),
      daysRemaining: data['daysRemaining'] as int?,
    );
  }
}
