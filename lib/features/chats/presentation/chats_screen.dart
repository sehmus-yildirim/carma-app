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

import 'contact_request_list_screen.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

const Color _myMessageBlueDark = Color(0xFF03172F);
const Color _myMessageBlue = Color(0xFF08264A);
const Color _myMessageBlueLight = Color(0xFF0D3566);
const Color _myMessageBorder = Color(0xFF164A86);
const Color _myMessageCheckBlue = Color(0xFF7FD6FF);

enum _ChatsView { chats, requests }

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

class _RequestCounts {
  const _RequestCounts({required this.incoming, required this.outgoing});

  final int incoming;
  final int outgoing;
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();

  _ChatsView _selectedView = _ChatsView.chats;

  late Stream<List<ChatRecord>> _chatStream;
  Future<_RequestCounts> _requestCountsFuture = Future.value(
    const _RequestCounts(incoming: 0, outgoing: 0),
  );
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
    _requestCountsFuture = _loadRequestCounts();
  }

  Stream<List<ChatRecord>> _watchChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Stream<List<ChatRecord>>.value(const <ChatRecord>[]);
    }

    return _chatRepository.watchChats(userId: userId);
  }

  Future<_RequestCounts> _loadRequestCounts() async {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return const _RequestCounts(incoming: 0, outgoing: 0);
    }

    final repository = FirestoreContactRequestRepository();

    final incomingRequests = await repository.loadIncomingRequests(
      userId: userId,
    );

    final outgoingRequests = await repository.loadOutgoingRequests(
      userId: userId,
    );

    return _RequestCounts(
      incoming: incomingRequests.length,
      outgoing: outgoingRequests.length,
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
        text:
            'Danke dir fÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼r den Hinweis. Ich schaue sofort nach.',
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

  void _refreshChatsAndRequests() {
    setState(() {
      _chatStream = _watchChats();
      _requestCountsFuture = _loadRequestCounts();
    });
  }

  Future<void> _openIncomingRequestsScreen() async {
    final acceptedChatId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ContactRequestListScreen(
          userState: widget.userState,
          mode: ContactRequestListMode.incoming,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();

    final chatId = acceptedChatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          chatId: chatId,
          initialMessages: const <_LocalChatMessage>[],
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshChatsAndRequests();
  }

  void _openOutgoingRequestsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactRequestListScreen(
          userState: widget.userState,
          mode: ContactRequestListMode.outgoing,
        ),
      ),
    );
  }

  void _openActiveChatsScreen({required List<ChatRecord> chats}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ActiveChatsScreen(
          chats: chats,
          hasLocalActiveChat: _hasActiveChat,
          messages: _chatMessages,
        ),
      ),
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
                    const SizedBox(height: 14),
                    Text(
                      'Hier findest du angenommene Unterhaltungen und Kontaktanfragen.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _MvpInfoCard(),
                    const SizedBox(height: 18),
                    if (!chatGateDecision.isAllowed)
                      _ChatAccessBlockedCard(
                        message:
                            chatGateDecision.reason ??
                            'Chats sind aktuell nicht verfÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼gbar.',
                      )
                    else ...[
                      _ChatsSegmentedControl(
                        selectedView: _selectedView,
                        onChanged: _selectView,
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
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

                                  return _ChatsOverview(
                                    chats: chats,
                                    isLoading: isLoading,
                                    hasLocalActiveChat: _hasActiveChat,
                                    localMessageCount: _chatMessages.length,
                                    onOpenActiveChats: () =>
                                        _openActiveChatsScreen(chats: chats),
                                  );
                                },
                              )
                            : FutureBuilder<_RequestCounts>(
                                key: const ValueKey('requests_view'),
                                future: _requestCountsFuture,
                                builder: (context, snapshot) {
                                  final counts =
                                      snapshot.data ??
                                      const _RequestCounts(
                                        incoming: 0,
                                        outgoing: 0,
                                      );
                                  final isLoading =
                                      snapshot.connectionState ==
                                      ConnectionState.waiting;

                                  return _RequestsOverview(
                                    incomingCount: counts.incoming,
                                    outgoingCount: counts.outgoing,
                                    isLoading: isLoading,
                                    onOpenIncoming: _openIncomingRequestsScreen,
                                    onOpenOutgoing: _openOutgoingRequestsScreen,
                                  );
                                },
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
    this.messageId,
    this.isReadByOther = false,
  });

  final String text;
  final bool isMine;
  final String timeLabel;
  final String? messageId;
  final bool isReadByOther;
}

class _MvpInfoCard extends StatelessWidget {
  const _MvpInfoCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: Icons.info_outline_rounded,
            size: 44,
            iconSize: 23,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Chats und Kontaktanfragen sind aktuell lokal vorbereitet. Echte Nachrichten, Anfrage-Status und Push-Benachrichtigungen verbinden wir spÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ter mit Firebase.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.80),
                fontWeight: FontWeight.w700,
                height: 1.36,
              ),
            ),
          ),
        ],
      ),
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
                  'Chats nicht verfÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼gbar',
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

class _ChatsOverview extends StatelessWidget {
  const _ChatsOverview({
    required this.chats,
    required this.isLoading,
    required this.hasLocalActiveChat,
    required this.localMessageCount,
    required this.onOpenActiveChats,
  });

  final List<ChatRecord> chats;
  final bool isLoading;
  final bool hasLocalActiveChat;
  final int localMessageCount;
  final VoidCallback onOpenActiveChats;

  bool get _hasActiveChat {
    return chats.isNotEmpty || hasLocalActiveChat;
  }

  String get _count {
    if (isLoading) {
      return '...';
    }

    if (chats.isNotEmpty) {
      return chats.length.toString();
    }

    return hasLocalActiveChat ? '1' : '0';
  }

  String get _bodyText {
    if (isLoading) {
      return 'Aktive Chats werden geladen...';
    }

    if (chats.isNotEmpty) {
      return chats.length == 1
          ? 'Ein aktiver Chat wurde aus Firestore geladen.'
          : '${chats.length} aktive Chats wurden aus Firestore geladen.';
    }

    if (hasLocalActiveChat) {
      return localMessageCount > 0
          ? '$localMessageCount lokale Beispielnachrichten verfÃ¼gbar.'
          : 'Ein lokaler Beispielchat ist verfÃ¼gbar.';
    }

    return 'Noch keine aktiven Chats. Sobald eine Kontaktanfrage angenommen wird, erscheint hier die Unterhaltung.';
  }

  @override
  Widget build(BuildContext context) {
    return _OverviewCard(
      icon: Icons.forum_rounded,
      title: 'Aktive Chats',
      count: _count,
      description: 'Angenommene Anfragen werden hier als Chat angezeigt.',
      bodyText: _bodyText,
      onTap: _hasActiveChat ? onOpenActiveChats : () {},
    );
  }
}

class _RequestsOverview extends StatelessWidget {
  const _RequestsOverview({
    required this.incomingCount,
    required this.outgoingCount,
    required this.isLoading,
    required this.onOpenIncoming,
    required this.onOpenOutgoing,
  });

  final int incomingCount;
  final int outgoingCount;
  final bool isLoading;
  final VoidCallback onOpenIncoming;
  final VoidCallback onOpenOutgoing;

  String get _incomingCountLabel {
    return isLoading ? '...' : incomingCount.toString();
  }

  String get _outgoingCountLabel {
    return isLoading ? '...' : outgoingCount.toString();
  }

  bool get _hasIncomingRequests {
    return incomingCount > 0;
  }

  bool get _hasOutgoingRequests {
    return outgoingCount > 0;
  }

  String get _incomingBodyText {
    if (!_hasIncomingRequests) {
      return 'Aktuell gibt es keine offenen Anfragen. Neue Kontakte erscheinen hier zuerst zur Freigabe.';
    }

    return incomingCount == 1
        ? 'Eine offene Anfrage wartet auf deine Entscheidung.'
        : ' offene Anfragen warten auf deine Entscheidung.';
  }

  String get _outgoingBodyText {
    if (!_hasOutgoingRequests) {
      return 'Du hast aktuell keine Anfrage gesendet. SpÃ¤ter erscheinen hier offene Anfragen aus der Suche.';
    }

    return outgoingCount == 1
        ? 'Eine gesendete Anfrage wartet auf Antwort.'
        : ' gesendete Anfragen warten auf Antwort.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewCard(
          icon: Icons.move_to_inbox_rounded,
          title: 'Eingehende Anfragen',
          count: _incomingCountLabel,
          description:
              'Anfragen von Nutzern, die dich Ã¼ber dein Kennzeichen gefunden haben.',
          bodyText: _incomingBodyText,
          onTap: onOpenIncoming,
        ),
        const SizedBox(height: 14),
        _OverviewCard(
          icon: Icons.outbox_rounded,
          title: 'Gesendete Anfragen',
          count: _outgoingCountLabel,
          description:
              'Anfragen, die du nach einer Kennzeichen-Suche verschickt hast.',
          bodyText: _outgoingBodyText,
          onTap: onOpenOutgoing,
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.description,
    required this.bodyText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String count;
  final String description;
  final String bodyText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CarmaBlueIconBox(icon: icon, size: 48, iconSize: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CountBadge(count: count),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white.withValues(alpha: 0.78),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bodyText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.74),
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_carmaBlueDark, _carmaBlueLight],
        ),
        boxShadow: [
          BoxShadow(
            color: _carmaBlue.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        count,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 19,
        ),
      ),
    );
  }
}

class _ChatOverflowMenu extends StatelessWidget {
  static final FirestoreChatRepository _chatRepository =
      FirestoreChatRepository();

  const _ChatOverflowMenu({this.chatId, this.title, this.subtitle});

  final String? chatId;
  final String? title;
  final String? subtitle;

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
        : 'Fahrzeugdetails sind aktuell nicht verfÃ¼gbar.';

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
              child: const Text('SchlieÃŸen'),
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
        'Diese Aktion ist fÃ¼r lokale Beispielchats noch nicht verfÃ¼gbar.',
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
        await _runChatPreferenceAction(
          context: context,
          successMessage: 'Chat wurde zu Favoriten hinzugefÃ¼gt.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatFavorite(
              chatId: chatId,
              userId: userId,
              isFavorite: true,
            );
          },
        );
      case _ChatMenuAction.mute:
        await _runChatPreferenceAction(
          context: context,
          successMessage: 'Chat wurde stummgeschaltet.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatMuted(
              chatId: chatId,
              userId: userId,
              isMuted: true,
            );
          },
        );
      case _ChatMenuAction.vehicleDetails:
        await _showVehicleDetails(context);
      case _ChatMenuAction.archive:
        await _runChatStatusAction(
          context: context,
          title: 'Chat archivieren?',
          message:
              'Der Chat wird aus der aktiven Ãœbersicht entfernt, bleibt aber fÃ¼r Sicherheit und Meldungen nachvollziehbar.',
          confirmLabel: 'Archivieren',
          successMessage: 'Chat wurde archiviert.',
          action: () async {
            final id = chatId?.trim();

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            await _chatRepository.archiveChat(chatId: id);
          },
        );
      case _ChatMenuAction.delete:
        await _runChatStatusAction(
          context: context,
          title: 'Chat lÃ¶schen?',
          message:
              'Der Chat wird aus deiner aktiven Ãœbersicht entfernt. Sicherheitsrelevante Daten kÃ¶nnen geschÃ¼tzt erhalten bleiben.',
          confirmLabel: 'LÃ¶schen',
          successMessage: 'Chat wurde gelÃ¶scht.',
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
              'Blockierte Nutzer kÃ¶nnen dich nicht mehr Ã¼ber diesen Chat kontaktieren.',
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
        'Diese Aktion ist fÃ¼r lokale Beispielchats noch nicht verfÃ¼gbar.',
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

      _showSnackBar(context, 'Aktion konnte nicht ausgefÃ¼hrt werden: $error');
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
        'Diese Aktion ist fÃ¼r lokale Beispielchats noch nicht verfÃ¼gbar.',
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
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Aktion konnte nicht ausgefÃ¼hrt werden: $error');
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
        return const [
          PopupMenuItem(
            value: _ChatMenuAction.favorite,
            child: Text('Zu Favoriten hinzufÃ¼gen'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.mute,
            child: Text('Benachrichtigungen stummschalten'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.vehicleDetails,
            child: Text('Fahrzeugdetails anzeigen'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.archive,
            child: Text('Chat archivieren'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.delete,
            child: Text('Chat lÃ¶schen'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.block,
            child: Text('Nutzer blockieren'),
          ),
          PopupMenuItem(
            value: _ChatMenuAction.report,
            child: Text('Nutzer melden'),
          ),
        ];
      },
    );
  }
}

class _ActiveChatsScreen extends StatelessWidget {
  const _ActiveChatsScreen({
    required this.chats,
    required this.hasLocalActiveChat,
    required this.messages,
  });

  final List<ChatRecord> chats;
  final bool hasLocalActiveChat;
  final List<_LocalChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (chats.isNotEmpty) {
      return _SubPageScaffold(
        icon: Icons.forum_rounded,
        headerTitle: 'Aktive Chats',
        subtitle:
            'Hier erscheinen alle Unterhaltungen, die nach angenommener Anfrage entstanden sind.',
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
                onTap: () async {
                  final didChange = await Navigator.of(context).push<bool>(
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

                  if (didChange == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
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
      subtitle:
          'Hier erscheinen alle Unterhaltungen, die nach angenommener Anfrage entstanden sind.',
      child: hasLocalActiveChat
          ? _ActiveChatListTile(
              title: 'Carma Nutzer',
              subtitle: messages.isNotEmpty
                  ? 'Letzte Nachricht: '
                  : 'BMW 1er Â· Schwarz',
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
              description:
                  'Sobald eine Anfrage angenommen wird, erscheint die Unterhaltung hier. Bis dahin bleibt dieser Bereich bewusst leer.',
            ),
    );
  }
}

class _SubPageScaffold extends StatelessWidget {
  const _SubPageScaffold({
    required this.icon,
    required this.headerTitle,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String headerTitle;
  final String subtitle;
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
                const SizedBox(height: 18),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    height: 1.35,
                  ),
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
  });

  final String title;
  final String subtitle;
  final bool isFavorite;
  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasStateIcons = isFavorite || isMuted;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const _UserAvatarPlaceholder(size: 56),
                const SizedBox(width: 14),
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
                                    fontSize: 17,
                                  ),
                            ),
                          ),
                          if (hasStateIcons) ...[
                            const SizedBox(width: 8),
                            if (isFavorite)
                              const _ChatStateIcon(
                                icon: Icons.star_rounded,
                                tooltip: 'Favorit',
                              ),
                            if (isFavorite && isMuted) const SizedBox(width: 6),
                            if (isMuted)
                              const _ChatStateIcon(
                                icon: Icons.notifications_off_rounded,
                                tooltip: 'Stummgeschaltet',
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.42),
                  size: 26,
                ),
              ],
            ),
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
  const _EmptyListCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          CarmaBlueIconBox(icon: icon, size: 64, iconSize: 32),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.055),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: Colors.white.withValues(alpha: 0.76),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live-Daten werden spÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ter mit Firebase geladen.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
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

class _UserAvatarPlaceholder extends StatelessWidget {
  const _UserAvatarPlaceholder({required this.size});

  final double size;

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
      child: Icon(Icons.person_rounded, color: Colors.white, size: size * 0.56),
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
  DateTime? _lastTypingWriteAt;
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

    var changed = false;

    final nextMessages = _messages.map((message) {
      if (!message.isMine || message.isReadByOther) {
        return message;
      }

      final parsedTime = _timeFromLabel(message.timeLabel);

      if (parsedTime == null || parsedTime.isAfter(otherLastReadAt)) {
        return message;
      }

      changed = true;

      return _LocalChatMessage(
        text: message.text,
        isMine: message.isMine,
        timeLabel: message.timeLabel,
        isReadByOther: true,
      );
    }).toList();

    if (!changed) {
      return;
    }

    setState(() {
      _messages = nextMessages;
    });
  }

  DateTime? _timeFromLabel(String label) {
    final parts = label.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
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

            if (!mounted) {
              return;
            }

            setState(() {
              _messages = records
                  .map(
                    (record) => _LocalChatMessage(
                      text: record.text,
                      isMine: record.senderUserId == currentUserId,
                      timeLabel: _timeLabel(record.createdAt),
                      messageId: record.id,
                    ),
                  )
                  .toList();

              _isLoadingMessages = false;
            });
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
                content: Text('Nachrichten konnten nicht geladen werden: '),
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
          'Foto aufnehmen oder aus Galerie wÃ¤hlen verbinden wir spÃ¤ter.',
        ),
      ),
    );
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
        const SnackBar(content: Text('Nachricht wurde gelÃƒÂ¶scht.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nachricht konnte nicht gelÃƒÂ¶scht werden: $error'),
        ),
      );
    }
  }

  Future<void> _handleSend() async {
    if (!_hasText || _isSendingMessage) {
      return;
    }

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
            timeLabel: 'Jetzt',
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
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingMessage = false;
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
              const _UserAvatarPlaceholder(size: 46),
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
                subtitle: ' Â· ',
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
  });

  final List<_LocalChatMessage> messages;
  final ValueChanged<_LocalChatMessage> onDeleteMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages.map((message) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChatMessageBubble(
            message: message,
            onDeleteMessage: onDeleteMessage,
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
  });

  final _LocalChatMessage message;
  final ValueChanged<_LocalChatMessage> onDeleteMessage;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMessageActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in const [
                      'â¤ï¸',
                      'ðŸ‘',
                      'ðŸ˜‚',
                      'ðŸ˜®',
                      'ðŸ˜¢',
                      'ðŸ™',
                    ])
                      _MessageReactionButton(
                        emoji: emoji,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _showSnackBar(context, 'Reaktion  vorgemerkt.');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Antworten',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSnackBar(
                      context,
                      'Antworten verbinden wir im nÃ¤chsten Schritt.',
                    );
                  },
                ),
                _MessageActionTile(
                  icon: Icons.forward_rounded,
                  label: 'Weiterleiten',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSnackBar(
                      context,
                      'Weiterleiten verbinden wir im nÃ¤chsten Schritt.',
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
                  icon: Icons.star_border_rounded,
                  label: 'Mit Stern markieren',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSnackBar(
                      context,
                      'Nachricht wurde als Stern vorgemerkt.',
                    );
                  },
                ),
                _MessageActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'LÃ¶schen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSnackBar(
                      context,
                      'Nachricht lÃ¶schen verbinden wir im nÃ¤chsten Schritt.',
                    );
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
    final timeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.72),
      fontWeight: FontWeight.w800,
      fontSize: 11,
    );

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
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.28,
                ),
              ),
              Text(message.timeLabel, style: timeStyle),
              if (message.isMine)
                const Icon(
                  Icons.done_all_rounded,
                  size: 17,
                  color: _myMessageCheckBlue,
                ),
            ],
          ),
        ),
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
          const SizedBox(height: 8),
          Text(
            'Dieser Chat ist lokal vorbereitet. Nachrichten, AnhÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤nge und Zustellstatus werden spÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ter mit Firebase verbunden.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
              height: 1.38,
            ),
          ),
        ],
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
                          'Kamera verbinden wir im nÃ¤chsten Schritt.',
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
                          'Standort senden verbinden wir im nÃ¤chsten Schritt.',
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
                          'Kontakt senden verbinden wir im nÃ¤chsten Schritt.',
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
                          'Dokument senden verbinden wir im nÃ¤chsten Schritt.',
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
      'Sprachmemo verbinden wir im nÃ¤chsten Schritt.',
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
