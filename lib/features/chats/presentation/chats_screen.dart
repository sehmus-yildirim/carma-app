import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';

const Color _carmaBlue = Color(0xFF139CFF);
const Color _carmaBlueLight = Color(0xFF63D5FF);
const Color _carmaBlueDark = Color(0xFF0A76FF);

enum _ChatsView {
  chats,
  requests,
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  _ChatsView _selectedView = _ChatsView.chats;

  // TODO: Später durch echte Firebase-Daten ersetzen.
  bool _hasIncomingRequest = true;
  bool _hasOutgoingRequest = false;
  bool _hasActiveChat = false;

  String get _currentFirstName {
    final fullName =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';

    if (fullName.isEmpty) {
      return 'Carma Nutzer';
    }

    return fullName.split(RegExp(r'\s+')).first.trim();
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
        builder: (_) => _IncomingRequestsScreen(
          hasIncomingRequest: _hasIncomingRequest,
          onAccept: () {
            setState(() {
              _hasIncomingRequest = false;
              _hasActiveChat = true;
              _selectedView = _ChatsView.chats;
            });
          },
          onDecline: () {
            setState(() {
              _hasIncomingRequest = false;
            });
          },
        ),
      ),
    );
  }

  void _openOutgoingRequestsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OutgoingRequestsScreen(
          hasOutgoingRequest: _hasOutgoingRequest,
          currentFirstName: _currentFirstName,
          onWithdraw: () {
            setState(() {
              _hasOutgoingRequest = false;
            });
          },
        ),
      ),
    );
  }

  void _openActiveChatsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ActiveChatsScreen(
          hasActiveChat: _hasActiveChat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                112 + keyboardInset,
              ),
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
                    const SizedBox(height: 20),
                    _ChatsSegmentedControl(
                      selectedView: _selectedView,
                      onChanged: _selectView,
                    ),
                    _ChatsSegmentedControl(
                      selectedView: _selectedView,
                      onChanged: _selectView,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _selectedView == _ChatsView.chats
                          ? _ChatsOverview(
                        key: const ValueKey('chats_view'),
                        hasActiveChat: _hasActiveChat,
                        onOpenActiveChats: _openActiveChatsScreen,
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
                ),
              ),
            );
          },
        ),
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
                _carmaBlueDark,
                _carmaBlue,
                _carmaBlueLight,
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
              Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
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
    super.key,
    required this.hasActiveChat,
    required this.onOpenActiveChats,
  });

  final bool hasActiveChat;
  final VoidCallback onOpenActiveChats;

  @override
  Widget build(BuildContext context) {
    return _OverviewCard(
      icon: Icons.forum_rounded,
      title: 'Aktive Chats',
      count: hasActiveChat ? '1' : '0',
      description: 'Angenommene Anfragen werden hier als Chat angezeigt.',
      bodyText: hasActiveChat
          ? 'Ein aktiver Chat ist verfügbar.'
          : 'Noch keine aktiven Chats.',
      onTap: onOpenActiveChats,
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
          'Anfragen von Nutzern, die dich über dein Kennzeichen gefunden haben.',
          bodyText: hasIncomingRequest
              ? 'Neue Anfrage wartet auf deine Entscheidung.'
              : 'Aktuell gibt es keine offenen Anfragen.',
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
              : 'Du hast aktuell keine Anfrage gesendet.',
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
                    CarmaBlueIconBox(
                      icon: icon,
                      size: 48,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
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
                            style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                              Colors.white.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CountBadge(
                      count: count,
                    ),
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
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                            Colors.white.withValues(alpha: 0.74),
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
  const _CountBadge({
    required this.count,
  });

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
          colors: [
            _carmaBlueDark,
            _carmaBlueLight,
          ],
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

class _IncomingRequestsScreen extends StatelessWidget {
  const _IncomingRequestsScreen({
    required this.hasIncomingRequest,
    required this.onAccept,
    required this.onDecline,
  });

  final bool hasIncomingRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      icon: Icons.move_to_inbox_rounded,
      headerTitle: 'Eingehende Anfragen',
      subtitle:
      'Hier entscheidest du, welche Kontaktanfragen angenommen oder abgelehnt werden.',
      child: hasIncomingRequest
          ? _IncomingRequestCard(
        onAccept: () {
          onAccept();
          Navigator.of(context).pop();
        },
        onDecline: () {
          onDecline();
          Navigator.of(context).pop();
        },
      )
          : const _EmptyListCard(
        icon: Icons.mark_email_unread_outlined,
        title: 'Keine offenen Anfragen',
        description:
        'Sobald dich jemand über dein Kennzeichen kontaktiert, erscheint die Anfrage hier.',
      ),
    );
  }
}

class _OutgoingRequestsScreen extends StatelessWidget {
  const _OutgoingRequestsScreen({
    required this.hasOutgoingRequest,
    required this.currentFirstName,
    required this.onWithdraw,
  });

  final bool hasOutgoingRequest;
  final String currentFirstName;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      icon: Icons.outbox_rounded,
      headerTitle: 'Gesendete Anfragen',
      subtitle:
      'Hier siehst du Anfragen, die du nach einer Kennzeichen-Suche gesendet hast.',
      child: hasOutgoingRequest
          ? _OutgoingRequestCard(
        currentFirstName: currentFirstName,
        onWithdraw: () {
          onWithdraw();
          Navigator.of(context).pop();
        },
      )
          : const _EmptyListCard(
        icon: Icons.schedule_send_outlined,
        title: 'Keine gesendeten Anfragen',
        description:
        'Wenn du eine Kontaktanfrage sendest, erscheint sie hier bis sie angenommen, abgelehnt oder zurückgezogen wird.',
      ),
    );
  }
}

class _ActiveChatsScreen extends StatelessWidget {
  const _ActiveChatsScreen({
    required this.hasActiveChat,
  });

  final bool hasActiveChat;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      icon: Icons.forum_rounded,
      headerTitle: 'Aktive Chats',
      subtitle:
      'Hier erscheinen alle Unterhaltungen, die nach angenommener Anfrage entstanden sind.',
      child: hasActiveChat
          ? _ActiveChatListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _ChatConversationScreen(),
            ),
          );
        },
      )
          : const _EmptyListCard(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Noch keine aktiven Chats',
        description:
        'Sobald eine Anfrage angenommen wird, erscheint die Unterhaltung hier.',
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
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              112 + keyboardInset,
            ),
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

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequestUserHeader(),
          const SizedBox(height: 18),
          const _RequestTextBox(
            text:
            'Hey, ich bin [Vorname]. Ich bin gerade mit dem [Farbe] [Marke] [Modell] an dir vorbeigefahren.',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SheetSecondaryButton(
                  label: 'Ablehnen',
                  onPressed: onDecline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetPrimaryButton(
                  label: 'Annehmen',
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutgoingRequestCard extends StatelessWidget {
  const _OutgoingRequestCard({
    required this.currentFirstName,
    required this.onWithdraw,
  });

  final String currentFirstName;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequestUserHeader(),
          const SizedBox(height: 18),
          _RequestTextBox(
            text:
            'Hey, ich bin $currentFirstName. Ich bin gerade mit dem [Farbe] [Marke] [Modell] an dir vorbeigefahren.',
          ),
          const SizedBox(height: 18),
          _SheetSecondaryButton(
            label: 'Anfrage zurückziehen',
            onPressed: onWithdraw,
          ),
        ],
      ),
    );
  }
}

class _RequestUserHeader extends StatelessWidget {
  const _RequestUserHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _UserAvatarPlaceholder(size: 54),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carma Nutzer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '[Farbe] [Marke] [Modell]',
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
      ],
    );
  }
}

class _RequestTextBox extends StatelessWidget {
  const _RequestTextBox({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ActiveChatListTile extends StatelessWidget {
  const _ActiveChatListTile({
    required this.onTap,
  });

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
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '[Farbe] [Marke] [Modell]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                          Colors.white.withValues(alpha: 0.68),
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
          CarmaBlueIconBox(
            icon: icon,
            size: 64,
            iconSize: 32,
          ),
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
        ],
      ),
    );
  }
}

class _UserAvatarPlaceholder extends StatelessWidget {
  const _UserAvatarPlaceholder({
    required this.size,
  });

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
          colors: [
            _carmaBlueDark,
            _carmaBlueLight,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  const _SheetPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _carmaBlueDark,
                _carmaBlue,
                _carmaBlueLight,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _carmaBlue.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetSecondaryButton extends StatelessWidget {
  const _SheetSecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatConversationScreen extends StatefulWidget {
  const _ChatConversationScreen();

  @override
  State<_ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<_ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
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
          'Foto aufnehmen oder aus Galerie wählen verbinden wir später.',
        ),
      ),
    );
  }

  void _handleSend() {
    if (!_hasText) {
      return;
    }

    _messageController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nachrichten werden später mit Firebase verbunden.'),
      ),
    );
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
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    18 + keyboardInset,
                  ),

                  child: Column(
                    children: [
                      _CompactChatInfoCard(
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 14),
                      const _ChatEmptySpace(),
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
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
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
                child: _VehicleInfoPill(
                  label: 'Modell',
                  value: '[Modell]',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _VehicleInfoPill(
                  label: 'Typ',
                  value: '[Typ]',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoPill extends StatelessWidget {
  const _VehicleInfoPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
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

class _ChatEmptySpace extends StatelessWidget {
  const _ChatEmptySpace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 220,
      ),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Text(
        'Noch keine Nachrichten',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.48),
          fontWeight: FontWeight.w700,
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
            _SendButton(
              isEnabled: hasText,
              onTap: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onTap,
  });

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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.onTap,
  });

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
                colors: [
                  _carmaBlueDark,
                  _carmaBlue,
                  _carmaBlueLight,
                ],
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