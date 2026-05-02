enum SearchCreditResetPeriod { daily, weekly, monthly, never }

class SearchCredit {
  const SearchCredit({
    required this.userId,
    required this.used,
    required this.limit,
    required this.resetPeriod,
    this.paidCredits = 0,
    this.periodKey,
    this.resetAt,
    this.updatedAt,
  });

  final String userId;

  /// Backwards-compatible field:
  /// Represents the free searches used in the current billing/month period.
  final int used;

  /// Backwards-compatible field:
  /// Represents the monthly free search limit.
  final int limit;

  final SearchCreditResetPeriod resetPeriod;

  /// Purchased credits available after the monthly free quota is exhausted.
  final int paidCredits;

  /// Month key for the free quota period, e.g. "2026-05".
  final String? periodKey;

  final DateTime? resetAt;
  final DateTime? updatedAt;

  int get freeUsedThisMonth {
    return used < 0 ? 0 : used;
  }

  int get freeMonthlyLimit {
    return limit < 0 ? 0 : limit;
  }

  int get remaining {
    final value = freeMonthlyLimit - freeUsedThisMonth;
    return value < 0 ? 0 : value;
  }

  int get freeRemainingThisMonth {
    return remaining;
  }

  int get availablePaidCredits {
    return paidCredits < 0 ? 0 : paidCredits;
  }

  int get totalAvailableRequests {
    return remaining + availablePaidCredits;
  }

  bool get isUnlimited {
    return limit < 0;
  }

  bool get hasFreeRemaining {
    return isUnlimited || remaining > 0;
  }

  bool get hasPaidRemaining {
    return availablePaidCredits > 0;
  }

  bool get hasRemaining {
    return isUnlimited || hasFreeRemaining || hasPaidRemaining;
  }

  bool get isExhausted {
    return !hasRemaining;
  }

  bool get needsPaidCredits {
    return !hasFreeRemaining;
  }

  bool get canUseFreeRequest {
    return isUnlimited || remaining > 0;
  }

  bool get canUsePaidCredit {
    return !canUseFreeRequest && availablePaidCredits > 0;
  }

  double get usageRatio {
    if (isUnlimited || freeMonthlyLimit == 0) {
      return 0;
    }

    final ratio = freeUsedThisMonth / freeMonthlyLimit;
    return ratio.clamp(0, 1).toDouble();
  }

  String get effectivePeriodKey {
    return periodKey ?? buildCurrentPeriodKey();
  }

  SearchCredit consume({int amount = 1}) {
    if (amount <= 0 || isUnlimited) {
      return this;
    }

    var nextUsed = freeUsedThisMonth;
    var nextPaidCredits = availablePaidCredits;

    for (var index = 0; index < amount; index++) {
      if (nextUsed < freeMonthlyLimit) {
        nextUsed++;
        continue;
      }

      if (nextPaidCredits > 0) {
        nextPaidCredits--;
      }
    }

    return copyWith(
      used: nextUsed,
      paidCredits: nextPaidCredits,
      periodKey: effectivePeriodKey,
      updatedAt: DateTime.now(),
    );
  }

  SearchCredit addPaidCredits(int amount) {
    if (amount <= 0) {
      return this;
    }

    return copyWith(
      paidCredits: availablePaidCredits + amount,
      updatedAt: DateTime.now(),
    );
  }

  SearchCredit resetFreeMonthlyQuota({String? nextPeriodKey}) {
    return copyWith(
      used: 0,
      periodKey: nextPeriodKey ?? buildCurrentPeriodKey(),
      resetPeriod: SearchCreditResetPeriod.monthly,
      updatedAt: DateTime.now(),
    );
  }

  SearchCredit reset() {
    return resetFreeMonthlyQuota();
  }

  SearchCredit normalizeForCurrentMonth() {
    final currentPeriodKey = buildCurrentPeriodKey();

    if (effectivePeriodKey == currentPeriodKey) {
      return this;
    }

    return resetFreeMonthlyQuota(nextPeriodKey: currentPeriodKey);
  }

  SearchCredit copyWith({
    String? userId,
    int? used,
    int? limit,
    SearchCreditResetPeriod? resetPeriod,
    int? paidCredits,
    String? periodKey,
    DateTime? resetAt,
    DateTime? updatedAt,
  }) {
    return SearchCredit(
      userId: userId ?? this.userId,
      used: used ?? this.used,
      limit: limit ?? this.limit,
      resetPeriod: resetPeriod ?? this.resetPeriod,
      paidCredits: paidCredits ?? this.paidCredits,
      periodKey: periodKey ?? this.periodKey,
      resetAt: resetAt ?? this.resetAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'used': freeUsedThisMonth,
      'limit': freeMonthlyLimit,
      'remaining': remaining,
      'resetPeriod': resetPeriod.name,
      'paidCredits': availablePaidCredits,
      'periodKey': effectivePeriodKey,
      'totalAvailableRequests': totalAvailableRequests,
      'resetAt': resetAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SearchCredit.fromMap(Map<String, dynamic> map) {
    return SearchCredit(
      userId: map['userId'] as String? ?? '',
      used: _intFromValue(map['used']),
      limit: _intFromValue(map['limit'], fallback: 2),
      resetPeriod: _resetPeriodFromName(map['resetPeriod'] as String?),
      paidCredits: _intFromValue(map['paidCredits']),
      periodKey: map['periodKey'] as String?,
      resetAt: _dateTimeFromValue(map['resetAt']),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
    );
  }

  factory SearchCredit.freeDefault({required String userId}) {
    return SearchCredit(
      userId: userId,
      used: 0,
      limit: 2,
      resetPeriod: SearchCreditResetPeriod.monthly,
      paidCredits: 0,
      periodKey: buildCurrentPeriodKey(),
      resetAt: null,
      updatedAt: DateTime.now(),
    );
  }

  static String buildCurrentPeriodKey({DateTime? now}) {
    final value = now ?? DateTime.now();
    final month = value.month.toString().padLeft(2, '0');

    return '${value.year}-$month';
  }

  static SearchCreditResetPeriod _resetPeriodFromName(String? name) {
    return SearchCreditResetPeriod.values.firstWhere(
      (period) => period.name == name,
      orElse: () => SearchCreditResetPeriod.monthly,
    );
  }

  static int _intFromValue(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
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
    if (isUnlimited) {
      return 'Unbegrenzte Anfragen';
    }

    if (hasFreeRemaining) {
      return '$remaining von $freeMonthlyLimit kostenlosen Anfragen verfügbar';
    }

    if (hasPaidRemaining) {
      return '$availablePaidCredits Credits verfügbar';
    }

    return 'Keine Anfragen verfügbar';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchCredit &&
            runtimeType == other.runtimeType &&
            userId == other.userId &&
            used == other.used &&
            limit == other.limit &&
            resetPeriod == other.resetPeriod &&
            paidCredits == other.paidCredits &&
            periodKey == other.periodKey &&
            resetAt == other.resetAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      used,
      limit,
      resetPeriod,
      paidCredits,
      periodKey,
      resetAt,
      updatedAt,
    );
  }
}
