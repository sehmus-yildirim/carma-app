part of '../chats_screen.dart';

enum _ChatsView { chats, requests }

enum _ChatListView { messages, archived, blocked }

enum _RequestListView { incoming, outgoing }

enum _ChatMenuAction {
  pin,
  favorite,
  mute,
  readState,
  vehicleDetails,
  archive,
  delete,
  block,
  unblock,
  report,
}

enum _LocalChatTestMode { empty, activeChat, activeChatWithMessages }

const _LocalChatTestMode _localChatTestMode = _LocalChatTestMode.empty;

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final FirestoreContactRequestRepository _requestRepository =
      FirestoreContactRequestRepository();
  final TextEditingController _searchController = TextEditingController();

  _ChatsView _selectedView = _ChatsView.chats;
  _ChatListView _selectedChatListView = _ChatListView.messages;
  _RequestListView _selectedRequestListView = _RequestListView.incoming;
  String _searchQuery = '';
  final Set<String> _busyRequestIds = <String>{};

  late Stream<List<ChatRecord>> _chatStream;
  late Stream<List<ChatRecord>> _archivedChatStream;
  late Stream<List<ChatRecord>> _blockedChatStream;
  late Stream<List<ContactRequestRecord>> _incomingRequestStream;
  late Stream<List<ContactRequestRecord>> _outgoingRequestStream;
  late bool _hasActiveChat;
  late List<_LocalChatMessage> _chatMessages;

  AppFeatureDecision get _chatGateDecision {
    return AppFeatureGate.evaluate(
      userState: widget.userState,
      feature: AppFeature.chat,
    );
  }

  String get _effectiveUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
  }

  @override
  void initState() {
    super.initState();
    _hasActiveChat =
        _localChatTestMode == _LocalChatTestMode.activeChat ||
        _localChatTestMode == _LocalChatTestMode.activeChatWithMessages;

    _chatMessages =
        _localChatTestMode == _LocalChatTestMode.activeChatWithMessages
        ? _buildLocalChatMessages()
        : <_LocalChatMessage>[];

    _chatStream = _watchChats();
    _archivedChatStream = _watchArchivedChats();
    _blockedChatStream = _watchBlockedChats();
    _incomingRequestStream = _watchIncomingRequests();
    _outgoingRequestStream = _watchOutgoingRequests();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<ChatRecord>> _watchChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchChats(userId: userId);
  }

  Stream<List<ChatRecord>> _watchArchivedChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchArchivedChats(userId: userId);
  }

  Stream<List<ChatRecord>> _watchBlockedChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchBlockedChats(userId: userId);
  }

  Stream<List<ContactRequestRecord>> _watchIncomingRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    return _requestRepository.watchIncomingRequests(userId: userId);
  }

  Stream<List<ContactRequestRecord>> _watchOutgoingRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ContactRequestRecord>>.value(
        const <ContactRequestRecord>[],
      );
    }

    return _requestRepository.watchOutgoingRequests(userId: userId);
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim();

    if (_searchQuery == nextQuery) {
      return;
    }

    setState(() {
      _searchQuery = nextQuery;
    });
  }

  bool _matchesSearch(String value) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return value.toLowerCase().contains(query);
  }

  bool _matchesChatSearch(ChatRecord chat) {
    final currentUserId = _effectiveUserId;

    return _matchesSearch(
      [
        chat.displayNameFor(currentUserId),
        chat.vehicleTitle,
        chat.vehicleModelLabel,
        chat.vehicleColorLabel,
        chat.displayPlate,
        chat.lastMessage,
      ].whereType<String>().join(' '),
    );
  }

  bool _matchesRequestSearch(ContactRequestRecord request) {
    return _matchesSearch(
      [
        request.senderDisplayName,
        request.receiverDisplayName,
        request.displayPlate,
        request.plateKey,
        request.vehicleTitle,
        request.message,
      ].whereType<String>().join(' '),
    );
  }

  List<_LocalChatMessage> _buildLocalChatMessages() {
    return const [
      _LocalChatMessage(
        text:
            'Hey, ich bin gerade an deinem Fahrzeug vorbeigefahren. Dein Fenster scheint noch offen zu sein.',
        isMine: false,
        timeLabel: '14:21',
      ),
      _LocalChatMessage(
        text: 'Danke dir f\u00FCr den Hinweis. Ich schaue sofort nach.',
        isMine: true,
        timeLabel: '14:23',
      ),
      _LocalChatMessage(
        text: 'Gerne. Ich wollte nur kurz Bescheid geben.',
        isMine: false,
        timeLabel: '14:24',
      ),
    ];
  }

  void _selectView(_ChatsView view) {
    if (_selectedView == view) {
      return;
    }

    setState(() {
      _selectedView = view;
    });
  }

  void _handleViewSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0 && _selectedView == _ChatsView.chats) {
      _selectView(_ChatsView.requests);
      return;
    }

    if (velocity > 0 && _selectedView == _ChatsView.requests) {
      _selectView(_ChatsView.chats);
    }
  }

  void _selectChatListView(_ChatListView view) {
    if (_selectedChatListView == view) {
      return;
    }

    setState(() {
      _selectedChatListView = view;
    });
  }

  void _handleChatListSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0 && _selectedChatListView == _ChatListView.messages) {
      _selectChatListView(_ChatListView.archived);
      return;
    }

    if (velocity < 0 && _selectedChatListView == _ChatListView.archived) {
      _selectChatListView(_ChatListView.blocked);
      return;
    }

    if (velocity > 0 && _selectedChatListView == _ChatListView.archived) {
      _selectChatListView(_ChatListView.messages);
      return;
    }

    if (velocity > 0 && _selectedChatListView == _ChatListView.blocked) {
      _selectChatListView(_ChatListView.archived);
    }
  }

  void _selectRequestListView(_RequestListView view) {
    if (_selectedRequestListView == view) {
      return;
    }

    setState(() {
      _selectedRequestListView = view;
    });
  }

  void _handleRequestListSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    if (velocity < 0 && _selectedRequestListView == _RequestListView.incoming) {
      _selectRequestListView(_RequestListView.outgoing);
      return;
    }

    if (velocity > 0 && _selectedRequestListView == _RequestListView.outgoing) {
      _selectRequestListView(_RequestListView.incoming);
    }
  }

  void _refreshChatsAndRequests() {
    setState(() {
      _chatStream = _watchChats();
      _archivedChatStream = _watchArchivedChats();
      _blockedChatStream = _watchBlockedChats();
      _incomingRequestStream = _watchIncomingRequests();
      _outgoingRequestStream = _watchOutgoingRequests();
    });
  }

  Future<void> _openChat(ChatRecord chat) async {
    final currentUserId = _effectiveUserId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          chatId: chat.id,
          initialMessages: const <_LocalChatMessage>[],
          displayName: chat.displayNameFor(currentUserId),
          profilePhotoUrl: chat.profilePhotoUrlFor(currentUserId),
          vehicleModel: chat.vehicleModelLabel,
          vehicleColor: chat.vehicleColorLabel,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();

    _refreshChatsAndRequests();
  }

  Future<void> _openLocalChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(initialMessages: _chatMessages),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
  }

  Future<void> _openAcceptedChat(String chatId) async {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          chatId: trimmedChatId,
          initialMessages: const <_LocalChatMessage>[],
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
  }

  Future<void> _runRequestAction({
    required ContactRequestRecord request,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      _refreshChatsAndRequests();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _acceptRequest(ContactRequestRecord request) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      final useCase = AcceptContactRequestUseCase(
        contactRequestRepository: _requestRepository,
        chatRepository: _chatRepository,
      );

      final result = await useCase(request: request);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontaktanfrage wurde angenommen.')),
      );
      _refreshChatsAndRequests();
      await _openAcceptedChat(result.chat.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _declineRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage: 'Kontaktanfrage wurde abgelehnt.',
      action: () async {
        await _requestRepository.declineRequest(requestId: request.id);
      },
    );
  }

  Future<void> _withdrawRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage: 'Kontaktanfrage wurde zurückgezogen.',
      action: () async {
        await _requestRepository.withdrawRequest(requestId: request.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final chatGateDecision = _chatGateDecision;

    return CarmaBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CarmaPageHeader(
                icon: Icons.chat_bubble_rounded,
                title: 'Chats',
              ),
              const SizedBox(height: 22),
              if (!chatGateDecision.isAllowed)
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _ChatAccessBlockedCard(
                      message:
                          chatGateDecision.reason ??
                          'Chats sind aktuell nicht verf\u00FCgbar.',
                    ),
                  ),
                )
              else ...[
                _ChatsSegmentedControl(
                  selectedView: _selectedView,
                  onChanged: _selectView,
                ),
                const SizedBox(height: 14),
                _ChatSearchField(controller: _searchController),
                const SizedBox(height: 16),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: _handleViewSwipe,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _selectedView == _ChatsView.chats
                          ? StreamBuilder<List<ChatRecord>>(
                              key: const ValueKey('chats_view'),
                              stream: _chatStream,
                              builder: (context, snapshot) {
                                final chats =
                                    snapshot.data ?? const <ChatRecord>[];
                                final isLoading =
                                    snapshot.connectionState ==
                                    ConnectionState.waiting;

                                return StreamBuilder<List<ChatRecord>>(
                                  stream: _archivedChatStream,
                                  builder: (context, archivedSnapshot) {
                                    final archivedChats =
                                        archivedSnapshot.data ??
                                        const <ChatRecord>[];
                                    final isArchivedLoading =
                                        archivedSnapshot.connectionState ==
                                        ConnectionState.waiting;

                                    return StreamBuilder<List<ChatRecord>>(
                                      stream: _blockedChatStream,
                                      builder: (context, blockedSnapshot) {
                                        final blockedChats =
                                            blockedSnapshot.data ??
                                            const <ChatRecord>[];
                                        final isBlockedLoading =
                                            blockedSnapshot.connectionState ==
                                            ConnectionState.waiting;

                                        return _ChatsOverview(
                                          chats: chats,
                                          archivedChats: archivedChats,
                                          blockedChats: blockedChats,
                                          isLoading:
                                              isLoading ||
                                              isArchivedLoading ||
                                              isBlockedLoading,
                                          hasLocalActiveChat: _hasActiveChat,
                                          localMessages: _chatMessages,
                                          searchQuery: _searchQuery,
                                          selectedListView:
                                              _selectedChatListView,
                                          matchesChat: _matchesChatSearch,
                                          onListViewChanged:
                                              _selectChatListView,
                                          onHorizontalSwipe:
                                              _handleChatListSwipe,
                                          onOpenChat: _openChat,
                                          onOpenLocalChat: _openLocalChat,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : _RequestsOverview(
                              key: const ValueKey('requests_view'),
                              incomingStream: _incomingRequestStream,
                              outgoingStream: _outgoingRequestStream,
                              busyRequestIds: _busyRequestIds,
                              searchQuery: _searchQuery,
                              selectedListView: _selectedRequestListView,
                              matchesRequest: _matchesRequestSearch,
                              onListViewChanged: _selectRequestListView,
                              onHorizontalSwipe: _handleRequestListSwipe,
                              onAccept: _acceptRequest,
                              onDecline: _declineRequest,
                              onWithdraw: _withdrawRequest,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
