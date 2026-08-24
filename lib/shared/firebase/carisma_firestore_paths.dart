class CaRismaFirestoreCollections {
  const CaRismaFirestoreCollections._();

  static const String users = 'users';
  static const String publicProfiles = 'public_profiles';
  static const String profiles = 'profiles';
  static const String vehicles = 'vehicles';
  static const String modifications = 'modifications';
  static const String gallery = 'gallery';
  static const String timeline = 'timeline';
  static const String encounters = 'encounters';
  static const String vehicleEncounters = 'vehicle_encounters';
  static const String plates = 'plates';
  static const String contactRequests = 'contact_requests';
  static const String profileConnections = 'profile_connections';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String reports = 'reports';
  static const String reportNotifications = 'report_notifications';
  static const String sentReportNotifications = 'sent_report_notifications';
  static const String legalConsents = 'legal_consents';
  static const String moderationActions = 'moderation_actions';
  static const String searchCredits = 'search_credits';
  static const String verificationRequests = 'verification_requests';
  static const String verificationNotifications = 'verification_notifications';
  static const String settings = 'settings';
  static const String pushTokens = 'push_tokens';
}

class CaRismaFirestoreFields {
  const CaRismaFirestoreFields._();

  static const String userId = 'userId';
  static const String ownerUserId = 'ownerUserId';
  static const String senderUserId = 'senderUserId';
  static const String receiverUserId = 'receiverUserId';
  static const String targetUserId = 'targetUserId';

  static const String countryCode = 'countryCode';
  static const String plateKey = 'plateKey';
  static const String normalizedPlate = 'normalizedPlate';

  static const String status = 'status';
  static const String state = 'state';
  static const String type = 'type';
  static const String reason = 'reason';

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String acceptedAt = 'acceptedAt';
  static const String declinedAt = 'declinedAt';
  static const String expiresAt = 'expiresAt';

  static const String participants = 'participants';
  static const String lastMessage = 'lastMessage';
  static const String lastMessageAt = 'lastMessageAt';

  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String geohash = 'geohash';

  static const String isActive = 'isActive';
  static const String isDeleted = 'isDeleted';
}

class CaRismaFirestorePaths {
  const CaRismaFirestorePaths._();

  static String user(String userId) {
    return '${CaRismaFirestoreCollections.users}/$userId';
  }

  static String userProfile(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.profiles}/main';
  }

  static String publicProfile(String userId) {
    return '${CaRismaFirestoreCollections.publicProfiles}/$userId';
  }

  static String userVehicles(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.vehicles}';
  }

  static String userVehicle(String userId, String vehicleId) {
    return '${userVehicles(userId)}/$vehicleId';
  }

  static String publicProfileVehicles(String userId) {
    return '${publicProfile(userId)}/${CaRismaFirestoreCollections.vehicles}';
  }

  static String publicProfileVehicle(String userId, String vehicleId) {
    return '${publicProfileVehicles(userId)}/$vehicleId';
  }

  static String userVehicleModifications(String userId, String vehicleId) {
    return '${userVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.modifications}';
  }

  static String userVehicleModification(
    String userId,
    String vehicleId,
    String modificationId,
  ) {
    return '${userVehicleModifications(userId, vehicleId)}/$modificationId';
  }

  static String publicVehicleModifications(String userId, String vehicleId) {
    return '${publicProfileVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.modifications}';
  }

  static String publicVehicleModification(
    String userId,
    String vehicleId,
    String modificationId,
  ) {
    return '${publicVehicleModifications(userId, vehicleId)}/$modificationId';
  }

  static String userVehicleGallery(String userId, String vehicleId) {
    return '${userVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.gallery}';
  }

  static String userVehicleGalleryMedia(
    String userId,
    String vehicleId,
    String mediaId,
  ) {
    return '${userVehicleGallery(userId, vehicleId)}/$mediaId';
  }

  static String publicVehicleGallery(String userId, String vehicleId) {
    return '${publicProfileVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.gallery}';
  }

  static String publicVehicleGalleryMedia(
    String userId,
    String vehicleId,
    String mediaId,
  ) {
    return '${publicVehicleGallery(userId, vehicleId)}/$mediaId';
  }

  static String userVehicleTimeline(String userId, String vehicleId) {
    return '${userVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.timeline}';
  }

  static String userVehicleTimelineEntry(
    String userId,
    String vehicleId,
    String entryId,
  ) {
    return '${userVehicleTimeline(userId, vehicleId)}/$entryId';
  }

  static String publicVehicleTimeline(String userId, String vehicleId) {
    return '${publicProfileVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.timeline}';
  }

  static String publicVehicleTimelineEntry(
    String userId,
    String vehicleId,
    String entryId,
  ) {
    return '${publicVehicleTimeline(userId, vehicleId)}/$entryId';
  }

  static String vehicleEncounter(String encounterId) {
    return '${CaRismaFirestoreCollections.vehicleEncounters}/$encounterId';
  }

  static String publicVehicleEncounters(String userId, String vehicleId) {
    return '${publicProfileVehicle(userId, vehicleId)}/${CaRismaFirestoreCollections.encounters}';
  }

  static String publicVehicleEncounter(
    String userId,
    String vehicleId,
    String encounterId,
  ) {
    return '${publicVehicleEncounters(userId, vehicleId)}/$encounterId';
  }

  static String userSearchCredit(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.searchCredits}/main';
  }

  static String userNotificationSettings(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.settings}/notifications';
  }

  static String userPushToken(String userId, String tokenHash) {
    return '${user(userId)}/${CaRismaFirestoreCollections.pushTokens}/$tokenHash';
  }

  static String userLegalConsents(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.legalConsents}';
  }

  static String userModerationActions(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.moderationActions}';
  }

  static String userReportNotifications(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.reportNotifications}';
  }

  static String userReportNotification(String userId, String reportId) {
    return '${userReportNotifications(userId)}/$reportId';
  }

  static String userSentReportNotifications(String userId) {
    return '${user(userId)}/${CaRismaFirestoreCollections.sentReportNotifications}';
  }

  static String userSentReportNotification(String userId, String reportId) {
    return '${userSentReportNotifications(userId)}/$reportId';
  }

  static String plate(String countryCode, String plateKey) {
    return '${CaRismaFirestoreCollections.plates}/${countryCode.toUpperCase()}_$plateKey';
  }

  static String contactRequest(String requestId) {
    return '${CaRismaFirestoreCollections.contactRequests}/$requestId';
  }

  static String profileConnection(String connectionId) {
    return '${CaRismaFirestoreCollections.profileConnections}/$connectionId';
  }

  static String chat(String chatId) {
    return '${CaRismaFirestoreCollections.chats}/$chatId';
  }

  static String chatMessages(String chatId) {
    return '${chat(chatId)}/${CaRismaFirestoreCollections.messages}';
  }

  static String chatMessage(String chatId, String messageId) {
    return '${chatMessages(chatId)}/$messageId';
  }

  static String report(String reportId) {
    return '${CaRismaFirestoreCollections.reports}/$reportId';
  }

  static String verificationRequest(String requestId) {
    return '${CaRismaFirestoreCollections.verificationRequests}/$requestId';
  }

  static String userVerificationNotifications(String userId) {
    return '${user(userId)}/'
        '${CaRismaFirestoreCollections.verificationNotifications}';
  }
}
