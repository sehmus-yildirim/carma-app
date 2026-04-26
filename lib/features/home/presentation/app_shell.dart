import 'package:flutter/material.dart';

import '../../chats/presentation/chats_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reports/presentation/report_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'dashboard_screen.dart';

const Color _navAccentBlue = Color(0xFF139CFF);

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    ChatsScreen(),
    ReportScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

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

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _GlassBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onTabSelected: _onTabSelected,
          bottomInset: bottomInset,
        ),
      ),
    );
  }
}

class _GlassBottomNavigationBar extends StatelessWidget {
  const _GlassBottomNavigationBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.bottomInset,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double bottomInset;

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
      label: 'Einstellung',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = bottomInset == 0 ? 8.0 : bottomInset;

    return Container(
      height: 76 + safeBottom,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: _navAccentBlue.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.10),
                _navAccentBlue.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final isSelected = selectedIndex == index;

                      return Expanded(
                        child: _GlassNavigationButton(
                          item: item,
                          isSelected: isSelected,
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
    );
  }
}

class _GlassNavigationButton extends StatelessWidget {
  const _GlassNavigationButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = isSelected ? item.activeIcon : item.icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: isSelected
                  ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0C7FFF),
                  Color(0xFF4FD2FF),
                ],
              )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.transparent,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: _navAccentBlue.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.70),
                  size: isSelected ? 22 : 21,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.72),
                      fontSize: 10.5,
                      fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
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