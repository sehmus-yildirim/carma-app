import '../../../shared/models/carma_models.dart';

class ProfileDocumentMapper {
  const ProfileDocumentMapper._();

  static const Map<String, VerificationDocumentType> documentTypeByTitle = {
    'Ausweis Vorderseite': VerificationDocumentType.idFront,
    'Ausweis Rückseite': VerificationDocumentType.idBack,
    'Führerschein Vorderseite': VerificationDocumentType.driverLicenseFront,
    'Führerschein Rückseite': VerificationDocumentType.driverLicenseBack,
    'Fahrzeugschein Vorderseite':
    VerificationDocumentType.vehicleRegistrationFront,
    'Fahrzeugschein Rückseite':
    VerificationDocumentType.vehicleRegistrationBack,
  };

  static VerificationDocumentType? typeForTitle(String title) {
    return documentTypeByTitle[title];
  }

  static String titleForType(VerificationDocumentType type) {
    return switch (type) {
      VerificationDocumentType.idFront => 'Ausweis Vorderseite',
      VerificationDocumentType.idBack => 'Ausweis Rückseite',
      VerificationDocumentType.driverLicenseFront =>
      'Führerschein Vorderseite',
      VerificationDocumentType.driverLicenseBack => 'Führerschein Rückseite',
      VerificationDocumentType.vehicleRegistrationFront =>
      'Fahrzeugschein Vorderseite',
      VerificationDocumentType.vehicleRegistrationBack =>
      'Fahrzeugschein Rückseite',
    };
  }

  static Map<VerificationDocumentType, String?> toDocumentLocalPaths(
      Map<String, String?> documentPathsByTitle,
      ) {
    return {
      for (final type in VerificationDocumentType.values)
        type: documentPathsByTitle[titleForType(type)],
    };
  }

  static List<VerificationDocument> toVerificationDocuments({
    required Map<String, String?> documentPathsByTitle,
    required bool isSubmittedForVerification,
    required bool isVerified,
  }) {
    final documentLocalPaths = toDocumentLocalPaths(documentPathsByTitle);

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

  static bool areAllDocumentsUploaded(Map<String, String?> documentPathsByTitle) {
    final documentLocalPaths = toDocumentLocalPaths(documentPathsByTitle);

    return VerificationDocumentType.values.every(
          (type) => documentLocalPaths[type]?.trim().isNotEmpty == true,
    );
  }
}