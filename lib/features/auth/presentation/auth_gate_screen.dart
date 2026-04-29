import 'package:flutter/material.dart';

import '../../../shared/models/carma_models.dart';
import '../../../shared/config/carma_app_config.dart';
import '../../home/presentation/app_shell.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import 'auth_flow_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  AppUserState? _appUserState;

  bool get _isAuthenticated {
    return _appUserState != null;
  }

  bool get _isOnboardingCompleted {
    return _appUserState?.accountStatus.isOnboardingCompleted ?? false;
  }

  void _completeAuth() {
    setState(() {
      _appUserState = AppUserState.localRegistered(
        userId: CarmaAppConfig.localUserId,
      );
    });
  }

  void _completeOnboarding() {
    final currentState = _appUserState;

    if (currentState == null) {
      return;
    }

    setState(() {
      _appUserState = currentState.markOnboardingCompleted();
    });
  }

  void _backToAuth() {
    setState(() {
      _appUserState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !_isAuthenticated
          ? AuthFlowScreen(
        key: const ValueKey('auth_flow'),
        onAuthFinished: _completeAuth,
      )
          : !_isOnboardingCompleted
          ? OnboardingFlowScreen(
        key: const ValueKey('onboarding_flow'),
        onCompleted: _completeOnboarding,
        onBack: _backToAuth,
      )
          : AppShell(
        key: const ValueKey('app_shell'),
        onLogout: _backToAuth,
      ),
    );
  }
}