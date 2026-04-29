import 'package:flutter/material.dart';

import '../../../shared/models/carma_models.dart';
import '../../home/presentation/app_shell.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import 'auth_flow_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  AccountStatus? _accountStatus;

  bool get _isAuthenticated {
    return _accountStatus != null;
  }

  bool get _isOnboardingCompleted {
    return _accountStatus?.isOnboardingCompleted ?? false;
  }

  void _completeAuth() {
    setState(() {
      _accountStatus = AccountStatus.localRegistered(
        userId: 'local-user',
      );
    });
  }

  void _completeOnboarding() {
    final currentStatus = _accountStatus;

    if (currentStatus == null) {
      return;
    }

    setState(() {
      _accountStatus = currentStatus.markOnboardingCompleted();
    });
  }

  void _backToAuth() {
    setState(() {
      _accountStatus = null;
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