import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carma_firestore_paths.dart';
import '../../../shared/firebase/carma_firestore_schema.dart';

enum ChatStatus { active, archived, blocked, deleted }

enum ChatMessageType { text, image, system }

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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

    return 'Carma Nutzer';
  }

  String? profilePhotoUrlFor(String currentUserId) {
    final isSender = senderUserId == currentUserId;
    final candidate = isSender ? receiverPhotoUrl : senderPhotoUrl;
    final trimmed = candidate?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
    this.reactionBy = const <String, String>{},
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
  final Map<String, String> reactionBy;

  bool get isSystem {
    return type == ChatMessageType.system;
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
    Map<String, String>? reactionBy,
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
      reactionBy: reactionBy ?? this.reactionBy,
    );
  }
}

abstract class ChatRepository {
  Future<List<ChatRecord>> loadChats({required String userId});

  Stream<List<ChatRecord>> watchChats({required String userId});

  Stream<List<ChatRecord>> watchArchivedChats({required String userId});

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
    String? replyToMessageId,
    String? replyToText,
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

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
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
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chatsCollection {
    return _firestore.collection(CarmaFirestoreCollections.chats);
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

    if (uniqueParticipants.length < 2) {
      throw ArgumentError('A chat requires at least two participants.');
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
    final snapshot = await _messagesCollection(
      chatId,
    ).where('isDeleted', isEqualTo: false).get();

    final messages = snapshot.docs.map(_messageFromSnapshot).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  @override
  Stream<List<ChatMessageRecord>> watchMessages({required String chatId}) {
    return _messagesCollection(
      chatId,
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

  @override
  Future<ChatMessageRecord> sendTextMessage({
    required String chatId,
    required String senderUserId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw ArgumentError('Message text must not be empty.');
    }

    if (trimmedText.length > FirestoreDocumentDefaults.maxChatMessageLength) {
      throw ArgumentError('Message text is too long.');
    }

    final now = DateTime.now();
    final messageDocument = _messagesCollection(chatId).doc();

    await _firestore.runTransaction((transaction) async {
      final chatDocument = _chatsCollection.doc(chatId);

      transaction.set(messageDocument, {
        'chatId': chatId,
        'senderUserId': senderUserId,
        'type': FirestoreMessageTypes.text,
        'text': trimmedText,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isDeleted': false,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
      });

      transaction.set(chatDocument, {
        'lastMessage': trimmedText,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastReadAtBy': {senderUserId: Timestamp.fromDate(now)},
        'manualUnreadBy': {senderUserId: false},
        'manualUnreadUpdatedAtBy': {senderUserId: Timestamp.fromDate(now)},
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    });

    final snapshot = await messageDocument.get();
    return _messageFromSnapshot(snapshot);
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
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
      throw ArgumentError('Chat ID and blocker user ID must not be empty.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);

    await chatDocument.set({
      'status': ChatStatus.blocked.name,
      'blockedBy': trimmedUserId,
      'blockedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
      throw ArgumentError('Chat ID and reporter user ID must not be empty.');
    }

    await _firestore.collection(CarmaFirestoreCollections.reports).add({
      'type': 'chat',
      'chatId': trimmedChatId,
      'reporterUserId': trimmedReporterId,
      'reason': trimmedReason.isEmpty ? 'Chat gemeldet' : trimmedReason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);

    await chatDocument.update({
      'status': FirestoreChatStatus.active,
      FieldPath(['archivedBy', trimmedUserId]): true,
      FieldPath(['archivedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await chatDocument.get();
    return _chatFromSnapshot(snapshot);
  }

  @override
  Future<ChatRecord> unarchiveChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);

    await chatDocument.update({
      'status': FirestoreChatStatus.active,
      FieldPath(['archivedBy', trimmedUserId]): false,
      FieldPath(['archivedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await chatDocument.get();
    return _chatFromSnapshot(snapshot);
  }

  @override
  Future<ChatRecord> deleteChat({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final chatDocument = _chatsCollection.doc(trimmedChatId);

    await chatDocument.update({
      'status': FirestoreChatStatus.active,
      'isDeleted': false,
      FieldPath(['deletedBy', trimmedUserId]): true,
      FieldPath(['deletedUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await chatDocument.get();
    return _chatFromSnapshot(snapshot);
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedMessageId = messageId.trim();

    if (trimmedChatId.isEmpty || trimmedMessageId.isEmpty) {
      throw ArgumentError('Chat ID and message ID must not be empty.');
    }

    await _messagesCollection(trimmedChatId).doc(trimmedMessageId).set({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
    final trimmedReaction = reaction.trim();

    if (trimmedChatId.isEmpty ||
        trimmedMessageId.isEmpty ||
        trimmedUserId.isEmpty) {
      throw ArgumentError('Chat ID, message ID and user ID must not be empty.');
    }

    await _messagesCollection(trimmedChatId).doc(trimmedMessageId).update({
      FieldPath(['reactionBy', trimmedUserId]): trimmedReaction,
      FieldPath(['reactionUpdatedAtBy', trimmedUserId]):
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _messagesCollection(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection(CarmaFirestoreCollections.messages);
  }

  ChatRecord _chatFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return ChatRecord(
      id: snapshot.id,
      participants: _stringListFromValue(data['participants']),
      status: _chatStatusFromName(data['status'] as String?),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime(1970),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime(1970),
      requestId: data['requestId'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: _dateTimeFromValue(data['lastMessageAt']),
      senderUserId: data['senderUserId'] as String?,
      receiverUserId: data['receiverUserId'] as String?,
      senderDisplayName: data['senderDisplayName'] as String?,
      receiverDisplayName: data['receiverDisplayName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      receiverPhotoUrl: data['receiverPhotoUrl'] as String?,
      displayPlate: data['displayPlate'] as String?,
      vehicleBrand: data['vehicleBrand'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      vehicleLabel: data['vehicleLabel'] as String?,
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
      reactionBy: _stringMapFromValue(data['reactionBy']),
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

  static Map<String, bool> _boolMapFromValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue == true),
      );
    }

    return const <String, bool>{};
  }

  static Map<String, String> _stringMapFromValue(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }

    final result = <String, String>{};

    for (final entry in value.entries) {
      final key = entry.key?.toString() ?? '';
      final mapValue = entry.value?.toString() ?? '';

      if (key.isNotEmpty && mapValue.isNotEmpty) {
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
    String? displayPlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleLabel,
  }) async {
    final now = DateTime.now();
    final uniqueParticipants = participants.toSet().toList()..sort();

    final chat = ChatRecord(
      id: 'local-chat-${now.microsecondsSinceEpoch}',
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
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw ArgumentError('Message text must not be empty.');
    }

    final now = DateTime.now();

    final message = ChatMessageRecord(
      id: 'local-message-${now.microsecondsSinceEpoch}',
      chatId: chatId,
      senderUserId: senderUserId,
      type: ChatMessageType.text,
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Chat not found: $trimmedChatId');
    }

    final archivedBy = Map<String, bool>.from(_chats[index].archivedBy)
      ..[trimmedUserId] = true;

    final updated = _chats[index].copyWith(
      status: ChatStatus.active,
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Chat not found: $trimmedChatId');
    }

    final archivedBy = Map<String, bool>.from(_chats[index].archivedBy)
      ..[trimmedUserId] = false;

    final updated = _chats[index].copyWith(
      status: ChatStatus.active,
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Chat not found: $trimmedChatId');
    }

    final deletedBy = Map<String, bool>.from(_chats[index].deletedBy)
      ..[trimmedUserId] = true;

    final updated = _chats[index].copyWith(
      status: ChatStatus.active,
      deletedBy: deletedBy,
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
      throw ArgumentError('Chat ID and user ID must not be empty.');
    }

    final index = _chats.indexWhere((chat) => chat.id == trimmedChatId);

    if (index < 0) {
      throw StateError('Chat not found: $trimmedChatId');
    }

    final pinnedBy = Map<String, bool>.from(_chats[index].pinnedBy)
      ..[trimmedUserId] = isPinned;

    _chats[index] = _chats[index].copyWith(pinnedBy: pinnedBy);
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

    if (reaction.trim().isEmpty) {
      nextReactionBy.remove(userId);
    } else {
      nextReactionBy[userId] = reaction.trim();
    }

    _messages[index] = _messages[index].copyWith(
      reactionBy: nextReactionBy,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final index = _messages.indexWhere(
      (message) => message.chatId == chatId && message.id == messageId,
    );

    if (index < 0) {
      throw StateError('Message not found: $messageId');
    }

    _messages[index] = _messages[index].copyWith(isDeleted: true);

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
  }) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);

    if (index < 0) {
      throw StateError('Chat not found: $chatId');
    }

    _chats[index] = _chats[index].copyWith(
      lastMessage: lastMessage,
      lastMessageAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
