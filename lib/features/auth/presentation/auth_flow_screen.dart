import 'package:flutter/material.dart';

import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

enum AuthFlowStep {
  login,
  register,
  forgotPassword,
}

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({
    super.key,
    this.onAuthFinished,
  });

  final VoidCallback? onAuthFinished;

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  AuthFlowStep _currentStep = AuthFlowStep.login;

  void _openLogin() {
    setState(() {
      _currentStep = AuthFlowStep.login;
    });
  }

  void _openRegister() {
    setState(() {
      _currentStep = AuthFlowStep.register;
    });
  }

  void _openForgotPassword() {
    setState(() {
      _currentStep = AuthFlowStep.forgotPassword;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_currentStep) {
      case AuthFlowStep.login:
        return LoginScreen(
          key: const ValueKey('login'),
          onRegisterPressed: _openRegister,
          onForgotPasswordPressed: _openForgotPassword,
          onLoginSuccess: widget.onAuthFinished,
        );

      case AuthFlowStep.register:
        return RegisterScreen(
          key: const ValueKey('register'),
          onBack: _openLogin,
          onLoginPressed: _openLogin,
          onRegisterSuccess: widget.onAuthFinished,
        );

      case AuthFlowStep.forgotPassword:
        return ForgotPasswordScreen(
          key: const ValueKey('forgot_password'),
          onBack: _openLogin,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildCurrentScreen(),
    );
  }
}