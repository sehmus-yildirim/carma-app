class CarmaFirestoreCollections {
  const CarmaFirestoreCollections._();

  static const String users = 'users';
  static const String profiles = 'profiles';
  static const String plates = 'plates';
  static const String contactRequests = 'contact_requests';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String reports = 'reports';
  static const String legalConsents = 'legal_consents';
  static const String moderationActions = 'moderation_actions';
  static const String searchCredits = 'search_credits';
  static const String verificationRequests = 'verification_requests';
}

class CarmaFirestoreFields {
  const CarmaFirestoreFields._();

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

class CarmaFirestorePaths {
  const CarmaFirestorePaths._();

  static String user(String userId) {
    return '${CarmaFirestoreCollections.users}/$userId';
  }

  static String userProfile(String userId) {
    return '${user(userId)}/${CarmaFirestoreCollections.profiles}/main';
  }

  static String userSearchCredit(String userId) {
    return '${user(userId)}/${CarmaFirestoreCollections.searchCredits}/main';
  }

  static String userLegalConsents(String userId) {
    return '${user(userId)}/${CarmaFirestoreCollections.legalConsents}';
  }

  static String userModerationActions(String userId) {
    return '${user(userId)}/${CarmaFirestoreCollections.moderationActions}';
  }

  static String plate(String countryCode, String plateKey) {
    return '${CarmaFirestoreCollections.plates}/${countryCode.toUpperCase()}_$plateKey';
  }

  static String contactRequest(String requestId) {
    return '${CarmaFirestoreCollections.contactRequests}/$requestId';
  }

  static String chat(String chatId) {
    return '${CarmaFirestoreCollections.chats}/$chatId';
  }

  static String chatMessages(String chatId) {
    return '${chat(chatId)}/${CarmaFirestoreCollections.messages}';
  }

  static String chatMessage(String chatId, String messageId) {
    return '${chatMessages(chatId)}/$messageId';
  }

  static String report(String reportId) {
    return '${CarmaFirestoreCollections.reports}/$reportId';
  }

  static String verificationRequest(String requestId) {
    return '${CarmaFirestoreCollections.verificationRequests}/$requestId';
  }
}