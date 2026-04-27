import 'package:flutter/material.dart';

import '../../home/presentation/app_shell.dart';
import 'auth_flow_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isAuthenticated = false;

  void _completeAuth() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isAuthenticated
          ? const AppShell(
        key: ValueKey('app_shell'),
      )
          : AuthFlowScreen(
        key: const ValueKey('auth_flow'),
        onAuthCompleted: _completeAuth,
      ),
    );
  }
}