enum SearchCreditResetPeriod {
  daily,
  weekly,
  monthly,
  never,
}

class SearchCredit {
  const SearchCredit({
    required this.userId,
    required this.used,
    required this.limit,
    required this.resetPeriod,
    this.resetAt,
    this.updatedAt,
  });

  final String userId;
  final int used;
  final int limit;
  final SearchCreditResetPeriod resetPeriod;
  final DateTime? resetAt;
  final DateTime? updatedAt;

  int get remaining {
    final value = limit - used;
    return value < 0 ? 0 : value;
  }

  bool get isUnlimited {
    return limit < 0;
  }

  bool get hasRemaining {
    return isUnlimited || remaining > 0;
  }

  bool get isExhausted {
    return !hasRemaining;
  }

  double get usageRatio {
    if (isUnlimited || limit == 0) {
      return 0;
    }

    final ratio = used / limit;
    return ratio.clamp(0, 1).toDouble();
  }

  SearchCredit consume({int amount = 1}) {
    if (amount <= 0 || isUnlimited) {
      return this;
    }

    return copyWith(
      used: used + amount,
      updatedAt: DateTime.now(),
    );
  }

  SearchCredit reset() {
    return copyWith(
      used: 0,
      updatedAt: DateTime.now(),
    );
  }

  SearchCredit copyWith({
    String? userId,
    int? used,
    int? limit,
    SearchCreditResetPeriod? resetPeriod,
    DateTime? resetAt,
    DateTime? updatedAt,
  }) {
    return SearchCredit(
      userId: userId ?? this.userId,
      used: used ?? this.used,
      limit: limit ?? this.limit,
      resetPeriod: resetPeriod ?? this.resetPeriod,
      resetAt: resetAt ?? this.resetAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'used': used,
      'limit': limit,
      'remaining': remaining,
      'resetPeriod': resetPeriod.name,
      'resetAt': resetAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SearchCredit.fromMap(Map<String, dynamic> map) {
    return SearchCredit(
      userId: map['userId'] as String? ?? '',
      used: map['used'] as int? ?? 0,
      limit: map['limit'] as int? ?? 0,
      resetPeriod: _resetPeriodFromName(map['resetPeriod'] as String?),
      resetAt: _dateTimeFromValue(map['resetAt']),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
    );
  }

  factory SearchCredit.freeDefault({
    required String userId,
  }) {
    return SearchCredit(
      userId: userId,
      used: 0,
      limit: 5,
      resetPeriod: SearchCreditResetPeriod.daily,
      resetAt: null,
      updatedAt: DateTime.now(),
    );
  }

  static SearchCreditResetPeriod _resetPeriodFromName(String? name) {
    return SearchCreditResetPeriod.values.firstWhere(
          (period) => period.name == name,
      orElse: () => SearchCreditResetPeriod.daily,
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
    if (isUnlimited) {
      return 'Unbegrenzte Suchen';
    }

    return '$remaining von $limit Suchen verfügbar';
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
      resetAt,
      updatedAt,
    );
  }
}