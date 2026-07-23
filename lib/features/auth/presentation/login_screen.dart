import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/carisma_auth_brand_header.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_social_auth_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_service.dart';
import '../data/user_profile_repository.dart';
import '../data/search_credit_repository.dart';
import '../../../shared/theme/carisma_design_tokens.dart';

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
  final AuthService _authService = AuthService();
  final UserProfileRepository _userProfileRepository = UserProfileRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final SearchCreditRepository _searchCreditRepository =
      SearchCreditRepository();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _hasValidEmail => _isValidEmail(_emailController.text);
  bool get _hasValidPassword => _passwordController.text.length >= 6;

  bool get _canSubmit => _hasValidEmail && _hasValidPassword && !_isLoading;

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

  Future<void> _prepareFirestoreUser(User user) async {
    await _userProfileRepository.createProfileForUser(user);
    await _profileRepository.createProfileIfMissing(user);
    await _searchCreditRepository.createSearchCreditIfMissing(userId: user.uid);
  }

  Future<void> _submitLogin() async {
    if (_isLoading) {
      return;
    }

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

    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Der Firebase-Nutzer konnte nicht geladen werden.',
        );
      }

      await _prepareFirestoreUser(user);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = _loginSuccessMessage(user);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage!)));

      widget.onLoginSuccess?.call();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
        _successMessage = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _successMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Login konnte gerade nicht durchgeführt werden.';
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

  Future<void> _submitGoogleLogin() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final credential = await _authService.signInWithGoogle();
      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Der Firebase-Nutzer konnte nicht geladen werden.',
        );
      }

      if (credential.additionalUserInfo?.isNewUser ?? false) {
        try {
          await user.delete();
        } finally {
          await _authService.signOut();
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage =
              'Bitte registriere dich zuerst, damit deine Zustimmungen gespeichert werden.';
          _successMessage = null;
        });
        return;
      }

      await _prepareFirestoreUser(user);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = _loginSuccessMessage(
          user,
          verifiedMessage: 'Google-Anmeldung erfolgreich.',
        );
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage!)));

      widget.onLoginSuccess?.call();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
        _successMessage = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _successMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Google Login konnte gerade nicht durchgeführt werden.';
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
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      case 'operation-not-allowed':
        return 'Diese Anmeldemethode ist in Firebase nicht aktiviert.';
      case 'aborted-by-user':
        return 'Die Anmeldung wurde abgebrochen.';
      case 'missing-user':
        return 'Der Firebase-Nutzer konnte nicht geladen werden.';
      default:
        return error.message ?? 'Ein unbekannter Login-Fehler ist aufgetreten.';
    }
  }

  String _loginSuccessMessage(
    User user, {
    String verifiedMessage = 'Erfolgreich eingeloggt.',
  }) {
    final email = user.email?.trim() ?? '';

    if (email.isEmpty || user.emailVerified) {
      return verifiedMessage;
    }

    return '$verifiedMessage Deine E-Mail-Adresse ist noch nicht bestätigt.';
  }

  String _mapFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore-Zugriff verweigert. Bitte prüfe die Firebase Rules.';
      case 'unavailable':
        return 'Firestore ist gerade nicht erreichbar. Bitte versuche es erneut.';
      default:
        return error.message ??
            'Firebase konnte die Nutzerdaten gerade nicht speichern.';
    }
  }

  void _openForgotPassword() {
    if (widget.onForgotPasswordPressed != null) {
      widget.onForgotPasswordPressed!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Passwort zurücksetzen ist vorbereitet.')),
    );
  }

  void _openRegister() {
    if (widget.onRegisterPressed != null) {
      widget.onRegisterPressed!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registrierung ist vorbereitet.')),
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
    final canPop = widget.onBack != null || Navigator.of(context).canPop();

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
                    if (canPop) CaRismaAuthBackButton(onTap: _goBack),
                  ],
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _AuthTextField(
                        controller: _emailController,
                        hintText: 'E-Mail-Adresse',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _openForgotPassword,
                          child: Text(
                            'Passwort vergessen?',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: CaRismaDesignTokens.textPrimary,
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
                  label: 'Einloggen',
                  loadingLabel: 'Wird geprüft...',
                  icon: Icons.login_rounded,
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
                  onPressed: _submitLogin,
                ),
                const SizedBox(height: 12),
                const _AuthDivider(),
                const SizedBox(height: 12),
                CaRismaSocialAuthButton(
                  provider: CaRismaSocialAuthProvider.google,
                  onPressed: () {
                    if (_isLoading) {
                      return;
                    }

                    _submitGoogleLogin();
                  },
                ),
                const SizedBox(height: 8),
                const CaRismaSocialAuthButton(
                  provider: CaRismaSocialAuthProvider.apple,
                  isEnabled: false,
                ),
                const SizedBox(height: 8),
                CaRismaAuthNavigationButton(
                  label: 'Noch kein Konto? Registrieren',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () {
                    if (_isLoading) {
                      return;
                    }

                    _openRegister();
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

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

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
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
