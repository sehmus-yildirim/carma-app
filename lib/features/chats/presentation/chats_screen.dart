import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/domain/app_feature_gate.dart';
import '../../../shared/models/carma_models.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/chat_repository.dart';
import 'contact_request_counts_card.dart';
import 'contact_request_list_screen.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

enum _ChatsView { chats, requests }

enum _LocalChatTestMode {
  empty,
  incomingRequest,
  outgoingRequest,
  activeChat,
  activeChatWithMessages,
}

const _LocalChatTestMode _localChatTestMode = _LocalChatTestMode.empty;

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();

  _ChatsView _selectedView = _ChatsView.chats;

  late Future<List<ChatRecord>> _chatFuture;
  late bool _hasIncomingRequest;
  late bool _hasOutgoingRequest;
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

    _hasIncomingRequest =
        _localChatTestMode == _LocalChatTestMode.incomingRequest;
    _hasOutgoingRequest =
        _localChatTestMode == _LocalChatTestMode.outgoingRequest;
    _hasActiveChat =
        _localChatTestMode == _LocalChatTestMode.activeChat ||
        _localChatTestMode == _LocalChatTestMode.activeChatWithMessages;

    _chatMessages =
        _localChatTestMode == _LocalChatTestMode.activeChatWithMessages
        ? _buildLocalChatMessages()
        : <_LocalChatMessage>[];

    _chatFuture = _loadChats();
  }

  Future<List<ChatRecord>> _loadChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Future.value(const <ChatRecord>[]);
    }

    return _chatRepository.loadChats(userId: userId);
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
            'Danke dir fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¼r den Hinweis. Ich schaue sofort nach.',
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

  void _openIncomingRequestsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactRequestListScreen(
          userState: widget.userState,
          mode: ContactRequestListMode.incoming,
        ),
      ),
    );
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

  void _openActiveChatsScreen({required bool hasFirestoreChats}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ActiveChatsScreen(
          hasActiveChat: _hasActiveChat || hasFirestoreChats,
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
                    const SizedBox(height: 12),
                    ContactRequestCountsCard(userState: widget.userState),
                    const SizedBox(height: 18),
                    if (!chatGateDecision.isAllowed)
                      _ChatAccessBlockedCard(
                        message:
                            chatGateDecision.reason ??
                            'Chats sind aktuell nicht verfÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¼gbar.',
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
                            ? FutureBuilder<List<ChatRecord>>(
                                key: const ValueKey('chats_view'),
                                future: _chatFuture,
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
                                        _openActiveChatsScreen(
                                          hasFirestoreChats: chats.isNotEmpty,
                                        ),
                                  );
                                },
                              )
                            : _RequestsOverview(
                                key: const ValueKey('requests_view'),
                                hasIncomingRequest: _hasIncomingRequest,
                                hasOutgoingRequest: _hasOutgoingRequest,
                                onOpenIncoming: _openIncomingRequestsScreen,
                                onOpenOutgoing: _openOutgoingRequestsScreen,
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
  });

  final String text;
  final bool isMine;
  final String timeLabel;
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
              'Chats und Kontaktanfragen sind aktuell lokal vorbereitet. Echte Nachrichten, Anfrage-Status und Push-Benachrichtigungen verbinden wir spÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤ter mit Firebase.',
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
                  'Chats nicht verfÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¼gbar',
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
                    colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
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
          ? '$localMessageCount lokale Beispielnachrichten verfügbar.'
          : 'Ein lokaler Beispielchat ist verfügbar.';
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
    super.key,
    required this.hasIncomingRequest,
    required this.hasOutgoingRequest,
    required this.onOpenIncoming,
    required this.onOpenOutgoing,
  });

  final bool hasIncomingRequest;
  final bool hasOutgoingRequest;
  final VoidCallback onOpenIncoming;
  final VoidCallback onOpenOutgoing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewCard(
          icon: Icons.move_to_inbox_rounded,
          title: 'Eingehende Anfragen',
          count: hasIncomingRequest ? '1' : '0',
          description:
              'Anfragen von Nutzern, die dich ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¼ber dein Kennzeichen gefunden haben.',
          bodyText: hasIncomingRequest
              ? 'Neue Anfrage wartet auf deine Entscheidung.'
              : 'Aktuell gibt es keine offenen Anfragen. Neue Kontakte erscheinen hier zuerst zur Freigabe.',
          onTap: onOpenIncoming,
        ),
        const SizedBox(height: 14),
        _OverviewCard(
          icon: Icons.outbox_rounded,
          title: 'Gesendete Anfragen',
          count: hasOutgoingRequest ? '1' : '0',
          description:
              'Anfragen, die du nach einer Kennzeichen-Suche verschickt hast.',
          bodyText: hasOutgoingRequest
              ? 'Eine Anfrage wartet auf Antwort.'
              : 'Du hast aktuell keine Anfrage gesendet. SpÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤ter erscheinen hier offene Anfragen aus der Suche.',
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

class _ActiveChatsScreen extends StatelessWidget {
  const _ActiveChatsScreen({
    required this.hasActiveChat,
    required this.messages,
  });

  final bool hasActiveChat;
  final List<_LocalChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      icon: Icons.forum_rounded,
      headerTitle: 'Aktive Chats',
      subtitle:
          'Hier erscheinen alle Unterhaltungen, die nach angenommener Anfrage entstanden sind.',
      child: hasActiveChat
          ? _ActiveChatListTile(
              hasMessages: messages.isNotEmpty,
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
  const _ActiveChatListTile({required this.hasMessages, required this.onTap});

  final bool hasMessages;
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
            child: Row(
              children: [
                const _UserAvatarPlaceholder(size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carma Nutzer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasMessages
                            ? 'Letzte Nachricht: Danke dir fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¼r den Hinweis.'
                            : 'Schwarz BMW 1er',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: 28,
                ),
              ],
            ),
          ),
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
                    'Live-Daten werden spÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤ter mit Firebase geladen.',
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
  const _ChatConversationScreen({required this.initialMessages});

  final List<_LocalChatMessage> initialMessages;

  @override
  State<_ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<_ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();

  late List<_LocalChatMessage> _messages;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _messages = [...widget.initialMessages];
    _messageController.addListener(_handleMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    final nextHasText = _messageController.text.trim().isNotEmpty;

    if (_hasText == nextHasText) {
      return;
    }

    setState(() {
      _hasText = nextHasText;
    });
  }

  void _handleAttach() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Foto aufnehmen oder aus Galerie wÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤hlen verbinden wir spÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤ter.',
        ),
      ),
    );
  }

  void _handleSend() {
    if (!_hasText) {
      return;
    }

    final message = _messageController.text.trim();

    setState(() {
      _messages = [
        ..._messages,
        _LocalChatMessage(text: message, isMine: true, timeLabel: 'Jetzt'),
      ];
    });

    _messageController.clear();
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
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 14),
                      if (_messages.isEmpty)
                        const _ChatEmptySpace()
                      else
                        _ChatMessageList(messages: _messages),
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
  const _CompactChatInfoCard({required this.onBack});

  final VoidCallback onBack;

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
                  'Carma Nutzer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _VehicleInfoPill(label: 'Modell', value: 'BMW 1er'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _VehicleInfoPill(label: 'Farbe', value: 'Schwarz'),
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
  const _ChatMessageList({required this.messages});

  final List<_LocalChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages.map((message) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChatMessageBubble(message: message),
        );
      }).toList(),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final _LocalChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
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
                  colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
                )
              : null,
          color: message.isMine ? null : Colors.white.withValues(alpha: 0.09),
          border: Border.all(
            color: Colors.white.withValues(alpha: message.isMine ? 0.18 : 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: message.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.32,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message.timeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.64),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
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
            'Dieser Chat ist lokal vorbereitet. Nachrichten, AnhÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤nge und Zustellstatus werden spÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¤ter mit Firebase verbunden.',
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
              icon: Icons.add_photo_alternate_outlined,
              onTap: onAttach,
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
                    horizontal: 14,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(19),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(19),
                    borderSide: BorderSide(
                      color: _carmaBlueLight.withValues(alpha: 0.88),
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(isEnabled: hasText, onTap: onSend),
          ],
        ),
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
  const _SendButton({required this.isEnabled, required this.onTap});

  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
              ),
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
