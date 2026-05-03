class PlateSearchResult {
  const PlateSearchResult({
    required this.found,
    this.targetUid,
    this.displayName,
    this.distanceKm,
    this.plateKey,
  });

  final bool found;
  final String? targetUid;
  final String? displayName;
  final double? distanceKm;
  final String? plateKey;

  factory PlateSearchResult.fromMap(Map<String, dynamic> map) {
    final distanceValue = map['distanceKm'];

    return PlateSearchResult(
      found: map['found'] == true,
      targetUid: map['targetUid'] as String?,
      displayName: map['displayName'] as String?,
      distanceKm: distanceValue is num ? distanceValue.toDouble() : null,
      plateKey: map['plateKey'] as String?,
    );
  }
}
