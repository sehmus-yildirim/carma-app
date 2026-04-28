import 'carma_plate.dart';

enum ContactRequestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired,
  blocked,
}

enum ContactRequestDirection {
  incoming,
  outgoing,
}

class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.senderUserId,
    required this.receiverUserId,
    required this.direction,
    required this.status,
    required this.targetPlate,
    required this.messagePreview,
    this.senderDisplayName,
    this.receiverDisplayName,
    this.vehicleDescription,
    this.createdAt,
    this.respondedAt,
    this.expiresAt,
  });

  final String id;
  final String senderUserId;
  final String receiverUserId;
  final ContactRequestDirection direction;
  final ContactRequestStatus status;
  final CarmaPlate targetPlate;
  final String messagePreview;
  final String? senderDisplayName;
  final String? receiverDisplayName;
  final String? vehicleDescription;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? expiresAt;

  bool get isPending {
    return status == ContactRequestStatus.pending;
  }

  bool get isAccepted {
    return status == ContactRequestStatus.accepted;
  }

  bool get isClosed {
    return status == ContactRequestStatus.accepted ||
        status == ContactRequestStatus.declined ||
        status == ContactRequestStatus.withdrawn ||
        status == ContactRequestStatus.expired ||
        status == ContactRequestStatus.blocked;
  }

  bool get isExpired {
    final expiration = expiresAt;

    if (expiration == null) {
      return false;
    }

    return DateTime.now().isAfter(expiration);
  }

  String get displayTitle {
    if (direction == ContactRequestDirection.incoming) {
      return senderDisplayName?.trim().isNotEmpty == true
          ? senderDisplayName!.trim()
          : 'Neue Kontaktanfrage';
    }

    return receiverDisplayName?.trim().isNotEmpty == true
        ? receiverDisplayName!.trim()
        : 'Gesendete Kontaktanfrage';
  }

  ContactRequest copyWith({
    String? id,
    String? senderUserId,
    String? receiverUserId,
    ContactRequestDirection? direction,
    ContactRequestStatus? status,
    CarmaPlate? targetPlate,
    String? messagePreview,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? vehicleDescription,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
  }) {
    return ContactRequest(
      id: id ?? this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      targetPlate: targetPlate ?? this.targetPlate,
      messagePreview: messagePreview ?? this.messagePreview,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      receiverDisplayName: receiverDisplayName ?? this.receiverDisplayName,
      vehicleDescription: vehicleDescription ?? this.vehicleDescription,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
      'direction': direction.name,
      'status': status.name,
      'targetPlate': targetPlate.toMap(),
      'messagePreview': messagePreview,
      'senderDisplayName': senderDisplayName,
      'receiverDisplayName': receiverDisplayName,
      'vehicleDescription': vehicleDescription,
      'createdAt': createdAt?.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory ContactRequest.fromMap(Map<String, dynamic> map) {
    final rawPlate = map['targetPlate'];

    return ContactRequest(
      id: map['id'] as String? ?? '',
      senderUserId: map['senderUserId'] as String? ?? '',
      receiverUserId: map['receiverUserId'] as String? ?? '',
      direction: _directionFromName(map['direction'] as String?),
      status: _statusFromName(map['status'] as String?),
      targetPlate: rawPlate is Map<String, dynamic>
          ? CarmaPlate.fromMap(rawPlate)
          : const CarmaPlate(
        countryCode: 'DE',
        region: '',
        letters: '',
        numbers: '',
      ),
      messagePreview: map['messagePreview'] as String? ?? '',
      senderDisplayName: map['senderDisplayName'] as String?,
      receiverDisplayName: map['receiverDisplayName'] as String?,
      vehicleDescription: map['vehicleDescription'] as String?,
      createdAt: _dateTimeFromValue(map['createdAt']),
      respondedAt: _dateTimeFromValue(map['respondedAt']),
      expiresAt: _dateTimeFromValue(map['expiresAt']),
    );
  }

  static ContactRequestDirection _directionFromName(String? name) {
    return ContactRequestDirection.values.firstWhere(
          (direction) => direction.name == name,
      orElse: () => ContactRequestDirection.incoming,
    );
  }

  static ContactRequestStatus _statusFromName(String? name) {
    return ContactRequestStatus.values.firstWhere(
          (status) => status.name == name,
      orElse: () => ContactRequestStatus.pending,
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
    return '$displayTitle (${status.name})';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ContactRequest &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            senderUserId == other.senderUserId &&
            receiverUserId == other.receiverUserId &&
            direction == other.direction &&
            status == other.status &&
            targetPlate == other.targetPlate &&
            messagePreview == other.messagePreview &&
            senderDisplayName == other.senderDisplayName &&
            receiverDisplayName == other.receiverDisplayName &&
            vehicleDescription == other.vehicleDescription &&
            createdAt == other.createdAt &&
            respondedAt == other.respondedAt &&
            expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      senderUserId,
      receiverUserId,
      direction,
      status,
      targetPlate,
      messagePreview,
      senderDisplayName,
      receiverDisplayName,
      vehicleDescription,
      createdAt,
      respondedAt,
      expiresAt,
    );
  }
}