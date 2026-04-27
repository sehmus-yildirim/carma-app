import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _hasEmail {
    return _emailController.text.trim().isNotEmpty;
  }

  bool get _canSubmit {
    return _hasEmail && !_isLoading;
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

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _successMessage =
      'Wenn ein Konto zu dieser E-Mail existiert, wird später ein Link zum Zurücksetzen gesendet.';
    });
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
                  icon: Icons.lock_reset_rounded,
                  title: 'Passwort vergessen',
                  onBack: _goBack,
                ),
                const SizedBox(height: 18),
                Text(
                  'Gib deine E-Mail-Adresse ein. Später senden wir dir darüber einen sicheren Link zum Zurücksetzen deines Passworts.',
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
                  label: 'Link vorbereiten',
                  loadingLabel: 'Wird vorbereitet...',
                  icon: Icons.mark_email_read_outlined,
                  isEnabled: _canSubmit,
                  isLoading: _isLoading,
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