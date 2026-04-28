class CarmaPlate {
  const CarmaPlate({
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
  });

  final String countryCode;
  final String region;
  final String letters;
  final String numbers;

  bool get isSwissPlate {
    return countryCode.toUpperCase() == 'CH';
  }

  bool get isComplete {
    final normalizedRegion = region.trim();
    final normalizedLetters = letters.trim();
    final normalizedNumbers = numbers.trim();

    if (isSwissPlate) {
      return normalizedRegion.isNotEmpty && normalizedNumbers.isNotEmpty;
    }

    return normalizedRegion.isNotEmpty &&
        normalizedLetters.isNotEmpty &&
        normalizedNumbers.isNotEmpty;
  }

  String get displayValue {
    final normalizedCountry = countryCode.trim().toUpperCase();
    final normalizedRegion = region.trim().toUpperCase();
    final normalizedLetters = letters.trim().toUpperCase();
    final normalizedNumbers = numbers.trim().toUpperCase();

    if (normalizedRegion.isEmpty &&
        normalizedLetters.isEmpty &&
        normalizedNumbers.isEmpty) {
      return '';
    }

    if (normalizedCountry == 'CH') {
      return [
        normalizedCountry,
        normalizedRegion,
        normalizedNumbers,
      ].where((part) => part.isNotEmpty).join(' ');
    }

    return [
      normalizedCountry,
      normalizedRegion,
      normalizedLetters,
      normalizedNumbers,
    ].where((part) => part.isNotEmpty).join(' ');
  }

  CarmaPlate copyWith({
    String? countryCode,
    String? region,
    String? letters,
    String? numbers,
  }) {
    return CarmaPlate(
      countryCode: countryCode ?? this.countryCode,
      region: region ?? this.region,
      letters: letters ?? this.letters,
      numbers: numbers ?? this.numbers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'countryCode': countryCode,
      'region': region,
      'letters': letters,
      'numbers': numbers,
      'displayValue': displayValue,
      'isComplete': isComplete,
    };
  }

  factory CarmaPlate.fromMap(Map<String, dynamic> map) {
    return CarmaPlate(
      countryCode: map['countryCode'] as String? ?? 'DE',
      region: map['region'] as String? ?? '',
      letters: map['letters'] as String? ?? '',
      numbers: map['numbers'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return displayValue;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CarmaPlate &&
            runtimeType == other.runtimeType &&
            countryCode == other.countryCode &&
            region == other.region &&
            letters == other.letters &&
            numbers == other.numbers;
  }

  @override
  int get hashCode {
    return Object.hash(
      countryCode,
      region,
      letters,
      numbers,
    );
  }
}