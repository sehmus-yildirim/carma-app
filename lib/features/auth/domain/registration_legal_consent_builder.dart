import '../../../shared/legal/legal_versions.dart';
import '../../../shared/models/carma_models.dart';

class RegistrationLegalConsentBuilder {
  const RegistrationLegalConsentBuilder._();

  static List<LegalConsent> buildLocalConsents({
    required String userId,
    DateTime? acceptedAt,
  }) {
    final timestamp = acceptedAt ?? DateTime.now();

    return [
      LegalConsent(
        id: '${userId}_terms_${LegalVersions.terms}',
        userId: userId,
        type: LegalConsentType.terms,
        version: LegalVersions.terms,
        acceptedAt: timestamp,
      ),
      LegalConsent(
        id: '${userId}_privacy_${LegalVersions.privacy}',
        userId: userId,
        type: LegalConsentType.privacy,
        version: LegalVersions.privacy,
        acceptedAt: timestamp,
      ),
      LegalConsent(
        id: '${userId}_responsible_use_${LegalVersions.responsibleUse}',
        userId: userId,
        type: LegalConsentType.responsibleUse,
        version: LegalVersions.responsibleUse,
        acceptedAt: timestamp,
      ),
      LegalConsent(
        id: '${userId}_no_emergency_use_${LegalVersions.noEmergencyUse}',
        userId: userId,
        type: LegalConsentType.noEmergencyUse,
        version: LegalVersions.noEmergencyUse,
        acceptedAt: timestamp,
      ),
    ];
  }
}