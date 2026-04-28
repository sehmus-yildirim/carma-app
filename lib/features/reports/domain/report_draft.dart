import '../../../shared/models/carma_models.dart';

enum ReportDraftCategory {
  vehicleOpen,
  lightsOrElectric,
  vehicleBlocked,
  visibleDamage,
  acuteDanger,
  policeOnSite,
}

class ReportDraft {
  const ReportDraft({
    required this.senderUserId,
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
    required this.category,
    required this.message,
    required this.useGpsLocation,
    this.manualAddress,
    this.latitude,
    this.longitude,
    this.imageLocalPath,
  });

  final String senderUserId;

  final String countryCode;
  final String region;
  final String letters;
  final String numbers;

  final ReportDraftCategory? category;
  final String message;

  final bool useGpsLocation;
  final String? manualAddress;
  final double? latitude;
  final double? longitude;

  final String? imageLocalPath;

  CarmaPlate get targetPlate {
    return CarmaPlate(
      countryCode: countryCode,
      region: region,
      letters: letters,
      numbers: numbers,
    );
  }

  bool get hasPlate {
    return targetPlate.isComplete;
  }

  bool get hasLocation {
    if (useGpsLocation) {
      return latitude != null && longitude != null;
    }

    return manualAddress?.trim().isNotEmpty == true;
  }

  bool get hasCategory {
    return category != null;
  }

  bool get hasImage {
    return imageLocalPath?.trim().isNotEmpty == true;
  }

  bool get canSubmit {
    return hasCategory && hasPlate && hasLocation;
  }

  bool get requiresCarefulHandling {
    return category == ReportDraftCategory.acuteDanger ||
        category == ReportDraftCategory.policeOnSite;
  }

  ReportType get reportType {
    return switch (category) {
      ReportDraftCategory.vehicleOpen => ReportType.windowOpen,
      ReportDraftCategory.lightsOrElectric => ReportType.lightsOn,
      ReportDraftCategory.vehicleBlocked => ReportType.parkingIssue,
      ReportDraftCategory.visibleDamage => ReportType.damageObserved,
      ReportDraftCategory.acuteDanger => ReportType.danger,
      ReportDraftCategory.policeOnSite => ReportType.danger,
      null => ReportType.other,
    };
  }

  String get categoryLabel {
    return switch (category) {
      ReportDraftCategory.vehicleOpen => 'Fahrzeug offen',
      ReportDraftCategory.lightsOrElectric => 'Licht / Elektrik',
      ReportDraftCategory.vehicleBlocked => 'Blockiert',
      ReportDraftCategory.visibleDamage => 'Schaden',
      ReportDraftCategory.acuteDanger => 'Akute Gefahr',
      ReportDraftCategory.policeOnSite => 'Polizei vor Ort',
      null => 'Kein Hinweis ausgewählt',
    };
  }

  String get normalizedMessage {
    final trimmedMessage = message.trim();

    if (trimmedMessage.isNotEmpty) {
      return trimmedMessage;
    }

    return categoryLabel;
  }

  String? get locationLabel {
    if (useGpsLocation) {
      if (latitude == null || longitude == null) {
        return null;
      }

      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }

    final address = manualAddress?.trim();

    if (address == null || address.isEmpty) {
      return null;
    }

    return address;
  }

  Report toReport({
    String id = 'local-report',
  }) {
    return Report(
      id: id,
      senderUserId: senderUserId,
      targetPlate: targetPlate,
      type: reportType,
      status: ReportStatus.draft,
      message: normalizedMessage,
      vehicleDescription: locationLabel,
      imageLocalPath: imageLocalPath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  ReportDraft copyWith({
    String? senderUserId,
    String? countryCode,
    String? region,
    String? letters,
    String? numbers,
    ReportDraftCategory? category,
    String? message,
    bool? useGpsLocation,
    String? manualAddress,
    double? latitude,
    double? longitude,
    String? imageLocalPath,
  }) {
    return ReportDraft(
      senderUserId: senderUserId ?? this.senderUserId,
      countryCode: countryCode ?? this.countryCode,
      region: region ?? this.region,
      letters: letters ?? this.letters,
      numbers: numbers ?? this.numbers,
      category: category ?? this.category,
      message: message ?? this.message,
      useGpsLocation: useGpsLocation ?? this.useGpsLocation,
      manualAddress: manualAddress ?? this.manualAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
    );
  }
}