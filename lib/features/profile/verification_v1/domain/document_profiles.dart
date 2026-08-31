import 'verification_models.dart';

enum DocumentProfileStatus {
  implementedNeedsRealValidation,
  productionValidated,
  unsupported,
}

enum DocumentSide { dataPage, front, back, registrationPage }

enum DocumentScript { latin, cyrillic, arabic, devanagari }

enum MrzFormat { td1, td2, td3 }

class VerificationCountry {
  const VerificationCountry({
    required this.code,
    required this.icaoCode,
    required this.label,
  });

  final String code;
  final String icaoCode;
  final String label;
}

class NormalizedFieldRegion {
  const NormalizedFieldRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;
}

class FieldAnchorDefinition {
  const FieldAnchorDefinition({
    required this.field,
    required this.aliases,
    this.exact = false,
  });

  final VerificationField field;
  final List<String> aliases;
  final bool exact;
}

class DocumentMrzConfiguration {
  const DocumentMrzConfiguration({
    required this.formats,
    this.required = false,
  });

  final List<MrzFormat> formats;
  final bool required;
}

class DocumentConfidenceThresholds {
  const DocumentConfidenceThresholds({
    this.minimumSignalsForHigh = 3,
    this.minimumSignalsForMedium = 2,
  });

  final int minimumSignalsForHigh;
  final int minimumSignalsForMedium;
}

class DocumentProfile {
  const DocumentProfile({
    required this.countryCode,
    required this.documentKind,
    required this.documentVersion,
    required this.supportedSides,
    required this.languages,
    required this.scripts,
    required this.anchors,
    required this.fieldRegions,
    required this.normalizationRules,
    required this.validationRules,
    required this.confidenceThresholds,
    required this.status,
    required this.sourceReferences,
    this.identityDocumentType,
    this.mrzConfiguration,
    this.preferred = true,
  });

  final String countryCode;
  final VerificationDocumentKind documentKind;
  final VerificationIdentityDocumentType? identityDocumentType;
  final String documentVersion;
  final List<DocumentSide> supportedSides;
  final List<String> languages;
  final List<DocumentScript> scripts;
  final List<FieldAnchorDefinition> anchors;
  final Map<VerificationField, NormalizedFieldRegion> fieldRegions;
  final DocumentMrzConfiguration? mrzConfiguration;
  final List<String> normalizationRules;
  final List<String> validationRules;
  final DocumentConfidenceThresholds confidenceThresholds;
  final DocumentProfileStatus status;
  final List<String> sourceReferences;
  final bool preferred;

  bool get parserAvailable => status != DocumentProfileStatus.unsupported;
  bool get productionValidated =>
      status == DocumentProfileStatus.productionValidated;

  String get parserVersion =>
      '${countryCode.toLowerCase()}_${documentKind.name}_$documentVersion';

  List<String> aliasesFor(VerificationField field) {
    return anchors
        .where((anchor) => anchor.field == field)
        .expand((anchor) => anchor.aliases)
        .toList(growable: false);
  }
}

abstract final class DocumentProfileRegistry {
  static const List<VerificationCountry> countries = [
    VerificationCountry(code: 'DE', icaoCode: 'DEU', label: 'Deutschland'),
    VerificationCountry(code: 'TR', icaoCode: 'TUR', label: 'Türkei'),
    VerificationCountry(code: 'UA', icaoCode: 'UKR', label: 'Ukraine'),
    VerificationCountry(code: 'SY', icaoCode: 'SYR', label: 'Syrien'),
    VerificationCountry(code: 'RO', icaoCode: 'ROU', label: 'Rumänien'),
    VerificationCountry(code: 'PL', icaoCode: 'POL', label: 'Polen'),
    VerificationCountry(code: 'IT', icaoCode: 'ITA', label: 'Italien'),
    VerificationCountry(code: 'AF', icaoCode: 'AFG', label: 'Afghanistan'),
    VerificationCountry(code: 'BG', icaoCode: 'BGR', label: 'Bulgarien'),
    VerificationCountry(code: 'HR', icaoCode: 'HRV', label: 'Kroatien'),
    VerificationCountry(code: 'GR', icaoCode: 'GRC', label: 'Griechenland'),
    VerificationCountry(code: 'XK', icaoCode: 'RKS', label: 'Kosovo'),
    VerificationCountry(code: 'IN', icaoCode: 'IND', label: 'Indien'),
    VerificationCountry(code: 'RU', icaoCode: 'RUS', label: 'Russland'),
    VerificationCountry(code: 'RS', icaoCode: 'SRB', label: 'Serbien'),
    VerificationCountry(code: 'AT', icaoCode: 'AUT', label: 'Österreich'),
    VerificationCountry(
      code: 'BA',
      icaoCode: 'BIH',
      label: 'Bosnien und Herzegowina',
    ),
    VerificationCountry(code: 'ES', icaoCode: 'ESP', label: 'Spanien'),
    VerificationCountry(code: 'FR', icaoCode: 'FRA', label: 'Frankreich'),
    VerificationCountry(code: 'NL', icaoCode: 'NLD', label: 'Niederlande'),
    VerificationCountry(code: 'CH', icaoCode: 'CHE', label: 'Schweiz'),
  ];

  static const String icaoSource =
      'https://www.icao.int/publications/doc-series/doc-9303';
  static const String pradoSource =
      'https://www.consilium.europa.eu/prado/en/search-by-document-country.html';
  static const String euVehicleSource =
      'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:31999L0037';

  static final List<DocumentProfile> profiles = [
    for (final country in countries) _passportProfile(country),
    ..._germanIdentityProfiles,
    _germanResidencePermitProfile,
    _germanVehicleRegistrationProfile,
  ];

  static VerificationCountry? country(String code) {
    final normalized = code.trim().toUpperCase();
    for (final country in countries) {
      if (country.code == normalized || country.icaoCode == normalized) {
        return country;
      }
    }
    return null;
  }

  static List<VerificationIdentityDocumentType> identityTypesFor(
    String countryCode,
  ) {
    final types = profiles
        .where(
          (profile) =>
              profile.countryCode == countryCode.trim().toUpperCase() &&
              profile.identityDocumentType != null &&
              profile.parserAvailable,
        )
        .map((profile) => profile.identityDocumentType!)
        .toSet();
    return VerificationIdentityDocumentType.values
        .where(types.contains)
        .toList(growable: false);
  }

  static DocumentProfile? identityProfile({
    required String countryCode,
    required VerificationIdentityDocumentType documentType,
  }) {
    final matches = profiles.where(
      (profile) =>
          profile.countryCode == countryCode.trim().toUpperCase() &&
          profile.identityDocumentType == documentType &&
          profile.parserAvailable,
    );
    for (final profile in matches) {
      if (profile.preferred) return profile;
    }
    return matches.isEmpty ? null : matches.first;
  }

  static DocumentProfile? vehicleRegistrationProfile(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();
    for (final profile in profiles) {
      if (profile.countryCode == normalized &&
          profile.documentKind ==
              VerificationDocumentKind.vehicleRegistration &&
          profile.parserAvailable) {
        return profile;
      }
    }
    return null;
  }

  static DocumentProfileStatus statusFor({
    required String countryCode,
    required VerificationDocumentKind kind,
  }) {
    final normalized = countryCode.trim().toUpperCase();
    final matches = profiles.where(
      (profile) =>
          profile.countryCode == normalized && profile.documentKind == kind,
    );
    if (matches.isEmpty) return DocumentProfileStatus.unsupported;
    if (matches.any((profile) => profile.productionValidated)) {
      return DocumentProfileStatus.productionValidated;
    }
    return DocumentProfileStatus.implementedNeedsRealValidation;
  }

  static DocumentProfile _passportProfile(VerificationCountry country) {
    return DocumentProfile(
      countryCode: country.code,
      documentKind: VerificationDocumentKind.passport,
      identityDocumentType: VerificationIdentityDocumentType.passport,
      documentVersion: 'icao_td3_eighth_edition_v1',
      supportedSides: const [DocumentSide.dataPage],
      languages: const ['document language', 'ICAO MRZ'],
      scripts: const [DocumentScript.latin],
      anchors: const [],
      fieldRegions: const {},
      mrzConfiguration: const DocumentMrzConfiguration(
        formats: [MrzFormat.td3],
        required: true,
      ),
      normalizationRules: const [
        'ICAO 9303 filler and transliteration rules',
        'Unicode source value is kept separate from the MRZ comparison value',
      ],
      validationRules: const [
        'TD3 line lengths and date check digits must be valid',
        'issuing country must match the selected document country',
      ],
      confidenceThresholds: const DocumentConfidenceThresholds(),
      status: DocumentProfileStatus.implementedNeedsRealValidation,
      sourceReferences: [icaoSource, pradoSource],
    );
  }

  static const List<DocumentProfile> _germanIdentityProfiles = [
    DocumentProfile(
      countryCode: 'DE',
      documentKind: VerificationDocumentKind.identityCard,
      identityDocumentType: VerificationIdentityDocumentType.idCard,
      documentVersion: 'deu_bo_02004_2021_v1',
      supportedSides: [DocumentSide.front],
      languages: ['de', 'en', 'fr'],
      scripts: [DocumentScript.latin],
      anchors: _germanIdentityAnchors,
      fieldRegions: _identityFieldRegions,
      mrzConfiguration: DocumentMrzConfiguration(formats: [MrzFormat.td1]),
      normalizationRules: ['German/ICAO name and date normalization'],
      validationRules: [
        'all four permitted identity fields are required',
        'ambiguous candidates are rejected',
      ],
      confidenceThresholds: DocumentConfidenceThresholds(),
      status: DocumentProfileStatus.implementedNeedsRealValidation,
      sourceReferences: [
        'https://www.consilium.europa.eu/prado/en/DEU-BO-02004/index.html',
        icaoSource,
      ],
    ),
    DocumentProfile(
      countryCode: 'DE',
      documentKind: VerificationDocumentKind.identityCard,
      identityDocumentType: VerificationIdentityDocumentType.idCard,
      documentVersion: 'deu_bo_02001_2010_v1',
      supportedSides: [DocumentSide.front],
      languages: ['de', 'en', 'fr'],
      scripts: [DocumentScript.latin],
      anchors: _germanIdentityAnchors,
      fieldRegions: _identityFieldRegions,
      mrzConfiguration: DocumentMrzConfiguration(formats: [MrzFormat.td1]),
      normalizationRules: ['German/ICAO name and date normalization'],
      validationRules: [
        'all four permitted identity fields are required',
        'ambiguous candidates are rejected',
      ],
      confidenceThresholds: DocumentConfidenceThresholds(),
      status: DocumentProfileStatus.implementedNeedsRealValidation,
      sourceReferences: [
        'https://www.consilium.europa.eu/prado/en/DEU-BO-02001/index.html',
        icaoSource,
      ],
      preferred: false,
    ),
  ];

  static const DocumentProfile _germanResidencePermitProfile = DocumentProfile(
    countryCode: 'DE',
    documentKind: VerificationDocumentKind.residencePermit,
    identityDocumentType: VerificationIdentityDocumentType.residencePermit,
    documentVersion: 'de_eat_card_family_v1',
    supportedSides: [DocumentSide.front],
    languages: ['de', 'en', 'fr'],
    scripts: [DocumentScript.latin],
    anchors: _germanIdentityAnchors,
    fieldRegions: _identityFieldRegions,
    mrzConfiguration: DocumentMrzConfiguration(formats: [MrzFormat.td1]),
    normalizationRules: ['German/ICAO name and date normalization'],
    validationRules: [
      'only card profiles exposing all four permitted fields are accepted',
      'ambiguous candidates are rejected',
    ],
    confidenceThresholds: DocumentConfidenceThresholds(),
    status: DocumentProfileStatus.implementedNeedsRealValidation,
    sourceReferences: [
      'https://www.consilium.europa.eu/prado/en/prado-documents/deu/h/docs-per-category.html',
      icaoSource,
    ],
  );

  static const DocumentProfile _germanVehicleRegistrationProfile =
      DocumentProfile(
        countryCode: 'DE',
        documentKind: VerificationDocumentKind.vehicleRegistration,
        documentVersion: 'deu_go_01001_2005_v1',
        supportedSides: [DocumentSide.registrationPage],
        languages: ['de', 'EU harmonised codes'],
        scripts: [DocumentScript.latin],
        anchors: [
          FieldAnchorDefinition(
            field: VerificationField.plateNumber,
            aliases: ['A'],
            exact: true,
          ),
          FieldAnchorDefinition(
            field: VerificationField.holderLastNameOrCompany,
            aliases: ['C.1.1', 'C 1.1'],
          ),
          FieldAnchorDefinition(
            field: VerificationField.holderFirstNames,
            aliases: ['C.1.2', 'C 1.2'],
          ),
        ],
        fieldRegions: {
          VerificationField.plateNumber: NormalizedFieldRegion(
            left: 0,
            top: 0,
            right: 1,
            bottom: 1,
          ),
          VerificationField.holderLastNameOrCompany: NormalizedFieldRegion(
            left: 0,
            top: 0,
            right: 1,
            bottom: 1,
          ),
          VerificationField.holderFirstNames: NormalizedFieldRegion(
            left: 0,
            top: 0,
            right: 1,
            bottom: 1,
          ),
        },
        normalizationRules: ['EU registration plate normalization'],
        validationRules: [
          'A and C.1.1 are required',
          'C.1.2 may be empty for a company holder',
        ],
        confidenceThresholds: DocumentConfidenceThresholds(),
        status: DocumentProfileStatus.implementedNeedsRealValidation,
        sourceReferences: [
          'https://www.consilium.europa.eu/prado/en/DEU-GO-01001/index.html',
          euVehicleSource,
        ],
      );

  static const List<FieldAnchorDefinition> _germanIdentityAnchors = [
    FieldAnchorDefinition(
      field: VerificationField.firstNames,
      aliases: [
        'Vornamen',
        'Vorname',
        'Vorname(n)',
        'Given names',
        'Given name',
        'Forenames',
        'Forename',
        'Prénoms',
        'Prenoms',
        'Given names/Prénoms',
        'Given names/Prenoms',
        'Vornamen/Given names/Prénoms',
        'Vornamen/Given names/Prenoms',
        'Vornamen/Given name(s)/Prénom(s)',
        'Vornamen/Given name(s)/Prenom(s)',
        'Vorname(n)/Given name(s)/Prénom(s)',
        'Vorname(n)/Given name(s)/Prenom(s)',
      ],
    ),
    FieldAnchorDefinition(
      field: VerificationField.lastName,
      aliases: [
        'Familienname',
        'Surname',
        'Nom',
        'Name',
        'Surname/Nom',
        'Name/Surname/Nom',
        'Familienname/Surname/Nom',
      ],
    ),
    FieldAnchorDefinition(
      field: VerificationField.dateOfBirth,
      aliases: [
        'Geburtsdatum',
        'Geburtstag',
        'Tag der Geburt',
        'Date of birth',
        'Date de naissance',
        'Date of birth/Date de naissance',
        'Geburtsdatum/Date of birth/Date de naissance',
        'Tag der Geburt/Date of birth/Date de naissance',
      ],
    ),
    FieldAnchorDefinition(
      field: VerificationField.documentExpiryDate,
      aliases: [
        'Gültig bis',
        'Gueltig bis',
        'Gultig bis',
        'Date of expiry',
        'Date of expiration',
        "Date d'expiration",
        'Date d expiration',
        "Date of expiry/Date d'expiration",
        'Date of expiry/Date d expiration',
        "Gültig bis/Date of expiry/Date d'expiration",
        'Gültig bis/Date of expiry/Date d expiration',
        'Expiry',
      ],
    ),
  ];

  static const Map<VerificationField, NormalizedFieldRegion>
  _identityFieldRegions = {
    VerificationField.firstNames: NormalizedFieldRegion(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
    ),
    VerificationField.lastName: NormalizedFieldRegion(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
    ),
    VerificationField.dateOfBirth: NormalizedFieldRegion(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
    ),
    VerificationField.documentExpiryDate: NormalizedFieldRegion(
      left: 0,
      top: 0,
      right: 1,
      bottom: 1,
    ),
  };
}
