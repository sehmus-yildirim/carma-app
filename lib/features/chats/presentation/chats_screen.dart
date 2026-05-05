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

  late Future<List<ChatRecord>> _chatFuture;
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

    _chatFuture = _loadChats();
    _requestCountsFuture = _loadRequestCounts();
  }

  Future<List<ChatRecord>> _loadChats() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Future.value(const <ChatRecord>[]);
    }

    return _chatRepository.loadChats(userId: userId);
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

  void _refreshChatsAndRequests() {
    setState(() {
      _chatFuture = _loadChats();
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
    this.isReadByOther = false,
  });

  final String text;
  final bool isMine;
  final String timeLabel;
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
      return 'Du hast aktuell keine Anfrage gesendet. Später erscheinen hier offene Anfragen aus der Suche.';
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
              'Anfragen von Nutzern, die dich über dein Kennzeichen gefunden haben.',
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
  const _ChatOverflowMenu({this.title, this.subtitle});

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
        : 'Fahrzeugdetails sind aktuell nicht verfügbar.';

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
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

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

  Future<void> _handleAction(
    BuildContext context,
    _ChatMenuAction action,
  ) async {
    switch (action) {
      case _ChatMenuAction.favorite:
        _showSnackBar(context, 'Chat wurde als Favorit vorgemerkt.');
      case _ChatMenuAction.mute:
        _showSnackBar(
          context,
          'Benachrichtigungen wurden zum Stummschalten vorgemerkt.',
        );
      case _ChatMenuAction.vehicleDetails:
        await _showVehicleDetails(context);
      case _ChatMenuAction.archive:
        await _confirmAction(
          context: context,
          title: 'Chat archivieren?',
          message:
              'Der Chat wird aus der aktiven Übersicht entfernt, bleibt aber für Sicherheit und Meldungen nachvollziehbar.',
          confirmLabel: 'Archivieren',
          resultMessage: 'Chat wurde zum Archivieren vorgemerkt.',
        );
      case _ChatMenuAction.delete:
        await _confirmAction(
          context: context,
          title: 'Chat löschen?',
          message:
              'Der Chat wird für dich entfernt. Sicherheitsrelevante Daten können geschützt erhalten bleiben.',
          confirmLabel: 'Löschen',
          resultMessage: 'Chat wurde zum Löschen vorgemerkt.',
        );
      case _ChatMenuAction.block:
        await _confirmAction(
          context: context,
          title: 'Nutzer blockieren?',
          message:
              'Blockierte Nutzer können dich nicht mehr über diesen Chat kontaktieren.',
          confirmLabel: 'Blockieren',
          resultMessage: 'Nutzer wurde zum Blockieren vorgemerkt.',
        );
      case _ChatMenuAction.report:
        await _confirmAction(
          context: context,
          title: 'Nutzer melden?',
          message:
              'Die Meldung wird später mit Chat-ID, Nutzer-ID und Grund an den Meldebereich übergeben.',
          confirmLabel: 'Melden',
          resultMessage: 'Meldung wurde vorgemerkt.',
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
        return const [
          PopupMenuItem(
            value: _ChatMenuAction.favorite,
            child: Text('Zu Favoriten hinzufügen'),
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
            child: Text('Chat löschen'),
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
                    ? 'Letzte Nachricht: '
                    : chat.vehicleTitle,
                onTap: () {
                  Navigator.of(context).push(
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
      subtitle:
          'Hier erscheinen alle Unterhaltungen, die nach angenommener Anfrage entstanden sind.',
      child: hasLocalActiveChat
          ? _ActiveChatListTile(
              title: 'Carma Nutzer',
              subtitle: messages.isNotEmpty
                  ? 'Letzte Nachricht: '
                  : 'BMW 1er · Schwarz',
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
  });

  final String title;
  final String subtitle;
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
                        title,
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
                        subtitle,
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
      _loadFirestoreMessages();
      _watchTypingStatus();
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

  Future<void> _loadFirestoreMessages() async {
    final chatId = widget.chatId?.trim();

    if (chatId == null || chatId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMessages = true;
    });

    try {
      final records = await _chatRepository.loadMessages(chatId: chatId);
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
              ),
            )
            .toList();
        _isLoadingMessages = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingMessages = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nachrichten konnten nicht geladen werden: $error'),
        ),
      );
    }
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
          'Foto aufnehmen oder aus Galerie wählen verbinden wir später.',
        ),
      ),
    );
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
      final sentMessage = await _chatRepository.sendTextMessage(
        chatId: chatId,
        senderUserId: currentUserId,
        text: message,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = [
          ..._messages,
          _LocalChatMessage(
            text: sentMessage.text,
            isMine: true,
            timeLabel: _timeLabel(sentMessage.createdAt),
          ),
        ];
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
                      ),
                      const SizedBox(height: 14),
                      if (_isLoadingMessages)
                        const _ChatLoadingSpace()
                      else if (_messages.isEmpty)
                        const _ChatEmptySpace()
                      else
                        _ChatMessageList(messages: _messages),
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
  });

  final String displayName;
  final String vehicleModel;
  final String vehicleColor;
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

              _ChatOverflowMenu(title: displayName, subtitle: ' · '),
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
                      '❤️',
                      '👍',
                      '😂',
                      '😮',
                      '😢',
                      '🙏',
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
                      'Antworten verbinden wir im nächsten Schritt.',
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
                      'Weiterleiten verbinden wir im nächsten Schritt.',
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
                  label: 'Löschen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSnackBar(
                      context,
                      'Nachricht löschen verbinden wir im nächsten Schritt.',
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
                      Color(0xFF064FAF),
                      Color(0xFF0872D8),
                      Color(0xFF0B8FEF),
                    ],
                  )
                : null,
            color: message.isMine ? null : Colors.white.withValues(alpha: 0.09),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: message.isMine ? 0.18 : 0.10,
              ),
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
                  color: Color(0xFF8FE7FF),
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
                          'Kamera verbinden wir im nächsten Schritt.',
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
                          'Standort senden verbinden wir im nächsten Schritt.',
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
                          'Kontakt senden verbinden wir im nächsten Schritt.',
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
                          'Dokument senden verbinden wir im nächsten Schritt.',
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
      'Sprachmemo verbinden wir im nächsten Schritt.',
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
                    colors: [_carmaBlueDark, _carmaBlue, _carmaBlueLight],
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
