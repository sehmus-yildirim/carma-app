import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/user_profile_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserProfileRepository _userProfileRepository = UserProfileRepository();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _acceptLegal = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Bitte gib deine E-Mail und dein Passwort ein.';
      });
      return;
    }

    if (!_isValidEmail(email)) {
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

    if (_isRegisterMode && !_acceptLegal) {
      setState(() {
        _errorMessage =
        'Bitte akzeptiere die AGB und Datenschutzerklärung, um fortzufahren.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user;

        if (user != null) {
          await _userProfileRepository.createProfileForUser(user);

          if (!user.emailVerified) {
            await user.sendEmailVerification();
          }
        }

        if (!mounted) return;

        setState(() {
          _isRegisterMode = false;
          _acceptLegal = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Konto erstellt. Wir haben dir eine E-Mail zur Verifizierung gesendet.',
            ),
          ),
        );
      } else {
        await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
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

  Future<void> _showResetPasswordDialog() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: _GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Passwort zurücksetzen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gib deine E-Mail-Adresse ein. Wir senden dir einen Link zum Zurücksetzen deines Passworts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                _GlassTextField(
                  controller: controller,
                  label: 'E-Mail',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  enabled: true,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryOutlineButton(
                        text: 'Abbrechen',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PrimaryButton(
                        text: 'Senden',
                        isLoading: false,
                        onPressed: () async {
                          final email = controller.text.trim();

                          if (email.isEmpty || !_isValidEmail(email)) {
                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bitte gib eine gültige E-Mail-Adresse ein.',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await _firebaseAuth.sendPasswordResetEmail(
                              email: email,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Der Link zum Zurücksetzen wurde per E-Mail gesendet.',
                                ),
                              ),
                            );
                          } on FirebaseAuthException catch (error) {
                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(_mapFirebaseAuthError(error)),
                              ),
                            );
                          } catch (_) {
                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ein unerwarteter Fehler ist aufgetreten.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  Future<void> _continueAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _firebaseAuth.signInAnonymously();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Anonymer Login aktiviert (nur für Entwicklung gedacht).',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Anonymer Login konnte nicht gestartet werden.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
      _acceptLegal = false;
    });
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label wird später eingebaut.'),
      ),
    );
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'user-disabled':
        return 'Dieses Konto wurde deaktiviert.';
      case 'user-not-found':
        return 'Kein Konto mit dieser E-Mail-Adresse gefunden.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch.';
      case 'email-already-in-use':
        return 'Für diese E-Mail-Adresse existiert bereits ein Konto.';
      case 'weak-password':
        return 'Das Passwort ist zu schwach.';
      case 'operation-not-allowed':
        return 'Diese Anmeldemethode ist in Firebase aktuell nicht aktiviert.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte versuche es später erneut.';
      case 'invalid-login-credentials':
        return 'Die Anmeldedaten sind ungültig.';
      case 'missing-email':
        return 'Bitte gib eine E-Mail-Adresse ein.';
      case 'admin-restricted-operation':
        return 'Diese Anmeldemethode ist in Firebase noch nicht aktiviert.';
      default:
        return error.message ?? 'Ein unbekannter Fehler ist aufgetreten.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = _isRegisterMode ? 'Konto erstellen' : 'Anmelden';
    final primaryButtonText = _isRegisterMode ? 'Registrieren' : 'Einloggen';
    final toggleText =
    _isRegisterMode ? 'Ich habe schon ein Konto' : 'Konto erstellen';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Image.asset(
                          'assets/images/carma_logo.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Carma',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kontakt aufnehmen. Sicher. Diskret. Fahrzeugbezogen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _GlassCard(
                        padding: const EdgeInsets.all(22),
                        borderRadius: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              screenTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _GlassTextField(
                              controller: _emailController,
                              label: 'E-Mail',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 14),
                            _GlassTextField(
                              controller: _passwordController,
                              label: 'Passwort',
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !_isLoading,
                              obscureText: _obscurePassword,
                              onSubmitted: (_) => _submit(),
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
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            if (_isRegisterMode) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                    Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(-6, -3),
                                      child: Checkbox(
                                        value: _acceptLegal,
                                        onChanged: _isLoading
                                            ? null
                                            : (value) {
                                          setState(() {
                                            _acceptLegal = value ?? false;
                                          });
                                        },
                                        activeColor: Colors.white,
                                        checkColor: Colors.black,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Wrap(
                                          crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Ich akzeptiere die ',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.82,
                                                ),
                                                fontSize: 13.5,
                                                height: 1.35,
                                              ),
                                            ),
                                            _InlineLink(
                                              text: 'AGB',
                                              onTap: () =>
                                                  _showComingSoon('AGB-Seite'),
                                            ),
                                            Text(
                                              ' und die ',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.82,
                                                ),
                                                fontSize: 13.5,
                                                height: 1.35,
                                              ),
                                            ),
                                            _InlineLink(
                                              text: 'Datenschutzerklärung',
                                              onTap: () => _showComingSoon(
                                                'Datenschutzerklärung',
                                              ),
                                            ),
                                            Text(
                                              '.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.82,
                                                ),
                                                fontSize: 13.5,
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
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _PrimaryButton(
                              text: primaryButtonText,
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _submit,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _isLoading || _isRegisterMode
                                      ? null
                                      : _showResetPasswordDialog,
                                  child: Text(
                                    'Passwort vergessen?',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: _isRegisterMode ? 0.35 : 0.85,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _isLoading ? null : _toggleMode,
                                  child: Text(
                                    toggleText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Divider(
                              color: Colors.white.withValues(alpha: 0.14),
                              height: 22,
                            ),
                            const SizedBox(height: 8),
                            _SecondaryOutlineButton(
                              text: 'Mit Google fortfahren',
                              icon: Icons.login,
                              onPressed: _isLoading
                                  ? null
                                  : () => _showComingSoon('Google Login'),
                            ),
                            const SizedBox(height: 12),
                            _SecondaryOutlineButton(
                              text: 'Mit Apple fortfahren',
                              icon: Icons.apple,
                              onPressed: _isLoading
                                  ? null
                                  : () => _showComingSoon('Apple Login'),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 12),
                              _SecondaryOutlineButton(
                                text: 'Ohne Konto fortfahren',
                                onPressed:
                                _isLoading ? null : _continueAnonymously,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        children: [
                          TextButton(
                            onPressed: () => _showComingSoon('AGB-Seite'),
                            child: const Text(
                              'AGB',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showComingSoon('Datenschutzerklärung'),
                            child: const Text(
                              'Datenschutz',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
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
                Color(0xFF050505),
                Color(0xFF0B0B0B),
                Color(0xFF111111),
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: _GlowCircle(
            size: 220,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        Positioned(
          top: 180,
          right: -70,
          child: _GlowCircle(
            size: 240,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        Positioned(
          bottom: -90,
          left: 20,
          child: _GlowCircle(
            size: 260,
            color: Colors.white.withValues(alpha: 0.04),
          ),
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.34),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
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
              spreadRadius: 35,
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 24,
          sigmaY: 24,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 18),
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
    required this.label,
    required this.keyboardType,
    required this.textInputAction,
    required this.enabled,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white.withValues(alpha: 0.28);
    final focusedBorderColor = Colors.white.withValues(alpha: 0.78);

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: focusedBorderColor,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onPressed,
    required this.isLoading,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        )
            : Text(text),
      ),
    );
  }
}

class _SecondaryOutlineButton extends StatelessWidget {
  const _SecondaryOutlineButton({
    required this.text,
    required this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null;

    if (!hasIcon) {
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: _buttonStyle(),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: _buttonStyle(),
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.24),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white,
          ),
        ),
      ),
    );
  }
}