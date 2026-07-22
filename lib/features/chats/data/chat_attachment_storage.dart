import 'dart:async';
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

class ChatVideoUploadResult {
  const ChatVideoUploadResult({
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
  static const int _maxChatVideoBytes = 80 * 1024 * 1024;
  static const int _maxStoryImageBytes = 10 * 1024 * 1024;
  static const int _maxStoryVideoBytes = 80 * 1024 * 1024;
  static const Set<String> _allowedChatDocumentContentTypes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/rtf',
    'application/octet-stream',
  };

  final FirebaseStorage _storage;

  Future<ChatImageUploadResult> uploadChatImage({
    required String chatId,
    required String userId,
    required String messageId,
    required File file,
  }) async {
    final trimmedChatId = _requireStoragePathSegment(chatId, 'Chat-ID');
    final trimmedUserId = _requireStoragePathSegment(userId, 'Nutzer-ID');
    final trimmedMessageId = _requireStoragePathSegment(
      messageId,
      'Nachrichten-ID',
    );

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

    final url = await _uploadChatFileAndResolveUrl(
      reference: reference,
      file: file,
      metadata: metadata,
    );

    return ChatImageUploadResult(path: path, url: url);
  }

  Future<ChatImageUploadResult> uploadChatStoryImage({
    required String userId,
    required String storyId,
    required File file,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedStoryId = storyId.trim();

    if (trimmedUserId.isEmpty || !_isSafeStoryId(trimmedStoryId)) {
      throw ArgumentError('Nutzer- oder Story-ID ist ungültig.');
    }

    await _ensureUploadFits(
      file: file,
      maxBytes: _maxStoryImageBytes,
      emptyMessage: 'Story-Foto ist leer.',
      tooLargeMessage: 'Story-Foto ist zu groß. Maximal 10 MB.',
    );

    final path = 'chat_stories/$trimmedUserId/$trimmedStoryId/media.jpg';
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
      throw ArgumentError('Nutzer- oder Story-ID ist ungültig.');
    }

    await _ensureUploadFits(
      file: file,
      maxBytes: _maxStoryVideoBytes,
      emptyMessage: 'Story-Video ist leer.',
      tooLargeMessage: 'Story-Video ist zu groß. Maximal 80 MB.',
    );

    final path = 'chat_stories/$trimmedUserId/$trimmedStoryId/media.mp4';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'video/mp4');

    await reference.putFile(file, metadata);

    return ChatImageUploadResult(path: path, url: path);
  }

  Future<String> getDownloadUrl({required String path}) async {
    final trimmedPath = path.trim();

    if (!RegExp(
      r'^chat_stories/[^/]+/(?:[0-9]{12,24}\.(?:jpg|mp4)|[0-9]{12,24}/media\.(?:jpg|mp4))$',
    ).hasMatch(trimmedPath)) {
      throw ArgumentError('Der Story-Medienpfad ist ungültig.');
    }

    return _storage.ref(trimmedPath).getDownloadURL();
  }

  Future<void> deleteUploadedStoryMedia({required String path}) async {
    final trimmedPath = path.trim();

    if (trimmedPath.isEmpty) {
      return;
    }

    if (!RegExp(
      r'^chat_stories/[^/]+/(?:[0-9]{12,24}\.(?:jpg|mp4)|[0-9]{12,24}/media\.(?:jpg|mp4))$',
    ).hasMatch(trimmedPath)) {
      throw ArgumentError('Der Story-Medienpfad ist ungültig.');
    }

    await _storage.ref(trimmedPath).delete();
  }

  Future<void> deleteUploadedChatAttachment({required String path}) async {
    final trimmedPath = path.trim();

    if (trimmedPath.isEmpty) {
      return;
    }

    if (!RegExp(
      r'^chat_(images|documents|voice_memos|videos)/[^/]+/[^/]+/[^/]+$',
    ).hasMatch(trimmedPath)) {
      throw ArgumentError('Der Chat-Anhangspfad ist ungültig.');
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
    final trimmedChatId = _requireStoragePathSegment(chatId, 'Chat-ID');
    final trimmedUserId = _requireStoragePathSegment(userId, 'Nutzer-ID');
    final trimmedMessageId = _requireStoragePathSegment(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedFileName = fileName.trim();
    final effectiveContentType = _normalizedContentType(
      contentType,
      fallback: 'application/octet-stream',
    );

    if (trimmedFileName.isEmpty) {
      throw ArgumentError('Der Dateiname darf nicht leer sein.');
    }

    if (trimmedFileName.length > 160) {
      throw ArgumentError('Der Dateiname ist zu lang.');
    }

    if (!_isAllowedChatDocumentContentType(effectiveContentType)) {
      throw const ChatAttachmentStorageException(
        'Dieser Dokumenttyp wird nicht unterstützt.',
      );
    }

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw const ChatAttachmentStorageException('Das Dokument ist leer.');
    }

    if (fileSizeBytes > _maxChatDocumentBytes) {
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

    final url = await _uploadChatFileAndResolveUrl(
      reference: reference,
      file: file,
      metadata: metadata,
    );

    return ChatDocumentUploadResult(
      path: path,
      url: url,
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
    final trimmedChatId = _requireStoragePathSegment(chatId, 'Chat-ID');
    final trimmedUserId = _requireStoragePathSegment(userId, 'Nutzer-ID');
    final trimmedMessageId = _requireStoragePathSegment(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedFileName = fileName.trim().isEmpty
        ? 'Sprachmemo.m4a'
        : fileName.trim();
    final effectiveContentType = 'audio/mp4';

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw const ChatAttachmentStorageException('Die Sprachmemo ist leer.');
    }

    if (fileSizeBytes > _maxChatVoiceMemoBytes) {
      throw const ChatAttachmentStorageException(
        'Sprachmemo ist zu groß. Maximal 15 MB.',
      );
    }

    final safeFileName = _safeVoiceMemoFileName(trimmedFileName);
    final path =
        'chat_voice_memos/$trimmedChatId/$trimmedUserId/${trimmedMessageId}_$safeFileName';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: effectiveContentType);

    final url = await _uploadChatFileAndResolveUrl(
      reference: reference,
      file: file,
      metadata: metadata,
    );

    return ChatVoiceMemoUploadResult(
      path: path,
      url: url,
      fileName: safeFileName,
      fileSizeBytes: fileSizeBytes,
      contentType: effectiveContentType,
    );
  }

  Future<ChatVideoUploadResult> uploadChatVideo({
    required String chatId,
    required String userId,
    required String messageId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final trimmedChatId = _requireStoragePathSegment(chatId, 'Chat-ID');
    final trimmedUserId = _requireStoragePathSegment(userId, 'Nutzer-ID');
    final trimmedMessageId = _requireStoragePathSegment(
      messageId,
      'Nachrichten-ID',
    );

    final fileSizeBytes = await file.length();

    if (fileSizeBytes <= 0) {
      throw const ChatAttachmentStorageException('Das Video ist leer.');
    }

    if (fileSizeBytes > _maxChatVideoBytes) {
      throw const ChatAttachmentStorageException(
        'Das Video ist zu groß. Maximal 80 MB.',
      );
    }

    final path =
        'chat_videos/$trimmedChatId/$trimmedUserId/$trimmedMessageId.mp4';
    final reference = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'video/mp4');
    final url = await _uploadChatFileAndResolveUrl(
      reference: reference,
      file: file,
      metadata: metadata,
      onProgress: onProgress,
    );

    return ChatVideoUploadResult(
      path: path,
      url: url,
      fileName: 'Video.mp4',
      fileSizeBytes: fileSizeBytes,
      contentType: 'video/mp4',
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

    if (fileSizeBytes > maxBytes) {
      throw ChatAttachmentStorageException(tooLargeMessage);
    }
  }

  Future<String> _uploadChatFileAndResolveUrl({
    required Reference reference,
    required File file,
    required SettableMetadata metadata,
    void Function(double progress)? onProgress,
  }) async {
    final uploadTask = reference.putFile(file, metadata);
    StreamSubscription<TaskSnapshot>? progressSubscription;

    if (onProgress != null) {
      progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
        final totalBytes = snapshot.totalBytes;

        if (totalBytes > 0) {
          onProgress(
            (snapshot.bytesTransferred / totalBytes).clamp(0.0, 1.0).toDouble(),
          );
        }
      });
    }

    try {
      await uploadTask;
    } catch (_) {
      try {
        await reference.delete();
      } catch (_) {
        // Eine nicht fertig geschriebene Datei existiert üblicherweise nicht.
      }
      rethrow;
    } finally {
      await progressSubscription?.cancel();
    }

    try {
      return await reference.getDownloadURL();
    } catch (error) {
      try {
        await reference.delete();
      } catch (cleanupError) {
        throw ChatAttachmentStorageException(
          'Der Upload konnte nicht abgeschlossen und die Datei nicht '
          'bereinigt werden: $cleanupError',
        );
      }

      rethrow;
    }
  }

  String _requireStoragePathSegment(String value, String label) {
    final trimmedValue = value.trim();

    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(trimmedValue)) {
      throw ArgumentError('$label ist ungültig.');
    }

    return trimmedValue;
  }

  bool _isAllowedChatDocumentContentType(String contentType) {
    return contentType.startsWith('text/') ||
        _allowedChatDocumentContentTypes.contains(contentType);
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
