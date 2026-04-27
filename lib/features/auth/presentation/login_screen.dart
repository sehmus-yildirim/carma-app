import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onBack,
    this.onLoginSuccess,
    this.onForgotPasswordPressed,
    this.onRegisterPressed,
  });

  final VoidCallback? onBack;
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onForgotPasswordPressed;
  final VoidCallback? onRegisterPressed;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _hasEmail {
    return _emailController.text.trim().isNotEmpty;
  }

  bool get _hasPassword {
    return _passwordController.text.trim().isNotEmpty;
  }

  bool get _canSubmit {
    return _hasEmail && _hasPassword && !_isLoading;
  }

  @override
  void initState() {
    super.initState();

    _emailController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refresh);
    _passwordController.removeListener(_refresh);

    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _refresh() {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
  }

  bool _isValidEmail(String value) {
    final email = value.trim();

    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Bitte gib eine gültige E-Mail-Adresse ein.';
        _successMessage = null;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Das Passwort muss mindestens 6 Zeichen haben.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _successMessage =
      'Login wurde lokal vorbereitet. Firebase Auth verbinden wir später.';
    });

    widget.onLoginSuccess?.call();
  }

  void _openForgotPassword() {
    if (widget.onForgotPasswordPressed != null) {
      widget.onForgotPasswordPressed!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passwort zurücksetzen verbinden wir im nächsten Schritt.'),
      ),
    );
  }

  void _openRegister() {
    if (widget.onRegisterPressed != null) {
      widget.onRegisterPressed!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registrierung verbinden wir im nächsten Schritt.'),
      ),
    );
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              28 + keyboardInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmaSubPageHeader(
                  icon: Icons.login_rounded,
                  title: 'Einloggen',
                  onBack: _goBack,
                ),
                const SizedBox(height: 18),
                Text(
                  'Melde dich an, um dein Profil, deine Chats und deine Fahrzeugdaten zu verwalten.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _AuthTextField(
                        controller: _emailController,
                        hintText: 'E-Mail-Adresse',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      _AuthTextField(
                        controller: _passwordController,
                        hintText: 'Passwort',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_canSubmit) {
                            _submitLogin();
                          }
                        },
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _openForgotPassword,
                          child: const Text(
                            'Passwort vergessen?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  CarmaMessageCard(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 14),
                  CarmaMessageCard(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                  ),
                ],
                const SizedBox(height: 18),
                CarmaPrimaryButton(
                  label: 'Einloggen',
                  loadingLabel: 'Wird geprüft...',
                  icon: Icons.login_rounded,
                  isEnabled: _canSubmit,
                  isLoading: _isLoading,
                  onPressed: _submitLogin,
                ),
                const SizedBox(height: 12),
                CarmaSecondaryButton(
                  label: 'Noch kein Konto? Registrieren',
                  icon: Icons.person_add_alt_1_rounded,
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  onPressed: _openRegister,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscureText,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.78),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: const Color(0xFF63D5FF).withValues(alpha: 0.90),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}