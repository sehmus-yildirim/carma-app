import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/carma_social_auth_button.dart';
import '../../../shared/widgets/glass_card.dart';

const Color _carmaBlueLight = Color(0xFF63D5FF);
const String _carmaLogoAsset = 'assets/images/carma_logo.png';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onBack,
    this.onRegisterSuccess,
    this.onLoginPressed,
  });

  final VoidCallback? onBack;
  final VoidCallback? onRegisterSuccess;
  final VoidCallback? onLoginPressed;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
  TextEditingController();

  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _hasEmail {
    return _emailController.text.trim().isNotEmpty;
  }

  bool get _hasPassword {
    return _passwordController.text.trim().isNotEmpty;
  }

  bool get _hasRepeatPassword {
    return _repeatPasswordController.text.trim().isNotEmpty;
  }

  bool get _canSubmit {
    return _hasEmail &&
        _hasPassword &&
        _hasRepeatPassword &&
        _acceptedTerms &&
        !_isLoading;
  }

  @override
  void initState() {
    super.initState();

    _emailController.addListener(_refresh);
    _passwordController.addListener(_refresh);
    _repeatPasswordController.addListener(_refresh);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refresh);
    _passwordController.removeListener(_refresh);
    _repeatPasswordController.removeListener(_refresh);

    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();

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

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final repeatPassword = _repeatPasswordController.text;

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

    if (password != repeatPassword) {
      setState(() {
        _errorMessage = 'Die Passwörter stimmen nicht überein.';
        _successMessage = null;
      });
      return;
    }

    if (!_acceptedTerms) {
      setState(() {
        _errorMessage =
        'Bitte bestätige, dass du Carma verantwortungsvoll nutzt.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 750));

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _successMessage =
      'Konto wurde lokal vorbereitet. Firebase Auth verbinden wir später.';
    });

    widget.onRegisterSuccess?.call();
  }

  void _openLogin() {
    if (widget.onLoginPressed != null) {
      widget.onLoginPressed!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login verbinden wir im nächsten Schritt.'),
      ),
    );
  }

  void _showSocialAuthComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text('$provider Registrierung verbinden wir später mit Firebase.'),
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
    final canPop = widget.onBack != null || Navigator.of(context).canPop();

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canPop)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _TopBackButton(
                      onTap: _goBack,
                    ),
                  ),
                SizedBox(height: canPop ? 14 : 8),
                const _RegisterBrandHeader(),
                const SizedBox(height: 28),
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
                        textInputAction: TextInputAction.next,
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
                      _AuthTextField(
                        controller: _repeatPasswordController,
                        hintText: 'Passwort wiederholen',
                        icon: Icons.lock_reset_rounded,
                        obscureText: _obscureRepeatPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_canSubmit) {
                            _submitRegister();
                          }
                        },
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureRepeatPassword =
                              !_obscureRepeatPassword;
                            });
                          },
                          icon: Icon(
                            _obscureRepeatPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _VerificationInfoCard(
                  acceptedTerms: _acceptedTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
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
                  label: 'Konto erstellen',
                  loadingLabel: 'Wird erstellt...',
                  icon: Icons.person_add_alt_1_rounded,
                  isEnabled: _canSubmit,
                  isLoading: _isLoading,
                  onPressed: _submitRegister,
                ),
                const SizedBox(height: 16),
                const CarmaAuthDivider(),
                const SizedBox(height: 16),
                CarmaSocialAuthButton(
                  provider: CarmaSocialAuthProvider.google,
                  onPressed: () => _showSocialAuthComingSoon('Google'),
                ),
                const SizedBox(height: 10),
                CarmaSocialAuthButton(
                  provider: CarmaSocialAuthProvider.apple,
                  onPressed: () => _showSocialAuthComingSoon('Apple'),
                ),
                const SizedBox(height: 12),
                CarmaSecondaryButton(
                  label: 'Schon ein Konto? Einloggen',
                  icon: Icons.login_rounded,
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  onPressed: _openLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterBrandHeader extends StatelessWidget {
  const _RegisterBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          _carmaLogoAsset,
          height: 96,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.white,
                size: 48,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Carma',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 32,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _TopBackButton extends StatelessWidget {
  const _TopBackButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _VerificationInfoCard extends StatelessWidget {
  const _VerificationInfoCard({
    required this.acceptedTerms,
    required this.onChanged,
  });

  final bool acceptedTerms;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: acceptedTerms,
            activeColor: const Color(0xFF139CFF),
            checkColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.42),
              width: 1.4,
            ),
            onChanged: (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ich nutze Carma verantwortungsvoll. Mir ist bewusst, dass Missbrauch, falsche Meldungen oder Belästigung zur Sperrung führen können.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                  height: 1.34,
                ),
              ),
            ),
          ),
        ],
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
            color: _carmaBlueLight.withValues(alpha: 0.90),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}