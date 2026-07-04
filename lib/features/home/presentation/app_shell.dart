import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../chats/data/chat_repository.dart';
import '../../chats/presentation/chats_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reports/data/report_repository.dart';
import '../../reports/presentation/report_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.userState, required this.onLogout});

  final AppUserState userState;
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final ReportRepository _reportRepository = ReportRepository();

  late final Stream<int> _openChatCountStream;
  late final Stream<int> _unreadReportCountStream;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _openChatCountStream = _watchOpenChatCount();
    _unreadReportCountStream = _watchUnreadReportCount();
  }

  Stream<int> _watchOpenChatCount() {
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<int>.value(0);
    }

    return _chatRepository.watchChats(userId: trimmedUserId).map((chats) {
      return chats
          .where((chat) => chat.isVisibleInActiveListFor(trimmedUserId))
          .length;
    });
  }

  Stream<int> _watchUnreadReportCount() {
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream<int>.value(0);
    }

    return _reportRepository
        .watchReportNotifications(userId: trimmedUserId)
        .map((notifications) {
          return notifications
              .where((notification) => notification.isUnread)
              .length;
        });
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final screens = [
      DashboardScreen(
        userState: widget.userState,
        onOpenChats: () => _onTabSelected(1),
      ),
      ChatsScreen(userState: widget.userState),
      ReportScreen(userState: widget.userState),
      ProfileScreen(userState: widget.userState),
      SettingsScreen(userState: widget.userState, onLogout: widget.onLogout),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _openChatCountStream,
        initialData: 0,
        builder: (context, chatSnapshot) {
          return StreamBuilder<int>(
            stream: _unreadReportCountStream,
            initialData: 0,
            builder: (context, reportSnapshot) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _GlassBottomNavigationBar(
                  selectedIndex: _selectedIndex,
                  onTabSelected: _onTabSelected,
                  bottomInset: bottomInset,
                  openChatCount: chatSnapshot.data ?? 0,
                  unreadReportCount: reportSnapshot.data ?? 0,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GlassBottomNavigationBar extends StatelessWidget {
  const _GlassBottomNavigationBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.bottomInset,
    required this.openChatCount,
    required this.unreadReportCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double bottomInset;
  final int openChatCount;
  final int unreadReportCount;

  static const List<_NavigationItem> _items = [
    _NavigationItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
      label: 'Suchen',
    ),
    _NavigationItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
    ),
    _NavigationItem(
      icon: Icons.report_outlined,
      activeIcon: Icons.report_rounded,
      label: 'Melden',
    ),
    _NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
    _NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Einstellungen',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = bottomInset == 0 ? 8.0 : bottomInset;

    return Container(
      height: 84 + safeBottom,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusNav),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusNav),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                CaRismaDesignTokens.radiusNav,
              ),
              color: CaRismaDesignTokens.backgroundTop.withValues(alpha: 0.96),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
                    child: Row(
                      children: List.generate(_items.length, (index) {
                        final item = _items[index];
                        final isSelected = selectedIndex == index;

                        return Expanded(
                          child: _GlassNavigationButton(
                            item: item,
                            isSelected: isSelected,
                            badgeCount: switch (index) {
                              1 => openChatCount,
                              2 => unreadReportCount,
                              _ => 0,
                            },
                            onTap: () => onTabSelected(index),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                SizedBox(height: safeBottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavigationButton extends StatelessWidget {
  const _GlassNavigationButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.badgeCount,
  });

  final _NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final icon = isSelected ? item.activeIcon : item.icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                width: 44,
                height: 38,
                decoration: isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: CaRismaDesignTokens.surface2,
                        border: Border.all(
                          color: CaRismaDesignTokens.bluePrimary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.50),
                            blurRadius: 10,
                            offset: const Offset(3, 3),
                          ),
                          BoxShadow(
                            color: CaRismaDesignTokens.bluePrimary.withValues(
                              alpha: 0.30,
                            ),
                            blurRadius: 10,
                            offset: const Offset(-1, -1),
                          ),
                        ],
                      )
                    : null,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? CaRismaDesignTokens.bluePrimary
                          : CaRismaDesignTokens.textMuted,
                      size: 22,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -10,
                        top: -8,
                        child: _NavigationBadge(count: badgeCount),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : CaRismaDesignTokens.textMuted.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationBadge extends StatelessWidget {
  const _NavigationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : count.toString();

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D6D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
