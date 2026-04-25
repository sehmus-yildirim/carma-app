import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../legal/presentation/privacy_policy_screen.dart';
import '../../legal/presentation/terms_screen.dart';
import '../data/auth_service.dart';

const Color _carmaCard = Color(0x1AFFFFFF);
const Color _carmaBorder = Color(0x33FFFFFF);
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

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

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
      } else {
        await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isRegisterMode
                ? 'Konto erfolgreich erstellt.'
                : 'Erfolgreich eingeloggt.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
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

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String email = _emailController.text.trim();

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

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Falls ein Konto mit $email existiert, wurde ein Link zum Zurücksetzen des Passworts gesendet.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
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

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google-Anmeldung erfolgreich.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
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

  Future<void> _showAppleInfo() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Apple Login ist vorbereitet und wird aktiviert, sobald wir das iOS-Setup sauber einbauen.',
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
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
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool compactHeight = screenSize.height < 780;
    final bool veryCompactHeight = screenSize.height < 700;

    final double logoSize = veryCompactHeight ? 68 : 86;
    final double titleSize = veryCompactHeight ? 34 : 42;
    final double subtitleSize = veryCompactHeight ? 16 : 18;
    final double topGap = veryCompactHeight ? 10 : 16;
    final double sectionGap = compactHeight ? 14 : 20;
    final double inputGap = compactHeight ? 10 : 14;
    final double insidePadding = compactHeight ? 18 : 24;
    final double buttonHeight = compactHeight ? 50 : 54;
    final double bottomLinksGap = compactHeight ? 14 : 18;

    final String cardTitle = _isRegisterMode ? 'Konto erstellen' : 'Anmelden';
    final String primaryButtonText =
    _isRegisterMode ? 'Registrieren' : 'Einloggen';
    final String switchText =
    _isRegisterMode ? 'Ich habe schon ein Konto' : 'Konto erstellen';

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool allowScroll = constraints.maxHeight < 720;

                return SingleChildScrollView(
                  physics: allowScroll
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/carma_logo.png',
                              width: logoSize,
                              height: logoSize,
                            ),
                            SizedBox(height: topGap),
                            Text(
                              'Carma',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _carmaWhite,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                shadows: [
                                  Shadow(
                                    blurRadius: 18,
                                    color: Colors.white.withValues(alpha: 0.16),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Finde die Person hinter dem Kennzeichen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _carmaMutedWhite,
                                fontSize: subtitleSize,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: sectionGap),
                            _GlassCard(
                              padding: EdgeInsets.all(insidePadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    cardTitle,
                                    style: const TextStyle(
                                      color: _carmaWhite,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
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
                                    _GlassCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      borderRadius: 16,
                                      blurSigma: 18,
                                      child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: _acceptedLegal,
                                            onChanged: _isLoading
                                                ? null
                                                : (value) {
                                              setState(() {
                                                _acceptedLegal =
                                                    value ?? false;
                                              });
                                            },
                                            activeColor: _carmaWhite,
                                            checkColor: Colors.black,
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.42,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding:
                                              const EdgeInsets.only(top: 10),
                                              child: Wrap(
                                                crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                                children: [
                                                  const Text(
                                                    'Ich akzeptiere die ',
                                                    style: TextStyle(
                                                      color: _carmaMutedWhite,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: _openTermsScreen,
                                                    child: const Text(
                                                      'AGB',
                                                      style: TextStyle(
                                                        color: _carmaWhite,
                                                        fontSize: 14,
                                                        fontWeight:
                                                        FontWeight.w700,
                                                        decoration:
                                                        TextDecoration
                                                            .underline,
                                                        decorationColor:
                                                        _carmaWhite,
                                                      ),
                                                    ),
                                                  ),
                                                  const Text(
                                                    ' und die ',
                                                    style: TextStyle(
                                                      color: _carmaMutedWhite,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: _openPrivacyScreen,
                                                    child: const Text(
                                                      'Datenschutzerklärung',
                                                      style: TextStyle(
                                                        color: _carmaWhite,
                                                        fontSize: 14,
                                                        fontWeight:
                                                        FontWeight.w700,
                                                        decoration:
                                                        TextDecoration
                                                            .underline,
                                                        decorationColor:
                                                        _carmaWhite,
                                                      ),
                                                    ),
                                                  ),
                                                  const Text(
                                                    '.',
                                                    style: TextStyle(
                                                      color: _carmaMutedWhite,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_errorMessage != null) ...[
                                    SizedBox(height: inputGap),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF4D4F,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFF4D4F,
                                          ).withValues(alpha: 0.30),
                                        ),
                                      ),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: sectionGap),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: FilledButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        disabledBackgroundColor: Colors.white
                                            .withValues(alpha: 0.75),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(16),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.black,
                                        ),
                                      )
                                          : Text(primaryButtonText),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            onPressed:
                                            _isLoading ? null : _resetPassword,
                                            style: TextButton.styleFrom(
                                              foregroundColor: _carmaMutedWhite,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 0,
                                                vertical: 6,
                                              ),
                                            ),
                                            child: const Text(
                                              'Passwort vergessen?',
                                              textAlign: TextAlign.left,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed:
                                            _isLoading ? null : _toggleMode,
                                            style: TextButton.styleFrom(
                                              foregroundColor: _carmaWhite,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 0,
                                                vertical: 6,
                                              ),
                                            ),
                                            child: Text(
                                              switchText,
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: inputGap),
                                  _SocialButton(
                                    label: 'Mit Google fortfahren',
                                    icon: const Text(
                                      'G',
                                      style: TextStyle(
                                        color: _carmaWhite,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    onPressed:
                                    _isLoading ? null : _signInWithGoogle,
                                  ),
                                  SizedBox(height: inputGap),
                                  _SocialButton(
                                    label: 'Mit Apple fortfahren',
                                    icon: const Icon(
                                      Icons.apple,
                                      color: _carmaWhite,
                                      size: 20,
                                    ),
                                    onPressed:
                                    _isLoading ? null : _showAppleInfo,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: bottomLinksGap),
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
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B0D12),
                Color(0xFF080A0F),
                Color(0xFF05070B),
              ],
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -60,
          child: _GlowOrb(
            size: 240,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -80,
          child: _GlowOrb(
            size: 280,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.34),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 120,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.blurSigma = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _carmaCard,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: _carmaBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
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
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: _carmaHint,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _carmaWhite,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.02),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(child: icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
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
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: _carmaMutedWhite,
        ),
      ),
    );
  }
}