import 'package:carisma/features/chats/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat attachment flow', () {
    test('stores image, document and voice metadata exactly once', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'attachment-request',
      );

      final image = await repository.sendImageMessage(
        chatId: chat.id,
        messageId: 'image-message',
        senderUserId: 'sender',
        imageUrl: 'https://example.invalid/image.jpg',
        imagePath: 'chat_images/${chat.id}/sender/image-message.jpg',
      );
      final document = await repository.sendDocumentMessage(
        chatId: chat.id,
        messageId: 'document-message',
        senderUserId: 'sender',
        fileUrl: 'https://example.invalid/document.pdf',
        filePath:
            'chat_documents/${chat.id}/sender/'
            'document-message_document.pdf',
        fileName: 'document.pdf',
        fileSizeBytes: 1024,
        fileContentType: 'application/pdf',
      );
      final audio = await repository.sendAudioMessage(
        chatId: chat.id,
        messageId: 'audio-message',
        senderUserId: 'sender',
        fileUrl: 'https://example.invalid/audio.m4a',
        filePath:
            'chat_voice_memos/${chat.id}/sender/'
            'audio-message_Sprachmemo.m4a',
        fileName: 'Sprachmemo.m4a',
        fileSizeBytes: 2048,
        fileDurationMs: 3500,
        fileContentType: 'audio/mp4',
      );

      final messages = await repository.loadMessages(chatId: chat.id);
      final updatedChat = await repository.loadChat(chatId: chat.id);

      expect(messages, hasLength(3));
      expect(image.id, 'image-message');
      expect(image.type, ChatMessageType.image);
      expect(document.id, 'document-message');
      expect(document.type, ChatMessageType.document);
      expect(document.fileName, 'document.pdf');
      expect(document.fileSizeBytes, 1024);
      expect(audio.id, 'audio-message');
      expect(audio.type, ChatMessageType.audio);
      expect(audio.fileDurationMs, 3500);
      expect(updatedChat?.lastMessage, 'Sprachnachricht');
      expect(updatedChat?.lastReadAtBy['sender'], audio.createdAt);
    });

    test('rejects duplicate IDs, outsiders and deleted chats', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'attachment-request',
      );

      Future<ChatMessageRecord> sendImage({
        String senderUserId = 'sender',
        String messageId = 'image-message',
      }) {
        return repository.sendImageMessage(
          chatId: chat.id,
          messageId: messageId,
          senderUserId: senderUserId,
          imageUrl: 'https://example.invalid/image.jpg',
          imagePath: 'chat_images/${chat.id}/$senderUserId/$messageId.jpg',
        );
      }

      await sendImage();
      await expectLater(sendImage(), throwsStateError);
      await expectLater(
        sendImage(senderUserId: 'outsider', messageId: 'outsider-image'),
        throwsStateError,
      );

      await repository.deleteChat(chatId: chat.id, userId: 'sender');
      await expectLater(
        sendImage(messageId: 'deleted-chat-image'),
        throwsStateError,
      );
      expect(await repository.loadMessages(chatId: chat.id), hasLength(1));
    });

    test('keeps location and contact payloads structured', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'attachment-request',
      );

      final location = await repository.sendTextMessage(
        chatId: chat.id,
        senderUserId: 'sender',
        text: 'Standort\n53.551086,9.993682',
        messageType: ChatMessageType.location,
      );
      final contact = await repository.sendTextMessage(
        chatId: chat.id,
        senderUserId: 'sender',
        text: 'Kontakt\nName: Max Mustermann\nTelefon: +49 123 456789',
        messageType: ChatMessageType.contact,
      );

      expect(location.type, ChatMessageType.location);
      expect(location.text, 'Standort\n53.551086,9.993682');
      expect(contact.type, ChatMessageType.contact);
      expect(contact.text, contains('Telefon: +49 123 456789'));
    });
  });
}
