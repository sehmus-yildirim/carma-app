import 'package:plaqa/features/chats/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat actions', () {
    test('archive and delete affect only the acting participant', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'chat-action-request',
      );

      final archived = await repository.archiveChat(
        chatId: chat.id,
        userId: 'sender',
      );

      expect(archived.status, ChatStatus.active);
      expect(archived.isArchivedFor('sender'), isTrue);
      expect(archived.isArchivedFor('receiver'), isFalse);
      expect(await repository.loadChats(userId: 'sender'), isEmpty);
      expect(await repository.loadChats(userId: 'receiver'), hasLength(1));
      expect(
        await repository.watchArchivedChats(userId: 'sender').first,
        hasLength(1),
      );

      final restored = await repository.unarchiveChat(
        chatId: chat.id,
        userId: 'sender',
      );

      expect(restored.isArchivedFor('sender'), isFalse);
      expect(await repository.loadChats(userId: 'sender'), hasLength(1));

      final deleted = await repository.deleteChat(
        chatId: chat.id,
        userId: 'sender',
      );
      final repeatedDelete = await repository.deleteChat(
        chatId: chat.id,
        userId: 'sender',
      );

      expect(deleted.status, ChatStatus.active);
      expect(repeatedDelete.isDeletedFor('sender'), isTrue);
      expect(deleted.isDeletedFor('receiver'), isFalse);
      expect(await repository.loadChats(userId: 'sender'), isEmpty);
      expect(await repository.loadChats(userId: 'receiver'), hasLength(1));
    });

    test('rejects chat actions from users outside the chat', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'participant-check-request',
      );

      await expectLater(
        repository.archiveChat(chatId: chat.id, userId: 'outsider'),
        throwsStateError,
      );
      await expectLater(
        repository.deleteChat(chatId: chat.id, userId: 'outsider'),
        throwsStateError,
      );
      await expectLater(
        repository.setChatPinned(
          chatId: chat.id,
          userId: 'outsider',
          isPinned: true,
        ),
        throwsStateError,
      );

      final now = DateTime(2026, 7, 20, 12);
      final malformedRepository = LocalChatRepository(
        seedChats: [
          ChatRecord(
            id: 'malformed-chat',
            participants: const ['receiver', 'sender', 'third-user'],
            status: ChatStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await expectLater(
        malformedRepository.archiveChat(
          chatId: 'malformed-chat',
          userId: 'sender',
        ),
        throwsStateError,
      );
    });

    test('only the blocker can unblock a blocked chat', () async {
      final now = DateTime(2026, 7, 20, 12);
      final blockedChat = ChatRecord(
        id: 'blocked-chat',
        participants: const ['receiver', 'sender'],
        status: ChatStatus.blocked,
        createdAt: now,
        updatedAt: now,
        blockedBy: 'sender',
        blockedAt: now,
      );
      final repository = LocalChatRepository(seedChats: [blockedChat]);

      expect(await repository.watchBlockedChats(userId: 'sender').first, [
        blockedChat,
      ]);
      expect(
        await repository.watchBlockedChats(userId: 'receiver').first,
        isEmpty,
      );

      await expectLater(
        repository.unblockChat(chatId: blockedChat.id, userId: 'receiver'),
        throwsStateError,
      );

      final unblocked = await repository.unblockChat(
        chatId: blockedChat.id,
        userId: 'sender',
      );

      expect(unblocked.status, ChatStatus.active);
      expect(unblocked.blockedBy, isEmpty);
      expect(
        await repository.watchBlockedChats(userId: 'sender').first,
        isEmpty,
      );
      expect(await repository.loadChats(userId: 'sender'), hasLength(1));
      expect(await repository.loadChats(userId: 'receiver'), hasLength(1));
    });
  });
}
