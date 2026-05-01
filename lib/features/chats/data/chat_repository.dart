enum ChatStatus {
  active,
  archived,
  blocked,
  deleted,
}

enum ChatMessageType {
  text,
  image,
  system,
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
  });

  final String id;
  final List<String> participants;
  final ChatStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? requestId;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  bool get isActive {
    return status == ChatStatus.active;
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
  });

  final String id;
  final String chatId;
  final String senderUserId;
  final ChatMessageType type;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

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
    );
  }
}

abstract class ChatRepository {
  Future<List<ChatRecord>> loadChats({
    required String userId,
  });

  Future<ChatRecord> createChat({
    required List<String> participants,
    String? requestId,
    String? systemMessage,
  });

  Future<List<ChatMessageRecord>> loadMessages({
    required String chatId,
  });

  Future<ChatMessageRecord> sendTextMessage({
    required String chatId,
    required String senderUserId,
    required String text,
  });

  Future<ChatMessageRecord> addSystemMessage({
    required String chatId,
    required String text,
  });

  Future<ChatRecord> archiveChat({
    required String chatId,
  });
}

class LocalChatRepository implements ChatRepository {
  LocalChatRepository({
    List<ChatRecord> seedChats = const [],
    List<ChatMessageRecord> seedMessages = const [],
  })  : _chats = [...seedChats],
        _messages = [...seedMessages];

  final List<ChatRecord> _chats;
  final List<ChatMessageRecord> _messages;

  @override
  Future<List<ChatRecord>> loadChats({
    required String userId,
  }) async {
    return _chats
        .where(
          (chat) =>
      chat.participants.contains(userId) &&
          chat.status == ChatStatus.active,
    )
        .toList();
  }

  @override
  Future<ChatRecord> createChat({
    required List<String> participants,
    String? requestId,
    String? systemMessage,
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
  Future<List<ChatMessageRecord>> loadMessages({
    required String chatId,
  }) async {
    return _messages
        .where(
          (message) => message.chatId == chatId && !message.isDeleted,
    )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<ChatMessageRecord> sendTextMessage({
    required String chatId,
    required String senderUserId,
    required String text,
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
  }) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);

    if (index < 0) {
      throw StateError('Chat not found: $chatId');
    }

    final updated = _chats[index].copyWith(
      status: ChatStatus.archived,
      updatedAt: DateTime.now(),
    );

    _chats[index] = updated;
    return updated;
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