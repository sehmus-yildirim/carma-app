class PlateCountryConfig {
  const PlateCountryConfig({
    required this.countryCode,
    required this.countryLabel,
    required this.regionLabel,
    required this.regionMaxLength,
    required this.lettersMaxLength,
    required this.numbersMaxLength,
    required this.usesLettersField,
    required this.numbersBeforeLetters,
    required this.allowsGermanElectricSuffix,
  });

  final String countryCode;
  final String countryLabel;
  final String regionLabel;
  final int regionMaxLength;
  final int lettersMaxLength;
  final int numbersMaxLength;
  final bool usesLettersField;
  final bool numbersBeforeLetters;
  final bool allowsGermanElectricSuffix;
}

const PlateCountryConfig germanPlateConfig = PlateCountryConfig(
  countryCode: 'DE',
  countryLabel: 'Deutschland',
  regionLabel: 'Stadt',
  regionMaxLength: 3,
  lettersMaxLength: 2,
  numbersMaxLength: 5,
  usesLettersField: true,
  numbersBeforeLetters: false,
  allowsGermanElectricSuffix: true,
);

const PlateCountryConfig austrianPlateConfig = PlateCountryConfig(
  countryCode: 'AT',
  countryLabel: 'Österreich',
  regionLabel: 'Bezirk',
  regionMaxLength: 2,
  lettersMaxLength: 2,
  numbersMaxLength: 5,
  usesLettersField: true,
  numbersBeforeLetters: true,
  allowsGermanElectricSuffix: false,
);

const PlateCountryConfig swissPlateConfig = PlateCountryConfig(
  countryCode: 'CH',
  countryLabel: 'Schweiz',
  regionLabel: 'Kanton',
  regionMaxLength: 2,
  lettersMaxLength: 0,
  numbersMaxLength: 6,
  usesLettersField: false,
  numbersBeforeLetters: false,
  allowsGermanElectricSuffix: false,
);

const List<PlateCountryConfig> plateCountryConfigs = [
  germanPlateConfig,
  austrianPlateConfig,
  swissPlateConfig,
];

PlateCountryConfig plateConfigForCountry(String countryCode) {
  return plateCountryConfigs.firstWhere(
        (config) => config.countryCode == countryCode,
    orElse: () => germanPlateConfig,
  );
}

String formatDisplayPlate({
  required String countryCode,
  required String region,
  required String letters,
  required String numbers,
}) {
  final normalizedRegion = region.trim().toUpperCase();
  final normalizedLetters = letters.trim().toUpperCase();
  final normalizedNumbers = numbers.trim().toUpperCase();

  if (countryCode == 'CH') {
    if (normalizedRegion.isEmpty && normalizedNumbers.isEmpty) {
      return '';
    }

    return '$normalizedRegion $normalizedNumbers';
  }

  if (countryCode == 'AT') {
    if (normalizedRegion.isEmpty &&
        normalizedNumbers.isEmpty &&
        normalizedLetters.isEmpty) {
      return '';
    }

    return '$normalizedRegion $normalizedNumbers $normalizedLetters';
  }

  if (normalizedRegion.isEmpty &&
      normalizedLetters.isEmpty &&
      normalizedNumbers.isEmpty) {
    return '';
  }

  return '$normalizedRegion-$normalizedLetters $normalizedNumbers';
}

String buildPlateValue({
  required String countryCode,
  required String region,
  required String letters,
  required String numbers,
}) {
  final normalizedRegion = region.trim().toUpperCase();
  final normalizedLetters = letters.trim().toUpperCase();
  final normalizedNumbers = numbers.trim().toUpperCase();

  if (countryCode == 'CH') {
    return '$normalizedRegion$normalizedNumbers';
  }

  if (countryCode == 'AT') {
    return '$normalizedRegion$normalizedNumbers$normalizedLetters';
  }

  return '$normalizedRegion$normalizedLetters$normalizedNumbers';
}