enum VerificationDocumentType {
  idFront,
  idBack,
  driverLicenseFront,
  driverLicenseBack,
  vehicleRegistrationFront,
  vehicleRegistrationBack,
}

enum VerificationDocumentStatus {
  missing,
  uploaded,
  pendingReview,
  approved,
  rejected,
}

class VerificationDocument {
  const VerificationDocument({
    required this.id,
    required this.type,
    required this.status,
    this.localPath,
    this.remoteUrl,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
  });

  final String id;
  final VerificationDocumentType type;
  final VerificationDocumentStatus status;
  final String? localPath;
  final String? remoteUrl;
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  String get title {
    return switch (type) {
      VerificationDocumentType.idFront => 'Ausweis Vorderseite',
      VerificationDocumentType.idBack => 'Ausweis Rückseite',
      VerificationDocumentType.driverLicenseFront => 'Führerschein Vorderseite',
      VerificationDocumentType.driverLicenseBack => 'Führerschein Rückseite',
      VerificationDocumentType.vehicleRegistrationFront =>
      'Fahrzeugschein Vorderseite',
      VerificationDocumentType.vehicleRegistrationBack =>
      'Fahrzeugschein Rückseite',
    };
  }

  bool get isUploaded {
    return localPath != null || remoteUrl != null;
  }

  bool get isLocked {
    return status == VerificationDocumentStatus.pendingReview ||
        status == VerificationDocumentStatus.approved;
  }

  VerificationDocument copyWith({
    String? id,
    VerificationDocumentType? type,
    VerificationDocumentStatus? status,
    String? localPath,
    String? remoteUrl,
    String? rejectionReason,
    DateTime? uploadedAt,
    DateTime? reviewedAt,
  }) {
    return VerificationDocument(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'status': status.name,
      'localPath': localPath,
      'remoteUrl': remoteUrl,
      'rejectionReason': rejectionReason,
      'uploadedAt': uploadedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }

  factory VerificationDocument.fromMap(Map<String, dynamic> map) {
    return VerificationDocument(
      id: map['id'] as String? ?? '',
      type: _documentTypeFromName(map['type'] as String?),
      status: _documentStatusFromName(map['status'] as String?),
      localPath: map['localPath'] as String?,
      remoteUrl: map['remoteUrl'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      uploadedAt: _dateTimeFromValue(map['uploadedAt']),
      reviewedAt: _dateTimeFromValue(map['reviewedAt']),
    );
  }

  static VerificationDocumentType _documentTypeFromName(String? name) {
    return VerificationDocumentType.values.firstWhere(
          (type) => type.name == name,
      orElse: () => VerificationDocumentType.idFront,
    );
  }

  static VerificationDocumentStatus _documentStatusFromName(String? name) {
    return VerificationDocumentStatus.values.firstWhere(
          (status) => status.name == name,
      orElse: () => VerificationDocumentStatus.missing,
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  @override
  String toString() {
    return '$title (${status.name})';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VerificationDocument &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            type == other.type &&
            status == other.status &&
            localPath == other.localPath &&
            remoteUrl == other.remoteUrl &&
            rejectionReason == other.rejectionReason &&
            uploadedAt == other.uploadedAt &&
            reviewedAt == other.reviewedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      status,
      localPath,
      remoteUrl,
      rejectionReason,
      uploadedAt,
      reviewedAt,
    );
  }
}