import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/plate/plate_country_config.dart';
import 'user_profile.dart';

enum ProfileVehicleStatus {
  active,
  modification,
  repair,
  seasonal,
  deregistered,
  sold,
  noLongerOwned,
  archived,
}

enum ProfileVehicleVisibility { contacts, onlyMe }

enum VehicleHeroImageStatus {
  notGenerated,
  queued,
  generating,
  ready,
  failed,
  regenerationRequired,
}

class ProfileVehicle {
  const ProfileVehicle({
    required this.id,
    required this.ownerUserId,
    required this.brand,
    required this.model,
    required this.color,
    required this.countryCode,
    required this.plateRegion,
    required this.plateLetters,
    required this.plateNumbers,
    this.series,
    this.isPrimary = false,
    this.isVerified = false,
    this.status = ProfileVehicleStatus.active,
    this.visibility = ProfileVehicleVisibility.contacts,
    this.showPlate = false,
    this.year,
    this.firstRegistration,
    this.bodyStyle,
    this.engineDescription,
    this.displacementCcm,
    this.horsepower,
    this.kilowatts,
    this.fuelType,
    this.transmission,
    this.drivetrain,
    this.equipment = const [],
    this.hsn,
    this.tsn,
    this.vin,
    this.ownedSince,
    this.mileage,
    this.heroImageUrl,
    this.heroImagePath,
    this.heroImageStatus = VehicleHeroImageStatus.notGenerated,
    this.heroSourceHash,
    this.heroPromptVersion,
    this.heroProvider,
    this.heroError,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String brand;
  final String model;
  final String? series;
  final String color;
  final String countryCode;
  final String plateRegion;
  final String plateLetters;
  final String plateNumbers;
  final bool isPrimary;
  final bool isVerified;
  final ProfileVehicleStatus status;
  final ProfileVehicleVisibility visibility;
  final bool showPlate;
  final int? year;
  final DateTime? firstRegistration;
  final String? bodyStyle;
  final String? engineDescription;
  final int? displacementCcm;
  final int? horsepower;
  final int? kilowatts;
  final String? fuelType;
  final String? transmission;
  final String? drivetrain;
  final List<String> equipment;
  final String? hsn;
  final String? tsn;
  final String? vin;
  final DateTime? ownedSince;
  final int? mileage;
  final String? heroImageUrl;
  final String? heroImagePath;
  final VehicleHeroImageStatus heroImageStatus;
  final String? heroSourceHash;
  final int? heroPromptVersion;
  final String? heroProvider;
  final String? heroError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => status == ProfileVehicleStatus.archived;

  bool get isPubliclyVisible =>
      visibility == ProfileVehicleVisibility.contacts && !isArchived;

  bool get hasRequiredData =>
      ownerUserId.trim().isNotEmpty &&
      brand.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      countryCode.trim().isNotEmpty &&
      plateRegion.trim().isNotEmpty &&
      (!plateConfigForCountry(countryCode).usesLettersField ||
          plateLetters.trim().isNotEmpty) &&
      plateNumbers.trim().isNotEmpty;

  String get displayName => [
    brand.trim(),
    model.trim(),
    series?.trim() ?? '',
  ].where((part) => part.isNotEmpty).join(' ');

  String get displayPlate => formatDisplayPlate(
    countryCode: countryCode,
    region: plateRegion,
    letters: plateLetters,
    numbers: plateNumbers,
  );

  factory ProfileVehicle.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ProfileVehicle(
      id: id,
      ownerUserId: data['ownerUserId'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
      model: data['model'] as String? ?? '',
      series: data['series'] as String?,
      color: data['color'] as String? ?? '',
      countryCode: data['countryCode'] as String? ?? 'DE',
      plateRegion: data['plateRegion'] as String? ?? '',
      plateLetters: data['plateLetters'] as String? ?? '',
      plateNumbers: data['plateNumbers'] as String? ?? '',
      isPrimary: data['isPrimary'] as bool? ?? false,
      isVerified: data['isVerified'] as bool? ?? false,
      status: _enumFromName(
        ProfileVehicleStatus.values,
        data['status'] as String?,
        ProfileVehicleStatus.active,
      ),
      visibility: _enumFromName(
        ProfileVehicleVisibility.values,
        data['visibility'] as String?,
        ProfileVehicleVisibility.contacts,
      ),
      showPlate: data['showPlate'] as bool? ?? false,
      year: data['year'] as int?,
      firstRegistration: _dateTimeFromValue(data['firstRegistration']),
      bodyStyle: data['bodyStyle'] as String?,
      engineDescription: data['engineDescription'] as String?,
      displacementCcm: data['displacementCcm'] as int?,
      horsepower: data['horsepower'] as int?,
      kilowatts: data['kilowatts'] as int?,
      fuelType: data['fuelType'] as String?,
      transmission: data['transmission'] as String?,
      drivetrain: data['drivetrain'] as String?,
      equipment: _stringListFromValue(data['equipment']),
      hsn: data['hsn'] as String?,
      tsn: data['tsn'] as String?,
      vin: data['vin'] as String?,
      ownedSince: _dateTimeFromValue(data['ownedSince']),
      mileage: data['mileage'] as int?,
      heroImageUrl: data['heroImageUrl'] as String?,
      heroImagePath: data['heroImagePath'] as String?,
      heroImageStatus: _enumFromName(
        VehicleHeroImageStatus.values,
        data['heroImageStatus'] as String?,
        VehicleHeroImageStatus.notGenerated,
      ),
      heroSourceHash: data['heroSourceHash'] as String?,
      heroPromptVersion: data['heroPromptVersion'] as int?,
      heroProvider: data['heroProvider'] as String?,
      heroError: data['heroError'] as String?,
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  factory ProfileVehicle.fromLegacyProfile(UserProfile profile) {
    return ProfileVehicle(
      id: profile.primaryVehicleId?.trim().isNotEmpty == true
          ? profile.primaryVehicleId!.trim()
          : 'legacy_primary',
      ownerUserId: profile.uid,
      brand: profile.vehicleBrand?.trim() ?? '',
      model: profile.vehicleModel?.trim() ?? '',
      color: profile.vehicleColor?.trim() ?? '',
      countryCode: profile.countryCode?.trim().toUpperCase() ?? 'DE',
      plateRegion: profile.plateRegion?.trim().toUpperCase() ?? '',
      plateLetters: profile.plateLetters?.trim().toUpperCase() ?? '',
      plateNumbers: profile.plateNumbers?.trim().toUpperCase() ?? '',
      isPrimary: true,
      isVerified: profile.verificationStatus == 'verified',
      visibility: profile.showVehicleOnPublicProfile
          ? ProfileVehicleVisibility.contacts
          : ProfileVehicleVisibility.onlyMe,
      showPlate: profile.showPlateOnPublicProfile,
    );
  }

  Map<String, Object?> toPrivateFirestore() {
    return <String, Object?>{
      'vehicleId': id.trim(),
      'ownerUserId': ownerUserId.trim(),
      'brand': _trimmedOrNull(brand),
      'model': _trimmedOrNull(model),
      'series': _trimmedOrNull(series),
      'color': _trimmedOrNull(color),
      'countryCode': countryCode.trim().toUpperCase(),
      'plateRegion': plateRegion.trim().toUpperCase(),
      'plateLetters': plateLetters.trim().toUpperCase(),
      'plateNumbers': plateNumbers.trim().toUpperCase(),
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'status': status.name,
      'visibility': visibility.name,
      'showPlate': showPlate,
      'year': year,
      'firstRegistration': firstRegistration == null
          ? null
          : Timestamp.fromDate(firstRegistration!),
      'bodyStyle': _trimmedOrNull(bodyStyle),
      'engineDescription': _trimmedOrNull(engineDescription),
      'displacementCcm': displacementCcm,
      'horsepower': horsepower,
      'kilowatts': kilowatts,
      'fuelType': _trimmedOrNull(fuelType),
      'transmission': _trimmedOrNull(transmission),
      'drivetrain': _trimmedOrNull(drivetrain),
      'equipment': _normalizedStringList(equipment),
      'hsn': _trimmedOrNull(hsn),
      'tsn': _trimmedOrNull(tsn),
      'vin': _trimmedOrNull(vin)?.toUpperCase(),
      'ownedSince': ownedSince == null ? null : Timestamp.fromDate(ownedSince!),
      'mileage': mileage,
    };
  }

  Map<String, Object?> toPublicFirestore() {
    return <String, Object?>{
      'vehicleId': id.trim(),
      'ownerUserId': ownerUserId.trim(),
      'brand': _trimmedOrNull(brand),
      'model': _trimmedOrNull(model),
      'series': _trimmedOrNull(series),
      'color': _trimmedOrNull(color),
      'countryCode': countryCode.trim().toUpperCase(),
      'plateRegion': showPlate ? plateRegion.trim().toUpperCase() : null,
      'plateLetters': showPlate ? plateLetters.trim().toUpperCase() : null,
      'plateNumbers': showPlate ? plateNumbers.trim().toUpperCase() : null,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'status': status.name,
      'visibility': visibility.name,
      'showPlate': showPlate,
      'year': year,
      'firstRegistration': firstRegistration == null
          ? null
          : Timestamp.fromDate(firstRegistration!),
      'bodyStyle': _trimmedOrNull(bodyStyle),
      'engineDescription': _trimmedOrNull(engineDescription),
      'displacementCcm': displacementCcm,
      'horsepower': horsepower,
      'kilowatts': kilowatts,
      'fuelType': _trimmedOrNull(fuelType),
      'transmission': _trimmedOrNull(transmission),
      'drivetrain': _trimmedOrNull(drivetrain),
      'equipment': _normalizedStringList(equipment),
      'ownedSince': ownedSince == null ? null : Timestamp.fromDate(ownedSince!),
      'mileage': mileage,
    };
  }

  ProfileVehicle copyWith({
    String? id,
    String? ownerUserId,
    String? brand,
    String? model,
    String? series,
    String? color,
    String? countryCode,
    String? plateRegion,
    String? plateLetters,
    String? plateNumbers,
    bool? isPrimary,
    bool? isVerified,
    ProfileVehicleStatus? status,
    ProfileVehicleVisibility? visibility,
    bool? showPlate,
    int? year,
    DateTime? firstRegistration,
    String? bodyStyle,
    String? engineDescription,
    int? displacementCcm,
    int? horsepower,
    int? kilowatts,
    String? fuelType,
    String? transmission,
    String? drivetrain,
    List<String>? equipment,
    String? hsn,
    String? tsn,
    String? vin,
    DateTime? ownedSince,
    int? mileage,
    String? heroImageUrl,
    String? heroImagePath,
    VehicleHeroImageStatus? heroImageStatus,
    String? heroSourceHash,
    int? heroPromptVersion,
    String? heroProvider,
    String? heroError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileVehicle(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      series: series ?? this.series,
      color: color ?? this.color,
      countryCode: countryCode ?? this.countryCode,
      plateRegion: plateRegion ?? this.plateRegion,
      plateLetters: plateLetters ?? this.plateLetters,
      plateNumbers: plateNumbers ?? this.plateNumbers,
      isPrimary: isPrimary ?? this.isPrimary,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      showPlate: showPlate ?? this.showPlate,
      year: year ?? this.year,
      firstRegistration: firstRegistration ?? this.firstRegistration,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      engineDescription: engineDescription ?? this.engineDescription,
      displacementCcm: displacementCcm ?? this.displacementCcm,
      horsepower: horsepower ?? this.horsepower,
      kilowatts: kilowatts ?? this.kilowatts,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      drivetrain: drivetrain ?? this.drivetrain,
      equipment: equipment ?? this.equipment,
      hsn: hsn ?? this.hsn,
      tsn: tsn ?? this.tsn,
      vin: vin ?? this.vin,
      ownedSince: ownedSince ?? this.ownedSince,
      mileage: mileage ?? this.mileage,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      heroImagePath: heroImagePath ?? this.heroImagePath,
      heroImageStatus: heroImageStatus ?? this.heroImageStatus,
      heroSourceHash: heroSourceHash ?? this.heroSourceHash,
      heroPromptVersion: heroPromptVersion ?? this.heroPromptVersion,
      heroProvider: heroProvider ?? this.heroProvider,
      heroError: heroError ?? this.heroError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static T _enumFromName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _stringListFromValue(Object? value) {
    if (value is! List) return const [];
    return _normalizedStringList(value.whereType<String>());
  }

  static List<String> _normalizedStringList(Iterable<String> values) {
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && !normalized.contains(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }
}
