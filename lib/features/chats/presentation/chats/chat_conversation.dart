part of '../chats_screen.dart';

class _ChatConversationScreen extends StatefulWidget {
  const _ChatConversationScreen({
    required this.initialMessages,
    this.chatId,
    this.displayName = 'CaRisma Nutzer',
    this.profilePhotoUrl,
    this.vehicleModel = 'BMW 1er',
    this.vehicleColor = 'Schwarz',
    this.displayPlate,
    this.profileUserId,
    this.isOnline = false,
  });

  final List<_LocalChatMessage> initialMessages;
  final String? chatId;
  final String displayName;
  final String? profilePhotoUrl;
  final String vehicleModel;
  final String vehicleColor;
  final String? displayPlate;
  final String? profileUserId;
  final bool isOnline;

  @override
  State<_ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<_ChatConversationScreen> {
  static const int _maxDocumentSizeBytes = 25 * 1024 * 1024;
  static const int _maxVoiceMemoDurationMs = 10 * 60 * 1000;
  static const Set<String> _allowedDocumentContentTypes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/rtf',
  };

  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final ChatAttachmentStorage _attachmentStorage = ChatAttachmentStorage();
  final ChatNativeBridge _nativeBridge = ChatNativeBridge();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messageScrollController = ScrollController();
  final GlobalKey _messageListEndKey = GlobalKey();

  late List<_LocalChatMessage> _messages;
  bool _hasText = false;
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  bool _isRecordingVoiceMemo = false;
  bool _isChatStatusLoading = false;
  bool _isOtherUserTyping = false;
  bool _isCurrentUserTyping = false;
  bool _forceScrollToBottomOnNextMessages = false;
  int _voiceMemoRecordingSeconds = 0;
  int _messageScrollRequestGeneration = 0;
  _LocalChatMessage? _replyingToMessage;
  String? _playingAudioMessageKey;
  DateTime? _lastTypingWriteAt;
  DateTime? _lastMarkedReadMessageAt;
  DateTime? _pendingMarkReadMessageAt;
  DateTime? _otherLastReadAt;
  DateTime? _otherLastActiveAt;
  DateTime? _keepLatestMessageVisibleUntil;
  DateTime? _suppressMessageAutoScrollUntil;
  DateTime? _outgoingReadReceiptGuardStartedAt;
  DateTime? _outgoingReadReceiptBaselineAt;
  ChatRecord? _currentChatRecord;
  String? _chatStatusErrorMessage;
  double _lastKeyboardInset = 0;
  Timer? _typingStopTimer;
  Timer? _voiceMemoRecordingTimer;
  Timer? _audioPlaybackStopTimer;
  Timer? _presenceTimer;
  bool _isMarkingChatRead = false;
  StreamSubscription<bool>? _typingSubscription;
  StreamSubscription<DateTime?>? _readReceiptSubscription;
  StreamSubscription<DateTime?>? _presenceSubscription;
  StreamSubscription<List<ChatMessageRecord>>? _messagesSubscription;
  StreamSubscription<ChatRecord?>? _chatStatusSubscription;

  static const Duration _onlineStatusWindow = Duration(seconds: 90);

  bool get _hasFirestoreChat {
    final chatId = widget.chatId?.trim();
    return chatId != null && chatId.isNotEmpty;
  }

  String? get _chatSendDisabledMessage {
    final chatId = widget.chatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      return null;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (currentUserId.isEmpty) {
      return 'Bitte melde dich an.';
    }

    final statusErrorMessage = _chatStatusErrorMessage;

    if (statusErrorMessage != null) {
      return statusErrorMessage;
    }

    final chat = _currentChatRecord;

    if (chat == null) {
      return _isChatStatusLoading
          ? 'Chat wird geprüft...'
          : 'Dieser Chat wurde nicht gefunden.';
    }

    final participantIds = chat.participants
        .map((participant) => participant.trim())
        .where((participant) => participant.isNotEmpty)
        .toSet();

    if (!participantIds.contains(currentUserId)) {
      return 'Du bist kein Teilnehmer dieses Chats.';
    }

    if (chat.status == ChatStatus.deleted || chat.isDeletedFor(currentUserId)) {
      return 'Dieser Chat wurde gelöscht.';
    }

    if (chat.status == ChatStatus.blocked) {
      return 'Dieser Chat ist blockiert.';
    }

    if (chat.status != ChatStatus.active &&
        chat.status != ChatStatus.archived) {
      return 'Dieser Chat ist nicht mehr aktiv.';
    }

    return null;
  }

  bool get _isChatComposerEnabled {
    return _chatSendDisabledMessage == null;
  }

  @override
  void initState() {
    super.initState();
    _messages = [...widget.initialMessages];
    _messageController.addListener(_handleMessageChanged);
    _messageFocusNode.addListener(_handleMessageFocusChanged);
    _scheduleScrollToBottom(animated: false);

    if (_hasFirestoreChat) {
      _watchCurrentChatStatus();
      _markChatRead();
      _watchMessages();
      _watchTypingStatus();
      _watchReadReceipts();
      _startPresenceTracking();
    }
  }

  @override
  void dispose() {
    if (_isRecordingVoiceMemo) {
      unawaited(_nativeBridge.cancelVoiceMemo());
    }
    unawaited(_nativeBridge.stopVoiceMemoPlayback());
    _typingStopTimer?.cancel();
    _voiceMemoRecordingTimer?.cancel();
    _audioPlaybackStopTimer?.cancel();
    _presenceTimer?.cancel();
    _typingSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _presenceSubscription?.cancel();
    _messagesSubscription?.cancel();
    _chatStatusSubscription?.cancel();
    _messageController.removeListener(_handleMessageChanged);
    _messageFocusNode.removeListener(_handleMessageFocusChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  bool get _isNearMessageBottom {
    if (!_messageScrollController.hasClients) {
      return true;
    }

    final position = _messageScrollController.position;
    return position.pixels - position.minScrollExtent <= 180;
  }

  bool get _shouldKeepLatestMessageVisible {
    final keepVisibleUntil = _keepLatestMessageVisibleUntil;
    return keepVisibleUntil != null && keepVisibleUntil.isAfter(DateTime.now());
  }

  bool get _isMessageAutoScrollSuppressed {
    final suppressUntil = _suppressMessageAutoScrollUntil;
    return suppressUntil != null && suppressUntil.isAfter(DateTime.now());
  }

  bool get _isOtherUserOnline {
    if (widget.isOnline) {
      return true;
    }

    final activeAt = _otherLastActiveAt;

    if (activeAt == null) {
      return false;
    }

    return DateTime.now().difference(activeAt) <= _onlineStatusWindow;
  }

  Future<String> _requireSendableCurrentChat({
    required String unauthenticatedMessage,
  }) async {
    final chatId = widget.chatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      return '';
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid.trim() ?? '';

    if (currentUserId.isEmpty) {
      throw StateError(unauthenticatedMessage);
    }

    final chat = await _chatRepository.loadChat(chatId: chatId);

    if (chat == null) {
      throw StateError('Dieser Chat wurde nicht gefunden.');
    }

    final participantIds = chat.participants
        .map((participant) => participant.trim())
        .where((participant) => participant.isNotEmpty)
        .toSet();

    if (!participantIds.contains(currentUserId)) {
      throw StateError('Du bist kein Teilnehmer dieses Chats.');
    }

    if (chat.status == ChatStatus.deleted || chat.isDeletedFor(currentUserId)) {
      throw StateError('Dieser Chat wurde gelöscht.');
    }

    if (chat.status == ChatStatus.blocked) {
      throw StateError('Dieser Chat ist blockiert.');
    }

    if (chat.status != ChatStatus.active &&
        chat.status != ChatStatus.archived) {
      throw StateError('Dieser Chat ist nicht mehr aktiv.');
    }

    return currentUserId;
  }

  String _friendlyChatErrorMessage(Object error) {
    return _friendlyChatUiError(error);
  }

  void _watchCurrentChatStatus() {
    final chatId = widget.chatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      return;
    }

    _isChatStatusLoading = true;
    _chatStatusSubscription?.cancel();
    _chatStatusSubscription = _chatRepository
        .watchChat(chatId: chatId)
        .listen(
          (chat) {
            if (!mounted) {
              return;
            }

            setState(() {
              _currentChatRecord = chat;
              _isChatStatusLoading = false;
              _chatStatusErrorMessage = null;
            });
            _stopComposerSideEffectsIfChatUnavailable();
            _cancelVoiceMemoIfChatBecameUnavailable();
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }

            setState(() {
              _currentChatRecord = null;
              _isChatStatusLoading = false;
              _chatStatusErrorMessage =
                  'Chatstatus konnte nicht geladen werden.';
            });
            _stopComposerSideEffectsIfChatUnavailable();
            _cancelVoiceMemoIfChatBecameUnavailable();
          },
        );
  }

  void _stopComposerSideEffectsIfChatUnavailable() {
    if (_isChatComposerEnabled) {
      return;
    }

    _typingStopTimer?.cancel();
    unawaited(_setCurrentUserTyping(false, force: true));
    _messageFocusNode.unfocus();

    if (!mounted || _replyingToMessage == null) {
      return;
    }

    setState(() {
      _replyingToMessage = null;
    });
  }

  void _cancelVoiceMemoIfChatBecameUnavailable() {
    if (!_isRecordingVoiceMemo || _isChatComposerEnabled) {
      return;
    }

    _voiceMemoRecordingTimer?.cancel();
    _typingStopTimer?.cancel();
    unawaited(_nativeBridge.cancelVoiceMemo());
    unawaited(_setCurrentUserTyping(false, force: true));

    if (!mounted) {
      return;
    }

    _messageFocusNode.unfocus();
    setState(() {
      _isRecordingVoiceMemo = false;
      _voiceMemoRecordingSeconds = 0;
      _replyingToMessage = null;
    });
  }

  void _showChatUnavailableMessage() {
    final message = _chatSendDisabledMessage;

    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottomNow({bool animated = true, bool force = false}) {
    if (!mounted) {
      return;
    }

    if (!force && _isMessageAutoScrollSuppressed) {
      return;
    }

    if (!_messageScrollController.hasClients) {
      final endContext = _messageListEndKey.currentContext;
      if (endContext != null) {
        Scrollable.ensureVisible(
          endContext,
          duration: animated
              ? const Duration(milliseconds: 260)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 1,
        );
      }
      return;
    }

    final target = _messageScrollController.position.minScrollExtent;

    if ((_messageScrollController.position.pixels - target).abs() < 1) {
      return;
    }

    if (animated) {
      _messageScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _messageScrollController.jumpTo(target);
    }
  }

  void _scheduleScrollToBottom({bool animated = true, bool force = false}) {
    if (force) {
      _suppressMessageAutoScrollUntil = null;
    }

    _messageScrollRequestGeneration += 1;
    final requestGeneration = _messageScrollRequestGeneration;
    _keepLatestMessageVisibleUntil = DateTime.now().add(
      const Duration(milliseconds: 420),
    );

    void schedule(Duration delay, {bool forceRequest = false}) {
      Future<void>.delayed(delay, () {
        if (requestGeneration != _messageScrollRequestGeneration) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (requestGeneration != _messageScrollRequestGeneration) {
            return;
          }

          _scrollToBottomNow(animated: animated, force: force || forceRequest);
        });
      });
    }

    schedule(Duration.zero, forceRequest: force);
    schedule(const Duration(milliseconds: 80));
    schedule(const Duration(milliseconds: 220));
    schedule(const Duration(milliseconds: 520));
    schedule(const Duration(milliseconds: 820), forceRequest: force);
  }

  void _scheduleScrollToBottomAfterKeyboard() {
    _scheduleScrollToBottom(force: true);
  }

  bool _handleMessageListSizeChanged(SizeChangedLayoutNotification _) {
    if ((_shouldKeepLatestMessageVisible || _isNearMessageBottom) &&
        !_isMessageAutoScrollSuppressed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomNow(animated: false);
      });
    }

    return false;
  }

  bool _handleMessageScrollNotification(ScrollNotification notification) {
    final isUserDragging =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null;
    final isUserOverscrolling =
        notification is OverscrollNotification &&
        notification.dragDetails != null;
    if (isUserDragging || isUserOverscrolling) {
      _suppressMessageAutoScroll();
    }

    return false;
  }

  void _suppressMessageAutoScroll() {
    _messageScrollRequestGeneration += 1;
    _suppressMessageAutoScrollUntil = DateTime.now().add(
      const Duration(milliseconds: 1500),
    );
    _keepLatestMessageVisibleUntil = null;
  }

  Future<void> _markChatRead({DateTime? latestIncomingMessageAt}) async {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chatId == null || chatId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    final lastMarkedReadMessageAt = _lastMarkedReadMessageAt;
    if (latestIncomingMessageAt != null &&
        lastMarkedReadMessageAt != null &&
        !latestIncomingMessageAt.isAfter(lastMarkedReadMessageAt)) {
      return;
    }

    if (_isMarkingChatRead) {
      if (latestIncomingMessageAt != null &&
          (_pendingMarkReadMessageAt == null ||
              latestIncomingMessageAt.isAfter(_pendingMarkReadMessageAt!))) {
        _pendingMarkReadMessageAt = latestIncomingMessageAt;
      }
      return;
    }

    _isMarkingChatRead = true;

    try {
      await _chatRepository.markChatRead(chatId: chatId, userId: currentUserId);

      if (latestIncomingMessageAt != null) {
        _lastMarkedReadMessageAt = latestIncomingMessageAt;
      }
    } catch (_) {
      // Read receipts are non-critical UI state.
    } finally {
      _isMarkingChatRead = false;

      final pendingMarkReadMessageAt = _pendingMarkReadMessageAt;
      _pendingMarkReadMessageAt = null;

      if (mounted && pendingMarkReadMessageAt != null) {
        unawaited(
          _markChatRead(latestIncomingMessageAt: pendingMarkReadMessageAt),
        );
      }
    }
  }

  void _handleReplyMessage(_LocalChatMessage message) {
    if (!_isChatComposerEnabled) {
      _showChatUnavailableMessage();
      return;
    }

    setState(() {
      _replyingToMessage = message;
    });
    _messageFocusNode.requestFocus();
    _scheduleScrollToBottomAfterKeyboard();
  }

  void _clearReplyMessage() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _handleMessageChanged() {
    final nextHasText = _messageController.text.trim().isNotEmpty;

    _handleTypingChanged(nextHasText);

    if (_hasText == nextHasText) {
      return;
    }

    setState(() {
      _hasText = nextHasText;
    });
  }

  void _handleMessageFocusChanged() {
    if (_messageFocusNode.hasFocus) {
      _scheduleScrollToBottomAfterKeyboard();
    }
  }

  void _watchTypingStatus() {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chatId == null || chatId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    _typingSubscription?.cancel();
    _typingSubscription = _chatRepository
        .watchOtherTypingStatus(chatId: chatId, currentUserId: currentUserId)
        .listen((isTyping) {
          if (!mounted || _isOtherUserTyping == isTyping) {
            return;
          }

          setState(() {
            _isOtherUserTyping = isTyping;
          });
        });
  }

  void _startPresenceTracking() {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chatId == null || chatId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    unawaited(_updatePresence());

    _presenceSubscription?.cancel();
    _presenceSubscription = _chatRepository
        .watchOtherLastActiveAt(chatId: chatId, currentUserId: currentUserId)
        .listen((activeAt) {
          if (!mounted) {
            return;
          }

          setState(() {
            _otherLastActiveAt = activeAt;
          });
        });

    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_updatePresence());

      if (!mounted) {
        return;
      }

      setState(() {});
    });
  }

  Future<void> _updatePresence() async {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chatId == null || chatId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    try {
      await _chatRepository.updateChatPresence(
        chatId: chatId,
        userId: currentUserId,
      );
    } catch (_) {
      // Presence should never block chat usage.
    }
  }

  void _watchReadReceipts() {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chatId == null || chatId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    _readReceiptSubscription?.cancel();
    _readReceiptSubscription = _chatRepository
        .watchOtherLastReadAt(chatId: chatId, currentUserId: currentUserId)
        .listen(_applyOtherLastReadAt);
  }

  void _applyOtherLastReadAt(DateTime? otherLastReadAt) {
    if (!mounted || otherLastReadAt == null) {
      return;
    }

    _otherLastReadAt = otherLastReadAt;
    var changed = false;

    final nextMessages = _messages.map((message) {
      if (!message.isMine || message.isReadByOther) {
        return message;
      }

      if (!_isReadByOther(message, otherLastReadAt)) {
        return message;
      }

      changed = true;

      return message.copyWith(isReadByOther: true);
    }).toList();

    if (!changed) {
      return;
    }

    setState(() {
      _messages = nextMessages;
    });
  }

  bool _isReadByOther(_LocalChatMessage message, DateTime? otherLastReadAt) {
    return _isMineMessageReadByOther(
      isMine: message.isMine,
      createdAt: message.createdAt,
      otherLastReadAt: otherLastReadAt,
    );
  }

  bool _isMineMessageReadByOther({
    required bool isMine,
    required DateTime? createdAt,
    required DateTime? otherLastReadAt,
  }) {
    if (!isMine || createdAt == null || otherLastReadAt == null) {
      return false;
    }

    final guardStartedAt = _outgoingReadReceiptGuardStartedAt;
    final baselineAt = _outgoingReadReceiptBaselineAt;

    if (guardStartedAt != null && !createdAt.isBefore(guardStartedAt)) {
      if (baselineAt != null && !otherLastReadAt.isAfter(baselineAt)) {
        return false;
      }

      if (baselineAt == null && otherLastReadAt.isBefore(guardStartedAt)) {
        return false;
      }
    }

    return !createdAt.isAfter(otherLastReadAt);
  }

  void _rememberOutgoingReadReceiptBaseline() {
    final currentBaselineAt = _otherLastReadAt;
    final existingBaselineAt = _outgoingReadReceiptBaselineAt;
    final hasNoGuard = _outgoingReadReceiptGuardStartedAt == null;
    final hasAdvancedBaseline =
        currentBaselineAt != null &&
        (existingBaselineAt == null ||
            currentBaselineAt.isAfter(existingBaselineAt));

    if (!hasNoGuard && !hasAdvancedBaseline) {
      return;
    }

    _outgoingReadReceiptGuardStartedAt = DateTime.now().subtract(
      const Duration(milliseconds: 50),
    );
    _outgoingReadReceiptBaselineAt = currentBaselineAt;
  }

  void _handleTypingChanged(bool hasText) {
    if (!_hasFirestoreChat) {
      return;
    }

    _typingStopTimer?.cancel();

    if (!_isChatComposerEnabled) {
      unawaited(_setCurrentUserTyping(false, force: true));
      return;
    }

    if (!hasText) {
      _setCurrentUserTyping(false);
      return;
    }

    final now = DateTime.now();
    final shouldWriteTyping =
        !_isCurrentUserTyping ||
        _lastTypingWriteAt == null ||
        now.difference(_lastTypingWriteAt!).inSeconds >= 2;

    if (shouldWriteTyping) {
      _setCurrentUserTyping(true);
    }

    _typingStopTimer = Timer(const Duration(seconds: 4), () {
      _setCurrentUserTyping(false);
    });
  }

  Future<void> _setCurrentUserTyping(
    bool isTyping, {
    bool force = false,
  }) async {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (chatId == null ||
        chatId.isEmpty ||
        currentUserId == null ||
        currentUserId.isEmpty) {
      return;
    }

    if (!force && isTyping && !_isChatComposerEnabled) {
      return;
    }

    if (_isCurrentUserTyping == isTyping && !isTyping) {
      return;
    }

    _isCurrentUserTyping = isTyping;
    _lastTypingWriteAt = DateTime.now();

    try {
      await _chatRepository.setTypingStatus(
        chatId: chatId,
        userId: currentUserId,
        isTyping: isTyping,
      );
    } catch (_) {
      // Typing ist nur ein Komfortsignal und darf den Chat nicht blockieren.
    }
  }

  void _watchMessages() {
    final chatId = widget.chatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMessages = true;
    });

    _messagesSubscription?.cancel();

    _messagesSubscription = _chatRepository
        .watchMessages(chatId: chatId)
        .listen(
          (records) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
            final otherLastReadAt = _otherLastReadAt;
            final previousMessageCount = _messages.length;
            final shouldKeepBottom = _isNearMessageBottom;
            final lastRecordIsMine =
                records.isNotEmpty &&
                records.last.senderUserId == currentUserId;
            final shouldScrollToBottom =
                _forceScrollToBottomOnNextMessages ||
                (records.length > previousMessageCount &&
                    (shouldKeepBottom || lastRecordIsMine));
            DateTime? latestIncomingMessageAt;

            for (final record in records) {
              if (record.senderUserId == currentUserId) {
                continue;
              }

              if (latestIncomingMessageAt == null ||
                  record.createdAt.isAfter(latestIncomingMessageAt)) {
                latestIncomingMessageAt = record.createdAt;
              }
            }

            if (!mounted) {
              return;
            }

            setState(() {
              _messages = records.map((record) {
                final isMine = record.senderUserId == currentUserId;

                return _LocalChatMessage(
                  text: record.text,
                  isMine: isMine,
                  timeLabel: _timeLabel(record.createdAt),
                  createdAt: record.createdAt,
                  messageId: record.id,
                  type: record.type,
                  imageUrl: record.imageUrl,
                  imagePath: record.imagePath,
                  fileUrl: record.fileUrl,
                  filePath: record.filePath,
                  fileName: record.fileName,
                  fileContentType: record.fileContentType,
                  fileSizeBytes: record.fileSizeBytes,
                  fileDurationMs: record.fileDurationMs,
                  isReadByOther: _isMineMessageReadByOther(
                    isMine: isMine,
                    createdAt: record.createdAt,
                    otherLastReadAt: otherLastReadAt,
                  ),
                  replyToText: record.replyToText,
                  isStarred: record.isStarred,
                  reactionBy: record.reactionBy,
                );
              }).toList();

              _isLoadingMessages = false;
            });

            if (shouldScrollToBottom) {
              _forceScrollToBottomOnNextMessages = false;
              _scheduleScrollToBottom(force: true);
            }

            if (latestIncomingMessageAt != null) {
              unawaited(
                _markChatRead(latestIncomingMessageAt: latestIncomingMessageAt),
              );
            }
          },
          onError: (error) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoadingMessages = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Nachrichten konnten nicht geladen werden: $error',
                ),
              ),
            );
          },
        );
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _handlePickImage(ImageSource source) async {
    if (_isSendingMessage) {
      return;
    }

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );

      if (pickedImage == null) {
        return;
      }

      await _sendImageAttachment(File(pickedImage.path));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto konnte nicht ausgewählt werden: $error')),
      );
    }
  }

  Future<void> _sendImageAttachment(File imageFile) async {
    if (_isSendingMessage) {
      return;
    }

    String? uploadedPath;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final chatId = widget.chatId?.trim();

      if (chatId == null || chatId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = [
            ..._messages,
            _LocalChatMessage(
              text: 'Foto',
              isMine: true,
              timeLabel: 'Jetzt',
              createdAt: DateTime.now(),
              type: ChatMessageType.image,
              imageUrl: imageFile.path,
              imagePath: imageFile.path,
              isReadByOther: false,
            ),
          ];
          _isSendingMessage = false;
        });
        _scheduleScrollToBottom(force: true);
        return;
      }

      final currentUserId = await _requireSendableCurrentChat(
        unauthenticatedMessage: 'Du musst angemeldet sein, um Fotos zu senden.',
      );

      final messageId = _chatRepository.createMessageId(chatId: chatId);
      final upload = await _attachmentStorage.uploadChatImage(
        chatId: chatId,
        userId: currentUserId,
        messageId: messageId,
        file: imageFile,
      );
      uploadedPath = upload.path;

      _forceScrollToBottomOnNextMessages = true;
      _rememberOutgoingReadReceiptBaseline();

      await _chatRepository.sendImageMessage(
        chatId: chatId,
        messageId: messageId,
        senderUserId: currentUserId,
        imageUrl: upload.url,
        imagePath: upload.path,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _scheduleScrollToBottom(force: true);
    } catch (error) {
      final cleanupError = await _cleanupFailedChatAttachment(uploadedPath);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _chatAttachmentSendErrorMessage(
              'Foto konnte nicht gesendet werden',
              error,
              cleanupError: cleanupError,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handlePickDocument() async {
    if (_isSendingMessage) {
      return;
    }

    try {
      final document = await _nativeBridge.pickDocumentFile();

      if (document == null) {
        return;
      }

      final validationError = _validatePickedDocument(document);

      if (validationError != null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }

      await _sendDocumentAttachment(document);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dokument konnte nicht ausgewählt werden: $error'),
        ),
      );
    }
  }

  String? _validatePickedDocument(PickedDocumentFile document) {
    final fileName = document.name.trim();
    final contentType = document.contentType.trim().toLowerCase();

    if (fileName.isEmpty) {
      return 'Dokument konnte nicht gelesen werden.';
    }

    if (fileName.length > 160) {
      return 'Der Dateiname ist zu lang.';
    }

    if (document.sizeBytes <= 0) {
      return 'Das Dokument ist leer.';
    }

    if (document.sizeBytes > _maxDocumentSizeBytes) {
      return 'Dokumente dürfen maximal 25 MB groß sein.';
    }

    if (!_isAllowedDocumentContentType(contentType)) {
      return 'Dieser Dateityp wird nicht unterstützt.';
    }

    return null;
  }

  bool _isAllowedDocumentContentType(String contentType) {
    return contentType.startsWith('text/') ||
        _allowedDocumentContentTypes.contains(contentType);
  }

  Future<void> _sendDocumentAttachment(PickedDocumentFile document) async {
    if (_isSendingMessage) {
      return;
    }

    String? uploadedPath;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final chatId = widget.chatId?.trim();
      final documentFile = File(document.path);

      if (chatId == null || chatId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = [
            ..._messages,
            _LocalChatMessage(
              text: 'Dokument: ${document.name}',
              isMine: true,
              timeLabel: 'Jetzt',
              createdAt: DateTime.now(),
              type: ChatMessageType.document,
              fileUrl: document.path,
              filePath: document.path,
              fileName: document.name,
              fileContentType: document.contentType,
              fileSizeBytes: document.sizeBytes,
              isReadByOther: false,
            ),
          ];
          _isSendingMessage = false;
        });
        _scheduleScrollToBottom(force: true);
        return;
      }

      final currentUserId = await _requireSendableCurrentChat(
        unauthenticatedMessage:
            'Du musst angemeldet sein, um Dokumente zu senden.',
      );

      final messageId = _chatRepository.createMessageId(chatId: chatId);
      final upload = await _attachmentStorage.uploadChatDocument(
        chatId: chatId,
        userId: currentUserId,
        messageId: messageId,
        file: documentFile,
        fileName: document.name,
        contentType: document.contentType,
      );
      uploadedPath = upload.path;

      _forceScrollToBottomOnNextMessages = true;
      _rememberOutgoingReadReceiptBaseline();

      await _chatRepository.sendDocumentMessage(
        chatId: chatId,
        messageId: messageId,
        senderUserId: currentUserId,
        fileUrl: upload.url,
        filePath: upload.path,
        fileName: upload.fileName,
        fileContentType: upload.contentType,
        fileSizeBytes: upload.fileSizeBytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _scheduleScrollToBottom(force: true);
    } catch (error) {
      final cleanupError = await _cleanupFailedChatAttachment(uploadedPath);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _chatAttachmentSendErrorMessage(
              'Dokument konnte nicht gesendet werden',
              error,
              cleanupError: cleanupError,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handleVoiceMemo() async {
    if (_isSendingMessage) {
      return;
    }

    if (!_isRecordingVoiceMemo) {
      try {
        await _requireSendableCurrentChat(
          unauthenticatedMessage:
              'Du musst angemeldet sein, um Sprachmemos aufzunehmen.',
        );

        await _nativeBridge.startVoiceMemo();

        if (!mounted) {
          return;
        }

        setState(() {
          _isRecordingVoiceMemo = true;
          _voiceMemoRecordingSeconds = 0;
        });
        _startVoiceMemoRecordingTimer();
      } catch (error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sprachmemo konnte nicht starten: ${_friendlyChatErrorMessage(error)}',
            ),
          ),
        );
      }

      return;
    }

    try {
      final voiceMemo = await _nativeBridge.stopVoiceMemo();

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingVoiceMemo = false;
        _voiceMemoRecordingSeconds = 0;
      });
      _voiceMemoRecordingTimer?.cancel();

      await _sendVoiceMemoAttachment(voiceMemo);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingVoiceMemo = false;
        _voiceMemoRecordingSeconds = 0;
      });
      _voiceMemoRecordingTimer?.cancel();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sprachmemo konnte nicht gesendet werden: ${_friendlyChatErrorMessage(error)}',
          ),
        ),
      );
    }
  }

  void _startVoiceMemoRecordingTimer() {
    _voiceMemoRecordingTimer?.cancel();
    _voiceMemoRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecordingVoiceMemo) {
        return;
      }

      setState(() {
        _voiceMemoRecordingSeconds += 1;
      });
    });
  }

  Future<void> _sendVoiceMemoAttachment(PickedVoiceMemoFile voiceMemo) async {
    if (_isSendingMessage) {
      return;
    }

    if (voiceMemo.durationMs < 0 ||
        voiceMemo.durationMs > _maxVoiceMemoDurationMs) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sprachmemos dürfen maximal 10 Minuten lang sein.'),
        ),
      );
      return;
    }

    String? uploadedPath;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final chatId = widget.chatId?.trim();
      final voiceMemoFile = File(voiceMemo.path);

      if (chatId == null || chatId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = [
            ..._messages,
            _LocalChatMessage(
              text: 'Sprachnachricht',
              isMine: true,
              timeLabel: 'Jetzt',
              createdAt: DateTime.now(),
              type: ChatMessageType.audio,
              fileUrl: voiceMemo.path,
              filePath: voiceMemo.path,
              fileName: voiceMemo.name,
              fileContentType: voiceMemo.contentType,
              fileSizeBytes: voiceMemo.sizeBytes,
              fileDurationMs: voiceMemo.durationMs,
              isReadByOther: false,
            ),
          ];
          _isSendingMessage = false;
        });
        _scheduleScrollToBottom(force: true);
        return;
      }

      final currentUserId = await _requireSendableCurrentChat(
        unauthenticatedMessage:
            'Du musst angemeldet sein, um Sprachmemos zu senden.',
      );

      final messageId = _chatRepository.createMessageId(chatId: chatId);
      final upload = await _attachmentStorage.uploadChatVoiceMemo(
        chatId: chatId,
        userId: currentUserId,
        messageId: messageId,
        file: voiceMemoFile,
        fileName: voiceMemo.name,
        contentType: voiceMemo.contentType,
      );
      uploadedPath = upload.path;

      _forceScrollToBottomOnNextMessages = true;
      _rememberOutgoingReadReceiptBaseline();

      await _chatRepository.sendAudioMessage(
        chatId: chatId,
        messageId: messageId,
        senderUserId: currentUserId,
        fileUrl: upload.url,
        filePath: upload.path,
        fileName: upload.fileName,
        fileContentType: upload.contentType,
        fileSizeBytes: upload.fileSizeBytes,
        fileDurationMs: voiceMemo.durationMs,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _scheduleScrollToBottom(force: true);
    } catch (error) {
      final cleanupError = await _cleanupFailedChatAttachment(uploadedPath);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _chatAttachmentSendErrorMessage(
              'Sprachmemo konnte nicht gesendet werden',
              error,
              cleanupError: cleanupError,
            ),
          ),
        ),
      );
    }
  }

  Future<Object?> _cleanupFailedChatAttachment(String? path) async {
    final trimmedPath = path?.trim() ?? '';

    if (trimmedPath.isEmpty) {
      return null;
    }

    try {
      await _attachmentStorage.deleteUploadedChatAttachment(path: trimmedPath);
      return null;
    } catch (error) {
      return error;
    }
  }

  String _chatAttachmentSendErrorMessage(
    String fallbackMessage,
    Object error, {
    Object? cleanupError,
  }) {
    final message = error is ChatAttachmentStorageException
        ? error.message
        : '$fallbackMessage: ${_friendlyChatErrorMessage(error)}';

    if (cleanupError == null) {
      return message;
    }

    return '$message Hochgeladener Anhang konnte nicht bereinigt werden: $cleanupError';
  }

  Future<Position> _resolveCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw StateError('Standortdienste sind deaktiviert.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('Standortberechtigung wurde verweigert.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Standortberechtigung wurde dauerhaft verweigert. Bitte in den App-Einstellungen erlauben.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _sendAttachmentTextMessage(
    String message, {
    ChatMessageType messageType = ChatMessageType.text,
  }) async {
    if (_isSendingMessage) {
      return;
    }

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final chatId = widget.chatId?.trim();

      if (chatId == null || chatId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages = [
            ..._messages,
            _LocalChatMessage(
              text: message,
              isMine: true,
              timeLabel: 'Jetzt',
              createdAt: DateTime.now(),
              type: messageType,
              isReadByOther: false,
            ),
          ];
          _isSendingMessage = false;
        });
        _scheduleScrollToBottom(force: true);
        return;
      }

      final currentUserId = await _requireSendableCurrentChat(
        unauthenticatedMessage:
            'Du musst angemeldet sein, um diesen Anhang zu senden.',
      );

      _forceScrollToBottomOnNextMessages = true;
      _rememberOutgoingReadReceiptBaseline();

      await _chatRepository.sendTextMessage(
        chatId: chatId,
        senderUserId: currentUserId,
        text: message,
        messageType: messageType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _scheduleScrollToBottom(force: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anhang konnte nicht gesendet werden: ${_friendlyChatErrorMessage(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _handleShareLocation() async {
    if (_isSendingMessage) {
      return;
    }

    try {
      final position = await _resolveCurrentPosition();
      final latitude = position.latitude.toStringAsFixed(6);
      final longitude = position.longitude.toStringAsFixed(6);
      final message = 'Standort\n$latitude,$longitude';

      await _sendAttachmentTextMessage(
        message,
        messageType: ChatMessageType.location,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Standort konnte nicht gesendet werden: $error'),
        ),
      );
    }
  }

  Future<void> _handleShareContact() async {
    if (_isSendingMessage) {
      return;
    }

    try {
      final contact = await _nativeBridge.pickPhoneContact();

      if (contact == null) {
        return;
      }

      final phoneNumber = contact.phoneNumber
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (phoneNumber.isEmpty) {
        throw StateError('Dieser Kontakt hat keine Telefonnummer.');
      }

      if (phoneNumber.length > 40) {
        throw StateError('Die Telefonnummer ist zu lang.');
      }

      final contactName = contact.name.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (contactName.length > 80) {
        throw StateError('Der Kontaktname ist zu lang.');
      }

      await _sendAttachmentTextMessage(
        'Kontakt\nName: ${contactName.isEmpty ? 'Kontakt' : contactName}\nTelefon: $phoneNumber',
        messageType: ChatMessageType.contact,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kontakt konnte nicht gesendet werden: $error')),
      );
    }
  }

  Future<void> _handleOpenLocation(_LocationPayload location) async {
    try {
      await _nativeBridge.openMap(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Karte konnte nicht geöffnet werden: $error')),
      );
    }
  }

  Future<void> _handleOpenDocument(_LocalChatMessage message) async {
    final fileUrl = message.fileUrl?.trim() ?? '';

    if (fileUrl.isEmpty) {
      return;
    }

    try {
      await _nativeBridge.openDocumentUrl(
        url: fileUrl,
        contentType: message.fileContentType ?? 'application/octet-stream',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dokument konnte nicht geöffnet werden: $error'),
        ),
      );
    }
  }

  String _audioMessageKey(_LocalChatMessage message) {
    final messageId = message.messageId?.trim();

    if (messageId != null && messageId.isNotEmpty) {
      return messageId;
    }

    return message.fileUrl?.trim() ?? '';
  }

  Future<void> _handleToggleAudioMessage(_LocalChatMessage message) async {
    final fileUrl = message.fileUrl?.trim() ?? '';

    if (fileUrl.isEmpty) {
      return;
    }

    final messageKey = _audioMessageKey(message);

    try {
      if (_playingAudioMessageKey == messageKey) {
        await _nativeBridge.stopVoiceMemoPlayback();
        _audioPlaybackStopTimer?.cancel();

        if (!mounted) {
          return;
        }

        setState(() {
          _playingAudioMessageKey = null;
        });
        return;
      }

      await _nativeBridge.playVoiceMemo(url: fileUrl);
      _audioPlaybackStopTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _playingAudioMessageKey = messageKey;
      });

      final durationMs = message.fileDurationMs ?? 0;
      if (durationMs > 0) {
        _audioPlaybackStopTimer = Timer(
          Duration(milliseconds: durationMs + 500),
          () {
            if (!mounted || _playingAudioMessageKey != messageKey) {
              return;
            }

            setState(() {
              _playingAudioMessageKey = null;
            });
          },
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sprachnachricht konnte nicht abgespielt werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _handleStarMessage(_LocalChatMessage message) async {
    final chatId = widget.chatId?.trim();
    final messageId = message.messageId?.trim();
    final nextIsStarred = !message.isStarred;

    if (chatId == null ||
        chatId.isEmpty ||
        messageId == null ||
        messageId.isEmpty) {
      setState(() {
        _messages = _messages.map((item) {
          if (!identical(item, message)) {
            return item;
          }

          return item.copyWith(isStarred: nextIsStarred);
        }).toList();
      });
      return;
    }

    try {
      await _chatRepository.setMessageStarred(
        chatId: chatId,
        messageId: messageId,
        isStarred: nextIsStarred,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stern-Markierung konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    }
  }

  Future<void> _handleReactMessage(
    _LocalChatMessage message,
    String reaction,
  ) async {
    if (_hasFirestoreChat && !_isChatComposerEnabled) {
      _showChatUnavailableMessage();
      return;
    }

    final chatId = widget.chatId?.trim();
    final messageId = message.messageId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final localUserId = currentUserId.isEmpty ? 'local-user' : currentUserId;
    final currentReaction = message.reactionBy[localUserId];
    final nextReaction = currentReaction == reaction ? '' : reaction;

    if (chatId == null ||
        chatId.isEmpty ||
        messageId == null ||
        messageId.isEmpty ||
        currentUserId.isEmpty) {
      setState(() {
        _messages = _messages.map((item) {
          if (!identical(item, message)) {
            return item;
          }

          final nextReactionBy = Map<String, String>.of(item.reactionBy);

          if (nextReaction.isEmpty) {
            nextReactionBy.remove(localUserId);
          } else {
            nextReactionBy[localUserId] = nextReaction;
          }

          return item.copyWith(reactionBy: nextReactionBy);
        }).toList();
      });
      return;
    }

    try {
      await _chatRepository.setMessageReaction(
        chatId: chatId,
        messageId: messageId,
        userId: currentUserId,
        reaction: nextReaction,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reaktion konnte nicht gespeichert werden: $error'),
        ),
      );
    }
  }

  Future<void> _handleDeleteMessage(_LocalChatMessage message) async {
    final shouldDelete = await _confirmDeleteMessage();

    if (!shouldDelete) {
      return;
    }

    if (!mounted) {
      return;
    }

    final chatId = widget.chatId?.trim();
    final messageId = message.messageId?.trim();

    if (chatId == null ||
        chatId.isEmpty ||
        messageId == null ||
        messageId.isEmpty) {
      setState(() {
        _messages = _messages
            .where((item) => !identical(item, message))
            .toList();
      });
      return;
    }

    try {
      await _chatRepository.deleteMessage(chatId: chatId, messageId: messageId);

      if (!mounted) return;

      setState(() {
        _messages = _messages
            .where((item) => item.messageId != message.messageId)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nachricht wurde gelöscht.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nachricht konnte nicht gelöscht werden: $error'),
        ),
      );
    }
  }

  Future<bool> _confirmDeleteMessage() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF101827).withValues(alpha: 0.95),
                      const Color(0xFF071120).withValues(alpha: 0.92),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.13),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Nachricht löschen?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Diese Nachricht wird aus diesem Chat entfernt.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Abbrechen',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Löschen',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _handleSend() async {
    if (!_hasText || _isSendingMessage) {
      return;
    }

    final replyTarget = _replyingToMessage;
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    final chatId = widget.chatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      setState(() {
        _messages = [
          ..._messages,
          _LocalChatMessage(
            text: message,
            isMine: true,
            replyToText: replyTarget?.text,
            timeLabel: 'Jetzt',
            createdAt: DateTime.now(),
            isReadByOther: false,
          ),
        ];
        _replyingToMessage = null;
      });
      _scheduleScrollToBottom(force: true);

      _messageController.clear();
      return;
    }

    setState(() {
      _isSendingMessage = true;
    });

    _LocalChatMessage? optimisticMessage;

    try {
      final currentUserId = await _requireSendableCurrentChat(
        unauthenticatedMessage:
            'Du musst angemeldet sein, um Nachrichten zu senden.',
      );

      _forceScrollToBottomOnNextMessages = true;
      _rememberOutgoingReadReceiptBaseline();

      optimisticMessage = _LocalChatMessage(
        text: message,
        isMine: true,
        replyToText: replyTarget?.text,
        timeLabel: 'Jetzt',
        createdAt: DateTime.now(),
        isReadByOther: false,
      );

      if (mounted) {
        setState(() {
          _messages = [..._messages, optimisticMessage!];
        });
        _scheduleScrollToBottom(force: true);
      }

      await _chatRepository.sendTextMessage(
        chatId: chatId,
        senderUserId: currentUserId,
        text: message,
        replyToMessageId: replyTarget?.messageId,
        replyToText: replyTarget?.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
        _replyingToMessage = null;
      });

      _messageController.clear();
      _scheduleScrollToBottom(force: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
        _messages = _messages
            .where((message) => !identical(message, optimisticMessage))
            .toList();
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nachricht konnte nicht gesendet werden: ${_friendlyChatErrorMessage(error)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final chatSendDisabledMessage = _chatSendDisabledMessage;
    final isChatComposerEnabled = chatSendDisabledMessage == null;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final currentChat = _currentChatRecord;

    if (keyboardInset > _lastKeyboardInset) {
      _scheduleScrollToBottomAfterKeyboard();
    }

    _lastKeyboardInset = keyboardInset;

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                child: _CompactChatInfoCard(
                  displayName: widget.displayName,
                  profilePhotoUrl: widget.profilePhotoUrl,
                  vehicleModel: widget.vehicleModel,
                  vehicleColor: widget.vehicleColor,
                  displayPlate: widget.displayPlate,
                  isOnline: _isOtherUserOnline,
                  onBack: () => Navigator.of(context).pop(),
                  onOpenProfile: _showChatProfileSheet,
                  chatId: widget.chatId,
                  isFavorite:
                      currentChat?.isFavoriteFor(currentUserId) ?? false,
                  isPinned: currentChat?.isPinnedFor(currentUserId) ?? false,
                  isMuted: currentChat?.isMutedFor(currentUserId) ?? false,
                  isUnread: currentChat?.hasUnreadFor(currentUserId) ?? false,
                  isArchived:
                      currentChat?.isArchivedFor(currentUserId) ?? false,
                  isBlocked: currentChat?.status == ChatStatus.blocked,
                  canUnblock: currentChat?.isBlockedBy(currentUserId) ?? false,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: _handleMessageListSizeChanged,
                  child: SizeChangedLayoutNotifier(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleMessageScrollNotification,
                      child: ListView(
                        controller: _messageScrollController,
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        children: [
                          SizedBox(key: _messageListEndKey, height: 1),
                          if (_isOtherUserTyping)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: _TypingIndicatorBubble(),
                            ),
                          if (_replyingToMessage != null)
                            _ReplyPreview(
                              message: _replyingToMessage!,
                              onClear: _clearReplyMessage,
                            ),
                          if (_isLoadingMessages)
                            const _ChatLoadingSpace()
                          else if (_messages.isEmpty)
                            const _ChatEmptySpace()
                          else
                            _ChatMessageList(
                              messages: _messages,
                              playingAudioMessageKey: _playingAudioMessageKey,
                              onDeleteMessage: _handleDeleteMessage,
                              onReplyMessage: _handleReplyMessage,
                              onStarMessage: _handleStarMessage,
                              onReactMessage: _handleReactMessage,
                              onOpenLocation: _handleOpenLocation,
                              onOpenDocument: _handleOpenDocument,
                              onToggleAudioMessage: _handleToggleAudioMessage,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _MessageComposer(
                controller: _messageController,
                focusNode: _messageFocusNode,
                hasText: _hasText,
                onPickPhoto: () => _handlePickImage(ImageSource.gallery),
                onTakePhoto: () => _handlePickImage(ImageSource.camera),
                onShareLocation: _handleShareLocation,
                onShareContact: _handleShareContact,
                onPickDocument: _handlePickDocument,
                onSend: _handleSend,
                onVoiceMemo: _handleVoiceMemo,
                isSending: _isSendingMessage,
                isEnabled: isChatComposerEnabled,
                disabledMessage: chatSendDisabledMessage,
                isRecordingVoiceMemo: _isRecordingVoiceMemo,
                voiceMemoRecordingSeconds: _voiceMemoRecordingSeconds,
                onTextInputFocus: _scheduleScrollToBottomAfterKeyboard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChatProfileSheet() async {
    final shouldOpenPublicProfile = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return _ChatProfileSheet(
          displayName: widget.displayName,
          profilePhotoUrl: widget.profilePhotoUrl,
          vehicleModel: widget.vehicleModel,
          displayPlate: widget.displayPlate,
          isOnline: _isOtherUserOnline,
          messages: _messages,
          onReplyMessage: _handleReplyMessage,
          onOpenPublicProfile: widget.profileUserId?.trim().isNotEmpty == true
              ? () => Navigator.of(context).pop(true)
              : null,
        );
      },
    );

    final profileUserId = widget.profileUserId?.trim() ?? '';
    if (!mounted || shouldOpenPublicProfile != true || profileUserId.isEmpty) {
      return;
    }

    final chatId = widget.chatId?.trim() ?? '';
    if (chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Das Profil kann nur aus einem aktiven Chat geöffnet werden.',
          ),
        ),
      );
      return;
    }

    try {
      await ProfileConnectionRepository().ensureForAcceptedChat(chatId: chatId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der Profilzugriff konnte nicht bestätigt werden. Bitte versuche es erneut.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(buildSocialProfileRoute(profileUserId: profileUserId));
  }
}

String _formatChatPlateLabel(String? value) {
  final trimmed = value?.trim();

  if (trimmed == null || trimmed.isEmpty) {
    return 'Kennzeichen';
  }

  final upper = trimmed.toUpperCase();
  final withSeparators = RegExp(
    r'^([A-ZÄÖÜ]{1,3})[-\s]+([A-ZÄÖÜ]{1,2})\s*(\d{1,4})$',
  ).firstMatch(upper);

  if (withSeparators != null) {
    return '${withSeparators.group(1)}-${withSeparators.group(2)} ${withSeparators.group(3)}';
  }

  final compact = upper.replaceAll(RegExp(r'[^A-ZÄÖÜ0-9]'), '');
  final compactMatch = RegExp(r'^([A-ZÄÖÜ]+)(\d{1,4})$').firstMatch(compact);

  if (compactMatch == null) {
    return upper;
  }

  final letters = compactMatch.group(1) ?? '';
  final numbers = compactMatch.group(2) ?? '';

  if (letters.length < 3) {
    return '$letters $numbers';
  }

  final cityLength = letters.length >= 5 ? 3 : 2;
  final city = letters.substring(0, cityLength);
  final serial = letters.substring(cityLength);

  if (serial.isEmpty) {
    return '$city $numbers';
  }

  return '$city-$serial $numbers';
}

Future<void> _showChatProfileImage(
  BuildContext context,
  String? profilePhotoUrl,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: _UserAvatarPlaceholder(
                  size: 230,
                  imageUrl: profilePhotoUrl,
                ),
              ),
            ),
            Positioned(
              top: 22,
              right: 18,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: Colors.white,
                tooltip: 'Schließen',
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CompactChatInfoCard extends StatelessWidget {
  const _CompactChatInfoCard({
    required this.displayName,
    this.profilePhotoUrl,
    required this.vehicleModel,
    required this.vehicleColor,
    this.displayPlate,
    this.isOnline = false,
    required this.onBack,
    required this.onOpenProfile,
    this.chatId,
    this.isFavorite = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isUnread = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.canUnblock = false,
  });

  final String displayName;
  final String? profilePhotoUrl;
  final String vehicleModel;
  final String vehicleColor;
  final String? displayPlate;
  final bool isOnline;
  final VoidCallback onBack;
  final VoidCallback onOpenProfile;
  final String? chatId;
  final bool isFavorite;
  final bool isPinned;
  final bool isMuted;
  final bool isUnread;
  final bool isArchived;
  final bool isBlocked;
  final bool canUnblock;
  @override
  Widget build(BuildContext context) {
    final vehicleModelLabel = vehicleModel.trim().isEmpty
        ? 'Fahrzeug'
        : vehicleModel.trim();
    final plateLabel = _formatChatPlateLabel(displayPlate);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.055),
              _myMessageBlue.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.025),
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showChatProfileImage(context, profilePhotoUrl),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _carismaBlueLight.withValues(alpha: 0.30),
                      ),
                    ),
                    child: _UserAvatarPlaceholder(
                      size: 42,
                      imageUrl: profilePhotoUrl,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF25D366),
                          border: Border.all(
                            color: const Color(0xFF111827),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(16),
                splashFactory: NoSplash.splashFactory,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _ChatHeaderInfoChip(
                              label: vehicleModelLabel,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            flex: 7,
                            child: _ChatHeaderInfoChip(label: plateLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _ChatOverflowMenu(
              chatId: chatId,
              title: displayName,
              subtitle: '$vehicleModelLabel - $plateLabel',
              vehicleLabel: vehicleModelLabel,
              plateLabel: plateLabel,
              isFavorite: isFavorite,
              isPinned: isPinned,
              isMuted: isMuted,
              isUnread: isUnread,
              isArchived: isArchived,
              isBlocked: isBlocked,
              canUnblock: canUnblock,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeaderInfoChip extends StatelessWidget {
  const _ChatHeaderInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatProfileLinkItem {
  const _ChatProfileLinkItem({required this.url, required this.message});

  final String url;
  final _LocalChatMessage message;
}

enum _ChatProfileSelectionAction { reply, share, save }

class _ChatProfileSheet extends StatelessWidget {
  const _ChatProfileSheet({
    required this.displayName,
    this.profilePhotoUrl,
    required this.vehicleModel,
    this.displayPlate,
    this.isOnline = false,
    required this.messages,
    required this.onReplyMessage,
    this.onOpenPublicProfile,
  });

  final String displayName;
  final String? profilePhotoUrl;
  final String vehicleModel;
  final String? displayPlate;
  final bool isOnline;
  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onReplyMessage;
  final VoidCallback? onOpenPublicProfile;

  List<_LocalChatMessage> get _mediaMessages {
    return messages.where((message) => message.isImage).toList();
  }

  List<_LocalChatMessage> get _documentMessages {
    return messages.where((message) => message.isDocument).toList();
  }

  List<_ChatProfileLinkItem> get _links {
    final linkPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    return messages
        .expand(
          (message) => linkPattern.allMatches(message.text).map((match) {
            return _ChatProfileLinkItem(
              url: match.group(0)?.trim() ?? '',
              message: message,
            );
          }),
        )
        .where((item) => item.url.isNotEmpty)
        .toList();
  }

  List<_LocalChatMessage> get _starredMessages {
    return messages.where((message) => message.isStarred).toList();
  }

  String get _vehicleLabel {
    final trimmed = vehicleModel.trim();
    return trimmed.isEmpty ? 'Fahrzeug' : trimmed;
  }

  String get _plateLabel {
    return _formatChatPlateLabel(displayPlate);
  }

  Future<void> _showAllMedia(
    BuildContext context,
    List<_LocalChatMessage> messages,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return _ChatProfileAllMediaSheet(
          messages: messages,
          onReplyMessage: (message) {
            onReplyMessage(message);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _showAllLinks(
    BuildContext context,
    List<_ChatProfileLinkItem> links,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return _ChatProfileAllLinksSheet(
          links: links,
          onReplyMessage: (message) {
            onReplyMessage(message);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _showAllDocuments(
    BuildContext context,
    List<_LocalChatMessage> messages,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return _ChatProfileAllDocumentsSheet(
          messages: messages,
          onReplyMessage: (message) {
            onReplyMessage(message);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareText(BuildContext context, String text) async {
    final safeText = text.trim();

    if (safeText.isEmpty) {
      _showSnackBar(context, 'Inhalt konnte nicht geteilt werden.');
      return;
    }

    try {
      await ChatNativeBridge().shareText(text: safeText);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Teilen konnte nicht geöffnet werden: $error');
    }
  }

  Future<void> _saveMediaMessage(
    BuildContext context,
    _LocalChatMessage message,
  ) async {
    final imageUrl = message.imageUrl?.trim() ?? '';

    if (imageUrl.isEmpty) {
      _showSnackBar(context, 'Medium konnte nicht gespeichert werden.');
      return;
    }

    try {
      await ChatNativeBridge().saveImageToGallery(
        url: imageUrl,
        fileName: message.fileName?.trim().isNotEmpty == true
            ? message.fileName!.trim()
            : 'carisma_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: message.fileContentType?.trim().isNotEmpty == true
            ? message.fileContentType!.trim()
            : 'image/jpeg',
      );

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Medium wurde in der Galerie gespeichert.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Speichern konnte nicht ausgeführt werden: $error',
      );
    }
  }

  Future<void> _saveDocumentMessage(
    BuildContext context,
    _LocalChatMessage message,
  ) async {
    final fileUrl = message.fileUrl?.trim() ?? '';

    if (fileUrl.isEmpty) {
      _showSnackBar(context, 'Dokument konnte nicht gespeichert werden.');
      return;
    }

    try {
      await ChatNativeBridge().saveDocumentToDownloads(
        url: fileUrl,
        fileName: message.fileName?.trim().isNotEmpty == true
            ? message.fileName!.trim()
            : 'carisma_document_${DateTime.now().millisecondsSinceEpoch}',
        contentType: message.fileContentType?.trim().isNotEmpty == true
            ? message.fileContentType!.trim()
            : 'application/octet-stream',
      );

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Dokument wurde gespeichert.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Speichern konnte nicht ausgeführt werden: $error',
      );
    }
  }

  Future<void> _copyLink(BuildContext context, String url) async {
    final safeUrl = url.trim();

    if (safeUrl.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: safeUrl));

    if (!context.mounted) {
      return;
    }

    _showSnackBar(context, 'Link wurde kopiert.');
  }

  Future<void> _showProfileItemActions({
    required BuildContext context,
    required _LocalChatMessage replyMessage,
    required VoidCallback onShare,
    required VoidCallback onSave,
    required IconData saveIcon,
    required String saveLabel,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Antworten',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pop();
                    onReplyMessage(replyMessage);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Teilen',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onShare();
                  },
                ),
                _MessageActionTile(
                  icon: saveIcon,
                  label: saveLabel,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSave();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaMessages = _mediaMessages;
    final documentMessages = _documentMessages;
    final links = _links;
    final starredMessages = _starredMessages;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _showChatProfileImage(context, profilePhotoUrl),
                        child: _UserAvatarPlaceholder(
                          size: 92,
                          imageUrl: profilePhotoUrl,
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF25D366),
                              border: Border.all(
                                color: const Color(0xFF101827),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _ChatProfileChip(
                        icon: Icons.directions_car_filled_rounded,
                        label: _vehicleLabel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _ChatProfileChip(
                        icon: Icons.confirmation_number_rounded,
                        label: _plateLabel,
                      ),
                    ),
                  ],
                ),
                if (onOpenPublicProfile != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton.icon(
                      onPressed: onOpenPublicProfile,
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('Öffentliches Profil ansehen'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ChatProfileStat(
                        label: 'Medien',
                        value: mediaMessages.length.toString(),
                        onTap: () => _showAllMedia(context, mediaMessages),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChatProfileStat(
                        label: 'Links',
                        value: links.length.toString(),
                        onTap: () => _showAllLinks(context, links),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChatProfileStat(
                        label: 'Doks',
                        value: documentMessages.length.toString(),
                        onTap: () =>
                            _showAllDocuments(context, documentMessages),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ChatProfileSectionTitle(
                  title: 'Medien',
                  onShowAll: () => _showAllMedia(context, mediaMessages),
                ),
                const SizedBox(height: 10),
                _ChatProfileMediaPreview(
                  messages: mediaMessages,
                  onOpenMessage: (message) {
                    unawaited(
                      _showProfileItemActions(
                        context: context,
                        replyMessage: message,
                        onShare: () => unawaited(
                          _shareText(context, message.imageUrl ?? ''),
                        ),
                        onSave: () =>
                            unawaited(_saveMediaMessage(context, message)),
                        saveIcon: Icons.download_rounded,
                        saveLabel: 'Speichern',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                _ChatProfileSectionTitle(
                  title: 'Links',
                  onShowAll: () => _showAllLinks(context, links),
                ),
                const SizedBox(height: 8),
                _ChatProfileLinkList(
                  links: links,
                  onOpenLink: (link) {
                    unawaited(
                      _showProfileItemActions(
                        context: context,
                        replyMessage: link.message,
                        onShare: () => unawaited(_shareText(context, link.url)),
                        onSave: () => unawaited(_copyLink(context, link.url)),
                        saveIcon: Icons.copy_rounded,
                        saveLabel: 'Kopieren',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                _ChatProfileSectionTitle(
                  title: 'Doks',
                  onShowAll: () => _showAllDocuments(context, documentMessages),
                ),
                const SizedBox(height: 8),
                _ChatProfileDocumentList(
                  messages: documentMessages,
                  onOpenMessage: (message) {
                    unawaited(
                      _showProfileItemActions(
                        context: context,
                        replyMessage: message,
                        onShare: () => unawaited(
                          _shareText(context, message.fileUrl ?? ''),
                        ),
                        onSave: () =>
                            unawaited(_saveDocumentMessage(context, message)),
                        saveIcon: Icons.download_rounded,
                        saveLabel: 'Speichern',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                _ChatProfileSectionTitle(title: 'Mit Stern markiert'),
                const SizedBox(height: 8),
                _ChatProfileStarredList(messages: starredMessages),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChatProfileChip extends StatelessWidget {
  const _ChatProfileChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _carismaBlueLight),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatProfileStat extends StatelessWidget {
  const _ChatProfileStat({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatProfileSectionTitle extends StatelessWidget {
  const _ChatProfileSectionTitle({required this.title, this.onShowAll});

  final String title;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onShowAll != null)
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              foregroundColor: _carismaBlueLight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Alle anzeigen'),
          ),
      ],
    );
  }
}

class _ChatProfileMediaPreview extends StatelessWidget {
  const _ChatProfileMediaPreview({
    required this.messages,
    required this.onOpenMessage,
  });

  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onOpenMessage;

  bool _isNetworkImage(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _ChatProfileEmptyRow(
        icon: Icons.photo_library_outlined,
        label: 'Keine Medien',
      );
    }

    return GridView.builder(
      itemCount: messages.length > 6 ? 6 : messages.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final imageUrl = messages[index].imageUrl?.trim() ?? '';
        final image = _isNetworkImage(imageUrl)
            ? Image.network(imageUrl, fit: BoxFit.cover)
            : Image.file(File(imageUrl), fit: BoxFit.cover);

        return GestureDetector(
          onTap: () => onOpenMessage(messages[index]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              color: Colors.white.withValues(alpha: 0.08),
              child: image,
            ),
          ),
        );
      },
    );
  }
}

class _ChatProfileLinkList extends StatelessWidget {
  const _ChatProfileLinkList({required this.links, required this.onOpenLink});

  final List<_ChatProfileLinkItem> links;
  final ValueChanged<_ChatProfileLinkItem> onOpenLink;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const _ChatProfileEmptyRow(
        icon: Icons.link_rounded,
        label: 'Keine Links',
      );
    }

    return Column(
      children: links.take(6).map((link) {
        return GestureDetector(
          onTap: () => onOpenLink(link),
          child: _ChatProfileListTile(
            icon: Icons.link_rounded,
            title: link.url,
            subtitle: 'Link',
          ),
        );
      }).toList(),
    );
  }
}

class _ChatProfileDocumentList extends StatelessWidget {
  const _ChatProfileDocumentList({
    required this.messages,
    required this.onOpenMessage,
  });

  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onOpenMessage;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _ChatProfileEmptyRow(
        icon: Icons.insert_drive_file_outlined,
        label: 'Keine Dokumente',
      );
    }

    return Column(
      children: messages.take(6).map((message) {
        return GestureDetector(
          onTap: () => onOpenMessage(message),
          child: _ChatProfileListTile(
            icon: Icons.insert_drive_file_rounded,
            title: message.fileName?.trim().isNotEmpty == true
                ? message.fileName!.trim()
                : 'Dokument',
            subtitle: message.timeLabel,
          ),
        );
      }).toList(),
    );
  }
}

class _ChatProfileAllMediaSheet extends StatelessWidget {
  const _ChatProfileAllMediaSheet({
    required this.messages,
    required this.onReplyMessage,
  });

  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onReplyMessage;

  bool _isNetworkImage(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Widget _buildImage(String imageUrl) {
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return const _ImageLoadError();
    }

    return _isNetworkImage(trimmedUrl)
        ? Image.network(
            trimmedUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _ImageLoadError(),
          )
        : Image.file(
            File(trimmedUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _ImageLoadError(),
          );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _mediaShareText(List<_LocalChatMessage> selectedMessages) {
    return selectedMessages
        .map((message) => message.imageUrl?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join('\n');
  }

  Future<void> _shareMedia(
    BuildContext context,
    List<_LocalChatMessage> selectedMessages,
  ) async {
    final text = _mediaShareText(selectedMessages);

    if (text.isEmpty) {
      _showSnackBar(context, 'Medium konnte nicht geteilt werden.');
      return;
    }

    try {
      await ChatNativeBridge().shareText(text: text);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Teilen konnte nicht geöffnet werden: $error');
    }
  }

  Future<void> _saveMedia(
    BuildContext context,
    List<_LocalChatMessage> selectedMessages,
  ) async {
    try {
      for (final message in selectedMessages) {
        final url = message.imageUrl?.trim() ?? '';

        if (url.isEmpty) {
          continue;
        }

        await ChatNativeBridge().saveImageToGallery(
          url: url,
          fileName: message.fileName?.trim().isNotEmpty == true
              ? message.fileName!.trim()
              : 'carisma_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: message.fileContentType?.trim().isNotEmpty == true
              ? message.fileContentType!.trim()
              : 'image/jpeg',
        );
      }

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Medien wurden in der Galerie gespeichert.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Speichern konnte nicht ausgeführt werden: $error',
      );
    }
  }

  _LocalChatMessage _replyMessageFor(List<_LocalChatMessage> selectedMessages) {
    if (selectedMessages.length == 1) {
      return selectedMessages.first;
    }

    return _LocalChatMessage(
      text: '${selectedMessages.length} Medien',
      isMine: false,
      timeLabel: '',
      createdAt: DateTime.now(),
    );
  }

  void _handleAction(
    BuildContext context,
    Set<int> selectedIndexes,
    _ChatProfileSelectionAction action,
  ) {
    final selectedMessages = selectedIndexes
        .where((index) => index >= 0 && index < messages.length)
        .map((index) => messages[index])
        .toList();

    if (selectedMessages.isEmpty) {
      return;
    }

    switch (action) {
      case _ChatProfileSelectionAction.reply:
        Navigator.of(context).pop();
        onReplyMessage(_replyMessageFor(selectedMessages));
      case _ChatProfileSelectionAction.share:
        unawaited(_shareMedia(context, selectedMessages));
      case _ChatProfileSelectionAction.save:
        unawaited(_saveMedia(context, selectedMessages));
    }
  }

  Future<void> _showItemActions(BuildContext context, int index) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Antworten',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.reply);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Teilen',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.share);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.download_rounded,
                  label: 'Speichern',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.save);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ChatProfileCollectionShell(
      title: 'Medien',
      itemCount: messages.length,
      onSelectionAction: (selectedIndexes, action) {
        _handleAction(context, selectedIndexes, action);
      },
      builder:
          (
            context,
            scrollController,
            isSelectionMode,
            selectedIndexes,
            onToggleSelection,
          ) {
            if (messages.isEmpty) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: const [
                  _ChatProfileEmptyRow(
                    icon: Icons.photo_library_outlined,
                    label: 'Keine Medien',
                  ),
                ],
              );
            }

            return GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: messages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final imageUrl = messages[index].imageUrl?.trim() ?? '';
                final isSelected = selectedIndexes.contains(index);

                return GestureDetector(
                  onTap: isSelectionMode
                      ? () => onToggleSelection(index)
                      : () => _showItemActions(context, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: Colors.white.withValues(alpha: 0.08),
                          child: _buildImage(imageUrl),
                        ),
                        if (isSelectionMode)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _ChatProfileSelectionCheck(
                              isSelected: isSelected,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}

class _ChatProfileAllLinksSheet extends StatelessWidget {
  const _ChatProfileAllLinksSheet({
    required this.links,
    required this.onReplyMessage,
  });

  final List<_ChatProfileLinkItem> links;
  final ValueChanged<_LocalChatMessage> onReplyMessage;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareLinks(
    BuildContext context,
    List<_ChatProfileLinkItem> selectedLinks,
  ) async {
    try {
      await ChatNativeBridge().shareText(
        text: selectedLinks.map((item) => item.url).join('\n'),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Teilen konnte nicht geöffnet werden: $error');
    }
  }

  _LocalChatMessage _replyMessageFor(List<_ChatProfileLinkItem> selectedLinks) {
    if (selectedLinks.length == 1) {
      return selectedLinks.first.message;
    }

    return _LocalChatMessage(
      text: '${selectedLinks.length} Links',
      isMine: false,
      timeLabel: '',
      createdAt: DateTime.now(),
    );
  }

  void _handleAction(
    BuildContext context,
    Set<int> selectedIndexes,
    _ChatProfileSelectionAction action,
  ) {
    final selectedLinks = selectedIndexes
        .where((index) => index >= 0 && index < links.length)
        .map((index) => links[index])
        .toList();

    if (selectedLinks.isEmpty) {
      return;
    }

    switch (action) {
      case _ChatProfileSelectionAction.reply:
        Navigator.of(context).pop();
        onReplyMessage(_replyMessageFor(selectedLinks));
      case _ChatProfileSelectionAction.share:
        unawaited(_shareLinks(context, selectedLinks));
      case _ChatProfileSelectionAction.save:
        Clipboard.setData(
          ClipboardData(text: selectedLinks.map((item) => item.url).join('\n')),
        );
        _showSnackBar(context, 'Links wurden kopiert.');
    }
  }

  Future<void> _showItemActions(BuildContext context, int index) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Antworten',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.reply);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Teilen',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.share);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Kopieren',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.save);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ChatProfileCollectionShell(
      title: 'Links',
      itemCount: links.length,
      onSelectionAction: (selectedIndexes, action) {
        _handleAction(context, selectedIndexes, action);
      },
      builder:
          (
            context,
            scrollController,
            isSelectionMode,
            selectedIndexes,
            onToggleSelection,
          ) {
            if (links.isEmpty) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: const [
                  _ChatProfileEmptyRow(
                    icon: Icons.link_rounded,
                    label: 'Keine Links',
                  ),
                ],
              );
            }

            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: links.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndexes.contains(index);

                return GestureDetector(
                  onTap: isSelectionMode
                      ? () => onToggleSelection(index)
                      : () => _showItemActions(context, index),
                  child: Stack(
                    children: [
                      _ChatProfileListTile(
                        icon: Icons.link_rounded,
                        title: links[index].url,
                        subtitle: 'Link',
                      ),
                      if (isSelectionMode)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _ChatProfileSelectionCheck(
                            isSelected: isSelected,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
    );
  }
}

class _ChatProfileAllDocumentsSheet extends StatelessWidget {
  const _ChatProfileAllDocumentsSheet({
    required this.messages,
    required this.onReplyMessage,
  });

  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onReplyMessage;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _documentShareText(List<_LocalChatMessage> selectedMessages) {
    return selectedMessages
        .map((message) => message.fileUrl?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join('\n');
  }

  Future<void> _shareDocuments(
    BuildContext context,
    List<_LocalChatMessage> selectedMessages,
  ) async {
    final text = _documentShareText(selectedMessages);

    if (text.isEmpty) {
      _showSnackBar(context, 'Dokument konnte nicht geteilt werden.');
      return;
    }

    try {
      await ChatNativeBridge().shareText(text: text);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Teilen konnte nicht geöffnet werden: $error');
    }
  }

  Future<void> _saveDocuments(
    BuildContext context,
    List<_LocalChatMessage> selectedMessages,
  ) async {
    try {
      for (final message in selectedMessages) {
        final url = message.fileUrl?.trim() ?? '';

        if (url.isEmpty) {
          continue;
        }

        await ChatNativeBridge().saveDocumentToDownloads(
          url: url,
          fileName: message.fileName?.trim().isNotEmpty == true
              ? message.fileName!.trim()
              : 'carisma_document_${DateTime.now().millisecondsSinceEpoch}',
          contentType: message.fileContentType?.trim().isNotEmpty == true
              ? message.fileContentType!.trim()
              : 'application/octet-stream',
        );
      }

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Dokumente wurden gespeichert.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Speichern konnte nicht ausgeführt werden: $error',
      );
    }
  }

  _LocalChatMessage _replyMessageFor(List<_LocalChatMessage> selectedMessages) {
    if (selectedMessages.length == 1) {
      return selectedMessages.first;
    }

    return _LocalChatMessage(
      text: '${selectedMessages.length} Dokumente',
      isMine: false,
      timeLabel: '',
      createdAt: DateTime.now(),
    );
  }

  void _handleAction(
    BuildContext context,
    Set<int> selectedIndexes,
    _ChatProfileSelectionAction action,
  ) {
    final selectedMessages = selectedIndexes
        .where((index) => index >= 0 && index < messages.length)
        .map((index) => messages[index])
        .toList();

    if (selectedMessages.isEmpty) {
      return;
    }

    switch (action) {
      case _ChatProfileSelectionAction.reply:
        Navigator.of(context).pop();
        onReplyMessage(_replyMessageFor(selectedMessages));
      case _ChatProfileSelectionAction.share:
        unawaited(_shareDocuments(context, selectedMessages));
      case _ChatProfileSelectionAction.save:
        unawaited(_saveDocuments(context, selectedMessages));
    }
  }

  Future<void> _showItemActions(BuildContext context, int index) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Antworten',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.reply);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Teilen',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.share);
                  },
                ),
                _MessageActionTile(
                  icon: Icons.download_rounded,
                  label: 'Speichern',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _handleAction(context, <int>{
                      index,
                    }, _ChatProfileSelectionAction.save);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ChatProfileCollectionShell(
      title: 'Doks',
      itemCount: messages.length,
      onSelectionAction: (selectedIndexes, action) {
        _handleAction(context, selectedIndexes, action);
      },
      builder:
          (
            context,
            scrollController,
            isSelectionMode,
            selectedIndexes,
            onToggleSelection,
          ) {
            if (messages.isEmpty) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: const [
                  _ChatProfileEmptyRow(
                    icon: Icons.insert_drive_file_outlined,
                    label: 'Keine Dokumente',
                  ),
                ],
              );
            }

            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isSelected = selectedIndexes.contains(index);

                return GestureDetector(
                  onTap: isSelectionMode
                      ? () => onToggleSelection(index)
                      : () => _showItemActions(context, index),
                  child: Stack(
                    children: [
                      _ChatProfileListTile(
                        icon: Icons.insert_drive_file_rounded,
                        title: message.fileName?.trim().isNotEmpty == true
                            ? message.fileName!.trim()
                            : 'Dokument',
                        subtitle: message.timeLabel,
                      ),
                      if (isSelectionMode)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _ChatProfileSelectionCheck(
                            isSelected: isSelected,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
    );
  }
}

class _ChatProfileCollectionShell extends StatelessWidget {
  const _ChatProfileCollectionShell({
    required this.title,
    required this.itemCount,
    required this.onSelectionAction,
    required this.builder,
  });

  final String title;
  final int itemCount;
  final void Function(
    Set<int> selectedIndexes,
    _ChatProfileSelectionAction action,
  )
  onSelectionAction;
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    bool isSelectionMode,
    Set<int> selectedIndexes,
    ValueChanged<int> onToggleSelection,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return _ChatProfileCollectionShellBody(
      title: title,
      itemCount: itemCount,
      onSelectionAction: onSelectionAction,
      builder: builder,
    );
  }
}

class _ChatProfileCollectionShellBody extends StatefulWidget {
  const _ChatProfileCollectionShellBody({
    required this.title,
    required this.itemCount,
    required this.onSelectionAction,
    required this.builder,
  });

  final String title;
  final int itemCount;
  final void Function(
    Set<int> selectedIndexes,
    _ChatProfileSelectionAction action,
  )
  onSelectionAction;
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    bool isSelectionMode,
    Set<int> selectedIndexes,
    ValueChanged<int> onToggleSelection,
  )
  builder;

  @override
  State<_ChatProfileCollectionShellBody> createState() =>
      _ChatProfileCollectionShellBodyState();
}

class _ChatProfileCollectionShellBodyState
    extends State<_ChatProfileCollectionShellBody> {
  bool _isSelectionMode = false;
  final Set<int> _selectedIndexes = <int>{};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIndexes.clear();
    });
  }

  void _toggleSelectedIndex(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _handleSelectionAction(_ChatProfileSelectionAction action) {
    widget.onSelectionAction(Set<int>.from(_selectedIndexes), action);

    if (!mounted || action == _ChatProfileSelectionAction.reply) {
      return;
    }

    setState(() {
      _isSelectionMode = false;
      _selectedIndexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (widget.itemCount > 0)
                      TextButton(
                        onPressed: _toggleSelectionMode,
                        child: Text(
                          _isSelectionMode ? 'Abbrechen' : 'Auswählen',
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      tooltip: 'Schließen',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.builder(
                  context,
                  scrollController,
                  _isSelectionMode,
                  _selectedIndexes,
                  _toggleSelectedIndex,
                ),
              ),
              if (_isSelectionMode && _selectedIndexes.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101827),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ChatProfileSelectionButton(
                            icon: Icons.reply_rounded,
                            label: 'Antworten',
                            onTap: () => _handleSelectionAction(
                              _ChatProfileSelectionAction.reply,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChatProfileSelectionButton(
                            icon: Icons.ios_share_rounded,
                            label: 'Teilen',
                            onTap: () => _handleSelectionAction(
                              _ChatProfileSelectionAction.share,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChatProfileSelectionButton(
                            icon: Icons.download_rounded,
                            label: 'Speichern',
                            onTap: () => _handleSelectionAction(
                              _ChatProfileSelectionAction.save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatProfileSelectionButton extends StatelessWidget {
  const _ChatProfileSelectionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ChatProfileSelectionCheck extends StatelessWidget {
  const _ChatProfileSelectionCheck({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? _carismaBlue : Colors.black.withValues(alpha: 0.46),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      ),
      child: Icon(
        isSelected ? Icons.check_rounded : Icons.circle_outlined,
        color: Colors.white,
        size: isSelected ? 18 : 14,
      ),
    );
  }
}

class _ChatProfileStarredList extends StatelessWidget {
  const _ChatProfileStarredList({required this.messages});

  final List<_LocalChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _ChatProfileEmptyRow(
        icon: Icons.star_border_rounded,
        label: 'Keine markierten Nachrichten',
      );
    }

    return Column(
      children: messages.take(4).map((message) {
        final title =
            message.contactPayload?.name ??
            message.fileName ??
            message.text.replaceAll('\n', ' ').trim();

        return _ChatProfileListTile(
          icon: Icons.star_rounded,
          title: title.isEmpty ? 'Markierte Nachricht' : title,
          subtitle: message.timeLabel,
        );
      }).toList(),
    );
  }
}

class _ChatProfileListTile extends StatelessWidget {
  const _ChatProfileListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _carismaBlueLight, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatProfileEmptyRow extends StatelessWidget {
  const _ChatProfileEmptyRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.42), size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
