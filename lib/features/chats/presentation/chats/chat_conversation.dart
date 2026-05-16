part of '../chats_screen.dart';

class _ChatConversationScreen extends StatefulWidget {
  const _ChatConversationScreen({
    required this.initialMessages,
    this.chatId,
    this.displayName = 'Carma Nutzer',
    this.profilePhotoUrl,
    this.vehicleModel = 'BMW 1er',
    this.vehicleColor = 'Schwarz',
  });

  final List<_LocalChatMessage> initialMessages;
  final String? chatId;
  final String displayName;
  final String? profilePhotoUrl;
  final String vehicleModel;
  final String vehicleColor;

  @override
  State<_ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<_ChatConversationScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final ChatAttachmentStorage _attachmentStorage = ChatAttachmentStorage();
  final ChatNativeBridge _nativeBridge = ChatNativeBridge();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  late List<_LocalChatMessage> _messages;
  bool _hasText = false;
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  bool _isOtherUserTyping = false;
  bool _isCurrentUserTyping = false;
  bool _forceScrollToBottomOnNextMessages = false;
  _LocalChatMessage? _replyingToMessage;
  DateTime? _lastTypingWriteAt;
  DateTime? _otherLastReadAt;
  double _lastKeyboardInset = 0;
  Timer? _typingStopTimer;
  StreamSubscription<bool>? _typingSubscription;
  StreamSubscription<DateTime?>? _readReceiptSubscription;
  StreamSubscription<List<ChatMessageRecord>>? _messagesSubscription;

  bool get _hasFirestoreChat {
    final chatId = widget.chatId?.trim();
    return chatId != null && chatId.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _messages = [...widget.initialMessages];
    _messageController.addListener(_handleMessageChanged);
    _scheduleScrollToBottom(animated: false);

    if (_hasFirestoreChat) {
      _markChatRead();
      _watchMessages();
      _watchTypingStatus();
      _watchReadReceipts();
    }
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    _typingSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _messagesSubscription?.cancel();
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  bool get _isNearMessageBottom {
    if (!_messageScrollController.hasClients) {
      return true;
    }

    final position = _messageScrollController.position;
    return position.maxScrollExtent - position.pixels <= 180;
  }

  void _scheduleScrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) {
        return;
      }

      final target = _messageScrollController.position.maxScrollExtent;

      if (animated) {
        _messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _messageScrollController.jumpTo(target);
      }
    });
  }

  void _scheduleScrollToBottomAfterKeyboard() {
    _scheduleScrollToBottom();
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }

      _scheduleScrollToBottom();
    });
  }

  Future<void> _markChatRead() async {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chatId == null || chatId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    try {
      await _chatRepository.markChatRead(chatId: chatId, userId: currentUserId);
    } catch (_) {
      // Read receipts are non-critical UI state.
    }
  }

  void _handleReplyMessage(_LocalChatMessage message) {
    setState(() {
      _replyingToMessage = message;
    });
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
    return isMine &&
        createdAt != null &&
        otherLastReadAt != null &&
        !createdAt.isAfter(otherLastReadAt);
  }

  void _handleTypingChanged(bool hasText) {
    if (!_hasFirestoreChat) {
      return;
    }

    _typingStopTimer?.cancel();

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

  Future<void> _setCurrentUserTyping(bool isTyping) async {
    final chatId = widget.chatId?.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (chatId == null ||
        chatId.isEmpty ||
        currentUserId == null ||
        currentUserId.isEmpty) {
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
              _scheduleScrollToBottom();
            }

            unawaited(_markChatRead());
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
        SnackBar(
          content: Text('Foto konnte nicht ausgew\u00E4hlt werden: $error'),
        ),
      );
    }
  }

  Future<void> _sendImageAttachment(File imageFile) async {
    if (_isSendingMessage) {
      return;
    }

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final chatId = widget.chatId?.trim();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
        _scheduleScrollToBottom();
        return;
      }

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein, um Fotos zu senden.');
      }

      final messageId = _chatRepository.createMessageId(chatId: chatId);
      final upload = await _attachmentStorage.uploadChatImage(
        chatId: chatId,
        userId: currentUserId,
        messageId: messageId,
        file: imageFile,
      );

      _forceScrollToBottomOnNextMessages = true;

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
      _scheduleScrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto konnte nicht gesendet werden: $error')),
      );
    }
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

  Future<void> _sendAttachmentTextMessage(String message) async {
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
              isReadByOther: false,
            ),
          ];
          _isSendingMessage = false;
        });
        _scheduleScrollToBottom();
        return;
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein, um Standort zu senden.');
      }

      _forceScrollToBottomOnNextMessages = true;

      await _chatRepository.sendTextMessage(
        chatId: chatId,
        senderUserId: currentUserId,
        text: message,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _scheduleScrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });
      _forceScrollToBottomOnNextMessages = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anhang konnte nicht gesendet werden: $error')),
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

      await _sendAttachmentTextMessage(message);
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
    try {
      final contact = await _nativeBridge.pickPhoneContact();

      if (contact == null) {
        return;
      }

      final phoneNumber = contact.phoneNumber.trim();

      if (phoneNumber.isEmpty) {
        throw StateError('Dieser Kontakt hat keine Telefonnummer.');
      }

      await _sendAttachmentTextMessage(
        'Kontakt\nName: ${contact.name}\nTelefon: $phoneNumber',
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
        const SnackBar(content: Text('Nachricht wurde gel\u00F6scht.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nachricht konnte nicht gel\u00F6scht werden: $error'),
        ),
      );
    }
  }

  Future<void> _handleSend() async {
    if (!_hasText || _isSendingMessage) {
      return;
    }

    final replyTarget = _replyingToMessage;
    final replyPrefix = _replyingToMessage == null
        ? ''
        : 'Antwort auf: "${_replyingToMessage!.text}"\n';
    final message = '$replyPrefix${_messageController.text.trim()}';

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
      });
      _scheduleScrollToBottom();

      _messageController.clear();
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Du musst angemeldet sein, um Nachrichten zu senden.'),
        ),
      );
      return;
    }

    setState(() {
      _isSendingMessage = true;
    });

    try {
      _forceScrollToBottomOnNextMessages = true;

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
      _scheduleScrollToBottom();
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
          content: Text('Nachricht konnte nicht gesendet werden: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    if (keyboardInset > _lastKeyboardInset) {
      _scheduleScrollToBottomAfterKeyboard();
    }

    _lastKeyboardInset = keyboardInset;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _CompactChatInfoCard(
                  displayName: widget.displayName,
                  profilePhotoUrl: widget.profilePhotoUrl,
                  vehicleModel: widget.vehicleModel,
                  vehicleColor: widget.vehicleColor,
                  onBack: () => Navigator.of(context).pop(),
                  chatId: widget.chatId,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  controller: _messageScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + keyboardInset),
                  child: Column(
                    children: [
                      if (_isLoadingMessages)
                        const _ChatLoadingSpace()
                      else if (_messages.isEmpty)
                        const _ChatEmptySpace()
                      else
                        _ChatMessageList(
                          messages: _messages,
                          onDeleteMessage: _handleDeleteMessage,
                          onReplyMessage: _handleReplyMessage,
                          onStarMessage: _handleStarMessage,
                          onReactMessage: _handleReactMessage,
                          onOpenLocation: _handleOpenLocation,
                        ),
                      if (_replyingToMessage != null)
                        _ReplyPreview(
                          message: _replyingToMessage!,
                          onClear: _clearReplyMessage,
                        ),
                      if (_isOtherUserTyping)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: _TypingIndicatorBubble(),
                        ),
                    ],
                  ),
                ),
              ),
              _MessageComposer(
                controller: _messageController,
                hasText: _hasText,
                onPickPhoto: () => _handlePickImage(ImageSource.gallery),
                onTakePhoto: () => _handlePickImage(ImageSource.camera),
                onShareLocation: _handleShareLocation,
                onShareContact: _handleShareContact,
                onSend: _handleSend,
                onTextInputFocus: _scheduleScrollToBottomAfterKeyboard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactChatInfoCard extends StatelessWidget {
  const _CompactChatInfoCard({
    required this.displayName,
    this.profilePhotoUrl,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.onBack,
    this.chatId,
  });

  final String displayName;
  final String? profilePhotoUrl;
  final String vehicleModel;
  final String vehicleColor;
  final VoidCallback onBack;
  final String? chatId;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 12),
              _UserAvatarPlaceholder(size: 46, imageUrl: profilePhotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              _ChatOverflowMenu(
                chatId: chatId,
                title: displayName,
                subtitle: ' \u00B7 ',
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _VehicleInfoPill(label: 'Modell', value: vehicleModel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VehicleInfoPill(label: 'Farbe', value: vehicleColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoPill extends StatelessWidget {
  const _VehicleInfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
