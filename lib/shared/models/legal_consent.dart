enum LegalConsentType {
  terms,
  privacy,
  responsibleUse,
  noEmergencyUse,
}

class LegalConsent {
  const LegalConsent({
    required this.id,
    required this.userId,
    required this.type,
    required this.version,
    required this.acceptedAt,
    this.ipAddress,
    this.userAgent,
  });

  final String id;
  final String userId;
  final LegalConsentType type;
  final String version;
  final DateTime acceptedAt;
  final String? ipAddress;
  final String? userAgent;

  String get typeLabel {
    return switch (type) {
      LegalConsentType.terms => 'AGB',
      LegalConsentType.privacy => 'Datenschutz',
      LegalConsentType.responsibleUse => 'Verantwortungsvolle Nutzung',
      LegalConsentType.noEmergencyUse => 'Keine Notfall-App',
    };
  }

  LegalConsent copyWith({
    String? id,
    String? userId,
    LegalConsentType? type,
    String? version,
    DateTime? acceptedAt,
    String? ipAddress,
    String? userAgent,
  }) {
    return LegalConsent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      version: version ?? this.version,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'typeLabel': typeLabel,
      'version': version,
      'acceptedAt': acceptedAt.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  factory LegalConsent.fromMap(Map<String, dynamic> map) {
    return LegalConsent(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: _typeFromName(map['type'] as String?),
      version: map['version'] as String? ?? '',
      acceptedAt: _dateTimeFromValue(map['acceptedAt']) ?? DateTime(1970),
      ipAddress: map['ipAddress'] as String?,
      userAgent: map['userAgent'] as String?,
    );
  }

  static LegalConsentType _typeFromName(String? name) {
    return LegalConsentType.values.firstWhere(
          (type) => type.name == name,
      orElse: () => LegalConsentType.terms,
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
    return '$typeLabel v$version akzeptiert am ${acceptedAt.toIso8601String()}';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LegalConsent &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            type == other.type &&
            version == other.version &&
            acceptedAt == other.acceptedAt &&
            ipAddress == other.ipAddress &&
            userAgent == other.userAgent;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      type,
      version,
      acceptedAt,
      ipAddress,
      userAgent,
    );
  }
}