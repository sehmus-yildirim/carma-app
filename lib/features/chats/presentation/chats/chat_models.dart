part of '../chats_screen.dart';

class _LocalChatMessage {
  const _LocalChatMessage({
    required this.text,
    required this.isMine,
    required this.timeLabel,
    this.createdAt,
    this.messageId,
    this.isReadByOther = false,
    this.replyToText,
    this.isStarred = false,
    this.type = ChatMessageType.text,
    this.imageUrl,
    this.imagePath,
    this.fileUrl,
    this.filePath,
    this.fileName,
    this.fileContentType,
    this.fileSizeBytes,
    this.reactionBy = const <String, String>{},
  });

  final String text;
  final bool isMine;
  final String timeLabel;
  final DateTime? createdAt;
  final String? messageId;
  final bool isReadByOther;
  final String? replyToText;
  final bool isStarred;
  final ChatMessageType type;
  final String? imageUrl;
  final String? imagePath;
  final String? fileUrl;
  final String? filePath;
  final String? fileName;
  final String? fileContentType;
  final int? fileSizeBytes;
  final Map<String, String> reactionBy;

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

  _LocationPayload? get locationPayload {
    return _LocationPayload.tryParse(text);
  }

  _ContactPayload? get contactPayload {
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
    bool? isStarred,
    ChatMessageType? type,
    String? imageUrl,
    String? imagePath,
    String? fileUrl,
    String? filePath,
    String? fileName,
    String? fileContentType,
    int? fileSizeBytes,
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
      isStarred: isStarred ?? this.isStarred,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      fileUrl: fileUrl ?? this.fileUrl,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileContentType: fileContentType ?? this.fileContentType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
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
        (lines.first != 'Kontakt' && lines.first != 'Carma Kontakt')) {
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
