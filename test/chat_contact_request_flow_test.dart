import 'package:plaqa/features/chats/data/chat_repository.dart';
import 'package:plaqa/features/chats/data/contact_request_repository.dart';
import 'package:plaqa/features/chats/domain/accept_contact_request_use_case.dart';
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
        vehicleId: 'vehicle-1',
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

    test('receiver sees request chat only after acceptance', () async {
      final chat = ChatRecord(
        id: 'request_request-id',
        participants: const ['receiver', 'sender'],
        status: ChatStatus.active,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        requestId: 'request-id',
        senderUserId: 'sender',
        receiverUserId: 'receiver',
      );

      expect(
        isChatVisibleForRequestState(
          chat: chat,
          currentUserId: 'sender',
          acceptedIncomingRequestIds: const <String>{},
        ),
        isTrue,
      );
      expect(
        isChatVisibleForRequestState(
          chat: chat,
          currentUserId: 'receiver',
          acceptedIncomingRequestIds: const <String>{},
        ),
        isFalse,
      );
      expect(
        isChatVisibleForRequestState(
          chat: chat,
          currentUserId: 'receiver',
          acceptedIncomingRequestIds: const <String>{'request-id'},
        ),
        isTrue,
      );
    });

    test('rejects expired contact requests before creating a chat', () async {
      final expiredRequest = ContactRequestRecord(
        id: 'expired-request',
        senderUserId: 'sender',
        receiverUserId: 'receiver',
        countryCode: 'DE',
        vehicleId: 'vehicle-1',
        plateKey: 'HHSY4700',
        message: 'Hallo',
        status: ContactRequestStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 49)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final requestRepository = LocalContactRequestRepository(
        seedRequests: [expiredRequest],
      );
      final chatRepository = LocalChatRepository();
      final useCase = AcceptContactRequestUseCase(
        contactRequestRepository: requestRepository,
        chatRepository: chatRepository,
      );

      await expectLater(
        useCase(request: expiredRequest),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Diese Kontaktanfrage ist abgelaufen.',
          ),
        ),
      );
      expect(await chatRepository.loadChats(userId: 'sender'), isEmpty);
    });
  });
}
