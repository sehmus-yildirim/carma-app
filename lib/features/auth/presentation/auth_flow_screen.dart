import 'package:flutter/material.dart';

import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'welcome_screen.dart';

enum _AuthStep {
  welcome,
  login,
  register,
  forgotPassword,
}

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({
    super.key,
    this.onAuthCompleted,
  });

  final VoidCallback? onAuthCompleted;

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  _AuthStep _step = _AuthStep.welcome;

  void _goToWelcome() {
    setState(() {
      _step = _AuthStep.welcome;
    });
  }

  void _goToLogin() {
    setState(() {
      _step = _AuthStep.login;
    });
  }

  void _goToRegister() {
    setState(() {
      _step = _AuthStep.register;
    });
  }

  void _goToForgotPassword() {
    setState(() {
      _step = _AuthStep.forgotPassword;
    });
  }

  void _completeAuth() {
    if (widget.onAuthCompleted != null) {
      widget.onAuthCompleted!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Auth-Flow ist vorbereitet. Die Weiterleitung in die App verbinden wir später.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: switch (_step) {
        _AuthStep.welcome => WelcomeScreen(
          key: const ValueKey('welcome'),
          onLoginPressed: _goToLogin,
          onRegisterPressed: _goToRegister,
        ),
        _AuthStep.login => LoginScreen(
          key: const ValueKey('login'),
          onBack: _goToWelcome,
          onLoginSuccess: _completeAuth,
          onForgotPasswordPressed: _goToForgotPassword,
          onRegisterPressed: _goToRegister,
        ),
        _AuthStep.register => RegisterScreen(
          key: const ValueKey('register'),
          onBack: _goToWelcome,
          onRegisterSuccess: _completeAuth,
          onLoginPressed: _goToLogin,
        ),
        _AuthStep.forgotPassword => ForgotPasswordScreen(
          key: const ValueKey('forgot_password'),
          onBack: _goToLogin,
        ),
      },
    );
  }
}