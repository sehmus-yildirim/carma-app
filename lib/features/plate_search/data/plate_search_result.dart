class PlateSearchResult {
  const PlateSearchResult({
    required this.found,
    this.targetUid,
    this.displayName,
    this.distanceKm,
    this.plateKey,
    this.displayPlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleLabel,
  });

  final bool found;
  final String? targetUid;
  final String? displayName;
  final double? distanceKm;
  final String? plateKey;
  final String? displayPlate;
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

    return PlateSearchResult(
      found: map['found'] == true,
      targetUid: map['targetUid'] as String?,
      displayName: map['displayName'] as String?,
      distanceKm: distanceValue is num ? distanceValue.toDouble() : null,
      plateKey: map['plateKey'] as String?,
      displayPlate: map['displayPlate'] as String?,
      vehicleBrand: map['vehicleBrand'] as String?,
      vehicleModel: map['vehicleModel'] as String?,
      vehicleColor: map['vehicleColor'] as String?,
      vehicleLabel: map['vehicleLabel'] as String?,
    );
  }
}
