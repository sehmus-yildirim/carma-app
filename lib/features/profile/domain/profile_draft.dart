import '../../../shared/models/carma_models.dart';

class ProfileDraft {
  const ProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.countryCode,
    required this.region,
    required this.letters,
    required this.numbers,
    required this.brand,
    required this.model,
    required this.color,
    required this.allowContactRequests,
    required this.allowAnonymousReports,
    required this.documentLocalPaths,
    this.profilePhotoLocalPath,
    this.isSubmittedForVerification = false,
    this.isVerified = false,
  });

  final String firstName;
  final String lastName;

  final String countryCode;
  final String region;
  final String letters;
  final String numbers;

  final String brand;
  final String model;
  final String color;

  final bool allowContactRequests;
  final bool allowAnonymousReports;

  final String? profilePhotoLocalPath;
  final Map<VerificationDocumentType, String?> documentLocalPaths;

  final bool isSubmittedForVerification;
  final bool isVerified;

  CarmaPlate get plate {
    return CarmaPlate(
      countryCode: countryCode,
      region: region,
      letters: letters,
      numbers: numbers,
    );
  }

  Vehicle get vehicle {
    return Vehicle(
      id: 'local-primary-vehicle',
      plate: plate,
      brand: brand,
      model: model,
      color: color,
      isPrimary: true,
      isVerified: isVerified,
    );
  }

  UserVerificationStatus get verificationStatus {
    if (isVerified) {
      return UserVerificationStatus.verified;
    }

    if (isSubmittedForVerification) {
      return UserVerificationStatus.pending;
    }

    return UserVerificationStatus.notSubmitted;
  }

  List<VerificationDocument> get documents {
    return VerificationDocumentType.values.map((type) {
      final localPath = documentLocalPaths[type];

      return VerificationDocument(
        id: type.name,
        type: type,
        status: localPath == null
            ? VerificationDocumentStatus.missing
            : isSubmittedForVerification || isVerified
            ? VerificationDocumentStatus.pendingReview
            : VerificationDocumentStatus.uploaded,
        localPath: localPath,
      );
    }).toList();
  }

  UserProfile toUserProfile({
    String id = 'local-user',
  }) {
    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      visibility: UserProfileVisibility.visible,
      verificationStatus: verificationStatus,
      vehicles: [vehicle],
      documents: documents,
      profilePhotoLocalPath: profilePhotoLocalPath,
      allowContactRequests: allowContactRequests,
      allowAnonymousReports: allowAnonymousReports,
      updatedAt: DateTime.now(),
    );
  }

  bool get hasName {
    return firstName.trim().isNotEmpty && lastName.trim().isNotEmpty;
  }

  bool get hasVehicle {
    return vehicle.hasRequiredData;
  }

  bool get hasAllDocuments {
    return documents.every((document) => document.isUploaded);
  }

  bool get canSubmitForVerification {
    return hasName && hasVehicle && hasAllDocuments;
  }
}