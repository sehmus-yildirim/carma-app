import 'carma_firestore_mapper.dart';
import 'carma_firestore_paths.dart';
import 'carma_firestore_schema.dart';

class CarmaFirestoreDocuments {
  const CarmaFirestoreDocuments._();

  static Map<String, dynamic> contactRequest({
    required String requestId,
    required String senderUserId,
    required String receiverUserId,
    required String countryCode,
    required String plateKey,
    required String message,
    required DateTime createdAt,
    DateTime? expiresAt,
    String status = FirestoreContactRequestStatus.pending,
    String? chatId,
  }) {
    return CarmaFirestoreMapper.cleanMap({
      'requestId': requestId,
      CarmaFirestoreFields.senderUserId: senderUserId,
      CarmaFirestoreFields.receiverUserId: receiverUserId,
      CarmaFirestoreFields.countryCode: countryCode.toUpperCase(),
      CarmaFirestoreFields.plateKey: plateKey,
      'message': message,
      CarmaFirestoreFields.status: status,
      'chatId': chatId,
      CarmaFirestoreFields.createdAt: createdAt,
      CarmaFirestoreFields.updatedAt: createdAt,
      CarmaFirestoreFields.expiresAt: expiresAt,
      CarmaFirestoreFields.isDeleted: false,
    });
  }

  static Map<String, dynamic> chat({
    required String chatId,
    required List<String> participants,
    required DateTime createdAt,
    String status = FirestoreChatStatus.active,
    String? requestId,
    String? lastMessage,
    DateTime? lastMessageAt,
  }) {
    final uniqueParticipants = participants.toSet().toList()..sort();

    return CarmaFirestoreMapper.cleanMap({
      'chatId': chatId,
      CarmaFirestoreFields.participants: uniqueParticipants,
      CarmaFirestoreFields.status: status,
      'requestId': requestId,
      CarmaFirestoreFields.lastMessage: lastMessage,
      CarmaFirestoreFields.lastMessageAt: lastMessageAt,
      CarmaFirestoreFields.createdAt: createdAt,
      CarmaFirestoreFields.updatedAt: createdAt,
      CarmaFirestoreFields.isDeleted: false,
    });
  }

  static Map<String, dynamic> message({
    required String messageId,
    required String chatId,
    required String senderUserId,
    required String text,
    required DateTime createdAt,
    String type = FirestoreMessageTypes.text,
    bool isSystem = false,
    bool isDeleted = false,
  }) {
    return CarmaFirestoreMapper.cleanMap({
      'messageId': messageId,
      'chatId': chatId,
      CarmaFirestoreFields.senderUserId: senderUserId,
      CarmaFirestoreFields.type: isSystem ? FirestoreMessageTypes.system : type,
      'text': text,
      CarmaFirestoreFields.createdAt: createdAt,
      CarmaFirestoreFields.updatedAt: createdAt,
      CarmaFirestoreFields.isDeleted: isDeleted,
    });
  }

  static Map<String, dynamic> report({
    required String reportId,
    required String senderUserId,
    required String countryCode,
    required String plateKey,
    required String category,
    required String message,
    required DateTime createdAt,
    double? latitude,
    double? longitude,
    String? manualAddress,
    String? imagePath,
    String status = FirestoreReportStatus.prepared,
  }) {
    return CarmaFirestoreMapper.cleanMap({
      'reportId': reportId,
      CarmaFirestoreFields.senderUserId: senderUserId,
      CarmaFirestoreFields.countryCode: countryCode.toUpperCase(),
      CarmaFirestoreFields.plateKey: plateKey,
      'category': category,
      'message': message,
      CarmaFirestoreFields.latitude: latitude,
      CarmaFirestoreFields.longitude: longitude,
      'manualAddress': manualAddress,
      'imagePath': imagePath,
      CarmaFirestoreFields.status: status,
      CarmaFirestoreFields.createdAt: createdAt,
      CarmaFirestoreFields.updatedAt: createdAt,
      CarmaFirestoreFields.isDeleted: false,
    });
  }

  static Map<String, dynamic> plate({
    required String ownerUserId,
    required String countryCode,
    required String plateKey,
    required String normalizedPlate,
    required DateTime createdAt,
    bool isActive = true,
  }) {
    return CarmaFirestoreMapper.cleanMap({
      CarmaFirestoreFields.ownerUserId: ownerUserId,
      CarmaFirestoreFields.countryCode: countryCode.toUpperCase(),
      CarmaFirestoreFields.plateKey: plateKey,
      CarmaFirestoreFields.normalizedPlate: normalizedPlate,
      CarmaFirestoreFields.createdAt: createdAt,
      CarmaFirestoreFields.updatedAt: createdAt,
      CarmaFirestoreFields.isActive: isActive,
      CarmaFirestoreFields.isDeleted: false,
    });
  }

  static Map<String, dynamic> verificationRequest({
    required String requestId,
    required String userId,
    required DateTime createdAt,
    String status = FirestoreVerificationStatus.draft,
    Map<String, dynamic> profileSnapshot = const {},
    List<String> documentPaths = const [],
  }) {
    return CarmaFirestoreMapper.cleanMap({
      'requestId': requestId,
      CarmaFirestoreFields.userId: userId,
      CarmaFirestoreFields.status: status,
      'profileSnapshot': profileSnapshot,
      'documentPaths': documentPaths,
      CarmaFirestoreFields.createdAt: createdAt,
      CarmaFirestoreFields.updatedAt: createdAt,
      CarmaFirestoreFields.isDeleted: false,
    });
  }
}