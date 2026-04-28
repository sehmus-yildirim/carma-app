import 'package:flutter/material.dart';

import '../../home/presentation/app_shell.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import 'auth_flow_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isAuthenticated = false;
  bool _isOnboardingCompleted = false;

  void _completeAuth() {
    setState(() {
      _isAuthenticated = true;
      _isOnboardingCompleted = false;
    });
  }

  void _completeOnboarding() {
    setState(() {
      _isOnboardingCompleted = true;
    });
  }

  void _backToAuth() {
    setState(() {
      _isAuthenticated = false;
      _isOnboardingCompleted = false;
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