import '../../../shared/security/trusted_firebase_media_url.dart';

class PlateSearchResult {
  const PlateSearchResult({
    required this.found,
    this.targetUid,
    this.displayName,
    this.profilePhotoUrl,
    this.isVerified = false,
    this.distanceKm,
    this.vehicleId,
    this.plateKey,
    this.displayPlate,
    this.countryCode,
    this.region,
    this.letters,
    this.numbers,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleLabel,
  });

  final bool found;
  final String? targetUid;
  final String? displayName;
  final String? profilePhotoUrl;
  final bool isVerified;
  final double? distanceKm;
  final String? vehicleId;
  final String? plateKey;
  final String? displayPlate;
  final String? countryCode;
  final String? region;
  final String? letters;
  final String? numbers;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleLabel;

  String get vehicleTitle {
    final label = vehicleLabel?.trim();

    if (label != null && label.isNotEmpty) {
      return label;
    }

    final parts = <String>[
      if (vehicleColor != null && vehicleColor!.trim().isNotEmpty)
        _vehicleColorAdjective(vehicleColor!),
      if (vehicleBrand != null && vehicleBrand!.trim().isNotEmpty)
        vehicleBrand!.trim(),
      if (vehicleModel != null && vehicleModel!.trim().isNotEmpty)
        vehicleModel!.trim(),
    ];

    final title = parts.join(' ').trim();
    return title.isEmpty ? 'Fahrzeug' : title;
  }

  static String _vehicleColorAdjective(String color) {
    return switch (color.trim().toLowerCase()) {
      'schwarz' => 'schwarzer',
      'weiß' || 'weiss' => 'weißer',
      'silber' => 'silberner',
      'grau' => 'grauer',
      'blau' => 'blauer',
      'rot' => 'roter',
      'grün' || 'gruen' => 'grüner',
      'braun' => 'brauner',
      'gelb' => 'gelber',
      'orange' => 'oranger',
      _ => color.trim(),
    };
  }

  factory PlateSearchResult.fromMap(Map<String, dynamic> map) {
    final distanceValue = map['distanceKm'];
    final targetUid = map['targetUid'] as String?;

    return PlateSearchResult(
      found: map['found'] == true,
      targetUid: targetUid,
      displayName: map['displayName'] as String?,
      profilePhotoUrl: trustedProfilePhotoUrl(
        url: map['profilePhotoUrl'],
        userId: targetUid,
      ),
      isVerified: map['isVerified'] == true,
      distanceKm: distanceValue is num ? distanceValue.toDouble() : null,
      vehicleId: map['vehicleId'] as String?,
      plateKey: map['plateKey'] as String?,
      displayPlate: map['displayPlate'] as String?,
      countryCode: map['countryCode'] as String?,
      region: map['region'] as String?,
      letters: map['letters'] as String?,
      numbers: map['numbers'] as String?,
      vehicleBrand: map['vehicleBrand'] as String?,
      vehicleModel: map['vehicleModel'] as String?,
      vehicleColor: map['vehicleColor'] as String?,
      vehicleLabel: map['vehicleLabel'] as String?,
    );
  }
}
