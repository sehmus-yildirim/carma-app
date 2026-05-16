import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ChatImageUploadResult {
  const ChatImageUploadResult({required this.path, required this.url});

  final String path;
  final String url;
}

class ChatDocumentUploadResult {
  const ChatDocumentUploadResult({
    required this.path,
    required this.url,
    required this.fileName,
    required this.fileSizeBytes,
    required this.contentType,
  });

  final String path;
  final String url;
  final String fileName;
  final int fileSizeBytes;
  final String contentType;
}

class ChatVoiceMemoUploadResult {
  const ChatVoiceMemoUploadResult({
    required this.path,
    required this.url,
    required this.fileName,
    required this.fileSizeBytes,
    required this.contentType,
  });

  final String path;
  final String url;
  final String fileName;
  final int fileSizeBytes;
  final String contentType;
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

  Future<ChatDocumentUploadResult> uploadChatDocument({
    required String chatId,
    required String userId,
    required String messageId,
    required File file,
    required String fileName,
    String? contentType,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();
    final trimmedMessageId = messageId.trim();
    final trimmedFileName = fileName.trim();
    final effectiveContentType = contentType?.trim().isNotEmpty == true
        ? contentType!.trim()
        : 'application/octet-stream';

    if (trimmedChatId.isEmpty ||
        trimmedUserId.isEmpty ||
        trimmedMessageId.isEmpty ||
        trimmedFileName.isEmpty) {
      throw ArgumentError('Chat, user, message and file names are required.');
    }

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw ArgumentError('Document file must not be empty.');
    }

    final safeFileName = trimmedFileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    final path =
        'chat_documents/$trimmedChatId/$trimmedUserId/${trimmedMessageId}_$safeFileName';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: effectiveContentType);

    await reference.putFile(file, metadata);

    return ChatDocumentUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
      fileName: trimmedFileName,
      fileSizeBytes: fileSizeBytes,
      contentType: effectiveContentType,
    );
  }

  Future<ChatVoiceMemoUploadResult> uploadChatVoiceMemo({
    required String chatId,
    required String userId,
    required String messageId,
    required File file,
    required String fileName,
    String? contentType,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();
    final trimmedMessageId = messageId.trim();
    final trimmedFileName = fileName.trim().isEmpty
        ? 'Sprachmemo.m4a'
        : fileName.trim();
    final effectiveContentType = contentType?.trim().isNotEmpty == true
        ? contentType!.trim()
        : 'audio/mp4';

    if (trimmedChatId.isEmpty ||
        trimmedUserId.isEmpty ||
        trimmedMessageId.isEmpty) {
      throw ArgumentError('Chat, user and message IDs are required.');
    }

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw ArgumentError('Voice memo file must not be empty.');
    }

    final safeFileName = trimmedFileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    final path =
        'chat_voice_memos/$trimmedChatId/$trimmedUserId/${trimmedMessageId}_$safeFileName';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: effectiveContentType);

    await reference.putFile(file, metadata);

    return ChatVoiceMemoUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
      fileName: trimmedFileName,
      fileSizeBytes: fileSizeBytes,
      contentType: effectiveContentType,
    );
  }
}
