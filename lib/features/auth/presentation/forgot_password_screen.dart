import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/carisma_auth_brand_header.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _hasValidEmail => _isValidEmail(_emailController.text);

  bool get _canSubmit {
    return _hasValidEmail && !_isLoading;
  }

  @override
  void initState() {
    super.initState();

    _emailController.addListener(_refresh);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refresh);
    _emailController.dispose();

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

  Future<void> _submitReset() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Bitte gib eine gültige E-Mail-Adresse ein.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage =
            'Wenn ein Konto zu dieser E-Mail existiert, wurde ein Link zum Zurücksetzen gesendet.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
        _successMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Der Reset-Link konnte gerade nicht gesendet werden.';
        _successMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'user-disabled':
        return 'Dieses Nutzerkonto wurde deaktiviert.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      default:
        return error.message ??
            'Der Reset-Link konnte gerade nicht gesendet werden.';
    }
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
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    const CaRismaAuthBrandHeader(),
                    CaRismaAuthBackButton(onTap: _goBack),
                  ],
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: _AuthTextField(
                    controller: _emailController,
                    hintText: 'E-Mail-Adresse',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_canSubmit) {
                        _submitReset();
                      }
                    },
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  CaRismaMessageCard(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 14),
                  CaRismaMessageCard(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                  ),
                ],
                const SizedBox(height: 14),
                CaRismaPrimaryButton(
                  label: 'Reset-Link senden',
                  loadingLabel: 'Wird gesendet...',
                  icon: Icons.mark_email_read_outlined,
                  isEnabled: _canSubmit,
                  isLoading: _isLoading,
                  surfaceOutlined: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  borderRadius: 22,
                  iconSize: 24,
                  fontSize: 17,
                  onPressed: _submitReset,
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
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
