import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../chats/presentation/chats_screen.dart';
import '../../profile/presentation/social_profile_screen.dart';
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
  final ReportRepository _reportRepository = ReportRepository();

  late final Stream<int> _unreadReportCountStream;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _unreadReportCountStream = _watchUnreadReportCount();
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
        onOpenChats: () => _onTabSelected(2),
      ),
      SocialProfileScreen(userState: widget.userState),
      ChatsScreen(userState: widget.userState),
      ReportScreen(userState: widget.userState),
      SettingsScreen(userState: widget.userState, onLogout: widget.onLogout),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _unreadReportCountStream,
        initialData: 0,
        builder: (context, reportSnapshot) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _GlassBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onTabSelected: _onTabSelected,
              bottomInset: bottomInset,
              unreadReportCount: reportSnapshot.data ?? 0,
            ),
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
    required this.unreadReportCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double bottomInset;
  final int unreadReportCount;

  static const List<_NavigationItem> _items = [
    _NavigationItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
      label: 'Suchen',
    ),
    _NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
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
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Einstellungen',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = bottomInset == 0 ? 8.0 : bottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: safeBottom),
      child: SizedBox(
        height: 72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusNav),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  CaRismaDesignTokens.radiusNav,
                ),
                color: CaRismaDesignTokens.card.withValues(alpha: 0.98),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compactWidth = (constraints.maxWidth * 0.155)
                        .clamp(44.0, 58.0)
                        .toDouble();
                    final activeWidth =
                        constraints.maxWidth -
                        compactWidth * (_items.length - 1);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_items.length, (index) {
                        final item = _items[index];
                        final isSelected = selectedIndex == index;

                        return _GlassNavigationButton(
                          item: item,
                          isSelected: isSelected,
                          width: isSelected ? activeWidth : compactWidth,
                          badgeCount: switch (index) {
                            3 => unreadReportCount,
                            _ => 0,
                          },
                          onTap: () => onTabSelected(index),
                        );
                      }),
                    );
                  },
                ),
              ),
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
    required this.width,
    required this.onTap,
    required this.badgeCount,
  });

  final _NavigationItem item;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final icon = isSelected ? item.activeIcon : item.icon;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: width,
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 4),
        decoration: isSelected
            ? BoxDecoration(
                color: CaRismaDesignTokens.bluePrimary,
                borderRadius: BorderRadius.circular(
                  CaRismaDesignTokens.radiusPanel,
                ),
                border: Border.all(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.14,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CaRismaDesignTokens.bluePrimary.withValues(
                      alpha: 0.28,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(
                    CaRismaDesignTokens.radiusPanel,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            icon,
                            key: ValueKey(icon),
                            color: isSelected
                                ? CaRismaDesignTokens.textPrimary
                                : CaRismaDesignTokens.textMuted,
                            size: 23,
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.loose,
                          child: ClipRect(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.centerLeft,
                              child: isSelected
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 7),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: const TextStyle(
                                            color:
                                                CaRismaDesignTokens.textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -3,
                top: -5,
                child: _NavigationBadge(count: badgeCount),
              ),
          ],
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
