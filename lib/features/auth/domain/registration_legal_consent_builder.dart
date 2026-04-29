import '../../../shared/models/carma_models.dart';

class RegistrationLegalConsentBuilder {
  const RegistrationLegalConsentBuilder._();

  static const String currentTermsVersion = '1.0.0';
  static const String currentPrivacyVersion = '1.0.0';
  static const String currentResponsibleUseVersion = '1.0.0';
  static const String currentNoEmergencyUseVersion = '1.0.0';

  static List<LegalConsent> buildLocalConsents({
    required String userId,
    DateTime? acceptedAt,
  }) {
    final timestamp = acceptedAt ?? DateTime.now();

    return [
      LegalConsent(
        id: '${userId}_terms_$currentTermsVersion',
        userId: userId,
        type: LegalConsentType.terms,
        version: currentTermsVersion,
        acceptedAt: timestamp,
      ),
      LegalConsent(
        id: '${userId}_privacy_$currentPrivacyVersion',
        userId: userId,
        type: LegalConsentType.privacy,
        version: currentPrivacyVersion,
        acceptedAt: timestamp,
      ),
      LegalConsent(
        id: '${userId}_responsible_use_$currentResponsibleUseVersion',
        userId: userId,
        type: LegalConsentType.responsibleUse,
        version: currentResponsibleUseVersion,
        acceptedAt: timestamp,
      ),
      LegalConsent(
        id: '${userId}_no_emergency_use_$currentNoEmergencyUseVersion',
        userId: userId,
        type: LegalConsentType.noEmergencyUse,
        version: currentNoEmergencyUseVersion,
        acceptedAt: timestamp,
      ),
    ];
  }
}