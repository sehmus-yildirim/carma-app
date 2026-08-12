part of '../chats_screen.dart';

String _storyReplyErrorMessage(Object error) {
  final errorText = '$error';

  if (errorText.contains('expired_story')) {
    return 'Diese Story ist abgelaufen.';
  }

  if (errorText.contains('story_not_visible')) {
    return 'Diese Story ist nicht mehr sichtbar.';
  }

  if (errorText.contains('story_replies_disabled')) {
    return 'Antworten auf diese Story sind deaktiviert.';
  }

  if (errorText.contains('story_reply_too_long')) {
    return 'Antwort ist zu lang.';
  }

  if (errorText.contains('No visible chat')) {
    return 'Zu dieser Story gibt es keinen aktiven Chat mehr.';
  }

  return 'Antwort konnte nicht gesendet werden.';
}

class _LocalChatMessage {
  const _LocalChatMessage({
    required this.text,
    required this.isMine,
    required this.timeLabel,
    this.createdAt,
    this.messageId,
    this.isReadByOther = false,
    this.replyToText,
    this.replyToSenderName,
    this.isStarred = false,
    this.type = ChatMessageType.text,
    this.imageUrl,
    this.imagePath,
    this.fileUrl,
    this.filePath,
    this.fileName,
    this.fileContentType,
    this.fileSizeBytes,
    this.fileDurationMs,
    this.isViewOnce = false,
    this.viewOnceOpenedAtBy = const <String, DateTime>{},
    this.reactionBy = const <String, String>{},
  });

  final String text;
  final bool isMine;
  final String timeLabel;
  final DateTime? createdAt;
  final String? messageId;
  final bool isReadByOther;
  final String? replyToText;
  final String? replyToSenderName;
  final bool isStarred;
  final ChatMessageType type;
  final String? imageUrl;
  final String? imagePath;
  final String? fileUrl;
  final String? filePath;
  final String? fileName;
  final String? fileContentType;
  final int? fileSizeBytes;
  final int? fileDurationMs;
  final bool isViewOnce;
  final Map<String, DateTime> viewOnceOpenedAtBy;
  final Map<String, String> reactionBy;

  bool isViewOnceOpenedFor(String userId) {
    return viewOnceOpenedAtBy.containsKey(userId.trim());
  }

  bool get isImage {
    return type == ChatMessageType.image && imageUrl?.trim().isNotEmpty == true;
  }

  bool get isDocument {
    return type == ChatMessageType.document &&
        fileUrl?.trim().isNotEmpty == true &&
        fileName?.trim().isNotEmpty == true;
  }

  bool get isAudio {
    return type == ChatMessageType.audio && fileUrl?.trim().isNotEmpty == true;
  }

  bool get isVideo {
    return type == ChatMessageType.video && fileUrl?.trim().isNotEmpty == true;
  }

  _LocationPayload? get locationPayload {
    if (type != ChatMessageType.location && type != ChatMessageType.text) {
      return null;
    }

    return _LocationPayload.tryParse(text);
  }

  _ContactPayload? get contactPayload {
    if (type != ChatMessageType.contact && type != ChatMessageType.text) {
      return null;
    }

    return _ContactPayload.tryParse(text);
  }

  _LocalChatMessage copyWith({
    String? text,
    bool? isMine,
    String? timeLabel,
    DateTime? createdAt,
    String? messageId,
    bool? isReadByOther,
    String? replyToText,
    String? replyToSenderName,
    bool? isStarred,
    ChatMessageType? type,
    String? imageUrl,
    String? imagePath,
    String? fileUrl,
    String? filePath,
    String? fileName,
    String? fileContentType,
    int? fileSizeBytes,
    int? fileDurationMs,
    bool? isViewOnce,
    Map<String, DateTime>? viewOnceOpenedAtBy,
    Map<String, String>? reactionBy,
  }) {
    return _LocalChatMessage(
      text: text ?? this.text,
      isMine: isMine ?? this.isMine,
      timeLabel: timeLabel ?? this.timeLabel,
      createdAt: createdAt ?? this.createdAt,
      messageId: messageId ?? this.messageId,
      isReadByOther: isReadByOther ?? this.isReadByOther,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      isStarred: isStarred ?? this.isStarred,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      fileUrl: fileUrl ?? this.fileUrl,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileContentType: fileContentType ?? this.fileContentType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileDurationMs: fileDurationMs ?? this.fileDurationMs,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewOnceOpenedAtBy: viewOnceOpenedAtBy ?? this.viewOnceOpenedAtBy,
      reactionBy: reactionBy ?? this.reactionBy,
    );
  }
}

class _LocationPayload {
  const _LocationPayload({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  String get coordinateLabel {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  static _LocationPayload? tryParse(String value) {
    final trimmed = value.trim();
    final directMatch = RegExp(
      r'^Standort\s*\n\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final mapsMatch = RegExp(
      r'query=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
    ).firstMatch(trimmed);
    final match = directMatch ?? mapsMatch;

    if (match == null) {
      return null;
    }

    final latitude = double.tryParse(match.group(1) ?? '');
    final longitude = double.tryParse(match.group(2) ?? '');

    if (latitude == null || longitude == null) {
      return null;
    }

    return _LocationPayload(latitude: latitude, longitude: longitude);
  }
}

class _ContactPayload {
  const _ContactPayload({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;

  static _ContactPayload? tryParse(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty ||
        (lines.first != 'Kontakt' && lines.first != 'CaRisma Kontakt')) {
      return null;
    }

    String? name;
    String? phoneNumber;

    for (final line in lines.skip(1)) {
      if (line.startsWith('Name:')) {
        name = line.substring('Name:'.length).trim();
      }

      if (line.startsWith('Telefon:')) {
        phoneNumber = line.substring('Telefon:'.length).trim();
      }

      if (line.startsWith('Telefonnummer:')) {
        phoneNumber = line.substring('Telefonnummer:'.length).trim();
      }

      if (line.startsWith('Rufnummer:')) {
        phoneNumber = line.substring('Rufnummer:'.length).trim();
      }

      if (line.startsWith('Kontakt:')) {
        phoneNumber = line.substring('Kontakt:'.length).trim();
      }
    }

    if ((name == null || name.isEmpty) &&
        (phoneNumber == null || phoneNumber.isEmpty)) {
      return null;
    }

    return _ContactPayload(
      name: name == null || name.isEmpty ? 'Kontakt' : name,
      phoneNumber: phoneNumber ?? '',
    );
  }
}
