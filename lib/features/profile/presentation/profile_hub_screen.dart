import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import 'profile_home_feed_screen.dart';
import 'social_profile_screen.dart';

class ProfileHubController extends ChangeNotifier {
  ProfileHubController({int initialIndex = 0})
    : _selectedIndex = initialIndex.clamp(0, 1);

  int _selectedIndex;

  int get selectedIndex => _selectedIndex;

  void select(int index) {
    final normalizedIndex = index.clamp(0, 1);
    if (normalizedIndex == _selectedIndex) return;
    _selectedIndex = normalizedIndex;
    notifyListeners();
  }
}

class ProfileHubScreen extends StatelessWidget {
  const ProfileHubScreen({
    super.key,
    required this.userState,
    required this.controller,
  });

  final AppUserState userState;
  final ProfileHubController controller;

  @override
  Widget build(BuildContext context) {
    return ProfileHubView(
      controller: controller,
      homePage: ProfileHomeFeedScreen(userState: userState),
      profilePage: SocialProfileScreen(
        userState: userState,
      ),
    );
  }
}

class ProfileHubView extends StatefulWidget {
  const ProfileHubView({
    super.key,
    required this.homePage,
    required this.profilePage,
    this.initialPage = 0,
    this.controller,
    this.showSwitcher = true,
  });

  final Widget homePage;
  final Widget profilePage;
  final int initialPage;
  final ProfileHubController? controller;
  final bool showSwitcher;

  @override
  State<ProfileHubView> createState() => _ProfileHubViewState();
}

class _ProfileHubViewState extends State<ProfileHubView> {
  late final PageController _pageController;
  late final ProfileHubController _hubController;
  late final bool _ownsHubController;
  late int _selectedPage;

  @override
  void initState() {
    super.initState();
    _ownsHubController = widget.controller == null;
    _hubController =
        widget.controller ??
        ProfileHubController(initialIndex: widget.initialPage);
    _selectedPage = _hubController.selectedIndex;
    _pageController = PageController(initialPage: _selectedPage);
    _hubController.addListener(_handleExternalSelection);
  }

  @override
  void dispose() {
    _hubController.removeListener(_handleExternalSelection);
    if (_ownsHubController) _hubController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleExternalSelection() {
    final page = _hubController.selectedIndex;
    if (page == _selectedPage || !_pageController.hasClients) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectPage(int page) {
    _hubController.select(page);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          key: const ValueKey('profile-hub-pages'),
          controller: _pageController,
          physics: const PageScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          allowImplicitScrolling: true,
          onPageChanged: (page) {
            setState(() => _selectedPage = page);
            _hubController.select(page);
          },
          children: [
            KeyedSubtree(
              key: const ValueKey('profile-hub-home-page'),
              child: widget.homePage,
            ),
            KeyedSubtree(
              key: const ValueKey('profile-hub-profile-page'),
              child: widget.profilePage,
            ),
          ],
        ),
        if (widget.showSwitcher)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 4,
            child: Center(
              child: ProfileHubSwitcher(
                selectedIndex: _selectedPage,
                onSelected: _selectPage,
              ),
            ),
          ),
      ],
    );
  }
}

class ProfileHubSwitcher extends StatelessWidget {
  const ProfileHubSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProfileHubSwitchButton(
          tooltip: 'Startseite',
          icon: selectedIndex == 0
              ? Icons.home_rounded
              : Icons.home_outlined,
          isSelected: selectedIndex == 0,
          onTap: () => onSelected(0),
        ),
        const SizedBox(width: 12),
        _ProfileHubSwitchButton(
          tooltip: 'Profil',
          icon: selectedIndex == 1
              ? Icons.person_rounded
              : Icons.person_outline_rounded,
          isSelected: selectedIndex == 1,
          onTap: () => onSelected(1),
        ),
      ],
    );
  }
}

class _ProfileHubSwitchButton extends StatelessWidget {
  const _ProfileHubSwitchButton({
    required this.tooltip,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: tooltip,
      child: SizedBox.square(
        dimension: 44,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          padding: EdgeInsets.zero,
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            overlayColor: WidgetStatePropertyAll(
              CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.12),
            ),
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: isSelected ? 25 : 23,
              color: isSelected
                  ? CaRismaDesignTokens.blueBright
                  : CaRismaDesignTokens.textMuted,
              shadows: const [
                Shadow(color: Color(0x99000000), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
