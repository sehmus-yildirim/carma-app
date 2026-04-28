import 'carma_plate.dart';

enum ReportType {
  parkingIssue,
  lightsOn,
  windowOpen,
  damageObserved,
  danger,
  abuse,
  other,
}

enum ReportStatus {
  draft,
  submitted,
  pendingReview,
  delivered,
  dismissed,
  blocked,
  deleted,
}

class Report {
  const Report({
    required this.id,
    required this.senderUserId,
    required this.targetPlate,
    required this.type,
    required this.status,
    required this.message,
    this.targetUserId,
    this.vehicleDescription,
    this.imageLocalPath,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.deliveredAt,
  });

  final String id;
  final String senderUserId;
  final String? targetUserId;
  final CarmaPlate targetPlate;
  final ReportType type;
  final ReportStatus status;
  final String message;
  final String? vehicleDescription;
  final String? imageLocalPath;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final DateTime? deliveredAt;

  bool get hasImage {
    return imageLocalPath != null || imageUrl != null;
  }

  bool get isSubmitted {
    return status == ReportStatus.submitted ||
        status == ReportStatus.pendingReview ||
        status == ReportStatus.delivered;
  }

  bool get isClosed {
    return status == ReportStatus.delivered ||
        status == ReportStatus.dismissed ||
        status == ReportStatus.blocked ||
        status == ReportStatus.deleted;
  }

  bool get requiresReview {
    return type == ReportType.abuse ||
        type == ReportType.danger ||
        status == ReportStatus.pendingReview;
  }

  String get typeLabel {
    return switch (type) {
      ReportType.parkingIssue => 'Parkhinweis',
      ReportType.lightsOn => 'Licht angelassen',
      ReportType.windowOpen => 'Fenster offen',
      ReportType.damageObserved => 'Schaden bemerkt',
      ReportType.danger => 'Gefahrensituation',
      ReportType.abuse => 'Missbrauch melden',
      ReportType.other => 'Sonstiger Hinweis',
    };
  }

  String get previewText {
    final normalizedMessage = message.trim();

    if (normalizedMessage.isNotEmpty) {
      return normalizedMessage;
    }

    return typeLabel;
  }

  Report copyWith({
    String? id,
    String? senderUserId,
    String? targetUserId,
    CarmaPlate? targetPlate,
    ReportType? type,
    ReportStatus? status,
    String? message,
    String? vehicleDescription,
    String? imageLocalPath,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
    DateTime? deliveredAt,
  }) {
    return Report(
      id: id ?? this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      targetUserId: targetUserId ?? this.targetUserId,
      targetPlate: targetPlate ?? this.targetPlate,
      type: type ?? this.type,
      status: status ?? this.status,
      message: message ?? this.message,
      vehicleDescription: vehicleDescription ?? this.vehicleDescription,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUserId': senderUserId,
      'targetUserId': targetUserId,
      'targetPlate': targetPlate.toMap(),
      'type': type.name,
      'typeLabel': typeLabel,
      'status': status.name,
      'message': message,
      'vehicleDescription': vehicleDescription,
      'imageLocalPath': imageLocalPath,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    final rawPlate = map['targetPlate'];

    return Report(
      id: map['id'] as String? ?? '',
      senderUserId: map['senderUserId'] as String? ?? '',
      targetUserId: map['targetUserId'] as String?,
      targetPlate: rawPlate is Map<String, dynamic>
          ? CarmaPlate.fromMap(rawPlate)
          : const CarmaPlate(
        countryCode: 'DE',
        region: '',
        letters: '',
        numbers: '',
      ),
      type: _reportTypeFromName(map['type'] as String?),
      status: _reportStatusFromName(map['status'] as String?),
      message: map['message'] as String? ?? '',
      vehicleDescription: map['vehicleDescription'] as String?,
      imageLocalPath: map['imageLocalPath'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: _dateTimeFromValue(map['createdAt']),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
      reviewedAt: _dateTimeFromValue(map['reviewedAt']),
      deliveredAt: _dateTimeFromValue(map['deliveredAt']),
    );
  }

  static ReportType _reportTypeFromName(String? name) {
    return ReportType.values.firstWhere(
          (type) => type.name == name,
      orElse: () => ReportType.other,
    );
  }

  static ReportStatus _reportStatusFromName(String? name) {
    return ReportStatus.values.firstWhere(
          (status) => status.name == name,
      orElse: () => ReportStatus.draft,
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
    return '$typeLabel: $previewText';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Report &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            senderUserId == other.senderUserId &&
            targetUserId == other.targetUserId &&
            targetPlate == other.targetPlate &&
            type == other.type &&
            status == other.status &&
            message == other.message &&
            vehicleDescription == other.vehicleDescription &&
            imageLocalPath == other.imageLocalPath &&
            imageUrl == other.imageUrl &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            reviewedAt == other.reviewedAt &&
            deliveredAt == other.deliveredAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      senderUserId,
      targetUserId,
      targetPlate,
      type,
      status,
      message,
      vehicleDescription,
      imageLocalPath,
      imageUrl,
      createdAt,
      updatedAt,
      reviewedAt,
      deliveredAt,
    );
  }
}