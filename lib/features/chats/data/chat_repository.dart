import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/firebase/carisma_firestore_schema.dart';

enum ChatStatus { active, archived, blocked, deleted }

enum ChatMessageType {
  text,
  image,
  document,
  audio,
  video,
  location,
  contact,
  system,
}

const int _maxChatImageCaptionLength = 1000;
const int _maxChatDocumentBytes = 25 * 1024 * 1024;
const int _maxChatVoiceMemoBytes = 15 * 1024 * 1024;
const int _maxChatVoiceMemoDurationMs = 10 * 60 * 1000;
const int _maxChatVideoBytes = 80 * 1024 * 1024;
const int _maxChatVideoDurationMs = 5 * 60 * 1000;
const Set<String> _allowedChatDocumentContentTypes = {
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

String _requiredChatAttachmentId(String value, String label) {
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

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

const Set<String> _allowedMessageReactions = <String>{
  '\u2764\uFE0F',
  '\u{1F44D}',
  '\u{1F602}',
  '\u{1F62E}',
  '\u{1F622}',
  '\u{1F64F}',
};

String _normalizedMessageReaction(String reaction) {
  final trimmed = reaction.trim();

  if (trimmed.isEmpty) {
    return '';
  }

  if (!_allowedMessageReactions.contains(trimmed)) {
    throw ArgumentError.value(reaction, 'reaction', 'Unsupported reaction.');
  }

  return trimmed;
}

class ChatRecord {
  const ChatRecord({
    required this.id,
    required this.participants,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.requestId,
    this.lastMessage,
    this.lastMessageAt,
    this.senderUserId,
    this.receiverUserId,
    this.senderDisplayName,
    this.receiverDisplayName,
    this.senderPhotoUrl,
    this.receiverPhotoUrl,
    this.blockedBy,
    this.blockedAt,
    this.countryCode,
    this.vehicleId,
    this.displayPlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleLabel,
    this.favoriteBy = const <String, bool>{},
    this.pinnedBy = const <String, bool>{},
    this.mutedBy = const <String, bool>{},
    this.archivedBy = const <String, bool>{},
    this.deletedBy = const <String, bool>{},
    this.manualUnreadBy = const <String, bool>{},
    this.lastReadAtBy = const <String, DateTime>{},
  });

  final String id;
  final List<String> participants;
  final ChatStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? requestId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? senderUserId;
  final String? receiverUserId;
  final String? senderDisplayName;
  final String? receiverDisplayName;
  final String? senderPhotoUrl;
  final String? receiverPhotoUrl;
  final String? blockedBy;
  final DateTime? blockedAt;
  final String? countryCode;
  final String? vehicleId;
  final String? displayPlate;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleLabel;
  final Map<String, bool> favoriteBy;
  final Map<String, bool> pinnedBy;
  final Map<String, bool> mutedBy;
  final Map<String, bool> archivedBy;
  final Map<String, bool> deletedBy;
  final Map<String, bool> manualUnreadBy;
  final Map<String, DateTime> lastReadAtBy;

  bool isFavoriteFor(String userId) {
    return favoriteBy[userId] == true;
  }

  bool isPinnedFor(String userId) {
    return pinnedBy[userId] == true;
  }

  bool isMutedFor(String userId) {
    return mutedBy[userId] == true;
  }

  bool isArchivedFor(String userId) {
    return archivedBy[userId] == true;
  }

  bool isDeletedFor(String userId) {
    return deletedBy[userId] == true;
  }

  bool isBlockedBy(String userId) {
    return blockedBy == userId;
  }

  bool isManuallyUnreadFor(String userId) {
    return manualUnreadBy[userId] == true;
  }

  bool isVisibleInActiveListFor(String userId) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty ||
        isArchivedFor(trimmedUserId) ||
        isDeletedFor(trimmedUserId)) {
      return false;
    }

    return status == ChatStatus.active || status == ChatStatus.archived;
  }

  bool isVisibleInArchivedListFor(String userId) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty ||
        !isArchivedFor(trimmedUserId) ||
        isDeletedFor(trimmedUserId)) {
      return false;
    }

    return status == ChatStatus.active || status == ChatStatus.archived;
  }

  bool isVisibleInBlockedListFor(String userId) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty || isDeletedFor(trimmedUserId)) {
      return false;
    }

    return status == ChatStatus.blocked && isBlockedBy(trimmedUserId);
  }

  bool hasUnreadFor(String userId) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return false;
    }

    if (isManuallyUnreadFor(trimmedUserId)) {
      return true;
    }

    if (lastMessageAt == null) {
      return false;
    }

    final lastReadAt = lastReadAtBy[trimmedUserId];

    if (lastReadAt == null) {
      return true;
    }

    return lastMessageAt!.isAfter(lastReadAt);
  }

  bool get isActive {
    return status == ChatStatus.active;
  }

  String displayNameFor(String currentUserId) {
    final isSender = senderUserId == currentUserId;
    final candidate = isSender ? receiverDisplayName : senderDisplayName;
    final trimmed = candidate?.trim();

    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    return 'plaqa Nutzer';
  }

  String? profilePhotoUrlFor(String currentUserId) {
    final isSender = senderUserId == currentUserId;
    final candidate = isSender ? receiverPhotoUrl : senderPhotoUrl;
    final trimmed = candidate?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? otherParticipantIdFor(String currentUserId) {
    final trimmedCurrentUserId = currentUserId.trim();

    for (final participant in participants) {
      final trimmedParticipant = participant.trim();
      if (trimmedParticipant.isNotEmpty &&
          trimmedParticipant != trimmedCurrentUserId) {
        return trimmedParticipant;
      }
    }

    return null;
  }

  String get vehicleTitle {
    final label = vehicleLabel?.trim();

    if (label != null && label.isNotEmpty) {
      return label;
    }

    final parts = <String>[
      if (vehicleColor != null && vehicleColor!.trim().isNotEmpty)
        _vehicleColorAdjective(vehicleColor!),
      if (vehicleBrand != null && vehicleBrand!.trim().isNotEmpty)
        vehicleBrand!.trim(),
      if (vehicleModel != null && vehicleModel!.trim().isNotEmpty)
        vehicleModel!.trim(),
    ];

    final title = parts.join(' ').trim();
    return title.isEmpty ? 'Fahrzeug' : title;
  }

  String get vehicleModelLabel {
    final parts = <String>[
      if (vehicleBrand != null && vehicleBrand!.trim().isNotEmpty)
        vehicleBrand!.trim(),
      if (vehicleModel != null && vehicleModel!.trim().isNotEmpty)
        vehicleModel!.trim(),
    ];

    final label = parts.join(' ').trim();
    return label.isEmpty ? 'Fahrzeug' : label;
  }

  String get vehicleColorLabel {
    final color = vehicleColor?.trim();
    return color == null || color.isEmpty ? '-' : color;
  }

  static String _vehicleColorAdjective(String color) {
    return switch (color.trim().toLowerCase()) {
      'schwarz' => 'schwarzer',
      'weiß' || 'weiss' => 'weißer',
      'silber' => 'silberner',
      'grau' => 'grauer',
      'blau' => 'blauer',
      'rot' => 'roter',
      'grün' || 'gruen' => 'grüner',
      'braun' => 'brauner',
      'gelb' => 'gelber',
      'orange' => 'oranger',
      _ => color.trim(),
    };
  }

  ChatRecord copyWith({
    String? id,
    List<String>? participants,
    ChatStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? requestId,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? senderUserId,
    String? receiverUserId,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? senderPhotoUrl,
    String? receiverPhotoUrl,
    String? blockedBy,
    DateTime? blockedAt,
    String? countryCode,
    String? vehicleId,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
    Map<String, bool>? favoriteBy,
    Map<String, bool>? pinnedBy,
    Map<String, bool>? mutedBy,
    Map<String, bool>? archivedBy,
    Map<String, bool>? deletedBy,
    Map<String, bool>? manualUnreadBy,
    Map<String, DateTime>? lastReadAtBy,
  }) {
    return ChatRecord(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requestId: requestId ?? this.requestId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      receiverDisplayName: receiverDisplayName ?? this.receiverDisplayName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      blockedBy: blockedBy ?? this.blockedBy,
      blockedAt: blockedAt ?? this.blockedAt,
      countryCode: countryCode ?? this.countryCode,
      vehicleId: vehicleId ?? this.vehicleId,
      displayPlate: displayPlate ?? this.displayPlate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      favoriteBy: favoriteBy ?? this.favoriteBy,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      mutedBy: mutedBy ?? this.mutedBy,
      archivedBy: archivedBy ?? this.archivedBy,
      deletedBy: deletedBy ?? this.deletedBy,
      manualUnreadBy: manualUnreadBy ?? this.manualUnreadBy,
      lastReadAtBy: lastReadAtBy ?? this.lastReadAtBy,
    );
  }
}

bool isChatVisibleForRequestState({
  required ChatRecord chat,
  required String currentUserId,
  required Set<String> acceptedIncomingRequestIds,
}) {
  final trimmedUserId = currentUserId.trim();
  final requestId = chat.requestId?.trim() ?? '';
  final receiverUserId = chat.receiverUserId?.trim() ?? '';

  if (trimmedUserId.isEmpty ||
      requestId.isEmpty ||
      receiverUserId != trimmedUserId) {
    return true;
  }

  return acceptedIncomingRequestIds.contains(requestId);
}

const Duration chatMessageDeleteForEveryoneWindow = Duration(hours: 48);

bool canDeleteChatMessageForEveryone(
  ChatMessageRecord message, {
  DateTime? now,
}) {
  final age = (now ?? DateTime.now()).difference(message.createdAt);
  return !age.isNegative && age <= chatMessageDeleteForEveryoneWindow;
}

class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.chatId,
    required this.senderUserId,
    required this.type,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isStarred = false,
    this.replyToMessageId,
    this.replyToText,
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
    this.deletedFor = const <String, bool>{},
  });

  final String id;
  final String chatId;
  final String senderUserId;
  final ChatMessageType type;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isStarred;
  final String? replyToMessageId;
  final String? replyToText;
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
  final Map<String, bool> deletedFor;

  bool get isSystem {
    return type == ChatMessageType.system;
  }

  bool isDeletedFor(String userId) {
    return deletedFor[userId.trim()] == true;
  }

  bool isViewOnceOpenedFor(String userId) {
    return viewOnceOpenedAtBy.containsKey(userId.trim());
  }

  ChatMessageRecord copyWith({
    String? id,
    String? chatId,
    String? senderUserId,
    ChatMessageType? type,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isStarred,
    String? replyToMessageId,
    String? replyToText,
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
    Map<String, bool>? deletedFor,
  }) {
    return ChatMessageRecord(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderUserId: senderUserId ?? this.senderUserId,
      type: type ?? this.type,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isStarred: isStarred ?? this.isStarred,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
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
      deletedFor: deletedFor ?? this.deletedFor,
    );
  }
}

abstract class ChatRepository {
  Future<List<ChatRecord>> loadChats({required String userId});

  Future<ChatRecord?> loadChat({required String chatId});

  Stream<List<ChatRecord>> watchChats({required String userId});

  Stream<List<ChatRecord>> watchArchivedChats({required String userId});

  Stream<List<ChatRecord>> watchBlockedChats({required String userId});

  Future<ChatRecord> createChat({
    required List<String> participants,
    String? requestId,
    String? systemMessage,
    String? senderUserId,
    String? receiverUserId,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? senderPhotoUrl,
    String? receiverPhotoUrl,
    String? countryCode,
    String? vehicleId,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
  });

  Future<List<ChatMessageRecord>> loadMessages({required String chatId});

  Stream<List<ChatMessageRecord>> watchMessages({required String chatId});
  Future<ChatMessageRecord> sendTextMessage({
    required String chatId,
    required String senderUserId,
    required String text,
    ChatMessageType messageType = ChatMessageType.text,
    String? replyToMessageId,
    String? replyToText,
  });

  String createMessageId({required String chatId});

  Future<ChatMessageRecord> sendImageMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String imageUrl,
    required String imagePath,
    String? caption,
    bool isViewOnce = false,
  });

  Future<ChatMessageRecord> sendDocumentMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    String? fileContentType,
  });

  Future<ChatMessageRecord> sendAudioMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required int fileDurationMs,
    String? fileContentType,
  });

  Future<ChatMessageRecord> sendVideoMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required int fileDurationMs,
    String? fileContentType,
    String? caption,
    bool isViewOnce = false,
  });

  Future<ChatMessageRecord> addSystemMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
  });

  Future<ChatRecord> archiveChat({
    required String chatId,
    required String userId,
  });

  Future<ChatRecord> unarchiveChat({
    required String chatId,
    required String userId,
  });

  Future<ChatRecord> deleteChat({
    required String chatId,
    required String userId,
  });

  Future<ChatRecord> unblockChat({
    required String chatId,
    required String userId,
  });

  Future<void> deleteMessageForUser({
    required String chatId,
    required String messageId,
    required String userId,
  });

  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String userId,
  });

  Future<void> setMessageStarred({
    required String chatId,
    required String messageId,
    required bool isStarred,
  });

  Future<void> setChatPinned({
    required String chatId,
    required String userId,
    required bool isPinned,
  });

  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String reaction,
  });

  Future<bool> markViewOnceMediaOpened({
    required String chatId,
    required String messageId,
    required String userId,
  });
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chatsCollection {
    return _firestore.collection(CaRismaFirestoreCollections.chats);
  }

  Future<bool> _readReceiptsEnabledFor(String userId) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return true;
    }

    final snapshot = await _firestore
        .doc(
          '${CaRismaFirestorePaths.user(trimmedUserId)}/'
          '${CaRismaFirestoreCollections.settings}/chat_privacy',
        )
        .get();

    return snapshot.data()?['readReceiptsEnabled'] as bool? ?? true;
  }

  @override
  Future<List<ChatRecord>> loadChats({required String userId}) async {
    final snapshot = await _chatsCollection
        .where('participants', arrayContains: userId)
        .get();

    final chats =
        snapshot.docs
            .map(_chatFromSnapshot)
            .where((chat) => chat.isVisibleInActiveListFor(userId))
            .toList()
          ..sort((a, b) {
            final aPinned = a.isPinnedFor(userId);
            final bPinned = b.isPinnedFor(userId);

            if (aPinned != bPinned) {
              return aPinned ? -1 : 1;
            }

            final aFavorite = a.isFavoriteFor(userId);
            final bFavorite = b.isFavoriteFor(userId);

            if (aFavorite != bFavorite) {
              return aFavorite ? -1 : 1;
            }

            return b.updatedAt.compareTo(a.updatedAt);
          });

    return chats;
  }

  @override
  Future<ChatRecord?> loadChat({required String chatId}) async {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return null;
    }

    final snapshot = await _chatsCollection.doc(trimmedChatId).get();

    if (!snapshot.exists) {
      return null;
    }

    return _chatFromSnapshot(snapshot);
  }

  Stream<ChatRecord?> watchChat({required String chatId}) {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return Stream<ChatRecord?>.value(null);
    }

    return _chatsCollection.doc(trimmedChatId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return _chatFromSnapshot(snapshot);
    });
  }

  @override
  Stream<List<ChatRecord>> watchChats({required String userId}) {
    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final chats =
              snapshot.docs
                  .map(_chatFromSnapshot)
                  .where((chat) => chat.isVisibleInActiveListFor(userId))
                  .toList()
                ..sort((a, b) {
                  final aPinned = a.isPinnedFor(userId);
                  final bPinned = b.isPinnedFor(userId);

                  if (aPinned != bPinned) {
                    return aPinned ? -1 : 1;
                  }

                  final aFavorite = a.isFavoriteFor(userId);
                  final bFavorite = b.isFavoriteFor(userId);

                  if (aFavorite != bFavorite) {
                    return aFavorite ? -1 : 1;
                  }

                  return b.updatedAt.compareTo(a.updatedAt);
                });

          return chats;
        });
  }

  @override
  Stream<List<ChatRecord>> watchArchivedChats({required String userId}) {
    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final chats =
              snapshot.docs
                  .map(_chatFromSnapshot)
                  .where((chat) => chat.isVisibleInArchivedListFor(userId))
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          return chats;
        });
  }

  @override
  Stream<List<ChatRecord>> watchBlockedChats({required String userId}) {
    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final chats =
              snapshot.docs
                  .map(_chatFromSnapshot)
                  .where((chat) => chat.isVisibleInBlockedListFor(userId))
                  .toList()
                ..sort((a, b) {
                  final aBlockedAt = a.blockedAt ?? a.updatedAt;
                  final bBlockedAt = b.blockedAt ?? b.updatedAt;
                  return bBlockedAt.compareTo(aBlockedAt);
                });

          return chats;
        });
  }

  @override
  Future<ChatRecord> createChat({
    required List<String> participants,
    String? requestId,
    String? systemMessage,
    String? senderUserId,
    String? receiverUserId,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? senderPhotoUrl,
    String? receiverPhotoUrl,
    String? countryCode,
    String? vehicleId,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
  }) async {
    final uniqueParticipants =
        participants
            .map((participant) => participant.trim())
            .where((participant) => participant.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (uniqueParticipants.length != 2) {
      throw ArgumentError('A chat requires exactly two participants.');
    }

    final chatDocument = requestId == null || requestId.trim().isEmpty
        ? _chatsCollection.doc()
        : _chatsCollection.doc('request_${requestId.trim()}');

    final now = DateTime.now();
    final trimmedSystemMessage = systemMessage?.trim();

    final data = <String, dynamic>{
      'participants': uniqueParticipants,
      'status': FirestoreChatStatus.active,
      'requestId': requestId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'lastMessage':
          trimmedSystemMessage == null || trimmedSystemMessage.isEmpty
          ? null
          : trimmedSystemMessage,
      'lastMessageAt':
          trimmedSystemMessage == null || trimmedSystemMessage.isEmpty
          ? null
          : Timestamp.fromDate(now),
      'isDeleted': false,
      'senderUserId': _trimmedOrNull(senderUserId),
      'receiverUserId': _trimmedOrNull(receiverUserId),
      'senderDisplayName': _trimmedOrNull(senderDisplayName),
      'receiverDisplayName': _trimmedOrNull(receiverDisplayName),
      'senderPhotoUrl': _trimmedOrNull(senderPhotoUrl),
      'receiverPhotoUrl': _trimmedOrNull(receiverPhotoUrl),
      'countryCode': _trimmedOrNull(countryCode)?.toUpperCase(),
      'vehicleId': _trimmedOrNull(vehicleId),
      'displayPlate': _trimmedOrNull(displayPlate),
      'vehicleBrand': _trimmedOrNull(vehicleBrand),
      'vehicleModel': _trimmedOrNull(vehicleModel),
      'vehicleColor': _trimmedOrNull(vehicleColor),
      'vehicleLabel': _trimmedOrNull(vehicleLabel),
    };

    await chatDocument.set(data);

    final snapshot = await chatDocument.get();
    return _chatFromSnapshot(snapshot);
  }

  @override
  Future<List<ChatMessageRecord>> loadMessages({required String chatId}) async {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return const <ChatMessageRecord>[];
    }

    final snapshot = await _messagesCollection(
      trimmedChatId,
    ).where('isDeleted', isEqualTo: false).get();

    final messages = snapshot.docs.map(_messageFromSnapshot).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  @override
  Stream<List<ChatMessageRecord>> watchMessages({required String chatId}) {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return Stream<List<ChatMessageRecord>>.value(const <ChatMessageRecord>[]);
    }

    return _messagesCollection(
      trimmedChatId,
    ).where('isDeleted', isEqualTo: false).snapshots().map((snapshot) {
      final messages = snapshot.docs.map(_messageFromSnapshot).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return messages;
    });
  }

  Future<void> markChatRead({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    if (!await _readReceiptsEnabledFor(trimmedUserId)) {
      return;
    }

    await _chatsCollection.doc(trimmedChatId).set({
      'lastReadAtBy': {trimmedUserId: FieldValue.serverTimestamp()},
      'manualUnreadBy': {trimmedUserId: false},
      'manualUnreadUpdatedAtBy': {trimmedUserId: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<void> markChatUnread({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    await _chatsCollection.doc(trimmedChatId).set({
      'manualUnreadBy': {trimmedUserId: true},
      'manualUnreadUpdatedAtBy': {trimmedUserId: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<DateTime?> loadOtherLastReadAt({
    required String chatId,
    required String currentUserId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedChatId.isEmpty || trimmedCurrentUserId.isEmpty) {
      return null;
    }

    final snapshot = await _chatsCollection.doc(trimmedChatId).get();
    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    final lastReadAtBy = data['lastReadAtBy'];

    if (lastReadAtBy is! Map) {
      return null;
    }

    DateTime? latestOtherReadAt;

    for (final entry in lastReadAtBy.entries) {
      final userId = entry.key?.toString() ?? '';

      if (userId.isEmpty || userId == trimmedCurrentUserId) {
        continue;
      }

      final readAt = _dateTimeFromValue(entry.value);

      if (readAt == null) {
        continue;
      }

      if (latestOtherReadAt == null || readAt.isAfter(latestOtherReadAt)) {
        latestOtherReadAt = readAt;
      }
    }

    return latestOtherReadAt;
  }

  Stream<DateTime?> watchOtherLastReadAt({
    required String chatId,
    required String currentUserId,
  }) {
    final trimmedChatId = chatId.trim();
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedChatId.isEmpty || trimmedCurrentUserId.isEmpty) {
      return Stream<DateTime?>.value(null);
    }

    return _chatsCollection.doc(trimmedChatId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      final lastReadAtBy = data['lastReadAtBy'];

      if (lastReadAtBy is! Map) {
        return null;
      }

      DateTime? latestOtherReadAt;

      for (final entry in lastReadAtBy.entries) {
        final userId = entry.key?.toString() ?? '';

        if (userId.isEmpty || userId == trimmedCurrentUserId) {
          continue;
        }

        final readAt = _dateTimeFromValue(entry.value);

        if (readAt == null) {
          continue;
        }

        if (latestOtherReadAt == null || readAt.isAfter(latestOtherReadAt)) {
          latestOtherReadAt = readAt;
        }
      }

      return latestOtherReadAt;
    });
  }

  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    await _chatsCollection.doc(trimmedChatId).set({
      'typingBy': {trimmedUserId: isTyping},
      'typingUpdatedAtBy': {trimmedUserId: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Stream<bool> watchOtherTypingStatus({
    required String chatId,
    required String currentUserId,
  }) {
    final trimmedChatId = chatId.trim();
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedChatId.isEmpty || trimmedCurrentUserId.isEmpty) {
      return Stream<bool>.value(false);
    }

    return _chatsCollection.doc(trimmedChatId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return false;
      }

      final typingBy = data['typingBy'];
      final typingUpdatedAtBy = data['typingUpdatedAtBy'];

      if (typingBy is! Map || typingUpdatedAtBy is! Map) {
        return false;
      }

      final now = DateTime.now();

      for (final entry in typingBy.entries) {
        final userId = entry.key?.toString() ?? '';

        if (userId.isEmpty || userId == trimmedCurrentUserId) {
          continue;
        }

        if (entry.value != true) {
          continue;
        }

        final updatedAt = _dateTimeFromValue(typingUpdatedAtBy[userId]);

        if (updatedAt == null) {
          continue;
        }

        return now.difference(updatedAt).inSeconds <= 6;
      }

      return false;
    });
  }

  Future<void> updateChatPresence({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    final settingsSnapshot = await _firestore
        .doc(
          '${CaRismaFirestorePaths.user(trimmedUserId)}/'
          '${CaRismaFirestoreCollections.settings}/chat_privacy',
        )
        .get();

    if (settingsSnapshot.data()?['onlineStatusEnabled'] != true) {
      return;
    }

    await _chatsCollection.doc(trimmedChatId).set({
      'onlineAtBy': {trimmedUserId: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Stream<DateTime?> watchOtherLastActiveAt({
    required String chatId,
    required String currentUserId,
  }) {
    final trimmedChatId = chatId.trim();
    final trimmedCurrentUserId = currentUserId.trim();

    if (trimmedChatId.isEmpty || trimmedCurrentUserId.isEmpty) {
      return Stream<DateTime?>.value(null);
    }

    return _chatsCollection.doc(trimmedChatId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      final onlineAtBy = data['onlineAtBy'];

      if (onlineAtBy is! Map) {
        return null;
      }

      DateTime? latestOtherActiveAt;

      for (final entry in onlineAtBy.entries) {
        final userId = entry.key?.toString() ?? '';

        if (userId.isEmpty || userId == trimmedCurrentUserId) {
          continue;
        }

        final activeAt = _dateTimeFromValue(entry.value);

        if (activeAt == null) {
          continue;
        }

        if (latestOtherActiveAt == null ||
            activeAt.isAfter(latestOtherActiveAt)) {
          latestOtherActiveAt = activeAt;
        }
      }

      return latestOtherActiveAt;
    });
  }

  @override
  String createMessageId({required String chatId}) {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      throw ArgumentError('Chat ID must not be empty.');
    }

    return _messagesCollection(trimmedChatId).doc().id;
  }

  @override
  Future<ChatMessageRecord> sendTextMessage({
    required String chatId,
    required String senderUserId,
    required String text,
    ChatMessageType messageType = ChatMessageType.text,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedSenderUserId = senderUserId.trim();
    final trimmedText = text.trim();

    if (trimmedChatId.isEmpty || trimmedSenderUserId.isEmpty) {
      throw ArgumentError('Chat ID and sender user ID must not be empty.');
    }

    if (trimmedText.isEmpty) {
      throw ArgumentError('Message text must not be empty.');
    }

    if (trimmedText.length > FirestoreDocumentDefaults.maxChatMessageLength) {
      throw ArgumentError('Message text is too long.');
    }

    final effectiveMessageType = switch (messageType) {
      ChatMessageType.location => ChatMessageType.location,
      ChatMessageType.contact => ChatMessageType.contact,
      _ => ChatMessageType.text,
    };
    final firestoreMessageType = switch (effectiveMessageType) {
      ChatMessageType.location => FirestoreMessageTypes.location,
      ChatMessageType.contact => FirestoreMessageTypes.contact,
      _ => FirestoreMessageTypes.text,
    };
    final lastMessageText = switch (effectiveMessageType) {
      ChatMessageType.location => 'Standort',
      ChatMessageType.contact => 'Kontakt',
      _ => trimmedText,
    };
    final readReceiptsEnabled = await _readReceiptsEnabledFor(
      trimmedSenderUserId,
    );

    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);
    final messageDocument = _messagesCollection(trimmedChatId).doc();

    await _firestore.runTransaction((transaction) async {
      final chatDocument = _chatsCollection.doc(trimmedChatId);
      final chatSnapshot = await transaction.get(chatDocument);
      final chatData = chatSnapshot.data();

      if (!chatSnapshot.exists || chatData == null) {
        throw StateError('Chat not found: $trimmedChatId');
      }

      final participantIds = _stringListFromValue(
        chatData['participants'],
      ).where((participantId) => participantId.trim().isNotEmpty).toSet();
      final status = chatData['status'];
      final deletedBy = _boolMapFromValue(chatData['deletedBy']);

      if (participantIds.length != 2 ||
          !participantIds.contains(trimmedSenderUserId)) {
        throw StateError('Sender is not a participant of this chat.');
      }

      if (status != FirestoreChatStatus.active &&
          status != FirestoreChatStatus.archived) {
        throw StateError('This chat is not open for new messages.');
      }

      if (deletedBy[trimmedSenderUserId] == true) {
        throw StateError('This chat was deleted for the sender.');
      }

      transaction.set(messageDocument, {
        'chatId': trimmedChatId,
        'senderUserId': trimmedSenderUserId,
        'type': firestoreMessageType,
        'text': trimmedText,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'isDeleted': false,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
      });

      transaction.set(chatDocument, {
        'lastMessage': lastMessageText,
        'lastMessageAt': timestamp,
        if (readReceiptsEnabled)
          'lastReadAtBy': {trimmedSenderUserId: timestamp},
        'manualUnreadBy': {trimmedSenderUserId: false},
        'manualUnreadUpdatedAtBy': {trimmedSenderUserId: timestamp},
        if (participantIds.isNotEmpty)
          'archivedBy': {
            for (final participantId in participantIds) participantId: false,
          },
        if (participantIds.isNotEmpty)
          'archivedUpdatedAtBy': {
            for (final participantId in participantIds)
              participantId: timestamp,
          },
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    });

    return ChatMessageRecord(
      id: messageDocument.id,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: effectiveMessageType,
      text: trimmedText,
      createdAt: now,
      updatedAt: now,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
    );
  }

  @override
  Future<ChatMessageRecord> sendImageMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String imageUrl,
    required String imagePath,
    String? caption,
    bool isViewOnce = false,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedImageUrl = imageUrl.trim();
    final trimmedImagePath = imagePath.trim();
    final trimmedCaption = caption?.trim() ?? '';

    if (trimmedImageUrl.isEmpty || trimmedImagePath.isEmpty) {
      throw ArgumentError('Foto-URL und Dateipfad dürfen nicht leer sein.');
    }

    if (trimmedCaption.length > _maxChatImageCaptionLength) {
      throw ArgumentError('Die Bildunterschrift ist zu lang.');
    }

    final expectedImagePath =
        'chat_images/$trimmedChatId/$trimmedSenderUserId/'
        '$trimmedMessageId.jpg';

    if (trimmedImagePath != expectedImagePath) {
      throw ArgumentError('Der Foto-Dateipfad passt nicht zur Nachricht.');
    }

    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);
    final messageDocument = _messagesCollection(
      trimmedChatId,
    ).doc(trimmedMessageId);
    final messageText = trimmedCaption.isEmpty ? 'Foto' : trimmedCaption;
    final readReceiptsEnabled = await _readReceiptsEnabledFor(
      trimmedSenderUserId,
    );

    await _firestore.runTransaction((transaction) async {
      final chatDocument = _chatsCollection.doc(trimmedChatId);
      final chatSnapshot = await transaction.get(chatDocument);
      final messageSnapshot = await transaction.get(messageDocument);
      final participantIds = _requireSendableAttachmentChat(
        chatSnapshot: chatSnapshot,
        senderUserId: trimmedSenderUserId,
      );

      if (messageSnapshot.exists) {
        throw StateError('Diese Nachricht wurde bereits gesendet.');
      }

      transaction.set(messageDocument, {
        'chatId': trimmedChatId,
        'senderUserId': trimmedSenderUserId,
        'type': FirestoreMessageTypes.image,
        'text': messageText,
        'imageUrl': trimmedImageUrl,
        'imagePath': trimmedImagePath,
        'isViewOnce': isViewOnce,
        'viewOnceOpenedAtBy': <String, Timestamp>{},
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'isDeleted': false,
      });

      transaction.set(chatDocument, {
        'lastMessage': messageText,
        'lastMessageAt': timestamp,
        if (readReceiptsEnabled)
          'lastReadAtBy': {trimmedSenderUserId: timestamp},
        'manualUnreadBy': {trimmedSenderUserId: false},
        'manualUnreadUpdatedAtBy': {trimmedSenderUserId: timestamp},
        if (participantIds.isNotEmpty)
          'archivedBy': {
            for (final participantId in participantIds) participantId: false,
          },
        if (participantIds.isNotEmpty)
          'archivedUpdatedAtBy': {
            for (final participantId in participantIds)
              participantId: timestamp,
          },
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    });

    return ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.image,
      text: messageText,
      imageUrl: trimmedImageUrl,
      imagePath: trimmedImagePath,
      isViewOnce: isViewOnce,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ChatMessageRecord> sendDocumentMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    String? fileContentType,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedFileUrl = fileUrl.trim();
    final trimmedFilePath = filePath.trim();
    final trimmedFileName = fileName.trim();
    final trimmedContentType = fileContentType?.trim().toLowerCase() ?? '';

    if (trimmedFileUrl.isEmpty ||
        trimmedFilePath.isEmpty ||
        trimmedFileName.isEmpty) {
      throw ArgumentError(
        'Dokument-URL, Dateipfad und Dateiname dürfen nicht leer sein.',
      );
    }

    if (trimmedFileName.length > 160) {
      throw ArgumentError('Der Dateiname ist zu lang.');
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxChatDocumentBytes) {
      throw ArgumentError('Die Dokumentgröße ist ungültig.');
    }

    if (trimmedContentType.isEmpty ||
        !_isAllowedChatDocumentContentType(trimmedContentType)) {
      throw ArgumentError('Dieser Dokumenttyp wird nicht unterstützt.');
    }

    final expectedPathPrefix =
        'chat_documents/$trimmedChatId/$trimmedSenderUserId/'
        '${trimmedMessageId}_';

    if (!trimmedFilePath.startsWith(expectedPathPrefix) ||
        trimmedFilePath.length == expectedPathPrefix.length ||
        trimmedFilePath.substring(expectedPathPrefix.length).contains('/')) {
      throw ArgumentError('Der Dokumentpfad passt nicht zur Nachricht.');
    }

    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);
    final messageDocument = _messagesCollection(
      trimmedChatId,
    ).doc(trimmedMessageId);
    final messageText = 'Dokument: $trimmedFileName';
    final readReceiptsEnabled = await _readReceiptsEnabledFor(
      trimmedSenderUserId,
    );

    await _firestore.runTransaction((transaction) async {
      final chatDocument = _chatsCollection.doc(trimmedChatId);
      final chatSnapshot = await transaction.get(chatDocument);
      final messageSnapshot = await transaction.get(messageDocument);
      final participantIds = _requireSendableAttachmentChat(
        chatSnapshot: chatSnapshot,
        senderUserId: trimmedSenderUserId,
      );

      if (messageSnapshot.exists) {
        throw StateError('Diese Nachricht wurde bereits gesendet.');
      }

      transaction.set(messageDocument, {
        'chatId': trimmedChatId,
        'senderUserId': trimmedSenderUserId,
        'type': FirestoreMessageTypes.document,
        'text': messageText,
        'fileUrl': trimmedFileUrl,
        'filePath': trimmedFilePath,
        'fileName': trimmedFileName,
        'fileContentType': trimmedContentType,
        'fileSizeBytes': fileSizeBytes,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'isDeleted': false,
      });

      transaction.set(chatDocument, {
        'lastMessage': messageText,
        'lastMessageAt': timestamp,
        if (readReceiptsEnabled)
          'lastReadAtBy': {trimmedSenderUserId: timestamp},
        'manualUnreadBy': {trimmedSenderUserId: false},
        'manualUnreadUpdatedAtBy': {trimmedSenderUserId: timestamp},
        if (participantIds.isNotEmpty)
          'archivedBy': {
            for (final participantId in participantIds) participantId: false,
          },
        if (participantIds.isNotEmpty)
          'archivedUpdatedAtBy': {
            for (final participantId in participantIds)
              participantId: timestamp,
          },
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    });

    return ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.document,
      text: messageText,
      fileUrl: trimmedFileUrl,
      filePath: trimmedFilePath,
      fileName: trimmedFileName,
      fileContentType: trimmedContentType,
      fileSizeBytes: fileSizeBytes,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ChatMessageRecord> sendAudioMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required int fileDurationMs,
    String? fileContentType,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedFileUrl = fileUrl.trim();
    final trimmedFilePath = filePath.trim();
    final trimmedFileName = fileName.trim();
    final trimmedContentType = fileContentType?.trim().toLowerCase() ?? '';

    if (trimmedFileUrl.isEmpty ||
        trimmedFilePath.isEmpty ||
        trimmedFileName.isEmpty) {
      throw ArgumentError(
        'Audio-URL, Dateipfad und Dateiname dürfen nicht leer sein.',
      );
    }

    if (trimmedFileName.length > 160) {
      throw ArgumentError('Der Dateiname ist zu lang.');
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxChatVoiceMemoBytes) {
      throw ArgumentError('Die Größe der Sprachmemo ist ungültig.');
    }

    if (fileDurationMs < 0 || fileDurationMs > _maxChatVoiceMemoDurationMs) {
      throw ArgumentError('Die Dauer der Sprachmemo ist ungültig.');
    }

    if (trimmedContentType != 'audio/mp4') {
      throw ArgumentError('Das Audioformat wird nicht unterstützt.');
    }

    final expectedPathPrefix =
        'chat_voice_memos/$trimmedChatId/$trimmedSenderUserId/'
        '${trimmedMessageId}_';

    if (!trimmedFilePath.startsWith(expectedPathPrefix) ||
        !trimmedFilePath.endsWith('.m4a') ||
        trimmedFilePath.length == expectedPathPrefix.length + 4 ||
        trimmedFilePath.substring(expectedPathPrefix.length).contains('/')) {
      throw ArgumentError('Der Sprachmemo-Pfad passt nicht zur Nachricht.');
    }

    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);
    final messageDocument = _messagesCollection(
      trimmedChatId,
    ).doc(trimmedMessageId);
    const messageText = 'Sprachnachricht';
    final readReceiptsEnabled = await _readReceiptsEnabledFor(
      trimmedSenderUserId,
    );

    await _firestore.runTransaction((transaction) async {
      final chatDocument = _chatsCollection.doc(trimmedChatId);
      final chatSnapshot = await transaction.get(chatDocument);
      final messageSnapshot = await transaction.get(messageDocument);
      final participantIds = _requireSendableAttachmentChat(
        chatSnapshot: chatSnapshot,
        senderUserId: trimmedSenderUserId,
      );

      if (messageSnapshot.exists) {
        throw StateError('Diese Nachricht wurde bereits gesendet.');
      }

      transaction.set(messageDocument, {
        'chatId': trimmedChatId,
        'senderUserId': trimmedSenderUserId,
        'type': FirestoreMessageTypes.audio,
        'text': messageText,
        'fileUrl': trimmedFileUrl,
        'filePath': trimmedFilePath,
        'fileName': trimmedFileName,
        'fileContentType': trimmedContentType,
        'fileSizeBytes': fileSizeBytes,
        'fileDurationMs': fileDurationMs,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'isDeleted': false,
      });

      transaction.set(chatDocument, {
        'lastMessage': messageText,
        'lastMessageAt': timestamp,
        if (readReceiptsEnabled)
          'lastReadAtBy': {trimmedSenderUserId: timestamp},
        'manualUnreadBy': {trimmedSenderUserId: false},
        'manualUnreadUpdatedAtBy': {trimmedSenderUserId: timestamp},
        if (participantIds.isNotEmpty)
          'archivedBy': {
            for (final participantId in participantIds) participantId: false,
          },
        if (participantIds.isNotEmpty)
          'archivedUpdatedAtBy': {
            for (final participantId in participantIds)
              participantId: timestamp,
          },
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    });

    return ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.audio,
      text: messageText,
      fileUrl: trimmedFileUrl,
      filePath: trimmedFilePath,
      fileName: trimmedFileName,
      fileContentType: trimmedContentType,
      fileSizeBytes: fileSizeBytes,
      fileDurationMs: fileDurationMs,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ChatMessageRecord> sendVideoMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required int fileDurationMs,
    String? fileContentType,
    String? caption,
    bool isViewOnce = false,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedFileUrl = fileUrl.trim();
    final trimmedFilePath = filePath.trim();
    final trimmedFileName = fileName.trim();
    final trimmedContentType = fileContentType?.trim().toLowerCase() ?? '';
    final trimmedCaption = caption?.trim() ?? '';

    if (trimmedFileUrl.isEmpty ||
        trimmedFilePath.isEmpty ||
        trimmedFileName.isEmpty) {
      throw ArgumentError(
        'Video-URL, Dateipfad und Dateiname dürfen nicht leer sein.',
      );
    }

    if (trimmedFileName.length > 160) {
      throw ArgumentError('Der Dateiname ist zu lang.');
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxChatVideoBytes) {
      throw ArgumentError('Die Videogröße ist ungültig.');
    }

    if (fileDurationMs <= 0 || fileDurationMs > _maxChatVideoDurationMs) {
      throw ArgumentError('Die Videodauer ist ungültig.');
    }

    if (trimmedContentType != 'video/mp4') {
      throw ArgumentError('Das Videoformat wird nicht unterstützt.');
    }

    if (trimmedCaption.length > _maxChatImageCaptionLength) {
      throw ArgumentError('Die Videobeschreibung ist zu lang.');
    }

    final expectedPath =
        'chat_videos/$trimmedChatId/$trimmedSenderUserId/'
        '$trimmedMessageId.mp4';

    if (trimmedFilePath != expectedPath) {
      throw ArgumentError('Der Videopfad passt nicht zur Nachricht.');
    }

    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);
    final messageDocument = _messagesCollection(
      trimmedChatId,
    ).doc(trimmedMessageId);
    final messageText = trimmedCaption.isEmpty ? 'Video' : trimmedCaption;
    final readReceiptsEnabled = await _readReceiptsEnabledFor(
      trimmedSenderUserId,
    );

    await _firestore.runTransaction((transaction) async {
      final chatDocument = _chatsCollection.doc(trimmedChatId);
      final chatSnapshot = await transaction.get(chatDocument);
      final messageSnapshot = await transaction.get(messageDocument);
      final participantIds = _requireSendableAttachmentChat(
        chatSnapshot: chatSnapshot,
        senderUserId: trimmedSenderUserId,
      );

      if (messageSnapshot.exists) {
        throw StateError('Diese Nachricht wurde bereits gesendet.');
      }

      transaction.set(messageDocument, {
        'chatId': trimmedChatId,
        'senderUserId': trimmedSenderUserId,
        'type': ChatMessageType.video.name,
        'text': messageText,
        'fileUrl': trimmedFileUrl,
        'filePath': trimmedFilePath,
        'fileName': trimmedFileName,
        'fileContentType': trimmedContentType,
        'fileSizeBytes': fileSizeBytes,
        'fileDurationMs': fileDurationMs,
        'isViewOnce': isViewOnce,
        'viewOnceOpenedAtBy': <String, Timestamp>{},
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'isDeleted': false,
      });

      transaction.set(chatDocument, {
        'lastMessage': messageText,
        'lastMessageAt': timestamp,
        if (readReceiptsEnabled)
          'lastReadAtBy': {trimmedSenderUserId: timestamp},
        'manualUnreadBy': {trimmedSenderUserId: false},
        'manualUnreadUpdatedAtBy': {trimmedSenderUserId: timestamp},
        if (participantIds.isNotEmpty)
          'archivedBy': {
            for (final participantId in participantIds) participantId: false,
          },
        if (participantIds.isNotEmpty)
          'archivedUpdatedAtBy': {
            for (final participantId in participantIds)
              participantId: timestamp,
          },
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    });

    return ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.video,
      text: messageText,
      fileUrl: trimmedFileUrl,
      filePath: trimmedFilePath,
      fileName: trimmedFileName,
      fileContentType: trimmedContentType,
      fileSizeBytes: fileSizeBytes,
      fileDurationMs: fileDurationMs,
      isViewOnce: isViewOnce,
      createdAt: now,
      updatedAt: now,
    );
  }

  Set<String> _requireSendableAttachmentChat({
    required DocumentSnapshot<Map<String, dynamic>> chatSnapshot,
    required String senderUserId,
  }) {
    final chatData = chatSnapshot.data();

    if (!chatSnapshot.exists || chatData == null) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final participantIds = _stringListFromValue(
      chatData['participants'],
    ).where((participantId) => participantId.trim().isNotEmpty).toSet();
    final status = chatData['status'];
    final deletedBy = _boolMapFromValue(chatData['deletedBy']);

    if (participantIds.length != 2 || !participantIds.contains(senderUserId)) {
      throw StateError('Du bist kein Teilnehmer dieses Chats.');
    }

    if (status != FirestoreChatStatus.active &&
        status != FirestoreChatStatus.archived) {
      throw StateError('Dieser Chat ist für neue Anhänge gesperrt.');
    }

    if (deletedBy[senderUserId] == true) {
      throw StateError('Dieser Chat wurde für dich gelöscht.');
    }

    return participantIds;
  }

  @override
  Future<ChatMessageRecord> addSystemMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw ArgumentError('System message text must not be empty.');
    }

    final now = DateTime.now();
    final messageDocument = _messagesCollection(chatId).doc();

    await messageDocument.set({
      'chatId': chatId,
      'senderUserId': 'system',
      'type': FirestoreMessageTypes.system,
      'text': trimmedText,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'isDeleted': false,
    });

    final snapshot = await messageDocument.get();
    return _messageFromSnapshot(snapshot);
  }

  Future<void> setChatFavorite({
    required String chatId,
    required String userId,
    required bool isFavorite,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    await _chatsCollection.doc(trimmedChatId).update({
      FieldPath(['favoriteBy', trimmedUserId]): isFavorite,
      FieldPath(['favoriteUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setChatMuted({
    required String chatId,
    required String userId,
    required bool isMuted,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    await _chatsCollection.doc(trimmedChatId).update({
      FieldPath(['mutedBy', trimmedUserId]): isMuted,
      FieldPath(['mutedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setChatPinned({
    required String chatId,
    required String userId,
    required bool isPinned,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    await _chatsCollection.doc(trimmedChatId).update({
      FieldPath(['pinnedBy', trimmedUserId]): isPinned,
      FieldPath(['pinnedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
    });
  }

  Future<ChatRecord> blockChat({
    required String chatId,
    required String blockedByUserId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = blockedByUserId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);
    final existingChat = await chatDocument.get();
    if (!existingChat.exists) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }
    final chat = _chatFromSnapshot(existingChat);
    _requireChatActionParticipant(
      chat: chat,
      userId: trimmedUserId,
      allowBlocked: true,
    );

    if (chat.status == ChatStatus.blocked) {
      if (chat.isBlockedBy(trimmedUserId)) {
        return chat;
      }
      throw StateError('Dieser Chat wurde bereits blockiert.');
    }

    if (chat.status != ChatStatus.active &&
        chat.status != ChatStatus.archived) {
      throw StateError('Dieser Chat kann nicht blockiert werden.');
    }
    final participants = _stringListFromValue(
      existingChat.data()?['participants'],
    );
    final existingRelationships = <DocumentReference<Map<String, dynamic>>>[];
    if (participants.length == 2) {
      final firstUserId = participants[0].trim();
      final secondUserId = participants[1].trim();
      if (firstUserId.isNotEmpty && secondUserId.isNotEmpty) {
        final relationships = _firestore.collection('follow_relationships');
        final references = <DocumentReference<Map<String, dynamic>>>[
          relationships.doc('${firstUserId}_$secondUserId'),
          relationships.doc('${secondUserId}_$firstUserId'),
        ];
        final snapshots = await Future.wait(
          references.map((reference) => reference.get()),
        );
        for (var index = 0; index < snapshots.length; index++) {
          if (snapshots[index].exists) {
            existingRelationships.add(references[index]);
          }
        }
      }
    }
    final batch = _firestore.batch();
    batch.set(chatDocument, {
      'status': ChatStatus.blocked.name,
      'blockedBy': trimmedUserId,
      'blockedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    for (final relationship in existingRelationships) {
      batch.delete(relationship);
    }
    await batch.commit();

    final snapshot = await chatDocument.get();
    return _chatFromSnapshot(snapshot);
  }

  @override
  Future<ChatRecord> unblockChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);
    final existingChat = await chatDocument.get();

    if (!existingChat.exists) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _chatFromSnapshot(existingChat);
    _requireChatActionParticipant(
      chat: chat,
      userId: trimmedUserId,
      allowBlocked: true,
    );

    if (chat.status != ChatStatus.blocked || !chat.isBlockedBy(trimmedUserId)) {
      throw StateError(
        'Nur der Nutzer, der blockiert hat, kann die Blockierung aufheben.',
      );
    }

    await chatDocument.update({
      'status': FirestoreChatStatus.active,
      'blockedBy': FieldValue.delete(),
      'blockedAt': FieldValue.delete(),
      'unblockedBy': trimmedUserId,
      'unblockedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await chatDocument.get();
    return _chatFromSnapshot(snapshot);
  }

  Future<void> reportChat({
    required String chatId,
    required String reporterUserId,
    String reason = 'Chat gemeldet',
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedReporterId = reporterUserId.trim();
    final trimmedReason = reason.trim();

    if (trimmedChatId.isEmpty || trimmedReporterId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final resolvedReason = trimmedReason.isEmpty
        ? 'Chat gemeldet'
        : trimmedReason;

    if (resolvedReason.length > 500) {
      throw ArgumentError('Der Meldegrund darf höchstens 500 Zeichen haben.');
    }

    final reportDocument = _firestore
        .collection(CaRismaFirestoreCollections.reports)
        .doc('chat_${trimmedChatId}_$trimmedReporterId');
    await _firestore.runTransaction((transaction) async {
      final existingReport = await transaction.get(reportDocument);

      if (existingReport.exists) {
        return;
      }

      transaction.set(reportDocument, {
        'type': 'chat',
        'chatId': trimmedChatId,
        'reporterUserId': trimmedReporterId,
        'reason': resolvedReason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<ChatRecord> archiveChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);
    final existingChat = await chatDocument.get();

    if (!existingChat.exists) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _chatFromSnapshot(existingChat);
    _requireChatActionParticipant(chat: chat, userId: trimmedUserId);

    if (chat.isArchivedFor(trimmedUserId)) {
      return chat;
    }

    await chatDocument.update({
      FieldPath(['archivedBy', trimmedUserId]): true,
      FieldPath(['archivedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final archivedBy = Map<String, bool>.from(chat.archivedBy)
      ..[trimmedUserId] = true;
    return chat.copyWith(archivedBy: archivedBy, updatedAt: DateTime.now());
  }

  @override
  Future<ChatRecord> unarchiveChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);
    final existingChat = await chatDocument.get();

    if (!existingChat.exists) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _chatFromSnapshot(existingChat);
    _requireChatActionParticipant(chat: chat, userId: trimmedUserId);

    if (!chat.isArchivedFor(trimmedUserId)) {
      return chat;
    }

    await chatDocument.update({
      FieldPath(['archivedBy', trimmedUserId]): false,
      FieldPath(['archivedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final archivedBy = Map<String, bool>.from(chat.archivedBy)
      ..[trimmedUserId] = false;
    return chat.copyWith(archivedBy: archivedBy, updatedAt: DateTime.now());
  }

  @override
  Future<ChatRecord> deleteChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);
    final existingChat = await chatDocument.get();

    if (!existingChat.exists) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _chatFromSnapshot(existingChat);
    _requireChatActionParticipant(
      chat: chat,
      userId: trimmedUserId,
      allowDeleted: true,
    );

    if (chat.isDeletedFor(trimmedUserId)) {
      return chat;
    }

    await chatDocument.update({
      FieldPath(['deletedBy', trimmedUserId]): true,
      FieldPath(['deletedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final deletedBy = Map<String, bool>.from(chat.deletedBy)
      ..[trimmedUserId] = true;
    return chat.copyWith(deletedBy: deletedBy, updatedAt: DateTime.now());
  }

  void _requireChatActionParticipant({
    required ChatRecord chat,
    required String userId,
    bool allowBlocked = false,
    bool allowDeleted = false,
  }) {
    final participantIds = chat.participants
        .map((participantId) => participantId.trim())
        .where((participantId) => participantId.isNotEmpty)
        .toSet();

    if (chat.participants.length != 2 ||
        participantIds.length != 2 ||
        !participantIds.contains(userId)) {
      throw StateError('Du bist kein Teilnehmer dieses Chats.');
    }

    if (!allowDeleted && chat.isDeletedFor(userId)) {
      throw StateError('Dieser Chat wurde für dich gelöscht.');
    }

    if (!allowBlocked && chat.status == ChatStatus.blocked) {
      throw StateError('Dieser Chat ist blockiert.');
    }
  }

  @override
  Future<void> deleteMessageForUser({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedMessageId = messageId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty ||
        trimmedMessageId.isEmpty ||
        trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-, Nachrichten- und Nutzer-ID fehlen.');
    }

    await _messagesCollection(trimmedChatId).doc(trimmedMessageId).update({
      'deletedFor.$trimmedUserId': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedMessageId = messageId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty ||
        trimmedMessageId.isEmpty ||
        trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-, Nachrichten- und Nutzer-ID fehlen.');
    }

    final messageDocument = _messagesCollection(
      trimmedChatId,
    ).doc(trimmedMessageId);
    final messageSnapshot = await messageDocument.get();

    if (!messageSnapshot.exists) {
      throw StateError('Die Nachricht wurde nicht gefunden.');
    }

    final message = _messageFromSnapshot(messageSnapshot);

    if (message.senderUserId != trimmedUserId) {
      throw StateError('Du kannst diese Nachricht nur für dich löschen.');
    }

    if (!canDeleteChatMessageForEveryone(message)) {
      throw StateError(
        'Diese Nachricht kann nicht mehr für alle gelöscht werden.',
      );
    }

    await messageDocument.update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final latestSnapshot = await _messagesCollection(
      trimmedChatId,
    ).where('isDeleted', isEqualTo: false).get();

    final latestMessages =
        latestSnapshot.docs.map(_messageFromSnapshot).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestMessage = latestMessages.isEmpty ? null : latestMessages.first;

    await _chatsCollection.doc(trimmedChatId).set({
      'lastMessage': latestMessage?.text,
      'lastMessageAt': latestMessage == null
          ? null
          : Timestamp.fromDate(latestMessage.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setMessageStarred({
    required String chatId,
    required String messageId,
    required bool isStarred,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedMessageId = messageId.trim();

    if (trimmedChatId.isEmpty || trimmedMessageId.isEmpty) {
      throw ArgumentError('Chat ID and message ID must not be empty.');
    }

    await _messagesCollection(trimmedChatId).doc(trimmedMessageId).set({
      'isStarred': isStarred,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedMessageId = messageId.trim();
    final trimmedUserId = userId.trim();
    final trimmedReaction = _normalizedMessageReaction(reaction);

    if (trimmedChatId.isEmpty ||
        trimmedMessageId.isEmpty ||
        trimmedUserId.isEmpty) {
      throw ArgumentError('Chat ID, message ID and user ID must not be empty.');
    }

    await _messagesCollection(trimmedChatId).doc(trimmedMessageId).update({
      FieldPath(['reactionBy', trimmedUserId]): trimmedReaction.isEmpty
          ? FieldValue.delete()
          : trimmedReaction,
      FieldPath(['reactionUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> markViewOnceMediaOpened({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedUserId = _requiredChatAttachmentId(userId, 'Nutzer-ID');
    final chatDocument = _chatsCollection.doc(trimmedChatId);
    final messageDocument = _messagesCollection(
      trimmedChatId,
    ).doc(trimmedMessageId);

    return _firestore.runTransaction<bool>((transaction) async {
      final chatSnapshot = await transaction.get(chatDocument);
      final messageSnapshot = await transaction.get(messageDocument);
      _requireSendableAttachmentChat(
        chatSnapshot: chatSnapshot,
        senderUserId: trimmedUserId,
      );

      final data = messageSnapshot.data();

      if (!messageSnapshot.exists || data == null) {
        throw StateError('Die Mediennachricht wurde nicht gefunden.');
      }

      final type = _messageTypeFromName(data['type'] as String?);
      final senderUserId = _stringFromValue(data['senderUserId']);
      final isViewOnce = data['isViewOnce'] as bool? ?? false;
      final isDeleted = data['isDeleted'] as bool? ?? false;

      if (!isViewOnce ||
          isDeleted ||
          (type != ChatMessageType.image && type != ChatMessageType.video)) {
        throw StateError('Diese Nachricht ist kein Einmal-Medium.');
      }

      if (senderUserId == trimmedUserId) {
        throw StateError(
          'Eigene Einmal-Medien können nicht erneut geöffnet werden.',
        );
      }

      final openedAtBy = _dateTimeMapFromValue(data['viewOnceOpenedAtBy']);

      if (openedAtBy.containsKey(trimmedUserId)) {
        return false;
      }

      final now = DateTime.now();
      final nextOpenedAtBy = <String, Timestamp>{
        for (final entry in openedAtBy.entries)
          entry.key: Timestamp.fromDate(entry.value),
        trimmedUserId: Timestamp.fromDate(now),
      };

      transaction.update(messageDocument, {
        'viewOnceOpenedAtBy': nextOpenedAtBy,
        'updatedAt': Timestamp.fromDate(now),
      });
      return true;
    });
  }

  CollectionReference<Map<String, dynamic>> _messagesCollection(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection(CaRismaFirestoreCollections.messages);
  }

  ChatRecord _chatFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return ChatRecord(
      id: snapshot.id,
      participants: _stringListFromValue(data['participants']),
      status: _chatStatusFromName(_stringFromValue(data['status'])),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime(1970),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime(1970),
      requestId: _stringFromValue(data['requestId']),
      lastMessage: _stringFromValue(data['lastMessage']),
      lastMessageAt: _dateTimeFromValue(data['lastMessageAt']),
      senderUserId: _stringFromValue(data['senderUserId']),
      receiverUserId: _stringFromValue(data['receiverUserId']),
      senderDisplayName: _stringFromValue(data['senderDisplayName']),
      receiverDisplayName: _stringFromValue(data['receiverDisplayName']),
      senderPhotoUrl: _stringFromValue(data['senderPhotoUrl']),
      receiverPhotoUrl: _stringFromValue(data['receiverPhotoUrl']),
      blockedBy: _stringFromValue(data['blockedBy']),
      blockedAt: _dateTimeFromValue(data['blockedAt']),
      countryCode: _stringFromValue(data['countryCode']),
      vehicleId: _stringFromValue(data['vehicleId']),
      displayPlate: _stringFromValue(data['displayPlate']),
      vehicleBrand: _stringFromValue(data['vehicleBrand']),
      vehicleModel: _stringFromValue(data['vehicleModel']),
      vehicleColor: _stringFromValue(data['vehicleColor']),
      vehicleLabel: _stringFromValue(data['vehicleLabel']),
      favoriteBy: _boolMapFromValue(data['favoriteBy']),
      pinnedBy: _boolMapFromValue(data['pinnedBy']),
      mutedBy: _boolMapFromValue(data['mutedBy']),
      archivedBy: _boolMapFromValue(data['archivedBy']),
      deletedBy: _boolMapFromValue(data['deletedBy']),
      manualUnreadBy: _boolMapFromValue(data['manualUnreadBy']),
      lastReadAtBy: _dateTimeMapFromValue(data['lastReadAtBy']),
    );
  }

  ChatMessageRecord _messageFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return ChatMessageRecord(
      id: snapshot.id,
      chatId: data['chatId'] as String? ?? '',
      senderUserId: data['senderUserId'] as String? ?? '',
      type: _messageTypeFromName(data['type'] as String?),
      text: data['text'] as String? ?? '',
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime(1970),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime(1970),
      isDeleted: data['isDeleted'] as bool? ?? false,
      isStarred: data['isStarred'] as bool? ?? false,
      replyToMessageId: data['replyToMessageId'] as String?,
      replyToText: data['replyToText'] as String?,
      imageUrl: data['imageUrl'] as String?,
      imagePath: data['imagePath'] as String?,
      fileUrl: data['fileUrl'] as String?,
      filePath: data['filePath'] as String?,
      fileName: data['fileName'] as String?,
      fileContentType: data['fileContentType'] as String?,
      fileSizeBytes: _intFromValue(data['fileSizeBytes']),
      fileDurationMs: _intFromValue(data['fileDurationMs']),
      isViewOnce: data['isViewOnce'] as bool? ?? false,
      viewOnceOpenedAtBy: _dateTimeMapFromValue(data['viewOnceOpenedAtBy']),
      reactionBy: _stringMapFromValue(
        data['reactionBy'],
        allowedValues: _allowedMessageReactions,
      ),
      deletedFor: _boolMapFromValue(data['deletedFor']),
    );
  }

  static Map<String, DateTime> _dateTimeMapFromValue(Object? value) {
    if (value is! Map) {
      return const <String, DateTime>{};
    }

    final result = <String, DateTime>{};

    for (final entry in value.entries) {
      final key = entry.key?.toString() ?? '';
      final dateTime = _dateTimeFromValue(entry.value);

      if (key.isNotEmpty && dateTime != null) {
        result[key] = dateTime;
      }
    }

    return result;
  }

  static ChatStatus _chatStatusFromName(String? name) {
    return ChatStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ChatStatus.active,
    );
  }

  static ChatMessageType _messageTypeFromName(String? name) {
    return ChatMessageType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => ChatMessageType.text,
    );
  }

  static List<String> _stringListFromValue(Object? value) {
    if (value is Iterable) {
      return value.whereType<String>().toList();
    }

    return const <String>[];
  }

  static String? _stringFromValue(Object? value) {
    return value is String ? value : null;
  }

  static Map<String, bool> _boolMapFromValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue == true),
      );
    }

    return const <String, bool>{};
  }

  static Map<String, String> _stringMapFromValue(
    Object? value, {
    Set<String>? allowedValues,
  }) {
    if (value is! Map) {
      return const <String, String>{};
    }

    final result = <String, String>{};

    for (final entry in value.entries) {
      final key = entry.key?.toString() ?? '';
      final mapValue = entry.value?.toString().trim() ?? '';

      if (key.isNotEmpty &&
          mapValue.isNotEmpty &&
          (allowedValues == null || allowedValues.contains(mapValue))) {
        result[key] = mapValue;
      }
    }

    return result;
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static int? _intFromValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}

class LocalChatRepository implements ChatRepository {
  LocalChatRepository({
    List<ChatRecord> seedChats = const [],
    List<ChatMessageRecord> seedMessages = const [],
  }) : _chats = [...seedChats],
       _messages = [...seedMessages];

  final List<ChatRecord> _chats;
  final List<ChatMessageRecord> _messages;

  List<ChatRecord> _sortChatsForUser(List<ChatRecord> chats, String userId) {
    return chats..sort((a, b) {
      final aPinned = a.isPinnedFor(userId);
      final bPinned = b.isPinnedFor(userId);

      if (aPinned != bPinned) {
        return aPinned ? -1 : 1;
      }

      final aFavorite = a.isFavoriteFor(userId);
      final bFavorite = b.isFavoriteFor(userId);

      if (aFavorite != bFavorite) {
        return aFavorite ? -1 : 1;
      }

      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  @override
  Future<List<ChatRecord>> loadChats({required String userId}) async {
    return _sortChatsForUser(
      _chats
          .where((chat) => chat.participants.contains(userId))
          .where((chat) => chat.isVisibleInActiveListFor(userId))
          .toList(),
      userId,
    );
  }

  @override
  Future<ChatRecord?> loadChat({required String chatId}) async {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return null;
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      return null;
    }

    return _chats[index];
  }

  @override
  Stream<List<ChatRecord>> watchChats({required String userId}) {
    return Stream<List<ChatRecord>>.value(
      _sortChatsForUser(
        _chats
            .where((chat) => chat.participants.contains(userId))
            .where((chat) => chat.isVisibleInActiveListFor(userId))
            .toList(),
        userId,
      ),
    );
  }

  @override
  Stream<List<ChatRecord>> watchArchivedChats({required String userId}) {
    return Stream<List<ChatRecord>>.value(
      _chats
          .where((chat) => chat.participants.contains(userId))
          .where((chat) => chat.isVisibleInArchivedListFor(userId))
          .toList(),
    );
  }

  @override
  Stream<List<ChatRecord>> watchBlockedChats({required String userId}) {
    return Stream<List<ChatRecord>>.value(
      _chats
          .where((chat) => chat.participants.contains(userId))
          .where((chat) => chat.isVisibleInBlockedListFor(userId))
          .toList()
        ..sort((a, b) {
          final aBlockedAt = a.blockedAt ?? a.updatedAt;
          final bBlockedAt = b.blockedAt ?? b.updatedAt;
          return bBlockedAt.compareTo(aBlockedAt);
        }),
    );
  }

  @override
  String createMessageId({required String chatId}) {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      throw ArgumentError('Chat ID must not be empty.');
    }

    return 'local-message-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Future<ChatRecord> createChat({
    required List<String> participants,
    String? requestId,
    String? systemMessage,
    String? senderUserId,
    String? receiverUserId,
    String? senderDisplayName,
    String? receiverDisplayName,
    String? senderPhotoUrl,
    String? receiverPhotoUrl,
    String? countryCode,
    String? vehicleId,
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
  }) async {
    final now = DateTime.now();
    final uniqueParticipants =
        participants
            .map((participant) => participant.trim())
            .where((participant) => participant.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (uniqueParticipants.length != 2) {
      throw ArgumentError('A chat requires exactly two participants.');
    }
    final trimmedRequestId = requestId?.trim() ?? '';
    final chatId = trimmedRequestId.isEmpty
        ? 'local-chat-${now.microsecondsSinceEpoch}'
        : 'request_$trimmedRequestId';
    final existingChat = await loadChat(chatId: chatId);

    if (existingChat != null) {
      return existingChat;
    }

    final chat = ChatRecord(
      id: chatId,
      participants: uniqueParticipants,
      status: ChatStatus.active,
      createdAt: now,
      updatedAt: now,
      requestId: requestId,
      lastMessage: systemMessage,
      lastMessageAt: systemMessage == null ? null : now,
      senderUserId: _trimmedOrNull(senderUserId),
      receiverUserId: _trimmedOrNull(receiverUserId),
      senderDisplayName: _trimmedOrNull(senderDisplayName),
      receiverDisplayName: _trimmedOrNull(receiverDisplayName),
      senderPhotoUrl: _trimmedOrNull(senderPhotoUrl),
      receiverPhotoUrl: _trimmedOrNull(receiverPhotoUrl),
      countryCode: _trimmedOrNull(countryCode)?.toUpperCase(),
      vehicleId: _trimmedOrNull(vehicleId),
      displayPlate: _trimmedOrNull(displayPlate),
      vehicleBrand: _trimmedOrNull(vehicleBrand),
      vehicleModel: _trimmedOrNull(vehicleModel),
      vehicleColor: _trimmedOrNull(vehicleColor),
      vehicleLabel: _trimmedOrNull(vehicleLabel),
    );

    _chats.add(chat);

    if (systemMessage != null && systemMessage.trim().isNotEmpty) {
      _messages.add(
        ChatMessageRecord(
          id: 'local-message-${now.microsecondsSinceEpoch}',
          chatId: chat.id,
          senderUserId: 'system',
          type: ChatMessageType.system,
          text: systemMessage.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return chat;
  }

  @override
  Future<List<ChatMessageRecord>> loadMessages({required String chatId}) async {
    return _messages
        .where((message) => message.chatId == chatId && !message.isDeleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Stream<List<ChatMessageRecord>> watchMessages({required String chatId}) {
    final messages =
        _messages
            .where((message) => message.chatId == chatId && !message.isDeleted)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Stream.value(messages);
  }

  @override
  Future<ChatMessageRecord> sendTextMessage({
    required String chatId,
    required String senderUserId,
    required String text,
    ChatMessageType messageType = ChatMessageType.text,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedSenderUserId = senderUserId.trim();
    final trimmedText = text.trim();

    if (trimmedChatId.isEmpty || trimmedSenderUserId.isEmpty) {
      throw ArgumentError('Chat ID and sender user ID must not be empty.');
    }

    if (trimmedText.isEmpty) {
      throw ArgumentError('Message text must not be empty.');
    }

    if (trimmedText.length > FirestoreDocumentDefaults.maxChatMessageLength) {
      throw ArgumentError('Message text is too long.');
    }

    final chat = await loadChat(chatId: trimmedChatId);

    if (chat == null) {
      throw StateError('Chat not found: $trimmedChatId');
    }

    final participantIds = chat.participants
        .map((participantId) => participantId.trim())
        .where((participantId) => participantId.isNotEmpty)
        .toSet();

    if (participantIds.length != 2 ||
        !participantIds.contains(trimmedSenderUserId)) {
      throw StateError('Sender is not a participant of this chat.');
    }

    if (chat.status != ChatStatus.active &&
        chat.status != ChatStatus.archived) {
      throw StateError('This chat is not open for new messages.');
    }

    if (chat.isDeletedFor(trimmedSenderUserId)) {
      throw StateError('This chat was deleted for the sender.');
    }

    final now = DateTime.now();
    final effectiveMessageType =
        messageType == ChatMessageType.location ||
            messageType == ChatMessageType.contact
        ? messageType
        : ChatMessageType.text;
    final lastMessageText = switch (effectiveMessageType) {
      ChatMessageType.location => 'Standort',
      ChatMessageType.contact => 'Kontakt',
      _ => trimmedText,
    };

    final message = ChatMessageRecord(
      id: 'local-message-${now.microsecondsSinceEpoch}',
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: effectiveMessageType,
      text: trimmedText,
      createdAt: now,
      updatedAt: now,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
    );

    _messages.add(message);
    _updateChatLastMessage(
      chatId: trimmedChatId,
      lastMessage: lastMessageText,
      timestamp: now,
      clearArchivedForParticipants: true,
      readByUserId: trimmedSenderUserId,
    );

    return message;
  }

  @override
  Future<ChatMessageRecord> sendImageMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String imageUrl,
    required String imagePath,
    String? caption,
    bool isViewOnce = false,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedImageUrl = imageUrl.trim();
    final trimmedImagePath = imagePath.trim();
    final trimmedCaption = caption?.trim() ?? '';
    final expectedImagePath =
        'chat_images/$trimmedChatId/$trimmedSenderUserId/'
        '$trimmedMessageId.jpg';

    _requireLocalAttachmentChat(
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      messageId: trimmedMessageId,
    );

    if (trimmedImageUrl.isEmpty || trimmedImagePath != expectedImagePath) {
      throw ArgumentError('Die Foto-Metadaten sind ungültig.');
    }

    if (trimmedCaption.length > _maxChatImageCaptionLength) {
      throw ArgumentError('Die Bildunterschrift ist zu lang.');
    }

    final now = DateTime.now();
    final messageText = trimmedCaption.isEmpty ? 'Foto' : trimmedCaption;
    final message = ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.image,
      text: messageText,
      imageUrl: trimmedImageUrl,
      imagePath: trimmedImagePath,
      isViewOnce: isViewOnce,
      createdAt: now,
      updatedAt: now,
    );

    _messages.add(message);
    _updateChatLastMessage(
      chatId: trimmedChatId,
      lastMessage: messageText,
      timestamp: now,
      clearArchivedForParticipants: true,
      readByUserId: trimmedSenderUserId,
    );

    return message;
  }

  @override
  Future<ChatMessageRecord> sendDocumentMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    String? fileContentType,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedFileUrl = fileUrl.trim();
    final trimmedFilePath = filePath.trim();
    final now = DateTime.now();
    final trimmedFileName = fileName.trim();
    final trimmedContentType = fileContentType?.trim().toLowerCase() ?? '';
    final expectedPathPrefix =
        'chat_documents/$trimmedChatId/$trimmedSenderUserId/'
        '${trimmedMessageId}_';

    _requireLocalAttachmentChat(
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      messageId: trimmedMessageId,
    );

    if (trimmedFileUrl.isEmpty ||
        trimmedFileName.isEmpty ||
        trimmedFileName.length > 160 ||
        !trimmedFilePath.startsWith(expectedPathPrefix) ||
        trimmedFilePath.length == expectedPathPrefix.length ||
        trimmedFilePath.substring(expectedPathPrefix.length).contains('/')) {
      throw ArgumentError('Die Dokument-Metadaten sind ungültig.');
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxChatDocumentBytes) {
      throw ArgumentError('Die Dokumentgröße ist ungültig.');
    }

    if (trimmedContentType.isEmpty ||
        !_isAllowedChatDocumentContentType(trimmedContentType)) {
      throw ArgumentError('Dieser Dokumenttyp wird nicht unterstützt.');
    }

    final messageText = 'Dokument: $trimmedFileName';
    final message = ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.document,
      text: messageText,
      fileUrl: trimmedFileUrl,
      filePath: trimmedFilePath,
      fileName: trimmedFileName,
      fileContentType: trimmedContentType,
      fileSizeBytes: fileSizeBytes,
      createdAt: now,
      updatedAt: now,
    );

    _messages.add(message);
    _updateChatLastMessage(
      chatId: trimmedChatId,
      lastMessage: messageText,
      timestamp: now,
      clearArchivedForParticipants: true,
      readByUserId: trimmedSenderUserId,
    );

    return message;
  }

  @override
  Future<ChatMessageRecord> sendAudioMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required int fileDurationMs,
    String? fileContentType,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedFileUrl = fileUrl.trim();
    final trimmedFilePath = filePath.trim();
    final trimmedFileName = fileName.trim();
    final trimmedContentType = fileContentType?.trim().toLowerCase() ?? '';
    final expectedPathPrefix =
        'chat_voice_memos/$trimmedChatId/$trimmedSenderUserId/'
        '${trimmedMessageId}_';

    _requireLocalAttachmentChat(
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      messageId: trimmedMessageId,
    );

    if (trimmedFileUrl.isEmpty ||
        trimmedFileName.isEmpty ||
        trimmedFileName.length > 160 ||
        !trimmedFilePath.startsWith(expectedPathPrefix) ||
        !trimmedFilePath.endsWith('.m4a') ||
        trimmedFilePath.substring(expectedPathPrefix.length).contains('/')) {
      throw ArgumentError('Die Sprachmemo-Metadaten sind ungültig.');
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxChatVoiceMemoBytes) {
      throw ArgumentError('Die Größe der Sprachmemo ist ungültig.');
    }

    if (fileDurationMs < 0 || fileDurationMs > _maxChatVoiceMemoDurationMs) {
      throw ArgumentError('Die Dauer der Sprachmemo ist ungültig.');
    }

    if (trimmedContentType != 'audio/mp4') {
      throw ArgumentError('Das Audioformat wird nicht unterstützt.');
    }

    final now = DateTime.now();
    const messageText = 'Sprachnachricht';
    final message = ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.audio,
      text: messageText,
      fileUrl: trimmedFileUrl,
      filePath: trimmedFilePath,
      fileName: trimmedFileName,
      fileContentType: trimmedContentType,
      fileSizeBytes: fileSizeBytes,
      fileDurationMs: fileDurationMs,
      createdAt: now,
      updatedAt: now,
    );

    _messages.add(message);
    _updateChatLastMessage(
      chatId: trimmedChatId,
      lastMessage: messageText,
      timestamp: now,
      clearArchivedForParticipants: true,
      readByUserId: trimmedSenderUserId,
    );

    return message;
  }

  @override
  Future<ChatMessageRecord> sendVideoMessage({
    required String chatId,
    required String messageId,
    required String senderUserId,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required int fileDurationMs,
    String? fileContentType,
    String? caption,
    bool isViewOnce = false,
  }) async {
    final trimmedChatId = _requiredChatAttachmentId(chatId, 'Chat-ID');
    final trimmedMessageId = _requiredChatAttachmentId(
      messageId,
      'Nachrichten-ID',
    );
    final trimmedSenderUserId = _requiredChatAttachmentId(
      senderUserId,
      'Absender-ID',
    );
    final trimmedFileUrl = fileUrl.trim();
    final trimmedFilePath = filePath.trim();
    final trimmedFileName = fileName.trim();
    final trimmedContentType = fileContentType?.trim().toLowerCase() ?? '';
    final trimmedCaption = caption?.trim() ?? '';
    final expectedPath =
        'chat_videos/$trimmedChatId/$trimmedSenderUserId/'
        '$trimmedMessageId.mp4';

    _requireLocalAttachmentChat(
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      messageId: trimmedMessageId,
    );

    if (trimmedFileUrl.isEmpty ||
        trimmedFilePath != expectedPath ||
        trimmedFileName.isEmpty ||
        trimmedFileName.length > 160) {
      throw ArgumentError('Die Video-Metadaten sind ungültig.');
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxChatVideoBytes) {
      throw ArgumentError('Die Videogröße ist ungültig.');
    }

    if (fileDurationMs <= 0 || fileDurationMs > _maxChatVideoDurationMs) {
      throw ArgumentError('Die Videodauer ist ungültig.');
    }

    if (trimmedContentType != 'video/mp4') {
      throw ArgumentError('Das Videoformat wird nicht unterstützt.');
    }

    if (trimmedCaption.length > _maxChatImageCaptionLength) {
      throw ArgumentError('Die Videobeschreibung ist zu lang.');
    }

    final now = DateTime.now();
    final messageText = trimmedCaption.isEmpty ? 'Video' : trimmedCaption;
    final message = ChatMessageRecord(
      id: trimmedMessageId,
      chatId: trimmedChatId,
      senderUserId: trimmedSenderUserId,
      type: ChatMessageType.video,
      text: messageText,
      fileUrl: trimmedFileUrl,
      filePath: trimmedFilePath,
      fileName: trimmedFileName,
      fileContentType: trimmedContentType,
      fileSizeBytes: fileSizeBytes,
      fileDurationMs: fileDurationMs,
      isViewOnce: isViewOnce,
      createdAt: now,
      updatedAt: now,
    );

    _messages.add(message);
    _updateChatLastMessage(
      chatId: trimmedChatId,
      lastMessage: messageText,
      timestamp: now,
      clearArchivedForParticipants: true,
      readByUserId: trimmedSenderUserId,
    );

    return message;
  }

  ChatRecord _requireLocalAttachmentChat({
    required String chatId,
    required String senderUserId,
    required String messageId,
  }) {
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);

    if (chatIndex < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _chats[chatIndex];
    final participantIds = chat.participants
        .map((participantId) => participantId.trim())
        .where((participantId) => participantId.isNotEmpty)
        .toSet();

    if (participantIds.length != 2 || !participantIds.contains(senderUserId)) {
      throw StateError('Du bist kein Teilnehmer dieses Chats.');
    }

    if (chat.status != ChatStatus.active &&
        chat.status != ChatStatus.archived) {
      throw StateError('Dieser Chat ist für neue Anhänge gesperrt.');
    }

    if (chat.isDeletedFor(senderUserId)) {
      throw StateError('Dieser Chat wurde für dich gelöscht.');
    }

    final messageExists = _messages.any(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (messageExists) {
      throw StateError('Diese Nachricht wurde bereits gesendet.');
    }

    return chat;
  }

  @override
  Future<ChatMessageRecord> addSystemMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw ArgumentError('System message text must not be empty.');
    }

    final now = DateTime.now();

    final message = ChatMessageRecord(
      id: 'local-message-${now.microsecondsSinceEpoch}',
      chatId: chatId,
      senderUserId: 'system',
      type: ChatMessageType.system,
      text: trimmedText,
      createdAt: now,
      updatedAt: now,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
    );

    _messages.add(message);
    _updateChatLastMessage(
      chatId: chatId,
      lastMessage: trimmedText,
      timestamp: now,
    );

    return message;
  }

  @override
  Future<ChatRecord> archiveChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _requireLocalChatActionParticipant(
      index: index,
      userId: trimmedUserId,
    );

    if (chat.isArchivedFor(trimmedUserId)) {
      return chat;
    }

    final archivedBy = Map<String, bool>.from(chat.archivedBy)
      ..[trimmedUserId] = true;

    final updated = chat.copyWith(
      archivedBy: archivedBy,
      updatedAt: DateTime.now(),
    );

    _chats[index] = updated;
    return updated;
  }

  @override
  Future<ChatRecord> unarchiveChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _requireLocalChatActionParticipant(
      index: index,
      userId: trimmedUserId,
    );

    if (!chat.isArchivedFor(trimmedUserId)) {
      return chat;
    }

    final archivedBy = Map<String, bool>.from(chat.archivedBy)
      ..[trimmedUserId] = false;

    final updated = chat.copyWith(
      archivedBy: archivedBy,
      updatedAt: DateTime.now(),
    );

    _chats[index] = updated;
    return updated;
  }

  @override
  Future<ChatRecord> deleteChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _requireLocalChatActionParticipant(
      index: index,
      userId: trimmedUserId,
      allowDeleted: true,
    );

    if (chat.isDeletedFor(trimmedUserId)) {
      return chat;
    }

    final deletedBy = Map<String, bool>.from(chat.deletedBy)
      ..[trimmedUserId] = true;

    final updated = chat.copyWith(
      deletedBy: deletedBy,
      updatedAt: DateTime.now(),
    );

    _chats[index] = updated;
    return updated;
  }

  @override
  Future<ChatRecord> unblockChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _requireLocalChatActionParticipant(
      index: index,
      userId: trimmedUserId,
      allowBlocked: true,
    );

    if (!chat.isBlockedBy(trimmedUserId)) {
      throw StateError(
        'Nur der Nutzer, der blockiert hat, kann die Blockierung aufheben.',
      );
    }

    final updated = chat.copyWith(
      status: ChatStatus.active,
      blockedBy: '',
      blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.now(),
    );

    _chats[index] = updated;
    return updated;
  }

  @override
  Future<void> setMessageStarred({
    required String chatId,
    required String messageId,
    required bool isStarred,
  }) async {
    final index = _messages.indexWhere(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (index < 0) {
      return;
    }

    _messages[index] = _messages[index].copyWith(
      isStarred: isStarred,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> setChatPinned({
    required String chatId,
    required String userId,
    required bool isPinned,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat-ID und Nutzer-ID dürfen nicht leer sein.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    final chat = _requireLocalChatActionParticipant(
      index: index,
      userId: trimmedUserId,
    );

    final pinnedBy = Map<String, bool>.from(chat.pinnedBy)
      ..[trimmedUserId] = isPinned;

    _chats[index] = chat.copyWith(pinnedBy: pinnedBy);
  }

  ChatRecord _requireLocalChatActionParticipant({
    required int index,
    required String userId,
    bool allowBlocked = false,
    bool allowDeleted = false,
  }) {
    final chat = _chats[index];
    final participantIds = chat.participants
        .map((participantId) => participantId.trim())
        .where((participantId) => participantId.isNotEmpty)
        .toSet();

    if (chat.participants.length != 2 ||
        participantIds.length != 2 ||
        !participantIds.contains(userId)) {
      throw StateError('Du bist kein Teilnehmer dieses Chats.');
    }

    if (!allowDeleted && chat.isDeletedFor(userId)) {
      throw StateError('Dieser Chat wurde für dich gelöscht.');
    }

    if (!allowBlocked && chat.status == ChatStatus.blocked) {
      throw StateError('Dieser Chat ist blockiert.');
    }

    return chat;
  }

  @override
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    final index = _messages.indexWhere(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (index < 0) {
      return;
    }

    final nextReactionBy = Map<String, String>.of(_messages[index].reactionBy);

    final trimmedReaction = _normalizedMessageReaction(reaction);

    if (trimmedReaction.isEmpty) {
      nextReactionBy.remove(userId);
    } else {
      nextReactionBy[userId] = trimmedReaction;
    }

    _messages[index] = _messages[index].copyWith(
      reactionBy: nextReactionBy,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> markViewOnceMediaOpened({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final trimmedUserId = userId.trim();
    final index = _messages.indexWhere(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Die Nutzer-ID fehlt.');
    }

    if (index < 0) {
      throw StateError('Die Mediennachricht wurde nicht gefunden.');
    }

    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);

    if (chatIndex < 0) {
      throw StateError('Der Chat wurde nicht gefunden.');
    }

    _requireLocalChatActionParticipant(index: chatIndex, userId: trimmedUserId);

    final message = _messages[index];

    if (!message.isViewOnce ||
        message.isDeleted ||
        (message.type != ChatMessageType.image &&
            message.type != ChatMessageType.video)) {
      throw StateError('Diese Nachricht ist kein Einmal-Medium.');
    }

    if (message.senderUserId == trimmedUserId) {
      throw StateError(
        'Eigene Einmal-Medien können nicht erneut geöffnet werden.',
      );
    }

    if (message.isViewOnceOpenedFor(trimmedUserId)) {
      return false;
    }

    final now = DateTime.now();
    _messages[index] = message.copyWith(
      viewOnceOpenedAtBy: <String, DateTime>{
        ...message.viewOnceOpenedAtBy,
        trimmedUserId: now,
      },
      updatedAt: now,
    );
    return true;
  }

  @override
  Future<void> deleteMessageForUser({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('Die Nutzer-ID fehlt.');
    }

    final index = _messages.indexWhere(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (index < 0) {
      throw StateError('Message not found: $messageId');
    }

    final deletedFor = Map<String, bool>.from(_messages[index].deletedFor)
      ..[trimmedUserId] = true;
    _messages[index] = _messages[index].copyWith(
      deletedFor: deletedFor,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final trimmedUserId = userId.trim();
    final index = _messages.indexWhere(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (index < 0) {
      throw StateError('Message not found: $messageId');
    }

    final message = _messages[index];

    if (trimmedUserId.isEmpty || message.senderUserId != trimmedUserId) {
      throw StateError('Du kannst diese Nachricht nur für dich löschen.');
    }

    if (!canDeleteChatMessageForEveryone(message)) {
      throw StateError(
        'Diese Nachricht kann nicht mehr für alle gelöscht werden.',
      );
    }

    _messages[index] = message.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
    );

    final latestMessages =
        _messages
            .where((message) => message.chatId == chatId && !message.isDeleted)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (latestMessages.isNotEmpty) {
      _updateChatLastMessage(
        chatId: chatId,
        lastMessage: latestMessages.first.text,
        timestamp: latestMessages.first.createdAt,
      );
    }
  }

  void _updateChatLastMessage({
    required String chatId,
    required String lastMessage,
    required DateTime timestamp,
    bool clearArchivedForParticipants = false,
    String? readByUserId,
  }) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);

    if (index < 0) {
      throw StateError('Chat not found: $chatId');
    }

    final archivedBy = clearArchivedForParticipants
        ? {
            for (final participantId in _chats[index].participants)
              if (participantId.trim().isNotEmpty) participantId: false,
          }
        : _chats[index].archivedBy;
    final lastReadAtBy = Map<String, DateTime>.from(_chats[index].lastReadAtBy);
    final trimmedReadByUserId = readByUserId?.trim() ?? '';

    if (trimmedReadByUserId.isNotEmpty) {
      lastReadAtBy[trimmedReadByUserId] = timestamp;
    }

    _chats[index] = _chats[index].copyWith(
      lastMessage: lastMessage,
      lastMessageAt: timestamp,
      archivedBy: archivedBy,
      lastReadAtBy: lastReadAtBy,
      updatedAt: timestamp,
    );
  }
}
