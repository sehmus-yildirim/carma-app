class CarmaFirestoreMapper {
  const CarmaFirestoreMapper._();

  static Map<String, dynamic> cleanMap(Map<String, dynamic> value) {
    final cleaned = <String, dynamic>{};

    for (final entry in value.entries) {
      final mappedValue = _cleanValue(entry.value);

      if (mappedValue != null) {
        cleaned[entry.key] = mappedValue;
      }
    }

    return cleaned;
  }

  static List<Map<String, dynamic>> cleanMapList(
      List<Map<String, dynamic>> values,
      ) {
    return values.map(cleanMap).toList();
  }

  static String dateTimeToIso(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  static String? optionalDateTimeToIso(DateTime? value) {
    return value == null ? null : dateTimeToIso(value);
  }

  static DateTime? dateTimeFromValue(Object? value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static List<String> stringListFromValue(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<String>().toList();
  }

  static List<Map<String, dynamic>> mapListFromValue(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic> mapFromValue(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }

  static String stringFromValue(Object? value, {String fallback = ''}) {
    if (value is String) {
      return value;
    }

    return fallback;
  }

  static bool boolFromValue(Object? value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }

    return fallback;
  }

  static int intFromValue(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }

  static double doubleFromValue(Object? value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return fallback;
  }

  static Object? _cleanValue(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return dateTimeToIso(value);
    }

    if (value is Map<String, dynamic>) {
      return cleanMap(value);
    }

    if (value is List) {
      return value
          .map(_cleanValue)
          .where((item) => item != null)
          .toList();
    }

    return value;
  }
}