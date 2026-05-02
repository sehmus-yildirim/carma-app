import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/config/carma_app_config.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_message_card.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/carma_social_auth_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/auth_service.dart';
import '../domain/registration_legal_consent_builder.dart';

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
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;
  bool _acceptedLegal = false;
  bool _acceptedResponsibleUse = false;
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
        _acceptedLegal &&
        _acceptedResponsibleUse &&
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

    if (!_acceptedLegal) {
      setState(() {
        _errorMessage =
            'Bitte akzeptiere die AGB und Datenschutzhinweise, um fortzufahren.';
        _successMessage = null;
      });
      return;
    }

    if (!_acceptedResponsibleUse) {
      setState(() {
        _errorMessage =
            'Bitte bestätige, dass du Carma verantwortungsvoll und nicht für Notfälle nutzt.';
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
      final credential = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = credential.user?.uid ?? CarmaAppConfig.localUserId;
      final legalConsents = RegistrationLegalConsentBuilder.buildLocalConsents(
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage =
            'Konto erstellt. ${legalConsents.length} Zustimmungen wurden lokal vorbereitet.';
      });

      widget.onRegisterSuccess?.call();
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
        _errorMessage =
            'Registrierung konnte gerade nicht durchgeführt werden.';
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

  Future<void> _submitGoogleRegister() async {
    FocusScope.of(context).unfocus();

    if (!_acceptedLegal || !_acceptedResponsibleUse) {
      setState(() {
        _errorMessage =
            'Bitte akzeptiere zuerst die Hinweise zur Registrierung.';
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
      await _authService.signInWithGoogle();

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = 'Google-Registrierung erfolgreich.';
      });

      widget.onRegisterSuccess?.call();
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
        _errorMessage =
            'Google Registrierung konnte gerade nicht durchgeführt werden.';
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
      case 'email-already-in-use':
        return 'Für diese E-Mail-Adresse existiert bereits ein Konto.';
      case 'weak-password':
        return 'Das Passwort ist zu schwach.';
      case 'operation-not-allowed':
        return 'Diese Anmeldemethode ist in Firebase nicht aktiviert.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      case 'aborted-by-user':
        return 'Die Anmeldung wurde abgebrochen.';
      default:
        return error.message ??
            'Ein unbekannter Registrierungsfehler ist aufgetreten.';
    }
  }

  void _openLogin() {
    if (widget.onLoginPressed != null) {
      widget.onLoginPressed!();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Login ist vorbereitet.')));
  }

  void _showAppleAuthComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Apple Registrierung wird später mit dem iOS-Setup aktiviert.',
        ),
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
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canPop)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _TopBackButton(onTap: _goBack),
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
                          onPressed: _isLoading
                              ? null
                              : () {
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
                          onPressed: _isLoading
                              ? null
                              : () {
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
                _RegistrationLegalCard(
                  acceptedLegal: _acceptedLegal,
                  acceptedResponsibleUse: _acceptedResponsibleUse,
                  onLegalChanged: (value) {
                    setState(() {
                      _acceptedLegal = value;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  onResponsibleUseChanged: (value) {
                    setState(() {
                      _acceptedResponsibleUse = value;
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
                  onPressed: () {
                    if (_isLoading) {
                      return;
                    }

                    _submitGoogleRegister();
                  },
                ),
                const SizedBox(height: 10),
                CarmaSocialAuthButton(
                  provider: CarmaSocialAuthProvider.apple,
                  onPressed: () {
                    if (_isLoading) {
                      return;
                    }

                    _showAppleAuthComingSoon();
                  },
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
                  onPressed: () {
                    if (_isLoading) {
                      return;
                    }

                    _openLogin();
                  },
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
  const _TopBackButton({required this.onTap});

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _RegistrationLegalCard extends StatelessWidget {
  const _RegistrationLegalCard({
    required this.acceptedLegal,
    required this.acceptedResponsibleUse,
    required this.onLegalChanged,
    required this.onResponsibleUseChanged,
  });

  final bool acceptedLegal;
  final bool acceptedResponsibleUse;
  final ValueChanged<bool> onLegalChanged;
  final ValueChanged<bool> onResponsibleUseChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        children: [
          _ConsentRow(
            value: acceptedLegal,
            onChanged: onLegalChanged,
            text:
                'Ich akzeptiere die AGB und Datenschutzhinweise von Carma. Mir ist bewusst, dass meine Angaben später für Konto, Profil, Fahrzeug, Verifizierung und Missbrauchsschutz verarbeitet werden.',
          ),
          const SizedBox(height: 10),
          _ConsentRow(
            value: acceptedResponsibleUse,
            onChanged: onResponsibleUseChanged,
            text:
                'Ich nutze Carma nur verantwortungsvoll. Carma ist keine Notfall-, Polizei- oder Abschlepp-App. Missbrauch, falsche Meldungen, Belästigung oder falsche Fahrzeugdaten können zur Sperrung führen.',
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          activeColor: const Color(0xFF139CFF),
          checkColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.42),
            width: 1.4,
          ),
          onChanged: _isEnabled
              ? (nextValue) => onChanged(nextValue ?? false)
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
                height: 1.34,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _isEnabled => true;
}

class CarmaAuthDivider extends StatelessWidget {
  const CarmaAuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.12),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'oder weiter mit',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.52),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.12),
            thickness: 1,
          ),
        ),
      ],
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
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.78)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
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
