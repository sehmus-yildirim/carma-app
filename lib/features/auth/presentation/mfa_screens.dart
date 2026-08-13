import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../data/auth_service.dart';
import '../data/mfa_service.dart';

class MfaManagementScreen extends StatefulWidget {
  const MfaManagementScreen({
    super.key,
    required this.initialAccount,
    required this.accountGateway,
    this.mfaGateway,
    this.onOpenSupport,
  });

  final AuthAccountSnapshot initialAccount;
  final AccountAuthGateway accountGateway;
  final MfaGateway? mfaGateway;
  final VoidCallback? onOpenSupport;

  @override
  State<MfaManagementScreen> createState() => _MfaManagementScreenState();
}

class _MfaManagementScreenState extends State<MfaManagementScreen> {
  late final MfaGateway _mfaGateway;
  late AuthAccountSnapshot _account;
  MfaStatusSnapshot? _status;
  bool _isLoading = true;
  bool _isSendingEmail = false;
  String? _message;
  bool _messageIsError = false;

  bool get _providerSupported {
    return _account.hasPasswordProvider ||
        _account.providers.contains(AuthLoginProvider.google);
  }

  @override
  void initState() {
    super.initState();
    _mfaGateway = widget.mfaGateway ?? FirebaseMfaService();
    _account = widget.initialAccount;
    _loadStatus();
  }

  Future<void> _loadStatus({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) _message = null;
    });
    try {
      final status = await _mfaGateway.loadStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = mfaErrorMessage(error);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Der Status des Zwei-Faktor-Schutzes konnte nicht geladen werden.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_isSendingEmail) return;
    setState(() {
      _isSendingEmail = true;
      _message = null;
    });
    try {
      await widget.accountGateway.sendCurrentUserEmailVerification();
      if (!mounted) return;
      setState(() {
        _message = 'Der Bestätigungslink wurde sicher versendet.';
        _messageIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = mfaErrorMessage(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  Future<void> _refreshAccount() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final account = await widget.accountGateway.loadCurrentAccount();
      if (account == null) {
        throw FirebaseAuthException(code: 'missing-user');
      }
      if (!mounted) return;
      setState(() {
        _account = account;
        _message = account.isEmailVerified
            ? 'Deine E-Mail Adresse ist bestätigt.'
            : 'Deine E-Mail Adresse ist noch nicht bestätigt.';
        _messageIsError = !account.isEmailVerified;
      });
      if (account.isEmailVerified) await _loadStatus();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = mfaErrorMessage(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startEnrollment() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            MfaEnrollmentScreen(account: _account, mfaGateway: _mfaGateway),
      ),
    );
    if (completed == true && mounted) {
      setState(() {
        _message = 'Der Zwei-Faktor-Schutz wurde erfolgreich aktualisiert.';
        _messageIsError = false;
      });
      await _loadStatus();
    }
  }

  Future<void> _openRecovery() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MfaRecoveryScreen(mfaGateway: _mfaGateway),
      ),
    );
  }

  Future<void> _removeFactor(MfaFactorSnapshot factor) async {
    final factors = _status?.factors ?? const <MfaFactorSnapshot>[];
    final removingLastFactor = factors.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _MfaDialog(
        title: removingLastFactor
            ? 'Letzten Faktor entfernen?'
            : 'Mobiltelefon entfernen?',
        message: removingLastFactor
            ? 'Danach ist dein Konto nicht mehr durch einen zweiten Faktor geschützt.'
            : '${factor.maskedPhoneNumber} wird nicht mehr zur Anmeldung verwendet.',
        confirmLabel: 'Entfernen',
        danger: true,
      ),
    );
    if (confirmed != true || !mounted) return;

    final reauthenticated = await _reauthenticateForRemoval();
    if (!reauthenticated || !mounted) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await _mfaGateway.removeFactor(factor.uid);
      if (!mounted) return;
      setState(() {
        _status = MfaStatusSnapshot(
          factors: factors
              .where((candidate) => candidate.uid != factor.uid)
              .toList(growable: false),
        );
        _message = removingLastFactor
            ? 'Der Zwei-Faktor-Schutz wurde deaktiviert.'
            : 'Das Mobiltelefon wurde entfernt.';
        _messageIsError = false;
      });
      await _loadStatus(clearMessage: false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = mfaErrorMessage(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _reauthenticateForRemoval() async {
    String? password;
    if (_account.hasPasswordProvider) {
      password = await _requestCurrentPassword();
      if (password == null) return false;
    }
    try {
      await _mfaGateway.reauthenticate(currentPassword: password);
      return true;
    } on FirebaseAuthMultiFactorException catch (error) {
      return _resolveReauthentication(error);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return false;
      setState(() {
        _message = mfaErrorMessage(error);
        _messageIsError = true;
      });
      return false;
    }
  }

  Future<bool> _resolveReauthentication(
    FirebaseAuthMultiFactorException error,
  ) async {
    try {
      final challenge = _mfaGateway.challengeFromException(error);
      final result = await Navigator.of(context).push<UserCredential>(
        MaterialPageRoute<UserCredential>(
          builder: (_) => MfaSignInChallengeScreen(
            challenge: challenge,
            mfaGateway: _mfaGateway,
            title: 'Entfernen bestätigen',
            description:
                'Tippe auf „SMS-Code zum Entfernen senden“ und bestätige den Code. Danach wird die Telefonnummer entfernt.',
            sendCodeLabel: 'SMS-Code zum Entfernen senden',
            confirmCodeLabel: 'Telefonnummer entfernen',
          ),
        ),
      );
      return result != null;
    } on FirebaseAuthException catch (mfaError) {
      if (mounted) {
        setState(() {
          _message = mfaErrorMessage(mfaError);
          _messageIsError = true;
        });
      }
      return false;
    }
  }

  Future<String?> _requestCurrentPassword() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _MfaPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factors = _status?.factors ?? const <MfaFactorSnapshot>[];
    final enabled = factors.isNotEmpty;
    return _MfaPageFrame(
      title: 'Zwei-Faktor-Schutz',
      onBack: () => Navigator.of(context).pop(),
      children: [
        _MfaCard(
          icon: enabled ? Icons.verified_user_rounded : Icons.security_rounded,
          title: enabled ? 'Eingerichtet' : 'Nicht eingerichtet',
          accent: enabled
              ? CaRismaDesignTokens.success
              : CaRismaDesignTokens.bluePrimary,
          child: Text(
            enabled
                ? '${factors.length} ${factors.length == 1 ? 'Faktor ist' : 'Faktoren sind'} für dein Konto registriert.'
                : 'Ein SMS-Code schützt deine Anmeldung zusätzlich zu deinem Passwort oder Google-Konto.',
            style: _mfaSecondaryText(),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          _MfaMessage(message: _message!, isError: _messageIsError),
        ],
        const SizedBox(height: 14),
        if (_isLoading)
          const _MfaLoadingCard()
        else if (!_providerSupported)
          const _MfaMessage(
            message:
                'Diese Anmeldeart unterstützt den SMS-Zwei-Faktor-Schutz nicht.',
            isError: true,
          )
        else if (!_account.isEmailVerified) ...[
          const _MfaMessage(
            message:
                'Bestätige zuerst deine E-Mail Adresse. Das verhindert, dass fremde Personen dein Konto mit einem zweiten Faktor sperren.',
            isError: true,
          ),
          const SizedBox(height: 10),
          _MfaButton(
            label: 'E-Mail erneut senden',
            icon: Icons.mark_email_unread_rounded,
            loading: _isSendingEmail,
            onTap: _sendVerificationEmail,
          ),
          const SizedBox(height: 10),
          _MfaButton(
            label: 'Status aktualisieren',
            icon: Icons.refresh_rounded,
            outlined: true,
            onTap: _refreshAccount,
          ),
        ] else ...[
          if (factors.isNotEmpty)
            _MfaCard(
              icon: Icons.phonelink_lock_rounded,
              title: 'Registrierte Faktoren',
              child: Column(
                children: [
                  for (var index = 0; index < factors.length; index++) ...[
                    _MfaFactorTile(
                      factor: factors[index],
                      onRemove: () => _removeFactor(factors[index]),
                    ),
                    if (index != factors.length - 1)
                      Divider(
                        color: Colors.white.withValues(alpha: 0.07),
                        height: 20,
                      ),
                  ],
                ],
              ),
            ),
          if (factors.isNotEmpty) const SizedBox(height: 12),
          _MfaButton(
            label: factors.isEmpty
                ? 'Zwei-Faktor-Schutz aktivieren'
                : 'Backup-Telefon hinzufügen',
            icon: factors.isEmpty ? Icons.security_rounded : Icons.add_call,
            onTap: _startEnrollment,
          ),
        ],
        const SizedBox(height: 14),
        const _MfaCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Kontozugriff sichern',
          child: Text(
            'Ein Passwort-Reset umgeht den zweiten Faktor nicht. Registriere nach Möglichkeit ein Backup-Telefon. Ohne Zugriff auf deinen einzigen Faktor kann nur ein kontrollierter Support-Prozess helfen.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        if (factors.isNotEmpty) ...[
          const SizedBox(height: 10),
          _MfaButton(
            label: 'Wiederherstellung verwalten',
            icon: Icons.restore_rounded,
            outlined: true,
            onTap: _openRecovery,
          ),
        ],
        if (widget.onOpenSupport != null) ...[
          const SizedBox(height: 10),
          _MfaButton(
            label: 'Support kontaktieren',
            icon: Icons.support_agent_rounded,
            outlined: true,
            onTap: widget.onOpenSupport!,
          ),
        ],
      ],
    );
  }
}

class MfaEnrollmentScreen extends StatefulWidget {
  const MfaEnrollmentScreen({
    super.key,
    required this.account,
    required this.mfaGateway,
  });

  final AuthAccountSnapshot account;
  final MfaGateway mfaGateway;

  @override
  State<MfaEnrollmentScreen> createState() => _MfaEnrollmentScreenState();
}

class _MfaEnrollmentScreenState extends State<MfaEnrollmentScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _consentAccepted = false;
  bool _passwordVisible = false;
  bool _isSending = false;
  bool _isConfirming = false;
  MfaCodeDispatch? _dispatch;
  String? _maskedPhoneNumber;
  String? _error;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (_isSending || _isConfirming) return;
    if (!resend && _dispatch != null) return;
    if (resend && (_dispatch == null || _cooldownSeconds > 0)) return;
    FocusScope.of(context).unfocus();

    String phoneNumber;
    try {
      phoneNumber = normalizeDachPhoneNumber(_phoneController.text);
    } on FirebaseAuthException catch (error) {
      setState(() => _error = mfaErrorMessage(error));
      return;
    }
    if (!_consentAccepted) {
      setState(() {
        _error =
            'Bestätige zuerst die Datenschutzhinweise für den SMS-Versand.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
      _maskedPhoneNumber = maskPhoneNumber(phoneNumber);
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      if (!resend) {
        await _reauthenticate();
      }
      await widget.mfaGateway.requestEnrollmentCode(
        phoneNumber: phoneNumber,
        forceResendingToken: resend ? _dispatch?.resendToken : null,
        onCodeSent: (dispatch) {
          if (!mounted) return;
          setState(() => _dispatch = dispatch);
          _startCooldown();
        },
        onVerificationFailed: (error) {
          if (!mounted) return;
          setState(() => _error = mfaErrorMessage(error));
        },
        onAutoVerified: () {
          if (mounted) Navigator.of(context).pop(true);
        },
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _reauthenticate() async {
    try {
      await widget.mfaGateway.reauthenticate(
        currentPassword: widget.account.hasPasswordProvider
            ? _passwordController.text
            : null,
      );
    } on FirebaseAuthMultiFactorException catch (error) {
      if (!mounted) {
        throw FirebaseAuthException(code: 'aborted-by-user');
      }
      final challenge = widget.mfaGateway.challengeFromException(error);
      final result = await Navigator.of(context).push<UserCredential>(
        MaterialPageRoute<UserCredential>(
          builder: (_) => MfaSignInChallengeScreen(
            challenge: challenge,
            mfaGateway: widget.mfaGateway,
          ),
        ),
      );
      if (result == null) {
        throw FirebaseAuthException(code: 'aborted-by-user');
      }
    }
  }

  Future<void> _confirmCode() async {
    final dispatch = _dispatch;
    if (dispatch == null || _isConfirming || _isSending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isConfirming = true;
      _error = null;
    });
    try {
      await widget.mfaGateway.confirmEnrollment(
        verificationId: dispatch.verificationId,
        smsCode: _codeController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeRequested = _dispatch != null;
    return _MfaPageFrame(
      title: codeRequested ? 'SMS-Code bestätigen' : 'Schutz aktivieren',
      onBack: () => Navigator.of(context).pop(false),
      children: [
        _MfaCard(
          icon: codeRequested
              ? Icons.sms_outlined
              : Icons.phonelink_lock_rounded,
          title: codeRequested ? 'Code wurde gesendet' : 'Mobiltelefon',
          child: codeRequested
              ? Text(
                  'Gib den sechsstelligen Code ein, den wir an ${_maskedPhoneNumber ?? 'dein Telefon'} gesendet haben.',
                  style: _mfaSecondaryText(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _phoneController,
                      enabled: !_isSending,
                      keyboardType: TextInputType.phone,
                      textInputAction: widget.account.hasPasswordProvider
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: _mfaInputDecoration(
                        label: 'z. B. +49 170 1234567',
                        icon: Icons.phone_iphone_rounded,
                      ),
                    ),
                    if (widget.account.hasPasswordProvider) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        enabled: !_isSending,
                        obscureText: !_passwordVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _requestCode(),
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: _mfaInputDecoration(
                          label: 'Aktuelles Passwort',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: _MfaPasswordVisibilityButton(
                            visible: _passwordVisible,
                            onTap: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _isSending
                          ? null
                          : () => setState(
                              () => _consentAccepted = !_consentAccepted,
                            ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _consentAccepted
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: _consentAccepted
                                ? CaRismaDesignTokens.bluePrimary
                                : CaRismaDesignTokens.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ich stimme zu, dass plaqa meine Telefonnummer zur sicheren SMS-Verifikation und zur Missbrauchsprävention verarbeitet.',
                              style: _mfaSecondaryText(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        if (codeRequested) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => _confirmCode(),
            style: const TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
            ),
            decoration: _mfaInputDecoration(
              label: 'Sechsstelliger SMS-Code',
              icon: Icons.password_rounded,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _MfaMessage(message: _error!, isError: true),
        ],
        const SizedBox(height: 14),
        _MfaButton(
          label: _isSending || _isConfirming
              ? 'Warten'
              : codeRequested
              ? 'Schutz aktivieren'
              : 'SMS-Code anfordern',
          icon: codeRequested
              ? Icons.verified_user_rounded
              : Icons.send_to_mobile_rounded,
          loading: codeRequested ? _isConfirming : _isSending,
          onTap: codeRequested ? _confirmCode : _requestCode,
        ),
        if (codeRequested) ...[
          const SizedBox(height: 10),
          _MfaButton(
            label: _cooldownSeconds > 0
                ? 'Erneut senden in $_cooldownSeconds s'
                : 'Code erneut senden',
            icon: Icons.refresh_rounded,
            outlined: true,
            enabled: _cooldownSeconds == 0,
            loading: _isSending,
            onTap: () => _requestCode(resend: true),
          ),
        ],
      ],
    );
  }
}

class MfaSignInChallengeScreen extends StatefulWidget {
  const MfaSignInChallengeScreen({
    super.key,
    required this.challenge,
    this.mfaGateway,
    this.title = 'Anmeldung bestätigen',
    this.description =
        'Bestätige deine Anmeldung mit einem registrierten Mobiltelefon.',
    this.sendCodeLabel = 'SMS-Code senden',
    this.confirmCodeLabel = 'Sicher anmelden',
  });

  final MfaSignInChallenge challenge;
  final MfaGateway? mfaGateway;
  final String title;
  final String description;
  final String sendCodeLabel;
  final String confirmCodeLabel;

  @override
  State<MfaSignInChallengeScreen> createState() =>
      _MfaSignInChallengeScreenState();
}

class _MfaSignInChallengeScreenState extends State<MfaSignInChallengeScreen> {
  late final MfaGateway _mfaGateway;
  late String _selectedFactorUid;
  final TextEditingController _codeController = TextEditingController();
  MfaCodeDispatch? _dispatch;
  bool _isSending = false;
  bool _isConfirming = false;
  String? _error;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _mfaGateway = widget.mfaGateway ?? FirebaseMfaService();
    _selectedFactorUid = widget.challenge.factors.first.uid;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_isSending || _isConfirming) return;
    if (!resend && _dispatch != null) return;
    if (resend && (_dispatch == null || _cooldownSeconds > 0)) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await _mfaGateway.requestSignInCode(
        challenge: widget.challenge,
        factorUid: _selectedFactorUid,
        forceResendingToken: resend ? _dispatch?.resendToken : null,
        onCodeSent: (dispatch) {
          if (!mounted) return;
          setState(() => _dispatch = dispatch);
          _startCooldown();
        },
        onVerificationFailed: (error) {
          if (mounted) setState(() => _error = mfaErrorMessage(error));
        },
        onAutoVerified: (credential) {
          if (mounted) Navigator.of(context).pop(credential);
        },
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirm() async {
    final dispatch = _dispatch;
    if (dispatch == null || _isSending || _isConfirming) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isConfirming = true;
      _error = null;
    });
    try {
      final result = await _mfaGateway.confirmSignIn(
        challenge: widget.challenge,
        verificationId: dispatch.verificationId,
        smsCode: _codeController.text,
      );
      if (mounted) Navigator.of(context).pop(result);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _dispatch != null;
    return _MfaPageFrame(
      title: widget.title,
      onBack: () => Navigator.of(context).pop(),
      children: [
        _MfaCard(
          icon: Icons.security_rounded,
          title: 'Zweiter Faktor erforderlich',
          child: Text(
            widget.description,
            style: const TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MfaCard(
          icon: Icons.phone_iphone_rounded,
          title: widget.challenge.factors.length == 1
              ? 'Mobiltelefon'
              : 'Mobiltelefon auswählen',
          child: Column(
            children: [
              for (final factor in widget.challenge.factors)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: codeSent
                      ? null
                      : () => setState(() => _selectedFactorUid = factor.uid),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _selectedFactorUid == factor.uid
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _selectedFactorUid == factor.uid
                              ? CaRismaDesignTokens.bluePrimary
                              : CaRismaDesignTokens.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                factor.displayName,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                factor.maskedPhoneNumber,
                                style: _mfaSecondaryText(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (codeSent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => _confirm(),
            style: const TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
            ),
            decoration: _mfaInputDecoration(
              label: 'Sechsstelliger SMS-Code',
              icon: Icons.password_rounded,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _MfaMessage(message: _error!, isError: true),
        ],
        const SizedBox(height: 14),
        _MfaButton(
          label: _isSending || _isConfirming
              ? 'Warten'
              : codeSent
              ? widget.confirmCodeLabel
              : widget.sendCodeLabel,
          icon: codeSent ? Icons.login_rounded : Icons.send_to_mobile_rounded,
          loading: codeSent ? _isConfirming : _isSending,
          onTap: codeSent ? _confirm : _sendCode,
        ),
        if (codeSent) ...[
          const SizedBox(height: 10),
          _MfaButton(
            label: _cooldownSeconds > 0
                ? 'Erneut senden in $_cooldownSeconds s'
                : 'Code erneut senden',
            icon: Icons.refresh_rounded,
            outlined: true,
            enabled: _cooldownSeconds == 0,
            loading: _isSending,
            onTap: () => _sendCode(resend: true),
          ),
        ],
        const SizedBox(height: 10),
        _MfaButton(
          label: 'Kein Zugriff auf dieses Mobiltelefon?',
          icon: Icons.help_outline_rounded,
          outlined: true,
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const MfaRecoveryInfoScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class MfaRecoveryScreen extends StatefulWidget {
  const MfaRecoveryScreen({super.key, required this.mfaGateway});

  final MfaGateway mfaGateway;

  @override
  State<MfaRecoveryScreen> createState() => _MfaRecoveryScreenState();
}

class _MfaRecoveryScreenState extends State<MfaRecoveryScreen> {
  MfaRecoverySnapshot? _recovery;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recovery = await widget.mfaGateway.loadRecoveryStatus();
      if (mounted) setState(() => _recovery = recovery);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestRecovery() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final recovery = await widget.mfaGateway.requestRecovery();
      if (mounted) setState(() => _recovery = recovery);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = mfaErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = _recovery;
    return _MfaPageFrame(
      title: 'MFA-Wiederherstellung',
      onBack: () => Navigator.of(context).pop(),
      children: [
        const _MfaCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Kontrollierte Sicherheitsprüfung',
          child: Text(
            'Eine Anfrage deaktiviert den zweiten Faktor nicht automatisch. '
            'plaqa prüft sie manuell. Support fragt niemals nach Passwort '
            'oder SMS-Code.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const _MfaLoadingCard()
        else
          _MfaCard(
            icon: _recoveryIcon(recovery?.status),
            title: _recoveryTitle(recovery?.status),
            accent: _recoveryAccent(recovery?.status),
            child: Text(
              _recoveryDescription(recovery?.status),
              style: _mfaSecondaryText(),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _MfaMessage(message: _error!, isError: true),
        ],
        if (!_isLoading && !(recovery?.hasActiveReview ?? false)) ...[
          const SizedBox(height: 12),
          _MfaButton(
            label: 'Sicherheitsprüfung anfordern',
            icon: Icons.mark_email_read_outlined,
            loading: _isSubmitting,
            onTap: _requestRecovery,
          ),
        ],
      ],
    );
  }
}

class MfaRecoveryInfoScreen extends StatelessWidget {
  const MfaRecoveryInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _MfaPageFrame(
      title: 'Zugriff wiederherstellen',
      onBack: () => Navigator.of(context).pop(),
      children: [
        const _MfaCard(
          icon: Icons.phonelink_erase_rounded,
          title: 'Mobiltelefon nicht verfügbar',
          accent: CaRismaDesignTokens.danger,
          child: Text(
            'MFA bleibt aktiv, bis eine kontrollierte Sicherheitsprüfung '
            'abgeschlossen ist. Eine E-Mail oder Supportnachricht allein '
            'reicht nicht zur Deaktivierung.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _MfaCard(
          icon: Icons.verified_user_outlined,
          title: 'Sicherer nächster Schritt',
          child: Text(
            'Wenn plaqa auf einem anderen Gerät noch angemeldet ist, öffne '
            'dort Konto und Sicherheit und fordere die MFA-Wiederherstellung '
            'an. Andernfalls wende dich an den Support. Teile niemals Passwort '
            'oder SMS-Code.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MfaButton(
          label: 'Zur Anmeldung zurück',
          icon: Icons.login_rounded,
          outlined: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

String _recoveryTitle(MfaRecoveryStatus? status) {
  return switch (status) {
    MfaRecoveryStatus.pending => 'Prüfung läuft',
    MfaRecoveryStatus.approved => 'Wiederherstellung genehmigt',
    MfaRecoveryStatus.rejected => 'Wiederherstellung abgelehnt',
    MfaRecoveryStatus.completed => 'Erneute Anmeldung erforderlich',
    _ => 'Keine offene Anfrage',
  };
}

String _recoveryDescription(MfaRecoveryStatus? status) {
  return switch (status) {
    MfaRecoveryStatus.pending =>
      'Deine Anfrage wird geprüft. Der zweite Faktor bleibt aktiv.',
    MfaRecoveryStatus.approved =>
      'Die Freigabe wird serverseitig abgeschlossen. MFA bleibt bis dahin aktiv.',
    MfaRecoveryStatus.rejected =>
      'Die Sicherheitsprüfung reichte nicht aus. MFA wurde nicht verändert.',
    MfaRecoveryStatus.completed =>
      'Alle Sitzungen wurden widerrufen. Melde dich neu an und richte MFA erneut ein.',
    _ =>
      'Fordere die Prüfung nur an, wenn du den Zugriff auf deine registrierten Faktoren verloren hast.',
  };
}

IconData _recoveryIcon(MfaRecoveryStatus? status) {
  return switch (status) {
    MfaRecoveryStatus.pending => Icons.hourglass_top_rounded,
    MfaRecoveryStatus.approved => Icons.verified_outlined,
    MfaRecoveryStatus.rejected => Icons.gpp_bad_outlined,
    MfaRecoveryStatus.completed => Icons.logout_rounded,
    _ => Icons.restore_rounded,
  };
}

Color _recoveryAccent(MfaRecoveryStatus? status) {
  return switch (status) {
    MfaRecoveryStatus.rejected => CaRismaDesignTokens.danger,
    MfaRecoveryStatus.completed => CaRismaDesignTokens.success,
    _ => CaRismaDesignTokens.bluePrimary,
  };
}

class _MfaPageFrame extends StatelessWidget {
  const _MfaPageFrame({
    required this.title,
    required this.onBack,
    required this.children,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Row(
                  children: [
                    _MfaRoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MfaCard extends StatelessWidget {
  const _MfaCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent = CaRismaDesignTokens.bluePrimary,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.card,
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusCard),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _MfaFactorTile extends StatelessWidget {
  const _MfaFactorTile({required this.factor, required this.onRemove});

  final MfaFactorSnapshot factor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.phone_iphone_rounded,
          color: CaRismaDesignTokens.bluePrimary,
          size: 22,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                factor.displayName,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                factor.maskedPhoneNumber,
                style: _mfaSecondaryText(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _MfaRoundButton(
          icon: Icons.delete_outline_rounded,
          color: CaRismaDesignTokens.danger,
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _MfaMessage extends StatelessWidget {
  const _MfaMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.card,
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: CaRismaDesignTokens.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MfaLoadingCard extends StatelessWidget {
  const _MfaLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(
          color: CaRismaDesignTokens.bluePrimary,
        ),
      ),
    );
  }
}

class _MfaButton extends StatelessWidget {
  const _MfaButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.enabled = true,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  final bool enabled;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canTap ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.card,
            borderRadius: BorderRadius.circular(
              CaRismaDesignTokens.radiusInput,
            ),
            border: Border.all(
              color: CaRismaDesignTokens.bluePrimary.withValues(
                alpha: outlined ? 0.85 : 0.55,
              ),
              width: outlined ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CaRismaDesignTokens.bluePrimary,
                  ),
                )
              else
                Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MfaRoundButton extends StatelessWidget {
  const _MfaRoundButton({
    required this.icon,
    required this.onTap,
    this.color = CaRismaDesignTokens.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CaRismaDesignTokens.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _MfaPasswordDialog extends StatefulWidget {
  const _MfaPasswordDialog();

  @override
  State<_MfaPasswordDialog> createState() => _MfaPasswordDialogState();
}

class _MfaPasswordDialogState extends State<_MfaPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final password = _controller.text;
    if (password.isNotEmpty) Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CaRismaDesignTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusPanel),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      title: const Text(
        'Anmeldung bestätigen',
        style: TextStyle(
          color: CaRismaDesignTokens.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: TextField(
        controller: _controller,
        obscureText: !_passwordVisible,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _confirm(),
        style: const TextStyle(color: CaRismaDesignTokens.textPrimary),
        decoration: _mfaInputDecoration(
          label: 'Aktuelles Passwort',
          icon: Icons.lock_outline_rounded,
          suffixIcon: _MfaPasswordVisibilityButton(
            visible: _passwordVisible,
            onTap: () => setState(() => _passwordVisible = !_passwordVisible),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Abbrechen',
            style: TextStyle(color: CaRismaDesignTokens.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _confirm,
          child: const Text(
            'Bestätigen',
            style: TextStyle(
              color: CaRismaDesignTokens.bluePrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MfaDialog extends StatelessWidget {
  const _MfaDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.bluePrimary;
    return AlertDialog(
      backgroundColor: CaRismaDesignTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusPanel),
        side: BorderSide(color: accent.withValues(alpha: 0.45)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: CaRismaDesignTokens.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(message, style: _mfaSecondaryText()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Abbrechen',
            style: TextStyle(color: CaRismaDesignTokens.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: accent, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

InputDecoration _mfaInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final normalBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: CaRismaDesignTokens.textSecondary,
      fontWeight: FontWeight.w700,
    ),
    prefixIcon: Icon(icon, color: CaRismaDesignTokens.bluePrimary),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: CaRismaDesignTokens.controlSurface,
    border: normalBorder,
    enabledBorder: normalBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
      borderSide: const BorderSide(
        color: CaRismaDesignTokens.bluePrimary,
        width: 1.4,
      ),
    ),
  );
}

class _MfaPasswordVisibilityButton extends StatelessWidget {
  const _MfaPasswordVisibilityButton({
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: visible ? 'Passwort ausblenden' : 'Passwort anzeigen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: CaRismaDesignTokens.textSecondary,
            size: 21,
          ),
        ),
      ),
    );
  }
}

TextStyle _mfaSecondaryText({double fontSize = 14}) {
  return TextStyle(
    color: CaRismaDesignTokens.textSecondary,
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );
}
