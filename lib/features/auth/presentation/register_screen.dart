import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_auth_brand_header.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_social_auth_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../legal/presentation/privacy_policy_screen.dart';
import '../../legal/presentation/terms_screen.dart';
import '../data/auth_service.dart';

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
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _acceptedResponsibleUse = false;
  bool _isLoading = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _hasValidEmail => _isValidEmail(_emailController.text);
  bool get _hasValidPassword => _passwordController.text.length >= 6;
  bool get _passwordsMatch =>
      _passwordController.text == _repeatPasswordController.text;

  bool get _canSubmit {
    return _hasValidEmail &&
        _hasValidPassword &&
        _passwordsMatch &&
        _acceptedTerms &&
        _acceptedPrivacy &&
        _acceptedResponsibleUse &&
        !_isLoading;
  }

  bool get _appleSignInAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
    if (_isLoading) {
      return;
    }

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
        _errorMessage = 'Bitte akzeptiere die AGB, um fortzufahren.';
        _successMessage = null;
      });
      return;
    }

    if (!_acceptedPrivacy) {
      setState(() {
        _errorMessage =
            'Bitte akzeptiere die Datenschutzerklärung, um fortzufahren.';
        _successMessage = null;
      });
      return;
    }

    if (!_acceptedResponsibleUse) {
      setState(() {
        _errorMessage =
            'Bitte bestätige, dass du plaqa verantwortungsvoll und nicht für Notfälle nutzt.';
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

      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Das Benutzerkonto konnte nicht geladen werden.',
        );
      }

      final verificationMessage = await _sendVerificationEmailIfNeeded(user);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = 'Konto erstellt.$verificationMessage';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage!)));

      widget.onRegisterSuccess?.call();
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
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_acceptedTerms || !_acceptedPrivacy || !_acceptedResponsibleUse) {
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
      final credential = await _authService.signInWithGoogle();
      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Das Benutzerkonto konnte nicht geladen werden.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = 'Google-Registrierung erfolgreich.';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage!)));

      widget.onRegisterSuccess?.call();
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

  Future<void> _submitAppleRegister() async {
    if (_isLoading || !_appleSignInAvailable) {
      return;
    }

    FocusScope.of(context).unfocus();
    if (!_acceptedTerms || !_acceptedPrivacy || !_acceptedResponsibleUse) {
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
      final credential = await _authService.signInWithApple();
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'missing-user');
      }

      if (!mounted) return;

      setState(() {
        _successMessage = 'Apple-Registrierung erfolgreich.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage!)));
      widget.onRegisterSuccess?.call();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapFirebaseAuthError(error);
        _successMessage = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapFirebaseError(error);
        _successMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Apple-Registrierung konnte gerade nicht durchgeführt werden.';
        _successMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        return 'Diese Anmeldemethode ist aktuell nicht verfügbar.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      case 'aborted-by-user':
        return 'Die Anmeldung wurde abgebrochen.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return 'Für diese Apple-Anmeldung besteht bereits ein Konto. Melde dich zuerst mit der bisherigen Methode an und verknüpfe Apple anschließend unter Konto & Sicherheit.';
      case 'missing-or-invalid-nonce':
      case 'invalid-provider-id':
        return 'Apple-Anmeldung ist noch nicht vollständig konfiguriert.';
      case 'missing-user':
        return 'Das Benutzerkonto konnte nicht geladen werden.';
      default:
        return 'Die Registrierung konnte gerade nicht abgeschlossen werden. Bitte versuche es erneut.';
    }
  }

  Future<String> _sendVerificationEmailIfNeeded(User user) async {
    final email = user.email?.trim() ?? '';

    if (email.isEmpty || user.emailVerified) {
      return '';
    }

    try {
      await _authService.sendEmailVerification(user);
      return ' Bitte bestätige deine E-Mail-Adresse über den Link, den wir dir gesendet haben.';
    } on FirebaseAuthException catch (error) {
      return ' Die Bestätigungs-E-Mail konnte gerade nicht gesendet werden: ${_mapEmailVerificationError(error)}';
    } catch (_) {
      return ' Die Bestätigungs-E-Mail konnte gerade nicht gesendet werden.';
    }
  }

  String _mapEmailVerificationError(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Bitte versuche es später erneut.';
      case 'network-request-failed':
        return 'Bitte prüfe deine Internetverbindung.';
      default:
        return 'Bitte versuche es später erneut.';
    }
  }

  String _mapFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Die Registrierung konnte nicht abgeschlossen werden. Bitte versuche es erneut.';
      case 'unavailable':
        return 'Der Kontodienst ist gerade nicht erreichbar. Bitte versuche es erneut.';
      case 'already-exists':
        return 'Die Zustimmung wurde bereits gespeichert.';
      default:
        return 'Die Kontodaten konnten gerade nicht gespeichert werden.';
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

  void _openTermsScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TermsScreen()));
  }

  void _openPrivacyPolicyScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
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
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
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
                            color: CaRismaDesignTokens.textPrimary.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                            color: CaRismaDesignTokens.textPrimary.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _RegistrationLegalCard(
                  acceptedTerms: _acceptedTerms,
                  acceptedPrivacy: _acceptedPrivacy,
                  acceptedResponsibleUse: _acceptedResponsibleUse,
                  onTermsChanged: (value) {
                    setState(() {
                      _acceptedTerms = value;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  onPrivacyChanged: (value) {
                    setState(() {
                      _acceptedPrivacy = value;
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
                  onTermsPressed: _openTermsScreen,
                  onPrivacyPressed: _openPrivacyPolicyScreen,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  CaRismaMessageCard(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 8),
                  CaRismaMessageCard(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                  ),
                ],
                const SizedBox(height: 10),
                CaRismaPrimaryButton(
                  label: 'Konto erstellen',
                  loadingLabel: 'Wird erstellt...',
                  icon: Icons.person_add_alt_1_rounded,
                  isEnabled: _canSubmit,
                  isLoading: _isLoading,
                  surfaceOutlined: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  borderRadius: 22,
                  iconSize: 24,
                  fontSize: 17,
                  onPressed: _submitRegister,
                ),
                const SizedBox(height: 8),
                const CaRismaAuthDivider(),
                const SizedBox(height: 8),
                CaRismaSocialAuthButton(
                  provider: CaRismaSocialAuthProvider.google,
                  onPressed: () {
                    if (_isLoading) {
                      return;
                    }

                    _submitGoogleRegister();
                  },
                ),
                const SizedBox(height: 8),
                CaRismaSocialAuthButton(
                  provider: CaRismaSocialAuthProvider.apple,
                  isEnabled: _appleSignInAvailable && !_isLoading,
                  onPressed: _appleSignInAvailable && !_isLoading
                      ? _submitAppleRegister
                      : null,
                ),
                const SizedBox(height: 8),
                CaRismaAuthNavigationButton(
                  label: 'Schon ein Konto? Einloggen',
                  icon: Icons.login_rounded,
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

class _RegistrationLegalCard extends StatelessWidget {
  const _RegistrationLegalCard({
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.acceptedResponsibleUse,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onResponsibleUseChanged,
    required this.onTermsPressed,
    required this.onPrivacyPressed,
  });

  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool acceptedResponsibleUse;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onResponsibleUseChanged;
  final VoidCallback onTermsPressed;
  final VoidCallback onPrivacyPressed;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          _ConsentRow(
            value: acceptedTerms,
            onChanged: onTermsChanged,
            semanticLabel: 'AGB akzeptieren',
            text: 'Ich akzeptiere die',
            linkLabel: 'AGB.',
            onLinkPressed: onTermsPressed,
          ),
          _ConsentRow(
            value: acceptedPrivacy,
            onChanged: onPrivacyChanged,
            semanticLabel: 'Datenschutzerklärung akzeptieren',
            text: 'Ich akzeptiere die',
            linkLabel: 'Datenschutzerklärung.',
            onLinkPressed: onPrivacyPressed,
          ),
          _ConsentRow(
            value: acceptedResponsibleUse,
            onChanged: onResponsibleUseChanged,
            semanticLabel: 'Verantwortungsvolle Nutzung bestätigen',
            text: 'Ich nutze plaqa verantwortungsvoll.',
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
    required this.semanticLabel,
    required this.text,
    this.linkLabel,
    this.onLinkPressed,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;
  final String text;
  final String? linkLabel;
  final VoidCallback? onLinkPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 36,
            child: Transform.scale(
              scale: 0.88,
              child: Checkbox(
                value: value,
                semanticLabel: semanticLabel,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: CaRismaDesignTokens.bluePrimary,
                checkColor: Colors.white,
                side: BorderSide(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.42,
                  ),
                  width: 1.4,
                ),
                onChanged: _isEnabled
                    ? (nextValue) => onChanged(nextValue ?? false)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: linkLabel == null || onLinkPressed == null
                  ? Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _consentTextStyle(context),
                    )
                  : Wrap(
                      spacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(text, style: _consentTextStyle(context)),
                        _InlineLegalLink(
                          label: linkLabel!,
                          onTap: onLinkPressed!,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isEnabled => true;
}

TextStyle? _consentTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.76),
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 1.08,
  );
}

class _InlineLegalLink extends StatelessWidget {
  const _InlineLegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: CaRismaDesignTokens.bluePrimary,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.underline,
            decorationColor: CaRismaDesignTokens.bluePrimary,
            fontSize: 12,
            height: 1.08,
          ),
        ),
      ),
    );
  }
}

class CaRismaAuthDivider extends StatelessWidget {
  const CaRismaAuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.12),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'oder weiter mit',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.52),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.12),
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
