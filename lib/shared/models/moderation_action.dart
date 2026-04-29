enum ModerationActionType {
  warning,
  restriction,
  suspension,
  accountDeletion,
  reportDismissed,
  reportConfirmed,
  manualReview,
}

enum ModerationReason {
  falseReport,
  harassment,
  fakeProfile,
  wrongVehicleData,
  documentMismatch,
  spam,
  abusiveLanguage,
  privacyViolation,
  safetyRisk,
  other,
}

class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    required this.createdAt,
    this.createdBy,
    this.relatedReportId,
    this.relatedRequestId,
    this.note,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String userId;
  final ModerationActionType type;
  final ModerationReason reason;
  final DateTime createdAt;
  final String? createdBy;
  final String? relatedReportId;
  final String? relatedRequestId;
  final String? note;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isActive {
    final now = DateTime.now();

    final starts = startsAt;
    if (starts != null && starts.isAfter(now)) {
      return false;
    }

    final ends = endsAt;
    if (ends != null && ends.isBefore(now)) {
      return false;
    }

    return true;
  }

  bool get blocksAccount {
    return type == ModerationActionType.suspension ||
        type == ModerationActionType.accountDeletion;
  }

  bool get restrictsFeatures {
    return type == ModerationActionType.restriction;
  }

  String get typeLabel {
    return switch (type) {
      ModerationActionType.warning => 'Verwarnung',
      ModerationActionType.restriction => 'Einschränkung',
      ModerationActionType.suspension => 'Sperre',
      ModerationActionType.accountDeletion => 'Kontolöschung',
      ModerationActionType.reportDismissed => 'Meldung abgewiesen',
      ModerationActionType.reportConfirmed => 'Meldung bestätigt',
      ModerationActionType.manualReview => 'Manuelle Prüfung',
    };
  }

  String get reasonLabel {
    return switch (reason) {
      ModerationReason.falseReport => 'Falsche Meldung',
      ModerationReason.harassment => 'Belästigung',
      ModerationReason.fakeProfile => 'Fake-Profil',
      ModerationReason.wrongVehicleData => 'Falsche Fahrzeugdaten',
      ModerationReason.documentMismatch => 'Dokument stimmt nicht überein',
      ModerationReason.spam => 'Spam',
      ModerationReason.abusiveLanguage => 'Beleidigende Sprache',
      ModerationReason.privacyViolation => 'Datenschutzverstoß',
      ModerationReason.safetyRisk => 'Sicherheitsrisiko',
      ModerationReason.other => 'Sonstiger Grund',
    };
  }

  ModerationAction copyWith({
    String? id,
    String? userId,
    ModerationActionType? type,
    ModerationReason? reason,
    DateTime? createdAt,
    String? createdBy,
    String? relatedReportId,
    String? relatedRequestId,
    String? note,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    return ModerationAction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      relatedReportId: relatedReportId ?? this.relatedReportId,
      relatedRequestId: relatedRequestId ?? this.relatedRequestId,
      note: note ?? this.note,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'typeLabel': typeLabel,
      'reason': reason.name,
      'reasonLabel': reasonLabel,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'relatedReportId': relatedReportId,
      'relatedRequestId': relatedRequestId,
      'note': note,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'isActive': isActive,
      'blocksAccount': blocksAccount,
      'restrictsFeatures': restrictsFeatures,
    };
  }

  factory ModerationAction.fromMap(Map<String, dynamic> map) {
    return ModerationAction(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: _typeFromName(map['type'] as String?),
      reason: _reasonFromName(map['reason'] as String?),
      createdAt: _dateTimeFromValue(map['createdAt']) ?? DateTime(1970),
      createdBy: map['createdBy'] as String?,
      relatedReportId: map['relatedReportId'] as String?,
      relatedRequestId: map['relatedRequestId'] as String?,
      note: map['note'] as String?,
      startsAt: _dateTimeFromValue(map['startsAt']),
      endsAt: _dateTimeFromValue(map['endsAt']),
    );
  }

  factory ModerationAction.localWarning({
    required String userId,
    required ModerationReason reason,
    String? note,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();

    return ModerationAction(
      id: '${userId}_warning_${timestamp.millisecondsSinceEpoch}',
      userId: userId,
      type: ModerationActionType.warning,
      reason: reason,
      createdAt: timestamp,
      note: note,
    );
  }

  factory ModerationAction.localRestriction({
    required String userId,
    required ModerationReason reason,
    required DateTime endsAt,
    String? note,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();

    return ModerationAction(
      id: '${userId}_restriction_${timestamp.millisecondsSinceEpoch}',
      userId: userId,
      type: ModerationActionType.restriction,
      reason: reason,
      createdAt: timestamp,
      note: note,
      startsAt: timestamp,
      endsAt: endsAt,
    );
  }

  factory ModerationAction.localSuspension({
    required String userId,
    required ModerationReason reason,
    DateTime? endsAt,
    String? note,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();

    return ModerationAction(
      id: '${userId}_suspension_${timestamp.millisecondsSinceEpoch}',
      userId: userId,
      type: ModerationActionType.suspension,
      reason: reason,
      createdAt: timestamp,
      note: note,
      startsAt: timestamp,
      endsAt: endsAt,
    );
  }

  static ModerationActionType _typeFromName(String? name) {
    return ModerationActionType.values.firstWhere(
          (type) => type.name == name,
      orElse: () => ModerationActionType.manualReview,
    );
  }

  static ModerationReason _reasonFromName(String? name) {
    return ModerationReason.values.firstWhere(
          (reason) => reason.name == name,
      orElse: () => ModerationReason.other,
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
    return 'ModerationAction(id: $id, userId: $userId, type: $typeLabel, reason: $reasonLabel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ModerationAction &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            userId == other.userId &&
            type == other.type &&
            reason == other.reason &&
            createdAt == other.createdAt &&
            createdBy == other.createdBy &&
            relatedReportId == other.relatedReportId &&
            relatedRequestId == other.relatedRequestId &&
            note == other.note &&
            startsAt == other.startsAt &&
            endsAt == other.endsAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      type,
      reason,
      createdAt,
      createdBy,
      relatedReportId,
      relatedRequestId,
      note,
      startsAt,
      endsAt,
    );
  }
}