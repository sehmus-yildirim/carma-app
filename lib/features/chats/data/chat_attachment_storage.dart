import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ChatImageUploadResult {
  const ChatImageUploadResult({required this.path, required this.url});

  final String path;
  final String url;
}

class ChatAttachmentStorage {
  ChatAttachmentStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<ChatImageUploadResult> uploadChatImage({
    required String chatId,
    required String userId,
    required String messageId,
    required File file,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();
    final trimmedMessageId = messageId.trim();

    if (trimmedChatId.isEmpty ||
        trimmedUserId.isEmpty ||
        trimmedMessageId.isEmpty) {
      throw ArgumentError('Chat, user and message IDs must not be empty.');
    }

    final path =
        'chat_images/$trimmedChatId/$trimmedUserId/$trimmedMessageId.jpg';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    await reference.putFile(file, metadata);

    return ChatImageUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
    );
  }
}
