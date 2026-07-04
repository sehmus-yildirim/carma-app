import 'carisma_firestore_mapper.dart';
import 'carisma_firestore_paths.dart';
import 'carisma_firestore_schema.dart';

class CaRismaFirestoreDocuments {
  const CaRismaFirestoreDocuments._();

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
    return CaRismaFirestoreMapper.cleanMap({
      'requestId': requestId,
      CaRismaFirestoreFields.senderUserId: senderUserId,
      CaRismaFirestoreFields.receiverUserId: receiverUserId,
      CaRismaFirestoreFields.countryCode: countryCode.toUpperCase(),
      CaRismaFirestoreFields.plateKey: plateKey,
      'message': message,
      CaRismaFirestoreFields.status: status,
      'chatId': chatId,
      CaRismaFirestoreFields.createdAt: createdAt,
      CaRismaFirestoreFields.updatedAt: createdAt,
      CaRismaFirestoreFields.expiresAt: expiresAt,
      CaRismaFirestoreFields.isDeleted: false,
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

    return CaRismaFirestoreMapper.cleanMap({
      'chatId': chatId,
      CaRismaFirestoreFields.participants: uniqueParticipants,
      CaRismaFirestoreFields.status: status,
      'requestId': requestId,
      CaRismaFirestoreFields.lastMessage: lastMessage,
      CaRismaFirestoreFields.lastMessageAt: lastMessageAt,
      CaRismaFirestoreFields.createdAt: createdAt,
      CaRismaFirestoreFields.updatedAt: createdAt,
      CaRismaFirestoreFields.isDeleted: false,
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
    return CaRismaFirestoreMapper.cleanMap({
      'messageId': messageId,
      'chatId': chatId,
      CaRismaFirestoreFields.senderUserId: senderUserId,
      CaRismaFirestoreFields.type: isSystem
          ? FirestoreMessageTypes.system
          : type,
      'text': text,
      CaRismaFirestoreFields.createdAt: createdAt,
      CaRismaFirestoreFields.updatedAt: createdAt,
      CaRismaFirestoreFields.isDeleted: isDeleted,
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
    return CaRismaFirestoreMapper.cleanMap({
      'reportId': reportId,
      CaRismaFirestoreFields.senderUserId: senderUserId,
      CaRismaFirestoreFields.countryCode: countryCode.toUpperCase(),
      CaRismaFirestoreFields.plateKey: plateKey,
      'category': category,
      'message': message,
      CaRismaFirestoreFields.latitude: latitude,
      CaRismaFirestoreFields.longitude: longitude,
      'manualAddress': manualAddress,
      'imagePath': imagePath,
      CaRismaFirestoreFields.status: status,
      CaRismaFirestoreFields.createdAt: createdAt,
      CaRismaFirestoreFields.updatedAt: createdAt,
      CaRismaFirestoreFields.isDeleted: false,
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
    return CaRismaFirestoreMapper.cleanMap({
      CaRismaFirestoreFields.ownerUserId: ownerUserId,
      CaRismaFirestoreFields.countryCode: countryCode.toUpperCase(),
      CaRismaFirestoreFields.plateKey: plateKey,
      CaRismaFirestoreFields.normalizedPlate: normalizedPlate,
      CaRismaFirestoreFields.createdAt: createdAt,
      CaRismaFirestoreFields.updatedAt: createdAt,
      CaRismaFirestoreFields.isActive: isActive,
      CaRismaFirestoreFields.isDeleted: false,
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
    return CaRismaFirestoreMapper.cleanMap({
      'requestId': requestId,
      CaRismaFirestoreFields.userId: userId,
      CaRismaFirestoreFields.status: status,
      'profileSnapshot': profileSnapshot,
      'documentPaths': documentPaths,
      CaRismaFirestoreFields.createdAt: createdAt,
      CaRismaFirestoreFields.updatedAt: createdAt,
      CaRismaFirestoreFields.isDeleted: false,
    });
  }
}
