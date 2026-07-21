import 'package:carisma/features/chats/data/chat_repository.dart';
import 'package:carisma/features/chats/data/contact_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contact request to chat flow', () {
    test('uses one deterministic chat and hides an accepted request', () async {
      final requestRepository = LocalContactRequestRepository();
      final chatRepository = LocalChatRepository();
      final request = await requestRepository.createRequest(
        senderUserId: 'sender',
        receiverUserId: 'receiver',
        countryCode: 'DE',
        plateKey: 'HHSY4700',
        message: 'Hallo',
      );

      final firstChat = await chatRepository.createChat(
        participants: [request.receiverUserId, request.senderUserId],
        requestId: request.id,
      );
      final reusedChat = await chatRepository.createChat(
        participants: [request.senderUserId, request.receiverUserId],
        requestId: request.id,
      );
      await requestRepository.acceptRequest(
        requestId: request.id,
        chatId: firstChat.id,
      );

      expect(firstChat.id, 'request_${request.id}');
      expect(reusedChat.id, firstChat.id);
      expect(firstChat.participants, ['receiver', 'sender']);
      expect(
        await requestRepository.loadIncomingRequests(userId: 'receiver'),
        isEmpty,
      );
      expect(
        await requestRepository.loadOutgoingRequests(userId: 'sender'),
        isEmpty,
      );
      expect(
        await chatRepository.loadChats(userId: 'sender'),
        contains(firstChat),
      );
    });

    test('rejects chats without exactly two distinct participants', () async {
      final chatRepository = LocalChatRepository();

      await expectLater(
        chatRepository.createChat(
          participants: ['sender', 'sender'],
          requestId: 'request-id',
        ),
        throwsArgumentError,
      );
      await expectLater(
        chatRepository.createChat(
          participants: ['sender', 'receiver', 'third'],
          requestId: 'request-id',
        ),
        throwsArgumentError,
      );
    });
  });
}
