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

class ChatAttachmentStorageException implements Exception {
  const ChatAttachmentStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatAttachmentStorage {
  ChatAttachmentStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static const int _maxStorageFileNameLength = 140;
  static const int _maxStorageDocumentFileNameLength = 180;
  static const int _maxChatImageBytes = 10 * 1024 * 1024;
  static const int _maxChatDocumentBytes = 25 * 1024 * 1024;
  static const int _maxChatVoiceMemoBytes = 15 * 1024 * 1024;
  static const int _maxStoryImageBytes = 10 * 1024 * 1024;
  static const int _maxStoryVideoBytes = 80 * 1024 * 1024;

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

    await _ensureUploadFits(
      file: file,
      maxBytes: _maxChatImageBytes,
      emptyMessage: 'Foto ist leer.',
      tooLargeMessage: 'Foto ist zu groß. Maximal 10 MB.',
    );

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

  Future<ChatImageUploadResult> uploadChatStoryImage({
    required String userId,
    required String storyId,
    required File file,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedStoryId = storyId.trim();

    if (trimmedUserId.isEmpty || !_isSafeStoryId(trimmedStoryId)) {
      throw ArgumentError('User and story IDs must not be empty.');
    }

    await _ensureUploadFits(
      file: file,
      maxBytes: _maxStoryImageBytes,
      emptyMessage: 'Story-Foto ist leer.',
      tooLargeMessage: 'Story-Foto ist zu groß. Maximal 10 MB.',
    );

    final path = 'chat_stories/$trimmedUserId/$trimmedStoryId.jpg';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    await reference.putFile(file, metadata);

    return ChatImageUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
    );
  }

  Future<ChatImageUploadResult> uploadChatStoryVideo({
    required String userId,
    required String storyId,
    required File file,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedStoryId = storyId.trim();

    if (trimmedUserId.isEmpty || !_isSafeStoryId(trimmedStoryId)) {
      throw ArgumentError('User and story IDs must not be empty.');
    }

    await _ensureUploadFits(
      file: file,
      maxBytes: _maxStoryVideoBytes,
      emptyMessage: 'Story-Video ist leer.',
      tooLargeMessage: 'Story-Video ist zu groß. Maximal 80 MB.',
    );

    final path = 'chat_stories/$trimmedUserId/$trimmedStoryId.mp4';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'video/mp4');

    await reference.putFile(file, metadata);

    return ChatImageUploadResult(path: path, url: path);
  }

  Future<String> getDownloadUrl({required String path}) async {
    final trimmedPath = path.trim();

    if (!RegExp(
      r'^chat_stories/[^/]+/[0-9]{12,24}\.(jpg|mp4)$',
    ).hasMatch(trimmedPath)) {
      throw ArgumentError('Story media path is invalid.');
    }

    return _storage.ref(trimmedPath).getDownloadURL();
  }

  Future<void> deleteUploadedStoryMedia({required String path}) async {
    final trimmedPath = path.trim();

    if (trimmedPath.isEmpty) {
      return;
    }

    if (!RegExp(
      r'^chat_stories/[^/]+/[0-9]{12,24}\.(jpg|mp4)$',
    ).hasMatch(trimmedPath)) {
      throw ArgumentError('Story media path is invalid.');
    }

    await _storage.ref(trimmedPath).delete();
  }

  Future<void> deleteUploadedChatAttachment({required String path}) async {
    final trimmedPath = path.trim();

    if (trimmedPath.isEmpty) {
      return;
    }

    if (!RegExp(
      r'^chat_(images|documents|voice_memos)/[^/]+/[^/]+/[^/]+$',
    ).hasMatch(trimmedPath)) {
      throw ArgumentError('Chat attachment path is invalid.');
    }

    await _storage.ref(trimmedPath).delete();
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
    final effectiveContentType = _normalizedContentType(
      contentType,
      fallback: 'application/octet-stream',
    );

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

    if (fileSizeBytes >= _maxChatDocumentBytes) {
      throw const ChatAttachmentStorageException(
        'Dokument ist zu groß. Maximal 25 MB.',
      );
    }

    final storageFileNamePrefix = '${trimmedMessageId}_';
    final maxSafeFileNameLength =
        (_maxStorageDocumentFileNameLength - storageFileNamePrefix.length)
            .clamp(1, _maxStorageFileNameLength)
            .toInt();
    final safeFileName = _safeStorageFileName(
      trimmedFileName,
      maxLength: maxSafeFileNameLength,
    );
    final storageFileName = '$storageFileNamePrefix$safeFileName';
    final path =
        'chat_documents/$trimmedChatId/$trimmedUserId/$storageFileName';
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
    final effectiveContentType = 'audio/mp4';

    if (trimmedChatId.isEmpty ||
        trimmedUserId.isEmpty ||
        trimmedMessageId.isEmpty) {
      throw ArgumentError('Chat, user and message IDs are required.');
    }

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw ArgumentError('Voice memo file must not be empty.');
    }

    if (fileSizeBytes >= _maxChatVoiceMemoBytes) {
      throw const ChatAttachmentStorageException(
        'Sprachmemo ist zu groß. Maximal 15 MB.',
      );
    }

    final safeFileName = _safeVoiceMemoFileName(trimmedFileName);
    final path =
        'chat_voice_memos/$trimmedChatId/$trimmedUserId/${trimmedMessageId}_$safeFileName';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: effectiveContentType);

    await reference.putFile(file, metadata);

    return ChatVoiceMemoUploadResult(
      path: path,
      url: await reference.getDownloadURL(),
      fileName: safeFileName,
      fileSizeBytes: fileSizeBytes,
      contentType: effectiveContentType,
    );
  }

  Future<void> _ensureUploadFits({
    required File file,
    required int maxBytes,
    required String emptyMessage,
    required String tooLargeMessage,
  }) async {
    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw ChatAttachmentStorageException(emptyMessage);
    }

    if (fileSizeBytes >= maxBytes) {
      throw ChatAttachmentStorageException(tooLargeMessage);
    }
  }

  String _safeStorageFileName(
    String fileName, {
    int maxLength = _maxStorageFileNameLength,
  }) {
    final safeFileName = fileName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );

    if (safeFileName.isEmpty) {
      return 'file';
    }

    if (safeFileName.length <= maxLength) {
      return safeFileName;
    }

    return safeFileName.substring(0, maxLength);
  }

  String _safeVoiceMemoFileName(String fileName) {
    final safeFileName = _safeStorageFileName(fileName);

    if (safeFileName.toLowerCase().endsWith('.m4a')) {
      return safeFileName;
    }

    final withoutExtension = safeFileName.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final baseName = withoutExtension.isEmpty ? 'Sprachmemo' : withoutExtension;
    final maxBaseLength = (_maxStorageFileNameLength - '.m4a'.length)
        .clamp(1, _maxStorageFileNameLength)
        .toInt();
    final clippedBaseName = baseName.length <= maxBaseLength
        ? baseName
        : baseName.substring(0, maxBaseLength);

    return '$clippedBaseName.m4a';
  }

  String _normalizedContentType(
    String? contentType, {
    required String fallback,
  }) {
    final trimmedContentType = contentType?.trim().toLowerCase();

    if (trimmedContentType == null || trimmedContentType.isEmpty) {
      return fallback;
    }

    return trimmedContentType;
  }

  bool _isSafeStoryId(String storyId) {
    return RegExp(r'^[0-9]{12,24}$').hasMatch(storyId);
  }
}
