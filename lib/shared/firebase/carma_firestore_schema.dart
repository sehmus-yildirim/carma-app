class CarmaFirestoreSchema {
  const CarmaFirestoreSchema._();
}

class FirestoreAccountStates {
  const FirestoreAccountStates._();

  static const String registered = 'registered';
  static const String onboardingCompleted = 'onboardingCompleted';
  static const String verificationPending = 'verificationPending';
  static const String verified = 'verified';
  static const String restricted = 'restricted';
  static const String suspended = 'suspended';
  static const String deleted = 'deleted';
}

class FirestoreContactRequestStatus {
  const FirestoreContactRequestStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
  static const String withdrawn = 'withdrawn';
  static const String expired = 'expired';
  static const String blocked = 'blocked';
}

class FirestoreChatStatus {
  const FirestoreChatStatus._();

  static const String active = 'active';
  static const String archived = 'archived';
  static const String blocked = 'blocked';
  static const String deleted = 'deleted';
}

class FirestoreMessageTypes {
  const FirestoreMessageTypes._();

  static const String text = 'text';
  static const String image = 'image';
  static const String system = 'system';
}

class FirestoreReportStatus {
  const FirestoreReportStatus._();

  static const String prepared = 'prepared';
  static const String submitted = 'submitted';
  static const String delivered = 'delivered';
  static const String dismissed = 'dismissed';
  static const String confirmed = 'confirmed';
  static const String underReview = 'underReview';
}

class FirestoreVerificationStatus {
  const FirestoreVerificationStatus._();

  static const String draft = 'draft';
  static const String submitted = 'submitted';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String needsMoreInfo = 'needsMoreInfo';
}

class FirestoreLegalConsentTypes {
  const FirestoreLegalConsentTypes._();

  static const String terms = 'terms';
  static const String privacy = 'privacy';
  static const String responsibleUse = 'responsibleUse';
  static const String noEmergencyUse = 'noEmergencyUse';
}

class FirestoreModerationTypes {
  const FirestoreModerationTypes._();

  static const String warning = 'warning';
  static const String restriction = 'restriction';
  static const String suspension = 'suspension';
  static const String accountDeletion = 'accountDeletion';
  static const String reportDismissed = 'reportDismissed';
  static const String reportConfirmed = 'reportConfirmed';
  static const String manualReview = 'manualReview';
}

class FirestoreDocumentDefaults {
  const FirestoreDocumentDefaults._();

  static const int freeSearchLimit = 5;
  static const int defaultRequestExpiryHours = 72;
  static const int maxReportMessageLength = 160;
  static const int maxChatMessageLength = 1000;
}