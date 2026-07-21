import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/plate/plate_country_config.dart';
import 'user_profile.dart';

class PlateRepository {
  PlateRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _plateDocument({
    required String countryCode,
    required String plateKey,
  }) {
    return _firestore.doc(CaRismaFirestorePaths.plate(countryCode, plateKey));
  }

  Future<void> registerPlateForProfile(
    UserProfile profile, {
    double? latitude,
    double? longitude,
  }) async {
    final countryCode = (profile.countryCode ?? profile.country)
        .trim()
        .toUpperCase();
    final region = profile.plateRegion?.trim() ?? '';
    final letters = profile.plateLetters?.trim() ?? '';
    final numbers = profile.plateNumbers?.trim() ?? '';

    final plateValue = buildPlateValue(
      countryCode: countryCode,
      region: region,
      letters: letters,
      numbers: numbers,
    );

    final plateKey = normalizePlateValue(plateValue);

    if (profile.uid.trim().isEmpty || countryCode.isEmpty || plateKey.isEmpty) {
      return;
    }

    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : _fallbackDisplayName(profile);

    final plateData = <String, Object?>{
      'ownerUserId': profile.uid,
      'countryCode': countryCode.toUpperCase(),
      'plateKey': plateKey,
      'normalizedPlate': plateKey,
      'displayPlate': formatDisplayPlate(
        countryCode: countryCode,
        region: region,
        letters: letters,
        numbers: numbers,
      ),
      'displayName': displayName,
      'profilePhotoUrl': profile.photoUrl?.trim(),
      'vehicleBrand': profile.vehicleBrand?.trim(),
      'vehicleModel': profile.vehicleModel?.trim(),
      'vehicleColor': profile.vehicleColor?.trim(),
      'vehicleLabel': _vehicleLabel(profile),
      'allowContactRequests': profile.allowContactRequests,
      'allowAnonymousReports': profile.allowAnonymousReports,
      'verificationStatus': profile.verificationStatus,
      'isActive': true,
      'isDeleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (latitude != null && longitude != null) {
      plateData['latitude'] = latitude;
      plateData['longitude'] = longitude;
      plateData['locationUpdatedAt'] = FieldValue.serverTimestamp();
    }

    await _plateDocument(
      countryCode: countryCode,
      plateKey: plateKey,
    ).set(plateData, SetOptions(merge: true));
  }

  Future<void> updatePlateProfileVisibility({
    required UserProfile profile,
  }) async {
    final countryCode = (profile.countryCode ?? profile.country)
        .trim()
        .toUpperCase();
    final region = profile.plateRegion?.trim() ?? '';
    final letters = profile.plateLetters?.trim() ?? '';
    final numbers = profile.plateNumbers?.trim() ?? '';

    final plateValue = buildPlateValue(
      countryCode: countryCode,
      region: region,
      letters: letters,
      numbers: numbers,
    );
    final plateKey = normalizePlateValue(plateValue);

    if (profile.uid.trim().isEmpty || countryCode.isEmpty || plateKey.isEmpty) {
      return;
    }

    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : _fallbackDisplayName(profile);

    await _plateDocument(countryCode: countryCode, plateKey: plateKey).set({
      'ownerUserId': profile.uid,
      'countryCode': countryCode.toUpperCase(),
      'plateKey': plateKey,
      'normalizedPlate': plateKey,
      'displayPlate': formatDisplayPlate(
        countryCode: countryCode,
        region: region,
        letters: letters,
        numbers: numbers,
      ),
      'displayName': displayName,
      'profilePhotoUrl': profile.photoUrl?.trim(),
      'vehicleBrand': profile.vehicleBrand?.trim(),
      'vehicleModel': profile.vehicleModel?.trim(),
      'vehicleColor': profile.vehicleColor?.trim(),
      'vehicleLabel': _vehicleLabel(profile),
      'allowContactRequests': profile.allowContactRequests,
      'allowAnonymousReports': profile.allowAnonymousReports,
      'verificationStatus': profile.verificationStatus,
      'isActive': true,
      'isDeleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deactivatePlateForProfile(UserProfile profile) async {
    final countryCode = (profile.countryCode ?? profile.country)
        .trim()
        .toUpperCase();
    final plateValue = buildPlateValue(
      countryCode: countryCode,
      region: profile.plateRegion?.trim() ?? '',
      letters: profile.plateLetters?.trim() ?? '',
      numbers: profile.plateNumbers?.trim() ?? '',
    );
    final plateKey = normalizePlateValue(plateValue);

    if (profile.uid.trim().isEmpty || countryCode.isEmpty || plateKey.isEmpty) {
      return;
    }

    final document = _plateDocument(
      countryCode: countryCode,
      plateKey: plateKey,
    );
    final snapshot = await document.get();
    if (!snapshot.exists || snapshot.data()?['ownerUserId'] != profile.uid) {
      return;
    }

    await document.update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _vehicleLabel(UserProfile profile) {
    final parts = <String>[
      if ((profile.vehicleColor ?? '').trim().isNotEmpty)
        _vehicleColorAdjective(profile.vehicleColor!),
      if ((profile.vehicleBrand ?? '').trim().isNotEmpty)
        profile.vehicleBrand!.trim(),
      if ((profile.vehicleModel ?? '').trim().isNotEmpty)
        profile.vehicleModel!.trim(),
    ];

    return parts.join(' ').trim();
  }

  String _vehicleColorAdjective(String color) {
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

  String normalizePlateValue(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');
  }

  String _fallbackDisplayName(UserProfile profile) {
    final firstName = profile.firstName.trim();
    final lastName = profile.lastName.trim();

    if (firstName.isEmpty && lastName.isEmpty) {
      return 'CaRisma Nutzer';
    }

    if (lastName.isEmpty) {
      return firstName;
    }

    if (firstName.isEmpty) {
      return '${lastName.substring(0, 1).toUpperCase()}.';
    }

    return '$firstName ${lastName.substring(0, 1).toUpperCase()}.';
  }
}
