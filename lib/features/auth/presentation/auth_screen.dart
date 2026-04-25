import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../legal/presentation/privacy_policy_screen.dart';
import '../../legal/presentation/terms_screen.dart';
import '../data/auth_service.dart';

const Color _carmaWhite = Colors.white;
const Color _carmaMutedWhite = Color(0xCCFFFFFF);
const Color _carmaHint = Color(0x99FFFFFF);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedLegal = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Bitte gib E-Mail und Passwort ein.';
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _errorMessage = 'Bitte gib eine gültige E-Mail-Adresse ein.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Das Passwort muss mindestens 6 Zeichen lang sein.';
      });
      return;
    }

    if (_isRegisterMode && !_acceptedLegal) {
      setState(() {
        _errorMessage =
        'Bitte akzeptiere die AGB und die Datenschutzerklärung.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await _authService.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Konto erfolgreich erstellt.'),
          ),
        );
      } else {
        await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Erfolgreich eingeloggt.'),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte gib zuerst deine E-Mail-Adresse ein, damit wir dir einen Reset-Link senden können.',
          ),
        ),
      );
      return;
    }

    if (!email.contains('@')) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Bitte gib eine gültige E-Mail-Adresse ein.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Falls ein Konto mit $email existiert, wurde ein Link zum Zurücksetzen des Passworts gesendet.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Der Reset-Link konnte gerade nicht gesendet werden.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google-Anmeldung erfolgreich.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Google Login konnte gerade nicht durchgeführt werden.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAppleInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Apple Login ist vorbereitet und wird später mit dem iOS-Setup aktiviert.',
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
      _acceptedLegal = false;
    });
  }

  void _openTermsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TermsScreen(),
      ),
    );
  }

  void _openPrivacyScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'user-disabled':
        return 'Dieses Nutzerkonto wurde deaktiviert.';
      case 'user-not-found':
        return 'Es wurde kein Konto mit dieser E-Mail-Adresse gefunden.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch.';
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
      case 'apple-not-configured':
        return 'Apple Login wird später mit dem iOS-Setup aktiviert.';
      default:
        return error.message ?? 'Ein unbekannter Fehler ist aufgetreten.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final veryCompactHeight = screenSize.height < 700;
    final compactHeight = screenSize.height < 790;

    final logoSize = veryCompactHeight ? 58.0 : 76.0;
    final titleSize = veryCompactHeight ? 34.0 : 42.0;
    final subtitleSize = veryCompactHeight ? 15.0 : 17.0;
    final sectionGap = compactHeight ? 12.0 : 16.0;
    final inputGap = compactHeight ? 9.0 : 12.0;
    final insidePadding = compactHeight ? 16.0 : 20.0;
    final buttonHeight = compactHeight ? 48.0 : 52.0;

    final cardTitle = _isRegisterMode ? 'Konto erstellen' : 'Anmelden';
    final primaryButtonText =
    _isRegisterMode ? 'Registrieren' : 'Einloggen';
    final switchText =
    _isRegisterMode ? 'Ich habe schon ein Konto' : 'Konto erstellen';

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final allowScroll = constraints.maxHeight < 720;

              return SingleChildScrollView(
                physics: allowScroll
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CarmaLogoMark(size: logoSize),
                          const SizedBox(height: 10),
                          _GlassTitle(fontSize: titleSize),
                          const SizedBox(height: 7),
                          Text(
                            'Finde die Person hinter dem Kennzeichen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _carmaMutedWhite,
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          GlassCard(
                            padding: EdgeInsets.all(insidePadding),
                            radius: 30,
                            opacity: 0.115,
                            borderOpacity: 0.26,
                            glow: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  cardTitle,
                                  style: const TextStyle(
                                    color: _carmaWhite,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                _GlassTextField(
                                  controller: _emailController,
                                  enabled: !_isLoading,
                                  hintText: 'E-Mail',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                ),
                                SizedBox(height: inputGap),
                                _GlassTextField(
                                  controller: _passwordController,
                                  enabled: !_isLoading,
                                  hintText: 'Passwort',
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  suffixIcon: IconButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                      setState(() {
                                        _obscurePassword =
                                        !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: _carmaMutedWhite,
                                    ),
                                  ),
                                ),
                                if (_isRegisterMode) ...[
                                  SizedBox(height: inputGap),
                                  _LegalAcceptanceBox(
                                    accepted: _acceptedLegal,
                                    enabled: !_isLoading,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptedLegal = value;
                                      });
                                    },
                                    onTermsTap: _openTermsScreen,
                                    onPrivacyTap: _openPrivacyScreen,
                                  ),
                                ],
                                if (_errorMessage != null) ...[
                                  SizedBox(height: inputGap),
                                  _ErrorBox(message: _errorMessage!),
                                ],
                                SizedBox(height: sectionGap),
                                GlassPrimaryButton(
                                  label: primaryButtonText,
                                  isLoading: _isLoading,
                                  height: buttonHeight,
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _resetPassword,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _carmaMutedWhite,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 0,
                                              vertical: 5,
                                            ),
                                          ),
                                          child: const Text(
                                            'Passwort vergessen?',
                                            textAlign: TextAlign.left,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _toggleMode,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _carmaWhite,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 0,
                                              vertical: 5,
                                            ),
                                          ),
                                          child: Text(
                                            switchText,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  height: 12,
                                  thickness: 1,
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                SizedBox(height: inputGap),
                                GlassSecondaryButton(
                                  height: buttonHeight,
                                  label: 'Mit Google fortfahren',
                                  icon: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: _carmaWhite,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  onPressed:
                                  _isLoading ? null : _signInWithGoogle,
                                ),
                                SizedBox(height: inputGap),
                                GlassSecondaryButton(
                                  height: buttonHeight,
                                  label: 'Mit Apple fortfahren',
                                  icon: const Icon(
                                    Icons.apple,
                                    color: _carmaWhite,
                                    size: 22,
                                  ),
                                  onPressed:
                                  _isLoading ? null : _showAppleInfo,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 22,
                            runSpacing: 6,
                            children: [
                              _BottomLink(
                                label: 'AGB',
                                onTap: _openTermsScreen,
                              ),
                              _BottomLink(
                                label: 'Datenschutz',
                                onTap: _openPrivacyScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CarmaLogoMark extends StatelessWidget {
  const _CarmaLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: size * 0.25,
      padding: EdgeInsets.zero,
      opacity: 0.13,
      borderOpacity: 0.30,
      glow: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.directions_car_filled_outlined,
              color: Colors.white,
              size: size * 0.50,
            ),
            Positioned(
              top: size * 0.18,
              right: size * 0.16,
              child: Icon(
                Icons.favorite_border,
                color: Colors.white.withValues(alpha: 0.9),
                size: size * 0.20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassTitle extends StatelessWidget {
  const _GlassTitle({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFDDEBFF),
            Colors.white,
          ],
        ).createShader(bounds);
      },
      child: Text(
        'Carma',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.9,
          shadows: [
            Shadow(
              blurRadius: 18,
              color: Colors.white.withValues(alpha: 0.22),
              offset: const Offset(0, 2),
            ),
            Shadow(
              blurRadius: 30,
              color: Colors.white.withValues(alpha: 0.10),
              offset: const Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalAcceptanceBox extends StatelessWidget {
  const _LegalAcceptanceBox({
    required this.accepted,
    required this.enabled,
    required this.onChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final bool accepted;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 17,
      opacity: 0.08,
      borderOpacity: 0.19,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: accepted,
            onChanged: enabled
                ? (value) {
              onChanged(value ?? false);
            }
                : null,
            activeColor: _carmaWhite,
            checkColor: Colors.black,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Ich akzeptiere die ',
                    style: TextStyle(
                      color: _carmaMutedWhite,
                      fontSize: 13,
                    ),
                  ),
                  _InlineLink(label: 'AGB', onTap: onTermsTap),
                  const Text(
                    ' und die ',
                    style: TextStyle(
                      color: _carmaMutedWhite,
                      fontSize: 13,
                    ),
                  ),
                  _InlineLink(
                    label: 'Datenschutzerklärung',
                    onTap: onPrivacyTap,
                  ),
                  const Text(
                    '.',
                    style: TextStyle(
                      color: _carmaMutedWhite,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: _carmaWhite,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
          decorationColor: _carmaWhite,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D4F).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF4D4F).withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hintText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 18,
      opacity: 0.075,
      borderOpacity: 0.20,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: _carmaWhite,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: _carmaHint,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

class _BottomLink extends StatelessWidget {
  const _BottomLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: _carmaMutedWhite,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: _carmaMutedWhite,
        ),
      ),
    );
  }
}