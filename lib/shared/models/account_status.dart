enum AccountState {
  registered,
  onboardingCompleted,
  verificationPending,
  verified,
  restricted,
  suspended,
  deleted,
}

class AccountStatus {
  const AccountStatus({
    required this.userId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.reason,
    this.restrictedUntil,
    this.suspendedUntil,
  });

  final String userId;
  final AccountState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reason;
  final DateTime? restrictedUntil;
  final DateTime? suspendedUntil;

  bool get isRegistered {
    return state == AccountState.registered;
  }

  bool get isOnboardingCompleted {
    return state == AccountState.onboardingCompleted ||
        state == AccountState.verificationPending ||
        state == AccountState.verified ||
        state == AccountState.restricted;
  }

  bool get isVerificationPending {
    return state == AccountState.verificationPending;
  }

  bool get isVerified {
    return state == AccountState.verified;
  }

  bool get isRestricted {
    if (state != AccountState.restricted) {
      return false;
    }

    final until = restrictedUntil;
    if (until == null) {
      return true;
    }

    return until.isAfter(DateTime.now());
  }

  bool get isSuspended {
    if (state != AccountState.suspended) {
      return false;
    }

    final until = suspendedUntil;
    if (until == null) {
      return true;
    }

    return until.isAfter(DateTime.now());
  }

  bool get isDeleted {
    return state == AccountState.deleted;
  }

  bool get canUseApp {
    return !isSuspended && !isDeleted;
  }

  bool get canSearchPlates {
    return canUseApp && isOnboardingCompleted && !isRestricted;
  }

  bool get canSendReports {
    return canUseApp && isOnboardingCompleted && !isRestricted;
  }

  bool get canRequestContact {
    return canUseApp && isOnboardingCompleted && !isRestricted;
  }

  String get stateLabel {
    return switch (state) {
      AccountState.registered => 'Registriert',
      AccountState.onboardingCompleted => 'Onboarding abgeschlossen',
      AccountState.verificationPending => 'Verifizierung ausstehend',
      AccountState.verified => 'Verifiziert',
      AccountState.restricted => 'Eingeschränkt',
      AccountState.suspended => 'Gesperrt',
      AccountState.deleted => 'Gelöscht',
    };
  }

  AccountStatus copyWith({
    String? userId,
    AccountState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reason,
    DateTime? restrictedUntil,
    DateTime? suspendedUntil,
  }) {
    return AccountStatus(
      userId: userId ?? this.userId,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reason: reason ?? this.reason,
      restrictedUntil: restrictedUntil ?? this.restrictedUntil,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
    );
  }

  AccountStatus markOnboardingCompleted() {
    return copyWith(
      state: AccountState.onboardingCompleted,
      updatedAt: DateTime.now(),
    );
  }

  AccountStatus markVerificationPending() {
    return copyWith(
      state: AccountState.verificationPending,
      updatedAt: DateTime.now(),
    );
  }

  AccountStatus markVerified() {
    return copyWith(
      state: AccountState.verified,
      updatedAt: DateTime.now(),
      reason: null,
      restrictedUntil: null,
      suspendedUntil: null,
    );
  }

  AccountStatus restrict({
    required String reason,
    DateTime? until,
  }) {
    return copyWith(
      state: AccountState.restricted,
      updatedAt: DateTime.now(),
      reason: reason,
      restrictedUntil: until,
    );
  }

  AccountStatus suspend({
    required String reason,
    DateTime? until,
  }) {
    return copyWith(
      state: AccountState.suspended,
      updatedAt: DateTime.now(),
      reason: reason,
      suspendedUntil: until,
    );
  }

  AccountStatus markDeleted({
    String? reason,
  }) {
    return copyWith(
      state: AccountState.deleted,
      updatedAt: DateTime.now(),
      reason: reason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'state': state.name,
      'stateLabel': stateLabel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'reason': reason,
      'restrictedUntil': restrictedUntil?.toIso8601String(),
      'suspendedUntil': suspendedUntil?.toIso8601String(),
      'canUseApp': canUseApp,
      'canSearchPlates': canSearchPlates,
      'canSendReports': canSendReports,
      'canRequestContact': canRequestContact,
    };
  }

  factory AccountStatus.fromMap(Map<String, dynamic> map) {
    return AccountStatus(
      userId: map['userId'] as String? ?? '',
      state: _stateFromName(map['state'] as String?),
      createdAt: _dateTimeFromValue(map['createdAt']) ?? DateTime(1970),
      updatedAt: _dateTimeFromValue(map['updatedAt']) ?? DateTime(1970),
      reason: map['reason'] as String?,
      restrictedUntil: _dateTimeFromValue(map['restrictedUntil']),
      suspendedUntil: _dateTimeFromValue(map['suspendedUntil']),
    );
  }

  factory AccountStatus.localRegistered({
    required String userId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();

    return AccountStatus(
      userId: userId,
      state: AccountState.registered,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  static AccountState _stateFromName(String? name) {
    return AccountState.values.firstWhere(
          (state) => state.name == name,
      orElse: () => AccountState.registered,
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
    return 'AccountStatus(userId: $userId, state: $stateLabel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AccountStatus &&
            runtimeType == other.runtimeType &&
            userId == other.userId &&
            state == other.state &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            reason == other.reason &&
            restrictedUntil == other.restrictedUntil &&
            suspendedUntil == other.suspendedUntil;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      state,
      createdAt,
      updatedAt,
      reason,
      restrictedUntil,
      suspendedUntil,
    );
  }
}