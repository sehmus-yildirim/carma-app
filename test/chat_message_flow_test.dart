import 'package:carisma/features/chats/data/chat_repository.dart';
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
          text: ' Hallo CaRisma ',
        );
        final messages = await repository.loadMessages(chatId: chat.id);
        final updatedChat = await repository.loadChat(chatId: chat.id);

        expect(messages, hasLength(1));
        expect(messages.single.id, message.id);
        expect(message.chatId, chat.id);
        expect(message.senderUserId, 'sender');
        expect(message.text, 'Hallo CaRisma');
        expect(updatedChat?.lastMessage, 'Hallo CaRisma');
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
  });
}
