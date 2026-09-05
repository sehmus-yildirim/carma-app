import 'package:flutter/foundation.dart';

enum VerificationIdentityDocumentType {
  idCard('id_card', 'Personalausweis', 'Vorderseite fotografieren'),
  passport('passport', 'Reisepass', 'Datenseite fotografieren'),
  residencePermit(
    'residence_permit',
    'Aufenthaltstitel',
    'Aufenthaltstitel fotografieren',
  );

  const VerificationIdentityDocumentType(
    this.value,
    this.label,
    this.captureLabel,
  );

  final String value;
  final String label;
  final String captureLabel;
}

enum VerificationVehicleRelation {
  registeredHolder('registered_holder', 'Ich bin eingetragener Halter'),
  leasing('leasing', 'Leasingfahrzeug'),
  companyCar('company_car', 'Firmen-/Dienstwagen'),
  authorizedPrivateVehicle(
    'authorized_private_vehicle',
    'Fahrzeug mit Erlaubnis des Halters',
  ),
  otherAuthorized(
    'other_authorized',
    'Sonstiges berechtigt genutztes Fahrzeug',
  );

  const VerificationVehicleRelation(this.value, this.label);

  final String value;
  final String label;

  bool get requiresDeclaration => this != registeredHolder;
}

enum VerificationDocumentKind {
  identityCard,
  passport,
  residencePermit,
  vehicleRegistration,
}

enum VerificationField {
  firstNames,
  lastName,
  dateOfBirth,
  documentExpiryDate,
  plateNumber,
  holderLastNameOrCompany,
  holderFirstNames,
}

enum VerificationV1Status {
  unverified,
  pending,
  requiresDeclaration,
  verified,
  expired,
  revoked,
  failed;

  static VerificationV1Status fromValue(Object? value) {
    final normalized = value?.toString().trim();
    return switch (normalized) {
      'requires_declaration' ||
      'requiresDeclaration' => VerificationV1Status.requiresDeclaration,
      'unverified' => VerificationV1Status.unverified,
      'pending' => VerificationV1Status.pending,
      'verified' => VerificationV1Status.verified,
      'expired' => VerificationV1Status.expired,
      'revoked' => VerificationV1Status.revoked,
      'failed' => VerificationV1Status.failed,
      _ => VerificationV1Status.unverified,
    };
  }
}

enum VerificationSessionState {
  created,
  dataSubmitted,
  requiresDeclaration,
  completed,
  expired,
  failed;

  static VerificationSessionState fromValue(Object? value) {
    final normalized = value?.toString().trim();
    return switch (normalized) {
      'data_submitted' ||
      'dataSubmitted' => VerificationSessionState.dataSubmitted,
      'requires_declaration' ||
      'requiresDeclaration' => VerificationSessionState.requiresDeclaration,
      'completed' => VerificationSessionState.completed,
      'expired' => VerificationSessionState.expired,
      'failed' => VerificationSessionState.failed,
      _ => VerificationSessionState.created,
    };
  }

  bool canTransitionTo(VerificationSessionState next) {
    if (this == next) return true;
    return switch (this) {
      VerificationSessionState.created => {
        VerificationSessionState.dataSubmitted,
        VerificationSessionState.requiresDeclaration,
        VerificationSessionState.completed,
        VerificationSessionState.expired,
        VerificationSessionState.failed,
      }.contains(next),
      VerificationSessionState.dataSubmitted => {
        VerificationSessionState.requiresDeclaration,
        VerificationSessionState.completed,
        VerificationSessionState.expired,
        VerificationSessionState.failed,
      }.contains(next),
      VerificationSessionState.requiresDeclaration => {
        VerificationSessionState.completed,
        VerificationSessionState.expired,
        VerificationSessionState.failed,
      }.contains(next),
      VerificationSessionState.completed ||
      VerificationSessionState.expired ||
      VerificationSessionState.failed => false,
    };
  }
}

enum VerificationParseFailure {
  imageBlurry,
  imageTooDark,
  imageOverexposed,
  documentCropped,
  strongReflection,
  documentNotRecognized,
  missingRequiredField,
  ambiguousField,
  invalidDate,
  conflictingMrz,
  unsupportedDocument,
}

@immutable
class OcrRect {
  const OcrRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

@immutable
class OcrBlock {
  const OcrBlock({required this.text, required this.bounds});

  final String text;
  final OcrRect bounds;
}

@immutable
class IdentityDocumentData {
  const IdentityDocumentData({
    required this.firstNames,
    required this.lastName,
    required this.dateOfBirth,
    required this.expiresAt,
    required this.documentType,
    required this.parserVersion,
    this.issuingCountryCode = 'DE',
    this.documentProfileVersion = '',
  });

  final String firstNames;
  final String lastName;
  final DateTime dateOfBirth;
  final DateTime expiresAt;
  final VerificationIdentityDocumentType documentType;
  final String parserVersion;
  final String issuingCountryCode;
  final String documentProfileVersion;

  Map<String, Object> toSubmissionJson() => {
    'firstNames': firstNames.trim(),
    'lastName': lastName.trim(),
    'dateOfBirth': _dateOnly(dateOfBirth),
    'expiresAt': _dateOnly(expiresAt),
    'documentType': documentType.value,
    'parserVersion': parserVersion,
    'issuingCountryCode': issuingCountryCode.trim().toUpperCase(),
    'documentProfileVersion': documentProfileVersion.trim().isEmpty
        ? parserVersion
        : documentProfileVersion.trim(),
  };
}

@immutable
class VehicleRegistrationData {
  const VehicleRegistrationData({
    required this.plate,
    required this.holderNameOrCompany,
    required this.holderFirstNames,
    required this.parserVersion,
    this.registrationCountryCode = 'DE',
    this.documentProfileVersion = '',
  });

  final String plate;
  final String holderNameOrCompany;
  final String? holderFirstNames;
  final String parserVersion;
  final String registrationCountryCode;
  final String documentProfileVersion;

  Map<String, Object?> toSubmissionJson() => {
    'plate': plate.trim(),
    'holderNameOrCompany': holderNameOrCompany.trim(),
    'holderFirstNames': holderFirstNames?.trim(),
    'parserVersion': parserVersion,
    'registrationCountryCode': registrationCountryCode.trim().toUpperCase(),
    'documentProfileVersion': documentProfileVersion.trim().isEmpty
        ? parserVersion
        : documentProfileVersion.trim(),
  };
}

@immutable
class VerificationParseResult<T> {
  const VerificationParseResult.success(
    this.data, {
    this.fieldConfidence = const {},
  }) : failure = null,
       message = null;

  const VerificationParseResult.failure(this.failure, this.message)
    : data = null,
      fieldConfidence = const {};

  final T? data;
  final VerificationParseFailure? failure;
  final String? message;
  final Map<VerificationField, FieldConfidence> fieldConfidence;

  bool get isSuccess => data != null;
}

@immutable
class CapturedVerificationDocument {
  const CapturedVerificationDocument({
    required this.path,
    required this.kind,
    this.deleteSourceAfterAdoption = true,
    this.isManagedTemporaryFile = false,
  });

  final String path;
  final VerificationDocumentKind kind;
  final bool deleteSourceAfterAdoption;
  final bool isManagedTemporaryFile;
}

enum FieldConfidence { high, medium, low }

enum ImageQualityFailure {
  tooSmall,
  tooDark,
  overexposed,
  blurry,
  documentTooSmall,
  documentCropped,
  documentRotated,
  perspectiveDistortion,
  strongReflection,
}

@immutable
class ImageQualityResult {
  const ImageQualityResult({
    required this.width,
    required this.height,
    required this.averageLuminance,
    required this.contrast,
    required this.sharpness,
    this.failures = const <ImageQualityFailure>[],
    this.framingHints = const <ImageQualityFailure>[],
  });

  final int width;
  final int height;
  final double averageLuminance;
  final double contrast;
  final double sharpness;
  final List<ImageQualityFailure> failures;
  // Image edges alone do not prove where a document ends. These observations
  // must not reject legible, tightly cropped documents before OCR runs.
  final List<ImageQualityFailure> framingHints;

  bool get isAcceptable => failures.isEmpty;

  String get userMessage {
    if (failures.contains(ImageQualityFailure.tooSmall)) {
      return 'Die Bildauflösung ist zu niedrig. Bitte verwende das Originalfoto oder nimm ein neues Foto auf.';
    }
    if (failures.contains(ImageQualityFailure.tooDark)) {
      return 'Das Foto ist zu dunkel. Bitte nutze mehr Licht oder den Blitz.';
    }
    if (failures.contains(ImageQualityFailure.overexposed)) {
      return 'Das Foto ist zu hell. Bitte vermeide direkte Spiegelungen.';
    }
    if (failures.contains(ImageQualityFailure.blurry)) {
      return 'Das Foto ist unscharf. Bitte halte das Smartphone ruhig und fotografiere erneut.';
    }
    if (failures.contains(ImageQualityFailure.strongReflection)) {
      return 'Auf dem Dokument wurde eine starke Reflexion erkannt. Bitte ändere den Winkel und fotografiere erneut.';
    }
    if (failures.contains(ImageQualityFailure.documentTooSmall)) {
      return 'Das Dokument ist zu klein im Bild. Bitte positioniere es näher und vollständig im Rahmen.';
    }
    if (failures.contains(ImageQualityFailure.documentCropped)) {
      return 'Das Dokument ist abgeschnitten. Bitte positioniere alle Ränder vollständig im Rahmen.';
    }
    if (failures.contains(ImageQualityFailure.documentRotated)) {
      return 'Das Dokument ist zu stark gedreht. Bitte richte es am Rahmen aus.';
    }
    if (failures.contains(ImageQualityFailure.perspectiveDistortion)) {
      return 'Das Dokument wurde zu schräg fotografiert. Bitte halte die Kamera möglichst parallel darüber.';
    }
    return 'Das Dokument wurde nicht vollständig erkannt. Bitte positioniere es vollständig im Rahmen.';
  }
}

@immutable
class VerificationSession {
  const VerificationSession({
    required this.sessionId,
    required this.nonce,
    required this.expiresAt,
    required this.state,
  });

  final String sessionId;
  final String nonce;
  final DateTime expiresAt;
  final VerificationSessionState state;
}

@immutable
class VerificationSubmissionResult {
  const VerificationSubmissionResult({
    required this.status,
    required this.holderMatch,
    this.declarationId,
  });

  final VerificationV1Status status;
  final bool holderMatch;
  final String? declarationId;
}

@immutable
class VerificationV1Record {
  const VerificationV1Record({
    required this.status,
    required this.assuranceLevel,
    required this.verificationMethod,
    this.documentExpiresAt,
    this.verifiedAt,
    this.vehicleId,
    this.declarationId,
  });

  final VerificationV1Status status;
  final String assuranceLevel;
  final String verificationMethod;
  final DateTime? documentExpiresAt;
  final DateTime? verifiedAt;
  final String? vehicleId;
  final String? declarationId;
}

abstract final class VerificationV1Policy {
  static const String verificationMethod = 'on_device_document_ocr_v1';
  static const String legacyVerificationMethod = 'on_device_ocr_front_v1';
  static const String assuranceLevel = 'document_data_match';
  static const String privacyVersion =
      'verification_privacy_international_v2.0.0';
  static const String declarationVersion =
      'vehicle_authorization_international_v2.0.0';

  static VerificationV1Status effectiveIdentityStatus(
    VerificationV1Record record, {
    required DateTime serverToday,
  }) {
    if (record.status != VerificationV1Status.verified) return record.status;
    final expiry = record.documentExpiresAt;
    if (expiry == null) return VerificationV1Status.failed;
    final today = DateTime(
      serverToday.year,
      serverToday.month,
      serverToday.day,
    );
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDay.isBefore(today)
        ? VerificationV1Status.expired
        : VerificationV1Status.verified;
  }

  static bool isProtectedActionAllowed({
    required VerificationV1Status identityStatus,
    required VerificationV1Status vehicleStatus,
  }) =>
      identityStatus == VerificationV1Status.verified &&
      vehicleStatus == VerificationV1Status.verified;
}

String _dateOnly(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
