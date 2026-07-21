import 'dach_registration_region_data.g.dart';

class CountryPresentationData {
  const CountryPresentationData({
    required this.countryCode,
    required this.label,
    required this.vehicleMark,
    required this.flagAsset,
  });

  final String countryCode;
  final String label;
  final String vehicleMark;
  final String flagAsset;
}

class RegistrationRegionPresentationData {
  const RegistrationRegionPresentationData({
    required this.countryCode,
    required this.plateCode,
    required this.displayName,
    required this.parentRegionName,
    required this.parentRegionCode,
    required this.regionCoatAsset,
    required this.plateSealAsset,
    required this.usesFallback,
  });

  final String countryCode;
  final String plateCode;
  final String displayName;
  final String parentRegionName;
  final String parentRegionCode;
  final String regionCoatAsset;
  final String plateSealAsset;
  final bool usesFallback;
}

const Map<String, CountryPresentationData> countryPresentationData = {
  'DE': CountryPresentationData(
    countryCode: 'DE',
    label: 'Deutschland',
    vehicleMark: 'D',
    flagAsset: 'assets/flags/de.png',
  ),
  'AT': CountryPresentationData(
    countryCode: 'AT',
    label: 'Österreich',
    vehicleMark: 'A',
    flagAsset: 'assets/flags/at.png',
  ),
  'CH': CountryPresentationData(
    countryCode: 'CH',
    label: 'Schweiz',
    vehicleMark: 'CH',
    flagAsset: 'assets/flags/ch.png',
  ),
};

CountryPresentationData countryPresentationFor(String countryCode) {
  return countryPresentationData[countryCode.toUpperCase()] ??
      countryPresentationData['DE']!;
}

List<RegistrationRegionPresentationData> registrationRegionsForCountry(
  String countryCode,
) {
  final normalizedCountry = countryCode.trim().toUpperCase();
  final source = switch (normalizedCountry) {
    'AT' => atRegistrationRegionData,
    'CH' => chRegistrationRegionData,
    _ => deRegistrationRegionData,
  };

  final regions = source.entries
      .where((entry) => entry.value.length >= 6)
      .map((entry) {
        final data = entry.value;
        return RegistrationRegionPresentationData(
          countryCode: normalizedCountry,
          plateCode: entry.key,
          displayName: data[0],
          parentRegionName: data[1],
          parentRegionCode: data[2],
          regionCoatAsset: data[3],
          plateSealAsset: data[4],
          usesFallback: data[5] == 'true',
        );
      })
      .toList(growable: false);
  regions.sort((a, b) => a.plateCode.compareTo(b.plateCode));
  return regions;
}

RegistrationRegionPresentationData registrationRegionPresentationFor({
  required String countryCode,
  required String plateCode,
}) {
  final normalizedCountry = countryCode.trim().toUpperCase();
  final normalizedCode = plateCode.trim().toUpperCase();
  final data = switch (normalizedCountry) {
    'AT' => atRegistrationRegionData[normalizedCode],
    'CH' => chRegistrationRegionData[normalizedCode],
    _ => deRegistrationRegionData[normalizedCode],
  };

  if (data != null && data.length >= 6) {
    return RegistrationRegionPresentationData(
      countryCode: normalizedCountry,
      plateCode: normalizedCode,
      displayName: data[0],
      parentRegionName: data[1],
      parentRegionCode: data[2],
      regionCoatAsset: data[3],
      plateSealAsset: data[4],
      usesFallback: data[5] == 'true',
    );
  }

  return _fallbackRegion(normalizedCountry, normalizedCode);
}

RegistrationRegionPresentationData _fallbackRegion(
  String countryCode,
  String plateCode,
) {
  final effectiveCode = plateCode.isEmpty ? '—' : plateCode;
  return switch (countryCode) {
    'AT' => RegistrationRegionPresentationData(
      countryCode: 'AT',
      plateCode: effectiveCode,
      displayName: plateCode.isEmpty
          ? 'Zulassungsbezirk wählen'
          : 'Zulassungsbezirk $plateCode',
      parentRegionName: 'Österreich',
      parentRegionCode: 'AT',
      regionCoatAsset: 'assets/coats/at/states/at.png',
      plateSealAsset: 'assets/plate_seals/at/at.png',
      usesFallback: true,
    ),
    'CH' => RegistrationRegionPresentationData(
      countryCode: 'CH',
      plateCode: effectiveCode,
      displayName: plateCode.isEmpty ? 'Kanton wählen' : 'Kanton $plateCode',
      parentRegionName: 'Schweiz',
      parentRegionCode: 'CH',
      regionCoatAsset: 'assets/coats/ch/cantons/ch.png',
      plateSealAsset: 'assets/plate_seals/ch/ch.png',
      usesFallback: true,
    ),
    _ => RegistrationRegionPresentationData(
      countryCode: 'DE',
      plateCode: effectiveCode,
      displayName: plateCode.isEmpty
          ? 'Zulassungsregion wählen'
          : 'Zulassungsregion $plateCode',
      parentRegionName: 'Deutschland',
      parentRegionCode: 'DE',
      regionCoatAsset: 'assets/coats/de/states/de.png',
      plateSealAsset: 'assets/plate_seals/de/de.png',
      usesFallback: true,
    ),
  };
}
