import 'package:plaqa/features/chats/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat attachment flow', () {
    test('stores image, document, voice and video metadata once', () async {
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
      final video = await repository.sendVideoMessage(
        chatId: chat.id,
        messageId: 'video-message',
        senderUserId: 'sender',
        fileUrl: 'https://example.invalid/video.mp4',
        filePath: 'chat_videos/${chat.id}/sender/video-message.mp4',
        fileName: 'Video.mp4',
        fileSizeBytes: 4 * 1024 * 1024,
        fileDurationMs: 12500,
        fileContentType: 'video/mp4',
      );

      final messages = await repository.loadMessages(chatId: chat.id);
      final updatedChat = await repository.loadChat(chatId: chat.id);

      expect(messages, hasLength(4));
      expect(image.id, 'image-message');
      expect(image.type, ChatMessageType.image);
      expect(document.id, 'document-message');
      expect(document.type, ChatMessageType.document);
      expect(document.fileName, 'document.pdf');
      expect(document.fileSizeBytes, 1024);
      expect(audio.id, 'audio-message');
      expect(audio.type, ChatMessageType.audio);
      expect(audio.fileDurationMs, 3500);
      expect(video.id, 'video-message');
      expect(video.type, ChatMessageType.video);
      expect(video.filePath, 'chat_videos/${chat.id}/sender/video-message.mp4');
      expect(video.fileContentType, 'video/mp4');
      expect(video.fileSizeBytes, 4 * 1024 * 1024);
      expect(video.fileDurationMs, 12500);
      expect(updatedChat?.lastMessage, 'Video');
      expect(updatedChat?.lastReadAtBy['sender'], video.createdAt);
    });

    test('rejects invalid video metadata and duplicate video IDs', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'video-validation-request',
      );

      Future<ChatMessageRecord> sendVideo({
        String messageId = 'video-message',
        String filePath = '',
        String contentType = 'video/mp4',
        int fileSizeBytes = 1024,
        int durationMs = 5000,
      }) {
        final resolvedPath = filePath.isEmpty
            ? 'chat_videos/${chat.id}/sender/$messageId.mp4'
            : filePath;
        return repository.sendVideoMessage(
          chatId: chat.id,
          messageId: messageId,
          senderUserId: 'sender',
          fileUrl: 'https://example.invalid/$messageId.mp4',
          filePath: resolvedPath,
          fileName: 'Video.mp4',
          fileSizeBytes: fileSizeBytes,
          fileDurationMs: durationMs,
          fileContentType: contentType,
        );
      }

      await sendVideo();
      await expectLater(sendVideo(), throwsStateError);
      await expectLater(
        sendVideo(
          messageId: 'wrong-path',
          filePath: 'chat_videos/${chat.id}/outsider/wrong-path.mp4',
        ),
        throwsArgumentError,
      );
      await expectLater(
        sendVideo(messageId: 'wrong-type', contentType: 'video/quicktime'),
        throwsArgumentError,
      );
      await expectLater(
        sendVideo(messageId: 'too-large', fileSizeBytes: 80 * 1024 * 1024 + 1),
        throwsArgumentError,
      );
      await expectLater(
        sendVideo(messageId: 'too-long', durationMs: 5 * 60 * 1000 + 1),
        throwsArgumentError,
      );
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

    test('opens view-once media exactly once for the receiver', () async {
      final repository = LocalChatRepository();
      final chat = await repository.createChat(
        participants: const ['receiver', 'sender'],
        requestId: 'view-once-request',
      );

      final image = await repository.sendImageMessage(
        chatId: chat.id,
        messageId: 'view-once-image',
        senderUserId: 'sender',
        imageUrl: 'https://example.invalid/view-once.jpg',
        imagePath: 'chat_images/${chat.id}/sender/view-once-image.jpg',
        caption: 'Nur einmal ansehen',
        isViewOnce: true,
      );

      expect(image.isViewOnce, isTrue);
      expect(image.text, 'Nur einmal ansehen');
      expect(image.viewOnceOpenedAtBy, isEmpty);

      expect(
        await repository.markViewOnceMediaOpened(
          chatId: chat.id,
          messageId: image.id,
          userId: 'receiver',
        ),
        isTrue,
      );
      expect(
        await repository.markViewOnceMediaOpened(
          chatId: chat.id,
          messageId: image.id,
          userId: 'receiver',
        ),
        isFalse,
      );
      await expectLater(
        repository.markViewOnceMediaOpened(
          chatId: chat.id,
          messageId: image.id,
          userId: 'sender',
        ),
        throwsStateError,
      );

      final stored = (await repository.loadMessages(chatId: chat.id)).single;
      expect(stored.isViewOnceOpenedFor('receiver'), isTrue);
      expect(stored.isViewOnceOpenedFor('sender'), isFalse);
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
