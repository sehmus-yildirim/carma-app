import 'package:plaqa/features/chats/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat message flow', () {
    test(
      'creates one normalized message and updates the chat summary',
      () async {
        final repository = LocalChatRepository();
        final chat = await repository.createChat(
          participants: const ['receiver', 'sender'],
          requestId: 'request-id',
        );

        final message = await repository.sendTextMessage(
          chatId: ' ${chat.id} ',
          senderUserId: ' sender ',
          text: ' Hallo plaqa ',
        );
        final messages = await repository.loadMessages(chatId: chat.id);
        final updatedChat = await repository.loadChat(chatId: chat.id);

        expect(messages, hasLength(1));
        expect(messages.single.id, message.id);
        expect(message.chatId, chat.id);
        expect(message.senderUserId, 'sender');
        expect(message.text, 'Hallo plaqa');
        expect(updatedChat?.lastMessage, 'Hallo plaqa');
        expect(updatedChat?.lastMessageAt, message.createdAt);
        expect(updatedChat?.lastReadAtBy['sender'], message.createdAt);
      },
    );

    test('rejects outsiders and users who deleted the chat', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'request-id',
      );

      await expectLater(
        repository.sendTextMessage(
          chatId: chat.id,
          senderUserId: 'outsider',
          text: 'Nicht erlaubt',
        ),
        throwsStateError,
      );

      await repository.deleteChat(chatId: chat.id, userId: 'sender');

      await expectLater(
        repository.sendTextMessage(
          chatId: chat.id,
          senderUserId: 'sender',
          text: 'Nicht erlaubt',
        ),
        throwsStateError,
      );
      expect(await repository.loadMessages(chatId: chat.id), isEmpty);
    });

    test('hides a received message only for the acting user', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'request-id',
      );
      final message = await repository.sendTextMessage(
        chatId: chat.id,
        senderUserId: 'sender',
        text: 'Nur lokal löschen',
      );

      await repository.deleteMessageForUser(
        chatId: chat.id,
        messageId: message.id,
        userId: 'receiver',
      );

      final storedMessage = (await repository.loadMessages(
        chatId: chat.id,
      )).single;
      expect(storedMessage.isDeleted, isFalse);
      expect(storedMessage.isDeletedFor('receiver'), isTrue);
      expect(storedMessage.isDeletedFor('sender'), isFalse);
    });

    test(
      'allows only the sender to delete a recent message for everyone',
      () async {
        final repository = LocalChatRepository();
        final chat = await repository.createChat(
          participants: const ['receiver', 'sender'],
          requestId: 'request-id',
        );
        final message = await repository.sendTextMessage(
          chatId: chat.id,
          senderUserId: 'sender',
          text: 'Für alle löschen',
        );

        await expectLater(
          repository.deleteMessageForEveryone(
            chatId: chat.id,
            messageId: message.id,
            userId: 'receiver',
          ),
          throwsStateError,
        );

        await repository.deleteMessageForEveryone(
          chatId: chat.id,
          messageId: message.id,
          userId: 'sender',
        );

        expect(await repository.loadMessages(chatId: chat.id), isEmpty);
      },
    );

    test('limits delete for everyone to 48 hours', () {
      final now = DateTime(2026, 7, 22, 12);
      final recent = ChatMessageRecord(
        id: 'recent',
        chatId: 'chat',
        senderUserId: 'sender',
        type: ChatMessageType.text,
        text: 'Neu',
        createdAt: now.subtract(const Duration(hours: 47)),
        updatedAt: now,
      );
      final expired = ChatMessageRecord(
        id: 'expired',
        chatId: 'chat',
        senderUserId: 'sender',
        type: ChatMessageType.text,
        text: 'Alt',
        createdAt: now.subtract(const Duration(hours: 49)),
        updatedAt: now,
      );

      expect(canDeleteChatMessageForEveryone(recent, now: now), isTrue);
      expect(canDeleteChatMessageForEveryone(expired, now: now), isFalse);
    });
  });
}
