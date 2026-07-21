import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../chats/data/chat_repository.dart';
import '../../chats/data/contact_request_repository.dart';

class ProfileConnectionRepository {
  ProfileConnectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String connectionIdFor(String firstUserId, String secondUserId) {
    final userIds = <String>[firstUserId.trim(), secondUserId.trim()]..sort();
    if (userIds.any((userId) => userId.isEmpty) || userIds[0] == userIds[1]) {
      throw ArgumentError('Two different user IDs are required.');
    }
    return '${userIds[0]}_${userIds[1]}';
  }

  Future<void> ensureForAcceptedChat({required String chatId}) async {
    final normalizedChatId = chatId.trim();
    if (normalizedChatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'A chat ID is required.');
    }

    final chatRepository = FirestoreChatRepository(firestore: _firestore);
    final chat = await chatRepository.loadChat(chatId: normalizedChatId);
    if (chat == null || chat.requestId?.trim().isEmpty != false) {
      throw StateError('The chat is not linked to a contact request.');
    }

    final requestDocument = await _firestore
        .doc(CaRismaFirestorePaths.contactRequest(chat.requestId!.trim()))
        .get();
    if (!requestDocument.exists) {
      throw StateError('The linked contact request does not exist.');
    }

    await ensureAcceptedConnection(
      request: ContactRequestRecord.fromFirestore(requestDocument),
      chat: chat,
    );
  }

  Future<void> ensureAcceptedConnection({
    required ContactRequestRecord request,
    required ChatRecord chat,
  }) async {
    if (!request.isAccepted) {
      throw StateError('The contact request must be accepted first.');
    }

    final participants = <String>[
      request.senderUserId.trim(),
      request.receiverUserId.trim(),
    ]..sort();
    final chatParticipants = chat.participants.map((id) => id.trim()).toList()
      ..sort();

    if (participants.length != 2 ||
        participants.any((userId) => userId.isEmpty) ||
        participants[0] == participants[1] ||
        chatParticipants.length != 2 ||
        chatParticipants[0] != participants[0] ||
        chatParticipants[1] != participants[1] ||
        chat.requestId?.trim() != request.id.trim()) {
      throw StateError('Contact request and chat participants do not match.');
    }

    final connectionId = connectionIdFor(participants[0], participants[1]);
    final document = _firestore.doc(
      CaRismaFirestorePaths.profileConnection(connectionId),
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      transaction.set(document, <String, Object?>{
        'connectionId': connectionId,
        'userAId': participants[0],
        'userBId': participants[1],
        'participants': participants,
        'requestId': request.id.trim(),
        'chatId': chat.id.trim(),
        'status': 'active',
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
