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

enum ProfileVehicleVerificationStatus {
  unverified,
  evidenceMissing,
  inReview,
  verified,
  rejected,
}

enum ProfileVehicleUseRelationship { owner, leasingCompany, authorizedUser }

enum ProfileVehicleType { passengerCar, motorcycle, transporter }

enum ProfilePlateType { standard, electric, historic, seasonal }

enum ProfilePlateDisplayMode { full, shortened, hidden }

enum VehicleHeroImageStatus {
  notGenerated,
  queued,
  generating,
  ready,
  failed,
  regenerationRequired,
}

enum ProfileVehicleHighlight {
  plate,
  color,
  mileage,
  status,
  ownedSince,
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
    this.verificationStatus = ProfileVehicleVerificationStatus.unverified,
    this.verificationLocked = false,
    this.verificationRejectionReason,
    this.status = ProfileVehicleStatus.active,
    this.visibility = ProfileVehicleVisibility.contacts,
    this.showPlate = false,
    this.useRelationship = ProfileVehicleUseRelationship.owner,
    this.vehicleType = ProfileVehicleType.passengerCar,
    this.plateType = ProfilePlateType.standard,
    this.seasonStartMonth,
    this.seasonEndMonth,
    this.showOnPublicProfile = true,
    this.discoverableByPlate = true,
    this.selectableInStories = true,
    this.allowContactRequests = true,
    this.plateDisplayMode = ProfilePlateDisplayMode.hidden,
    this.publicPlateLabel,
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
    this.profileHighlights = const <ProfileVehicleHighlight>[
      ProfileVehicleHighlight.plate,
      ProfileVehicleHighlight.color,
      ProfileVehicleHighlight.mileage,
      ProfileVehicleHighlight.ownedSince,
    ],
    this.heroImageUrl,
    this.heroImagePath,
    this.heroImageStatus = VehicleHeroImageStatus.notGenerated,
    this.heroSourceHash,
    this.heroPromptVersion,
    this.heroProvider,
    this.heroError,
    this.createdAt,
    this.updatedAt,
    this.deactivatedAt,
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
  final ProfileVehicleVerificationStatus verificationStatus;
  final bool verificationLocked;
  final String? verificationRejectionReason;
  final ProfileVehicleStatus status;
  final ProfileVehicleVisibility visibility;
  final bool showPlate;
  final ProfileVehicleUseRelationship useRelationship;
  final ProfileVehicleType vehicleType;
  final ProfilePlateType plateType;
  final int? seasonStartMonth;
  final int? seasonEndMonth;
  final bool showOnPublicProfile;
  final bool discoverableByPlate;
  final bool selectableInStories;
  final bool allowContactRequests;
  final ProfilePlateDisplayMode plateDisplayMode;
  final String? publicPlateLabel;
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
  final List<ProfileVehicleHighlight> profileHighlights;
  final String? heroImageUrl;
  final String? heroImagePath;
  final VehicleHeroImageStatus heroImageStatus;
  final String? heroSourceHash;
  final int? heroPromptVersion;
  final String? heroProvider;
  final String? heroError;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deactivatedAt;

  bool get isArchived => status == ProfileVehicleStatus.archived;

  bool get isPubliclyVisible =>
      showOnPublicProfile &&
      visibility == ProfileVehicleVisibility.contacts &&
      !isArchived;

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

  String get displayPlate {
    final formatted = formatDisplayPlate(
      countryCode: countryCode,
      region: plateRegion,
      letters: plateLetters,
      numbers: plateNumbers,
    );
    if (formatted.isNotEmpty) return formatted;
    return publicPlateLabel?.trim() ?? '';
  }

  String get publicDisplayPlate {
    return switch (plateDisplayMode) {
      ProfilePlateDisplayMode.full => displayPlate,
      ProfilePlateDisplayMode.shortened => _shortenedPlateLabel(),
      ProfilePlateDisplayMode.hidden => 'Kennzeichen verborgen',
    };
  }

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
      verificationStatus: _verificationStatusFromData(data),
      verificationLocked: data['verificationLocked'] as bool? ?? false,
      verificationRejectionReason:
          data['verificationRejectionReason'] as String?,
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
      useRelationship: _enumFromName(
        ProfileVehicleUseRelationship.values,
        data['useRelationship'] as String?,
        ProfileVehicleUseRelationship.owner,
      ),
      vehicleType: _enumFromName(
        ProfileVehicleType.values,
        data['vehicleType'] as String?,
        ProfileVehicleType.passengerCar,
      ),
      plateType: _enumFromName(
        ProfilePlateType.values,
        data['plateType'] as String?,
        ProfilePlateType.standard,
      ),
      seasonStartMonth: data['seasonStartMonth'] as int?,
      seasonEndMonth: data['seasonEndMonth'] as int?,
      showOnPublicProfile:
          data['showOnPublicProfile'] as bool? ??
          data['visibility'] == ProfileVehicleVisibility.contacts.name,
      discoverableByPlate: data['discoverableByPlate'] as bool? ?? true,
      selectableInStories: data['selectableInStories'] as bool? ?? true,
      allowContactRequests: data['allowContactRequests'] as bool? ?? true,
      plateDisplayMode: _plateDisplayModeFromData(data),
      publicPlateLabel: data['plateDisplayLabel'] as String?,
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
      profileHighlights: _highlightListFromValue(data['profileHighlights']),
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
      deactivatedAt: _dateTimeFromValue(data['deactivatedAt']),
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
      verificationStatus: profile.verificationStatus == 'verified'
          ? ProfileVehicleVerificationStatus.verified
          : ProfileVehicleVerificationStatus.unverified,
      visibility: profile.showVehicleOnPublicProfile
          ? ProfileVehicleVisibility.contacts
          : ProfileVehicleVisibility.onlyMe,
      showPlate: profile.showPlateOnPublicProfile,
      showOnPublicProfile: profile.showVehicleOnPublicProfile,
      discoverableByPlate: profile.allowContactRequests,
      allowContactRequests: profile.allowContactRequests,
      plateDisplayMode: profile.showPlateOnPublicProfile
          ? ProfilePlateDisplayMode.full
          : ProfilePlateDisplayMode.hidden,
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
      'verificationStatus': verificationStatus.name,
      'verificationLocked': verificationLocked,
      'verificationRejectionReason': _trimmedOrNull(
        verificationRejectionReason,
      ),
      'status': status.name,
      'visibility': visibility.name,
      'showPlate': showPlate,
      'useRelationship': useRelationship.name,
      'vehicleType': vehicleType.name,
      'plateType': plateType.name,
      'seasonStartMonth': seasonStartMonth,
      'seasonEndMonth': seasonEndMonth,
      'showOnPublicProfile': showOnPublicProfile,
      'discoverableByPlate': discoverableByPlate,
      'selectableInStories': selectableInStories,
      'allowContactRequests': allowContactRequests,
      'plateDisplayMode': plateDisplayMode.name,
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
      'profileHighlights': profileHighlights.map((value) => value.name).toList(),
      'deactivatedAt': deactivatedAt == null
          ? null
          : Timestamp.fromDate(deactivatedAt!),
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
      'plateRegion': plateDisplayMode == ProfilePlateDisplayMode.full
          ? plateRegion.trim().toUpperCase()
          : null,
      'plateLetters': plateDisplayMode == ProfilePlateDisplayMode.full
          ? plateLetters.trim().toUpperCase()
          : null,
      'plateNumbers': plateDisplayMode == ProfilePlateDisplayMode.full
          ? plateNumbers.trim().toUpperCase()
          : null,
      'plateDisplayLabel': publicDisplayPlate,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus.name,
      'status': status.name,
      'visibility': visibility.name,
      'showPlate': showPlate,
      'vehicleType': vehicleType.name,
      'plateType': plateType.name,
      'seasonStartMonth': seasonStartMonth,
      'seasonEndMonth': seasonEndMonth,
      'showOnPublicProfile': showOnPublicProfile,
      'selectableInStories': selectableInStories,
      'allowContactRequests': allowContactRequests,
      'plateDisplayMode': plateDisplayMode.name,
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
      'profileHighlights': profileHighlights.map((value) => value.name).toList(),
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
    ProfileVehicleVerificationStatus? verificationStatus,
    bool? verificationLocked,
    String? verificationRejectionReason,
    ProfileVehicleStatus? status,
    ProfileVehicleVisibility? visibility,
    bool? showPlate,
    ProfileVehicleUseRelationship? useRelationship,
    ProfileVehicleType? vehicleType,
    ProfilePlateType? plateType,
    int? seasonStartMonth,
    int? seasonEndMonth,
    bool? showOnPublicProfile,
    bool? discoverableByPlate,
    bool? selectableInStories,
    bool? allowContactRequests,
    ProfilePlateDisplayMode? plateDisplayMode,
    String? publicPlateLabel,
    int? year,
    DateTime? firstRegistration,
    bool clearFirstRegistration = false,
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
    bool clearOwnedSince = false,
    int? mileage,
    List<ProfileVehicleHighlight>? profileHighlights,
    String? heroImageUrl,
    String? heroImagePath,
    VehicleHeroImageStatus? heroImageStatus,
    String? heroSourceHash,
    int? heroPromptVersion,
    String? heroProvider,
    String? heroError,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deactivatedAt,
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
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationLocked: verificationLocked ?? this.verificationLocked,
      verificationRejectionReason:
          verificationRejectionReason ?? this.verificationRejectionReason,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      showPlate: showPlate ?? this.showPlate,
      useRelationship: useRelationship ?? this.useRelationship,
      vehicleType: vehicleType ?? this.vehicleType,
      plateType: plateType ?? this.plateType,
      seasonStartMonth: seasonStartMonth ?? this.seasonStartMonth,
      seasonEndMonth: seasonEndMonth ?? this.seasonEndMonth,
      showOnPublicProfile:
          showOnPublicProfile ?? this.showOnPublicProfile,
      discoverableByPlate: discoverableByPlate ?? this.discoverableByPlate,
      selectableInStories: selectableInStories ?? this.selectableInStories,
      allowContactRequests:
          allowContactRequests ?? this.allowContactRequests,
      plateDisplayMode: plateDisplayMode ?? this.plateDisplayMode,
      publicPlateLabel: publicPlateLabel ?? this.publicPlateLabel,
      year: year ?? this.year,
      firstRegistration: clearFirstRegistration
          ? null
          : firstRegistration ?? this.firstRegistration,
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
      ownedSince: clearOwnedSince ? null : ownedSince ?? this.ownedSince,
      mileage: mileage ?? this.mileage,
      profileHighlights: profileHighlights ?? this.profileHighlights,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      heroImagePath: heroImagePath ?? this.heroImagePath,
      heroImageStatus: heroImageStatus ?? this.heroImageStatus,
      heroSourceHash: heroSourceHash ?? this.heroSourceHash,
      heroPromptVersion: heroPromptVersion ?? this.heroPromptVersion,
      heroProvider: heroProvider ?? this.heroProvider,
      heroError: heroError ?? this.heroError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
    );
  }

  String _shortenedPlateLabel() {
    final region = plateRegion.trim().toUpperCase();
    if (region.isEmpty) return 'Kennzeichen verkürzt';
    final firstLetter = plateLetters.trim().isEmpty
        ? ''
        : ' ${plateLetters.trim().substring(0, 1).toUpperCase()}';
    return '$region$firstLetter •••';
  }

  static ProfileVehicleVerificationStatus _verificationStatusFromData(
    Map<String, dynamic> data,
  ) {
    final explicit = data['verificationStatus'] as String?;
    if (explicit != null) {
      return _enumFromName(
        ProfileVehicleVerificationStatus.values,
        explicit,
        ProfileVehicleVerificationStatus.unverified,
      );
    }
    return data['isVerified'] == true
        ? ProfileVehicleVerificationStatus.verified
        : ProfileVehicleVerificationStatus.unverified;
  }

  static ProfilePlateDisplayMode _plateDisplayModeFromData(
    Map<String, dynamic> data,
  ) {
    final explicit = data['plateDisplayMode'] as String?;
    if (explicit != null) {
      return _enumFromName(
        ProfilePlateDisplayMode.values,
        explicit,
        ProfilePlateDisplayMode.hidden,
      );
    }
    return data['showPlate'] == true
        ? ProfilePlateDisplayMode.full
        : ProfilePlateDisplayMode.hidden;
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

  static List<ProfileVehicleHighlight> _highlightListFromValue(Object? value) {
    if (value is! List) {
      return const <ProfileVehicleHighlight>[
        ProfileVehicleHighlight.plate,
        ProfileVehicleHighlight.color,
        ProfileVehicleHighlight.mileage,
        ProfileVehicleHighlight.ownedSince,
      ];
    }
    final highlights = <ProfileVehicleHighlight>[];
    for (final name in value.whereType<String>()) {
      for (final highlight in ProfileVehicleHighlight.values) {
        if (highlight.name == name && !highlights.contains(highlight)) {
          highlights.add(highlight);
        }
      }
    }
    return highlights.isEmpty
        ? const <ProfileVehicleHighlight>[ProfileVehicleHighlight.plate]
        : highlights.take(5).toList(growable: false);
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
