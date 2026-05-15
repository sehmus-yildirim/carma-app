import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carma_models.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/chat_repository.dart';
import '../data/contact_request_repository.dart';
import '../domain/accept_contact_request_use_case.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

const Color _myMessageBlueDark = Color(0xFF03172F);
const Color _myMessageBlue = Color(0xFF08264A);
const Color _myMessageBlueLight = Color(0xFF0D3566);
const Color _myMessageBorder = Color(0xFF164A86);
const Color _myMessageCheckBlue = Color(0xFF7FD6FF);

enum _ChatsView { chats, requests }

enum _ChatListView { messages, archived }

enum _RequestListView { incoming, outgoing }

enum _ChatMenuAction {
  favorite,
  mute,
  vehicleDetails,
  archive,
  delete,
  block,
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

    if (velocity > 0 && _selectedChatListView == _ChatListView.archived) {
      _selectChatListView(_ChatListView.messages);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CarmaPageHeader(
                      icon: Icons.chat_bubble_rounded,
                      title: 'Chats',
                    ),
                    const SizedBox(height: 22),
                    if (!chatGateDecision.isAllowed)
                      _ChatAccessBlockedCard(
                        message:
                            chatGateDecision.reason ??
                            'Chats sind aktuell nicht verf\u00FCgbar.',
                      )
                    else ...[
                      _ChatsSegmentedControl(
                        selectedView: _selectedView,
                        onChanged: _selectView,
                      ),
                      const SizedBox(height: 14),
                      _ChatSearchField(controller: _searchController),
                      const SizedBox(height: 16),
                      GestureDetector(
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

                                        return _ChatsOverview(
                                          chats: chats,
                                          archivedChats: archivedChats,
                                          isLoading:
                                              isLoading || isArchivedLoading,
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
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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
    this.isStarred = false,
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
  final Map<String, String> reactionBy;

  _LocalChatMessage copyWith({
    String? text,
    bool? isMine,
    String? timeLabel,
    DateTime? createdAt,
    String? messageId,
    bool? isReadByOther,
    String? replyToText,
    bool? isStarred,
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
      reactionBy: reactionBy ?? this.reactionBy,
    );
  }
}

class _ChatAccessBlockedCard extends StatelessWidget {
  const _ChatAccessBlockedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: Icons.lock_outline_rounded,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chats nicht verf\u00FCgbar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.34,
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

class _ChatsSegmentedControl extends StatelessWidget {
  const _ChatsSegmentedControl({
    required this.selectedView,
    required this.onChanged,
  });

  final _ChatsView selectedView;
  final ValueChanged<_ChatsView> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Chats',
              icon: Icons.forum_rounded,
              isSelected: selectedView == _ChatsView.chats,
              onTap: () => onChanged(_ChatsView.chats),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SegmentButton(
              label: 'Anfragen',
              icon: Icons.mark_chat_unread_rounded,
              isSelected: selectedView == _ChatsView.requests,
              onTap: () => onChanged(_ChatsView.requests),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _myMessageBlueDark,
                      _myMessageBlue,
                      _myMessageBlueLight,
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _carmaBlue.withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Suchen',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.58),
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }

            return IconButton(
              onPressed: controller.clear,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
              tooltip: 'Suche löschen',
            );
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ChatsOverview extends StatelessWidget {
  const _ChatsOverview({
    required this.chats,
    required this.archivedChats,
    required this.isLoading,
    required this.hasLocalActiveChat,
    required this.localMessages,
    required this.searchQuery,
    required this.selectedListView,
    required this.matchesChat,
    required this.onListViewChanged,
    required this.onHorizontalSwipe,
    required this.onOpenChat,
    required this.onOpenLocalChat,
  });

  final List<ChatRecord> chats;
  final List<ChatRecord> archivedChats;
  final bool isLoading;
  final bool hasLocalActiveChat;
  final List<_LocalChatMessage> localMessages;
  final String searchQuery;
  final _ChatListView selectedListView;
  final bool Function(ChatRecord chat) matchesChat;
  final ValueChanged<_ChatListView> onListViewChanged;
  final GestureDragEndCallback onHorizontalSwipe;
  final ValueChanged<ChatRecord> onOpenChat;
  final VoidCallback onOpenLocalChat;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final visibleChats = chats.where(matchesChat).toList();
    final visibleArchivedChats = archivedChats.where(matchesChat).toList();
    final isArchivedView = selectedListView == _ChatListView.archived;
    final selectedChats = isArchivedView ? visibleArchivedChats : visibleChats;
    final showLocalChat =
        !isArchivedView &&
        hasLocalActiveChat &&
        (searchQuery.trim().isEmpty ||
            'carma nutzer bmw 1er schwarz ${localMessages.map((message) => message.text).join(' ')}'
                .toLowerCase()
                .contains(searchQuery.trim().toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChatStoriesStrip(chats: visibleChats),
        const SizedBox(height: 16),
        _InlineTextTabs<_ChatListView>(
          selectedValue: selectedListView,
          items: const [
            _InlineTextTabItem(
              value: _ChatListView.messages,
              label: 'Nachrichten',
            ),
            _InlineTextTabItem(
              value: _ChatListView.archived,
              label: 'Archiviert',
            ),
          ],
          onChanged: onListViewChanged,
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const _InlineLoadingRow(label: 'Chats werden geladen...')
        else if (selectedChats.isEmpty && !showLocalChat)
          _EmptyListCard(
            icon: isArchivedView
                ? Icons.archive_outlined
                : Icons.chat_bubble_outline_rounded,
            title: isArchivedView ? 'Keine archivierten Chats' : 'Keine Chats',
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: onHorizontalSwipe,
            child: Column(
              children: [
                for (final chat in selectedChats) ...[
                  _ActiveChatListTile(
                    title: chat.displayNameFor(currentUserId),
                    subtitle: chat.lastMessage?.trim().isNotEmpty == true
                        ? chat.lastMessage!.trim()
                        : chat.vehicleTitle,
                    isFavorite: chat.isFavoriteFor(currentUserId),
                    isMuted: chat.isMutedFor(currentUserId),
                    isUnread: chat.hasUnreadFor(currentUserId),
                    trailing: _ChatOverflowMenu(
                      chatId: chat.id,
                      title: chat.displayNameFor(currentUserId),
                      subtitle: chat.vehicleTitle,
                      isFavorite: chat.isFavoriteFor(currentUserId),
                      isMuted: chat.isMutedFor(currentUserId),
                      isArchived: isArchivedView,
                      popAfterStatusAction: false,
                    ),
                    onTap: () => onOpenChat(chat),
                  ),
                  const SizedBox(height: 6),
                ],
                if (showLocalChat)
                  _ActiveChatListTile(
                    title: 'Carma Nutzer',
                    subtitle: localMessages.isNotEmpty
                        ? localMessages.last.text
                        : 'BMW 1er · Schwarz',
                    trailing: const _ChatOverflowMenu(
                      title: 'Carma Nutzer',
                      subtitle: 'BMW 1er · Schwarz',
                      popAfterStatusAction: false,
                    ),
                    onTap: onOpenLocalChat,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RequestsOverview extends StatelessWidget {
  const _RequestsOverview({
    required this.incomingStream,
    required this.outgoingStream,
    required this.busyRequestIds,
    required this.searchQuery,
    required this.selectedListView,
    required this.matchesRequest,
    required this.onListViewChanged,
    required this.onHorizontalSwipe,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
    super.key,
  });

  final Stream<List<ContactRequestRecord>> incomingStream;
  final Stream<List<ContactRequestRecord>> outgoingStream;
  final Set<String> busyRequestIds;
  final String searchQuery;
  final _RequestListView selectedListView;
  final bool Function(ContactRequestRecord request) matchesRequest;
  final ValueChanged<_RequestListView> onListViewChanged;
  final GestureDragEndCallback onHorizontalSwipe;
  final ValueChanged<ContactRequestRecord> onAccept;
  final ValueChanged<ContactRequestRecord> onDecline;
  final ValueChanged<ContactRequestRecord> onWithdraw;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactRequestRecord>>(
      stream: incomingStream,
      builder: (context, incomingSnapshot) {
        return StreamBuilder<List<ContactRequestRecord>>(
          stream: outgoingStream,
          builder: (context, outgoingSnapshot) {
            final incoming =
                (incomingSnapshot.data ?? const <ContactRequestRecord>[])
                    .where(matchesRequest)
                    .toList();
            final outgoing =
                (outgoingSnapshot.data ?? const <ContactRequestRecord>[])
                    .where(matchesRequest)
                    .toList();
            final isLoading =
                incomingSnapshot.connectionState == ConnectionState.waiting ||
                outgoingSnapshot.connectionState == ConnectionState.waiting;
            final error = incomingSnapshot.error ?? outgoingSnapshot.error;

            if (error != null) {
              return _InlineErrorCard(message: error.toString());
            }

            final isIncomingView =
                selectedListView == _RequestListView.incoming;
            final selectedRequests = isIncomingView ? incoming : outgoing;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InlineTextTabs<_RequestListView>(
                  selectedValue: selectedListView,
                  items: [
                    _InlineTextTabItem(
                      value: _RequestListView.incoming,
                      label: 'Eingehend',
                      count: incoming.length,
                    ),
                    _InlineTextTabItem(
                      value: _RequestListView.outgoing,
                      label: 'Gesendet',
                      count: outgoing.length,
                    ),
                  ],
                  onChanged: onListViewChanged,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: onHorizontalSwipe,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isLoading
                        ? const _InlineLoadingRow(
                            label: 'Anfragen werden geladen...',
                          )
                        : selectedRequests.isEmpty
                        ? _EmptyListCard(
                            key: ValueKey(selectedListView),
                            icon: isIncomingView
                                ? Icons.mark_email_unread_outlined
                                : Icons.schedule_send_outlined,
                            title: isIncomingView
                                ? 'Keine eingehenden Anfragen'
                                : 'Keine gesendeten Anfragen',
                          )
                        : _InlineRequestList(
                            key: ValueKey(selectedListView),
                            requests: selectedRequests,
                            isIncoming: isIncomingView,
                            busyRequestIds: busyRequestIds,
                            onAccept: onAccept,
                            onDecline: onDecline,
                            onWithdraw: onWithdraw,
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InlineTextTabItem<T> {
  const _InlineTextTabItem({
    required this.value,
    required this.label,
    this.count,
  });

  final T value;
  final String label;
  final int? count;
}

class _InlineTextTabs<T> extends StatelessWidget {
  const _InlineTextTabs({
    required this.selectedValue,
    required this.items,
    required this.onChanged,
  });

  final T selectedValue;
  final List<_InlineTextTabItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items) ...[
          _InlineTextTab<T>(
            item: item,
            isSelected: item.value == selectedValue,
            onTap: () => onChanged(item.value),
          ),
          if (item != items.last) const SizedBox(width: 22),
        ],
      ],
    );
  }
}

class _InlineTextTab<T> extends StatelessWidget {
  const _InlineTextTab({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _InlineTextTabItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.48);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (item.count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 24,
                    constraints: const BoxConstraints(minWidth: 24),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _carmaBlue.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? _carmaBlueLight.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '${item.count}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: isSelected ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: _carmaBlueLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStoriesStrip extends StatelessWidget {
  const _ChatStoriesStrip({required this.chats});

  final List<ChatRecord> chats;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final storyChats = chats.take(12).toList();

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: storyChats.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _StoryBubble(
              label: 'Deine Story',
              imageUrl: null,
              isOwnStory: true,
            );
          }

          final chat = storyChats[index - 1];
          return _StoryBubble(
            label: chat.displayNameFor(currentUserId),
            imageUrl: null,
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    this.imageUrl,
    this.isOwnStory = false,
  });

  final String label;
  final String? imageUrl;
  final bool isOwnStory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 66,
                height: 66,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_carmaBlueDark, _carmaBlueLight],
                  ),
                ),
                child: _AvatarCircle(
                  size: 62,
                  imageUrl: imageUrl,
                  iconSize: 34,
                ),
              ),
              if (isOwnStory)
                Positioned(
                  right: -2,
                  bottom: -1,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _carmaBlue,
                      border: Border.all(
                        color: const Color(0xFF101827),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadingRow extends StatelessWidget {
  const _InlineLoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.76),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineRequestList extends StatelessWidget {
  const _InlineRequestList({
    required this.requests,
    required this.isIncoming,
    required this.busyRequestIds,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
    super.key,
  });

  final List<ContactRequestRecord> requests;
  final bool isIncoming;
  final Set<String> busyRequestIds;
  final ValueChanged<ContactRequestRecord> onAccept;
  final ValueChanged<ContactRequestRecord> onDecline;
  final ValueChanged<ContactRequestRecord> onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final request in requests) ...[
          _InlineRequestTile(
            request: request,
            isIncoming: isIncoming,
            isBusy: busyRequestIds.contains(request.id),
            onAccept: () => onAccept(request),
            onDecline: () => onDecline(request),
            onWithdraw: () => onWithdraw(request),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InlineRequestTile extends StatelessWidget {
  const _InlineRequestTile({
    required this.request,
    required this.isIncoming,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
  });

  final ContactRequestRecord request;
  final bool isIncoming;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;

  String get _brand {
    final brand = request.vehicleBrand?.trim();
    return brand == null || brand.isEmpty ? 'Automarke' : brand;
  }

  String get _model {
    final model = request.vehicleModel?.trim();
    return model == null || model.isEmpty ? 'Automodell' : model;
  }

  String get _color {
    final color = request.vehicleColor?.trim();
    return color == null || color.isEmpty ? 'Farbe unbekannt' : color;
  }

  String get _plate {
    final plate = request.displayPlate?.trim();
    final rawPlate = plate == null || plate.isEmpty ? request.plateKey : plate;
    return _formatPlate(rawPlate);
  }

  String get _incomingMessage {
    final vehicle = [
      if (request.vehicleColor != null &&
          request.vehicleColor!.trim().isNotEmpty)
        _vehicleColorAdjective(request.vehicleColor!),
      if (request.vehicleBrand != null &&
          request.vehicleBrand!.trim().isNotEmpty)
        request.vehicleBrand!.trim(),
      if (request.vehicleModel != null &&
          request.vehicleModel!.trim().isNotEmpty)
        request.vehicleModel!.trim(),
    ].join(' ').trim();

    if (vehicle.isEmpty) {
      return 'Hey, ich bin der Fahrer dieses Fahrzeugs.';
    }

    return 'Hey, ich bin der Fahrer im $vehicle.';
  }

  static String _vehicleColorAdjective(String color) {
    return switch (color.trim().toLowerCase()) {
      'schwarz' => 'schwarzen',
      'weiss' || 'weiß' => 'weißen',
      'silber' => 'silbernen',
      'grau' => 'grauen',
      'blau' => 'blauen',
      'rot' => 'roten',
      'gruen' || 'grün' => 'grünen',
      'braun' => 'braunen',
      'gelb' => 'gelben',
      'orange' => 'orangenen',
      _ => color.trim(),
    };
  }

  static String _formatPlate(String value) {
    final normalized = value.trim().toUpperCase();

    if (normalized.isEmpty) {
      return '-';
    }

    if (normalized.contains('-') || normalized.contains(' ')) {
      return normalized.replaceAll(RegExp(r'\s+'), ' ');
    }

    final match = RegExp(
      r'^([A-ZÄÖÜ]{2,4})([0-9]{1,4})$',
    ).firstMatch(normalized);

    if (match == null) {
      return normalized;
    }

    final letters = match.group(1)!;
    final numbers = match.group(2)!;
    final regionLength = letters.length >= 4 ? 2 : 1;
    final region = letters.substring(0, regionLength);
    final serial = letters.substring(regionLength);

    if (serial.isEmpty) {
      return '$region $numbers';
    }

    return '$region-$serial $numbers';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _carmaBlue.withValues(alpha: 0.16),
              border: Border.all(
                color: _carmaBlueLight.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              isIncoming
                  ? Icons.mark_email_unread_rounded
                  : Icons.schedule_send_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _color,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (isIncoming) ...[
                  const SizedBox(height: 8),
                  Text(
                    _incomingMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                isIncoming
                    ? Row(
                        children: [
                          Expanded(
                            child: _InlineRequestButton(
                              label: 'Annehmen',
                              icon: Icons.check_rounded,
                              isBusy: isBusy,
                              isPrimary: true,
                              onPressed: onAccept,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InlineRequestButton(
                              label: 'Ablehnen',
                              icon: Icons.close_rounded,
                              isBusy: isBusy,
                              isPrimary: false,
                              onPressed: onDecline,
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: _InlineRequestButton(
                          label: 'Zurückziehen',
                          icon: Icons.undo_rounded,
                          isBusy: isBusy,
                          isPrimary: false,
                          onPressed: onWithdraw,
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

class _InlineRequestButton extends StatelessWidget {
  const _InlineRequestButton({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isBusy;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBusy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    if (isPrimary) {
      return FilledButton(
        onPressed: isBusy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _carmaBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _carmaBlue.withValues(alpha: 0.32),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.62),
          minimumSize: const Size(0, 44),
          shape: shape,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
        minimumSize: const Size(0, 44),
        shape: shape,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

class _ChatOverflowMenu extends StatelessWidget {
  static final FirestoreChatRepository _chatRepository =
      FirestoreChatRepository();

  const _ChatOverflowMenu({
    this.chatId,
    this.title,
    this.subtitle,
    this.isFavorite = false,
    this.isMuted = false,
    this.isArchived = false,
    this.popAfterStatusAction = true,
  });

  final String? chatId;
  final String? title;
  final String? subtitle;
  final bool isFavorite;
  final bool isMuted;
  final bool isArchived;
  final bool popAfterStatusAction;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showVehicleDetails(BuildContext context) async {
    final safeTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Carma Nutzer';

    final safeSubtitle = subtitle?.trim().isNotEmpty == true
        ? subtitle!.trim()
        : 'Fahrzeugdetails sind aktuell nicht verf\u00FCgbar.';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fahrzeugdetails'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                safeTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(safeSubtitle),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schlie\u00DFen'),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required String resultMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      _showSnackBar(context, resultMessage);
    }
  }

  Future<void> _runReportAction(BuildContext context) async {
    final id = chatId?.trim();

    if (id == null || id.isEmpty) {
      _showSnackBar(
        context,
        'Diese Aktion ist f\u00FCr lokale Beispielchats noch nicht verf\u00FCgbar.',
      );
      return;
    }

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          title: const Text(
            'Nutzer melden?',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Grund optional eingeben',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Melden'),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (confirmed != true) {
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      await _chatRepository.reportChat(
        chatId: id,
        reporterUserId: currentUserId,
        reason: reason.isEmpty ? 'Chat gemeldet' : reason,
      );

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Meldung wurde gesendet.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Meldung konnte nicht gesendet werden: $error');
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    _ChatMenuAction action,
  ) async {
    switch (action) {
      case _ChatMenuAction.favorite:
        final nextIsFavorite = !isFavorite;
        await _runChatPreferenceAction(
          context: context,
          successMessage: nextIsFavorite
              ? 'Chat wurde zu Favoriten hinzugefuegt.'
              : 'Chat wurde aus Favoriten entfernt.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatFavorite(
              chatId: chatId,
              userId: userId,
              isFavorite: nextIsFavorite,
            );
          },
        );
      case _ChatMenuAction.mute:
        final nextIsMuted = !isMuted;
        await _runChatPreferenceAction(
          context: context,
          successMessage: nextIsMuted
              ? 'Chat wurde stummgeschaltet.'
              : 'Benachrichtigungen wurden eingeschaltet.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatMuted(
              chatId: chatId,
              userId: userId,
              isMuted: nextIsMuted,
            );
          },
        );
      case _ChatMenuAction.vehicleDetails:
        await _showVehicleDetails(context);
      case _ChatMenuAction.archive:
        await _runChatStatusAction(
          context: context,
          title: isArchived ? 'Chat aus Archiv holen?' : 'Chat archivieren?',
          message: isArchived
              ? 'Der Chat wird wieder in deiner aktiven \u00DCbersicht angezeigt.'
              : 'Der Chat wird aus der aktiven \u00DCbersicht entfernt, bleibt aber f\u00FCr Sicherheit und Meldungen nachvollziehbar.',
          confirmLabel: isArchived ? 'Zur\u00FCckholen' : 'Archivieren',
          successMessage: isArchived
              ? 'Chat wurde aus dem Archiv geholt.'
              : 'Chat wurde archiviert.',
          action: () async {
            final id = chatId?.trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            if (currentUserId == null || currentUserId.isEmpty) {
              throw StateError('Du musst angemeldet sein.');
            }

            if (isArchived) {
              await _chatRepository.unarchiveChat(
                chatId: id,
                userId: currentUserId,
              );
            } else {
              await _chatRepository.archiveChat(
                chatId: id,
                userId: currentUserId,
              );
            }
          },
        );
      case _ChatMenuAction.delete:
        await _runChatStatusAction(
          context: context,
          title: 'Chat l\u00F6schen?',
          message:
              'Der Chat wird aus deiner aktiven \u00DCbersicht entfernt. Sicherheitsrelevante Daten k\u00F6nnen gesch\u00FCtzt erhalten bleiben.',
          confirmLabel: 'L\u00F6schen',
          successMessage: 'Chat wurde gel\u00F6scht.',
          action: () async {
            final id = chatId?.trim();

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            await _chatRepository.deleteChat(chatId: id);
          },
        );
      case _ChatMenuAction.block:
        await _runChatStatusAction(
          context: context,
          title: 'Nutzer blockieren?',
          message:
              'Blockierte Nutzer k\u00F6nnen dich nicht mehr \u00FCber diesen Chat kontaktieren.',
          confirmLabel: 'Blockieren',
          successMessage: 'Nutzer wurde blockiert.',
          action: () async {
            final id = chatId?.trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            if (currentUserId == null || currentUserId.isEmpty) {
              throw StateError('Du musst angemeldet sein.');
            }

            await _chatRepository.blockChat(
              chatId: id,
              blockedByUserId: currentUserId,
            );
          },
        );
      case _ChatMenuAction.report:
        await _runReportAction(context);
    }
  }

  Future<void> _runChatPreferenceAction({
    required BuildContext context,
    required Future<void> Function({
      required String chatId,
      required String userId,
    })
    action,
    required String successMessage,
  }) async {
    final id = chatId?.trim();

    if (id == null || id.isEmpty) {
      _showSnackBar(
        context,
        'Diese Aktion ist f\u00FCr lokale Beispielchats noch nicht verf\u00FCgbar.',
      );
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      await action(chatId: id, userId: currentUserId);

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, successMessage);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Aktion konnte nicht ausgef\u00FChrt werden: $error',
      );
    }
  }

  Future<void> _runChatStatusAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final id = chatId?.trim();

    if (id == null || id.isEmpty) {
      _showSnackBar(
        context,
        'Diese Aktion ist f\u00FCr lokale Beispielchats noch nicht verf\u00FCgbar.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.76)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await action();

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, successMessage);
      if (popAfterStatusAction) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Aktion konnte nicht ausgef\u00FChrt werden: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChatMenuAction>(
      tooltip: 'Chat-Einstellungen',
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
      color: const Color(0xFF101827),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: _ChatMenuAction.favorite,
            child: Text(
              isFavorite
                  ? 'Aus Favoriten entfernen'
                  : 'Zu Favoriten hinzufuegen',
            ),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.mute,
            child: Text(
              isMuted
                  ? 'Benachrichtigungen einschalten'
                  : 'Benachrichtigungen stummschalten',
            ),
          ),
          const PopupMenuItem(
            value: _ChatMenuAction.vehicleDetails,
            child: Text('Fahrzeugdetails anzeigen'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.archive,
            child: Text(isArchived ? 'Aus Archiv holen' : 'Chat archivieren'),
          ),
          const PopupMenuItem(
            value: _ChatMenuAction.delete,
            child: Text('Chat l\u00F6schen'),
          ),
          const PopupMenuItem(
            value: _ChatMenuAction.block,
            child: Text('Nutzer blockieren'),
          ),
          const PopupMenuItem(
            value: _ChatMenuAction.report,
            child: Text('Nutzer melden'),
          ),
        ];
      },
    );
  }
}

// ignore: unused_element
class _ActiveChatsScreen extends StatelessWidget {
  const _ActiveChatsScreen({
    required this.chatStream,
    required this.initialChats,
    required this.hasLocalActiveChat,
    required this.messages,
  });

  final Stream<List<ChatRecord>> chatStream;
  final List<ChatRecord> initialChats;
  final bool hasLocalActiveChat;
  final List<_LocalChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRecord>>(
      stream: chatStream,
      initialData: initialChats,
      builder: (context, snapshot) {
        final chats = snapshot.data ?? initialChats;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

        if (chats.isNotEmpty) {
          return _SubPageScaffold(
            icon: Icons.forum_rounded,
            headerTitle: 'Aktive Chats',
            child: Column(
              children: [
                for (final chat in chats) ...[
                  _ActiveChatListTile(
                    title: chat.displayNameFor(currentUserId),
                    subtitle: chat.lastMessage?.trim().isNotEmpty == true
                        ? 'Letzte Nachricht: ${chat.lastMessage!.trim()}'
                        : chat.vehicleTitle,
                    isFavorite: chat.isFavoriteFor(currentUserId),
                    isMuted: chat.isMutedFor(currentUserId),
                    isUnread: chat.hasUnreadFor(currentUserId),
                    trailing: _ChatOverflowMenu(
                      chatId: chat.id,
                      title: chat.displayNameFor(currentUserId),
                      subtitle: chat.vehicleTitle,
                      isFavorite: chat.isFavoriteFor(currentUserId),
                      isMuted: chat.isMutedFor(currentUserId),
                      popAfterStatusAction: false,
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ChatConversationScreen(
                            chatId: chat.id,
                            initialMessages: const <_LocalChatMessage>[],
                            displayName: chat.displayNameFor(currentUserId),
                            vehicleModel: chat.vehicleModelLabel,
                            vehicleColor: chat.vehicleColorLabel,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        }

        return _SubPageScaffold(
          icon: Icons.forum_rounded,
          headerTitle: 'Aktive Chats',
          child: hasLocalActiveChat
              ? _ActiveChatListTile(
                  title: 'Carma Nutzer',
                  subtitle: messages.isNotEmpty
                      ? 'Letzte Nachricht: ${messages.last.text}'
                      : 'BMW 1er · Schwarz',
                  trailing: const _ChatOverflowMenu(
                    title: 'Carma Nutzer',
                    subtitle: 'BMW 1er · Schwarz',
                    popAfterStatusAction: false,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _ChatConversationScreen(initialMessages: messages),
                      ),
                    );
                  },
                )
              : const _EmptyListCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Noch keine aktiven Chats',
                ),
        );
      },
    );
  }
}

class _SubPageScaffold extends StatelessWidget {
  const _SubPageScaffold({
    required this.icon,
    required this.headerTitle,
    required this.child,
  });

  final IconData icon;
  final String headerTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmaSubPageHeader(
                  icon: icon,
                  title: headerTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveChatListTile extends StatelessWidget {
  const _ActiveChatListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFavorite = false,
    this.isMuted = false,
    this.isUnread = false,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool isFavorite;
  final bool isMuted;
  final bool isUnread;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasStateIcons = isFavorite || isMuted || isUnread;
    final stateIcons = <Widget>[
      if (isUnread)
        const _ChatStateIcon(
          icon: Icons.mark_chat_unread_rounded,
          tooltip: 'Ungelesen',
        ),
      if (isUnread && (isFavorite || isMuted)) const SizedBox(width: 6),
      if (isFavorite)
        const _ChatStateIcon(icon: Icons.star_rounded, tooltip: 'Favorit'),
      if (isFavorite && isMuted) const SizedBox(width: 6),
      if (isMuted)
        const _ChatStateIcon(
          icon: Icons.notifications_off_rounded,
          tooltip: 'Stummgeschaltet',
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Row(
            children: [
              const _UserAvatarPlaceholder(size: 48, imageUrl: null),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                          ),
                        ),
                        if (hasStateIcons) ...[
                          const SizedBox(width: 8),
                          ...stateIcons,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatStateIcon extends StatelessWidget {
  const _ChatStateIcon({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.09),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.84),
          size: 16,
        ),
      ),
    );
  }
}

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.58),
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatarPlaceholder extends StatelessWidget {
  const _UserAvatarPlaceholder({required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_carmaBlueDark, _carmaBlueLight],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: _AvatarCircle(
        size: size,
        imageUrl: imageUrl,
        iconSize: size * 0.56,
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.size,
    required this.iconSize,
    this.imageUrl,
  });

  final double size;
  final double iconSize;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallbackIcon(size: iconSize),
              )
            : _AvatarFallbackIcon(size: iconSize),
      ),
    );
  }
}

class _AvatarFallbackIcon extends StatelessWidget {
  const _AvatarFallbackIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Icon(Icons.person_rounded, color: Colors.white, size: size),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ChatConversationScreen extends StatefulWidget {
  const _ChatConversationScreen({
    required this.initialMessages,
    this.chatId,
    this.displayName = 'Carma Nutzer',
    this.vehicleModel = 'BMW 1er',
    this.vehicleColor = 'Schwarz',
  });

  final List<_LocalChatMessage> initialMessages;
  final String? chatId;
  final String displayName;
  final String vehicleModel;
  final String vehicleColor;

  @override
  State<_ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<_ChatConversationScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final TextEditingController _messageController = TextEditingController();

  late List<_LocalChatMessage> _messages;
  bool _hasText = false;
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  bool _isOtherUserTyping = false;
  bool _isCurrentUserTyping = false;
  _LocalChatMessage? _replyingToMessage;
  DateTime? _lastTypingWriteAt;
  DateTime? _otherLastReadAt;
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

    if (_hasFirestoreChat) {
      _markChatRead();
      _watchMessages();
      _watchTypingStatus();
      _watchReadReceipts();
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
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

  void _handleAttach() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Foto aufnehmen oder aus Galerie w\u00E4hlen verbinden wir sp\u00E4ter.',
        ),
      ),
    );
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
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
      });

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

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + keyboardInset),
                  child: Column(
                    children: [
                      _CompactChatInfoCard(
                        displayName: widget.displayName,
                        vehicleModel: widget.vehicleModel,
                        vehicleColor: widget.vehicleColor,
                        onBack: () => Navigator.of(context).pop(),
                        chatId: widget.chatId,
                      ),
                      const SizedBox(height: 14),
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
                onAttach: _handleAttach,
                onSend: _handleSend,
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
    required this.vehicleModel,
    required this.vehicleColor,
    required this.onBack,
    this.chatId,
  });

  final String displayName;
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
              const _UserAvatarPlaceholder(size: 46, imageUrl: null),
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

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({
    required this.messages,
    required this.onDeleteMessage,
    required this.onReplyMessage,
    required this.onStarMessage,
    required this.onReactMessage,
  });

  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onDeleteMessage;

  final ValueChanged<_LocalChatMessage> onReplyMessage;
  final ValueChanged<_LocalChatMessage> onStarMessage;
  final void Function(_LocalChatMessage message, String reaction)
  onReactMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages.map((message) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChatMessageBubble(
            message: message,
            onDeleteMessage: onDeleteMessage,
            onReplyMessage: onReplyMessage,
            onStarMessage: onStarMessage,
            onReactMessage: onReactMessage,
          ),
        );
      }).toList(),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.onDeleteMessage,
    required this.onReplyMessage,
    required this.onStarMessage,
    required this.onReactMessage,
  });

  final _LocalChatMessage message;
  final ValueChanged<_LocalChatMessage> onDeleteMessage;

  final ValueChanged<_LocalChatMessage> onReplyMessage;
  final ValueChanged<_LocalChatMessage> onStarMessage;
  final void Function(_LocalChatMessage message, String reaction)
  onReactMessage;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMessageActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final emoji in const [
                        '\u2764\uFE0F',
                        '\u{1F44D}',
                        '\u{1F602}',
                        '\u{1F62E}',
                        '\u{1F622}',
                        '\u{1F64F}',
                      ])
                        _MessageReactionButton(
                          emoji: emoji,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onReactMessage(message, emoji);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MessageActionTile(
                    icon: Icons.reply_rounded,
                    label: 'Antworten',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onReplyMessage(message);
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.forward_rounded,
                    label: 'Weiterleiten',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      Navigator.of(sheetContext).pop();
                      _showSnackBar(
                        context,
                        'Nachricht wurde zum Weiterleiten kopiert.',
                      );
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.copy_rounded,
                    label: 'Kopieren',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      Navigator.of(sheetContext).pop();
                      _showSnackBar(context, 'Nachricht wurde kopiert.');
                    },
                  ),
                  _MessageActionTile(
                    icon: message.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    label: message.isStarred
                        ? 'Stern entfernen'
                        : 'Mit Stern markieren',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onStarMessage(message);
                    },
                  ),
                  _MessageActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'L\u00F6schen',
                    isDestructive: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onDeleteMessage(message);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.72),
      fontWeight: FontWeight.w800,
      fontSize: 11,
    );
    final reactions = message.reactionBy.values
        .where((reaction) => reaction.trim().isNotEmpty)
        .toList();

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(message.isMine ? 20 : 5),
              bottomRight: Radius.circular(message.isMine ? 5 : 20),
            ),
            gradient: message.isMine
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _myMessageBlueDark,
                      _myMessageBlue,
                      _myMessageBlueLight,
                    ],
                  )
                : null,
            color: message.isMine ? null : Colors.white.withValues(alpha: 0.09),
            border: Border.all(
              color: message.isMine
                  ? _myMessageBorder
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 7,
            runSpacing: 3,
            children: [
              if (message.replyToText != null &&
                  message.replyToText!.trim().isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    message.replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.28,
                ),
              ),
              Text(message.timeLabel, style: timeStyle),
              if (message.isMine) _MessageDeliveryStatusIcon(message: message),
              if (reactions.isNotEmpty)
                _MessageReactionSummary(reactions: reactions),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageDeliveryStatusIcon extends StatelessWidget {
  const _MessageDeliveryStatusIcon({required this.message});

  final _LocalChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDelivered = message.messageId?.trim().isNotEmpty == true;
    final isRead = message.isReadByOther;

    return Icon(
      isDelivered || isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 17,
      color: isRead
          ? _myMessageCheckBlue
          : Colors.white.withValues(alpha: 0.62),
    );
  }
}

class _MessageReactionSummary extends StatelessWidget {
  const _MessageReactionSummary({required this.reactions});

  final List<String> reactions;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};

    for (final reaction in reactions) {
      counts[reaction] = (counts[reaction] ?? 0) + 1;
    }

    final label = counts.entries
        .map(
          (entry) =>
              entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
    );
  }
}

class _MessageReactionButton extends StatelessWidget {
  const _MessageReactionButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

class _MessageActionTile extends StatelessWidget {
  const _MessageActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : Colors.white;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChatLoadingSpace extends StatelessWidget {
  const _ChatLoadingSpace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(20),
          ),
          color: Colors.white.withValues(alpha: 0.09),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 4),
            _TypingDot(delay: 120),
            const SizedBox(width: 4),
            _TypingDot(delay: 240),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );

    _opacity = Tween<double>(
      begin: 0.35,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _ChatEmptySpace extends StatelessWidget {
  const _ChatEmptySpace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: [
          const SizedBox(height: 18),
          CarmaBlueIconBox(
            icon: Icons.chat_bubble_outline_rounded,
            size: 60,
            iconSize: 30,
          ),
          const SizedBox(height: 18),
          Text(
            'Noch keine Nachrichten',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onClear});

  final _LocalChatMessage message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = message.isMine ? 'Antwort auf dich' : 'Antwort auf Nachricht';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color: _carmaBlueLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _carmaBlueLight,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (message.replyToText != null &&
                      message.replyToText!.trim().isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    message.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
              tooltip: 'Antwort entfernen',
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.hasText,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  void _showComposerMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAttachmentSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Anhang senden',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _AttachmentSheetAction(
                      icon: Icons.photo_library_rounded,
                      label: 'Foto',
                      onTap: () {
                        Navigator.of(context).pop();
                        onAttach();
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.photo_camera_rounded,
                      label: 'Kamera',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showComposerMessage(
                          context,
                          'Kamera verbinden wir im n\u00E4chsten Schritt.',
                        );
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.location_on_rounded,
                      label: 'Standort',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showComposerMessage(
                          context,
                          'Standort senden verbinden wir im n\u00E4chsten Schritt.',
                        );
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.person_rounded,
                      label: 'Kontakt',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showComposerMessage(
                          context,
                          'Kontakt senden verbinden wir im n\u00E4chsten Schritt.',
                        );
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Dokument',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showComposerMessage(
                          context,
                          'Dokument senden verbinden wir im n\u00E4chsten Schritt.',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleVoiceMemo(BuildContext context) {
    _showComposerMessage(
      context,
      'Sprachmemo verbinden wir im n\u00E4chsten Schritt.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _ComposerIconButton(
              icon: Icons.add_rounded,
              onTap: () => _openAttachmentSheet(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Nachricht schreiben',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(
              isEnabled: true,
              icon: hasText ? Icons.send_rounded : Icons.mic_rounded,
              onTap: hasText ? onSend : () => _handleVoiceMemo(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSheetAction extends StatelessWidget {
  const _AttachmentSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(icon, color: Colors.white, size: 27),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.icon,
    required this.onTap,
  });

  final bool isEnabled;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _myMessageBlueDark,
                      _myMessageBlue,
                      _myMessageBlueLight,
                    ],
                  )
                : null,
            color: isEnabled ? null : Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.0 : 0.14),
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: _carmaBlue.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Icon(
            icon,
            color: isEnabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.42),
            size: 22,
          ),
        ),
      ),
    );
  }
}
