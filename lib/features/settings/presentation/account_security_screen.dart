import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/mfa_screens.dart';
import '../data/user_settings_repository.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({
    super.key,
    required this.onLogout,
    required this.onRequestAccountDeletion,
    required this.onOpenSupport,
    this.accountGateway,
    this.initialAccount,
    this.appleLinkAvailable,
  });

  final VoidCallback onLogout;
  final VoidCallback onRequestAccountDeletion;
  final VoidCallback onOpenSupport;
  final AccountAuthGateway? accountGateway;
  final AuthAccountSnapshot? initialAccount;
  final bool? appleLinkAvailable;

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  late final AccountAuthGateway _accountGateway;
  AuthAccountSnapshot? _account;
  bool _isLoading = false;
  bool _isLinkingApple = false;
  String? _loadError;
  String? _appleLinkMessage;
  bool _appleLinkMessageIsError = false;

  bool get _appleLinkAvailable =>
      widget.appleLinkAvailable ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _accountGateway = widget.accountGateway ?? AuthService();
    _account = widget.initialAccount;
    if (_account == null) {
      _refreshAccount();
    }
  }

  Future<void> _refreshAccount() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final account = await _accountGateway.loadCurrentAccount();
      if (!mounted) {
        return;
      }
      setState(() {
        _account = account;
        if (account == null) {
          _loadError = 'Deine Kontodaten konnten nicht geladen werden.';
        }
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = accountAuthErrorMessage(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = 'Deine Kontodaten konnten nicht geladen werden.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPage(Widget page, {bool refreshAfterwards = false}) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (refreshAfterwards && mounted) {
      await _refreshAccount();
    }
  }

  Future<void> _linkApple() async {
    if (_isLinkingApple || !_appleLinkAvailable) {
      return;
    }

    setState(() {
      _isLinkingApple = true;
      _appleLinkMessage = null;
    });

    try {
      await _accountGateway.linkCurrentUserWithApple();
      final account = await _accountGateway.loadCurrentAccount();
      if (!mounted) return;
      setState(() {
        _account = account ?? _account;
        _appleLinkMessage = 'Apple wurde sicher mit deinem Konto verknüpft.';
        _appleLinkMessageIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _appleLinkMessage = accountAuthErrorMessage(error);
        _appleLinkMessageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appleLinkMessage =
            'Apple konnte gerade nicht mit deinem Konto verknüpft werden.';
        _appleLinkMessageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLinkingApple = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;

    return _AccountPageFrame(
      title: 'Konto & Sicherheit',
      icon: Icons.admin_panel_settings_rounded,
      onBack: () => Navigator.of(context).pop(),
      children: [
        if (_isLoading && account == null)
          const _AccountLoadingCard()
        else if (account == null)
          _AccountErrorCard(
            message:
                _loadError ?? 'Deine Kontodaten konnten nicht geladen werden.',
            onRetry: _refreshAccount,
          )
        else ...[
          _AccountStatusCard(account: account),
          const SizedBox(height: 14),
          _AccountSectionCard(
            icon: Icons.alternate_email_rounded,
            title: 'E-Mail & Anmeldung',
            children: [
              _AccountActionTile(
                icon: account.isEmailVerified
                    ? Icons.mark_email_read_rounded
                    : Icons.mark_email_unread_outlined,
                title: 'E-Mail bestätigen',
                description: account.isEmailVerified
                    ? 'Deine E-Mail Adresse ist bestätigt.'
                    : 'Bestätigungslink senden und Status aktualisieren.',
                onTap: () => _openPage(
                  EmailVerificationScreen(
                    accountGateway: _accountGateway,
                    initialAccount: account,
                  ),
                  refreshAfterwards: true,
                ),
              ),
              _AccountDivider(),
              _AccountActionTile(
                icon: Icons.password_rounded,
                title: account.hasPasswordProvider
                    ? 'Passwort ändern'
                    : 'Passwort verwalten',
                description: account.hasPasswordProvider
                    ? account.isEmailVerified
                          ? 'Zurücksetzungslink kontrolliert anfordern.'
                          : 'Bestätige zuerst deine E-Mail Adresse.'
                    : _providerManagedPasswordText(account),
                enabled: account.hasPasswordProvider && account.isEmailVerified,
                badge: !account.hasPasswordProvider
                    ? 'Extern'
                    : account.isEmailVerified
                    ? null
                    : 'E-Mail offen',
                onTap: account.hasPasswordProvider && account.isEmailVerified
                    ? () => _openPage(
                        PasswordResetRequestScreen(
                          accountGateway: _accountGateway,
                          account: account,
                        ),
                      )
                    : null,
              ),
              _AccountDivider(),
              _AccountActionTile(
                icon: Icons.edit_note_rounded,
                title: 'E-Mail Adresse ändern',
                description: account.hasPasswordProvider
                    ? 'Neue Adresse erst nach sicherer Bestätigung übernehmen.'
                    : _providerManagedEmailText(account),
                enabled: account.hasPasswordProvider,
                badge: account.hasPasswordProvider ? null : 'Extern',
                onTap: account.hasPasswordProvider
                    ? () => _openPage(
                        ChangeAccountEmailScreen(
                          accountGateway: _accountGateway,
                          account: account,
                        ),
                        refreshAfterwards: true,
                      )
                    : null,
              ),
              if (_appleLinkAvailable) ...[
                _AccountDivider(),
                _AccountActionTile(
                  icon: Icons.apple,
                  title: account.hasAppleProvider
                      ? 'Mit Apple verknüpft'
                      : 'Mit Apple verknüpfen',
                  description: account.hasAppleProvider
                      ? 'Apple kann für die Anmeldung und sichere Kontobestätigung verwendet werden.'
                      : 'Apple kontrolliert als zusätzliche Anmeldemethode mit diesem Konto verbinden.',
                  enabled: !account.hasAppleProvider && !_isLinkingApple,
                  badge: account.hasAppleProvider
                      ? 'Aktiv'
                      : _isLinkingApple
                      ? 'Wird verknüpft'
                      : null,
                  onTap: account.hasAppleProvider || _isLinkingApple
                      ? null
                      : _linkApple,
                ),
                if (_appleLinkMessage != null) ...[
                  _AccountDivider(),
                  _AccountSecurityHintLine(
                    icon: _appleLinkMessageIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    text: _appleLinkMessage!,
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 14),
          _AccountSectionCard(
            icon: Icons.shield_outlined,
            title: 'Kontoschutz',
            children: [
              _AccountStatusLine(
                icon: Icons.verified_user_outlined,
                title: 'E-Mail Adresse',
                value: account.isEmailVerified
                    ? 'Bestätigt'
                    : 'Nicht bestätigt',
                valueColor: account.isEmailVerified
                    ? CaRismaDesignTokens.success
                    : CaRismaDesignTokens.danger,
              ),
              _AccountDivider(),
              _AccountStatusLine(
                icon: Icons.key_rounded,
                title: 'Anmeldemethoden',
                value: account.providerLabel,
              ),
              _AccountDivider(),
              _AccountStatusLine(
                icon: Icons.schedule_rounded,
                title: 'Letzte Anmeldung',
                value: formatAccountDateTime(account.lastSignInTime),
              ),
              if (!account.isEmailVerified) ...[
                _AccountDivider(),
                const _AccountSecurityHintLine(
                  icon: Icons.info_outline_rounded,
                  text:
                      'Bestätige deine E-Mail Adresse, damit du den Kontozugriff leichter wiederherstellen kannst.',
                ),
              ],
              _AccountDivider(),
              _AccountActionTile(
                icon: Icons.security_rounded,
                title: 'Zwei-Faktor-Schutz',
                description: account.isEmailVerified
                    ? 'SMS-Schutz aktivieren und registrierte Faktoren verwalten.'
                    : 'Bestätige zuerst deine E-Mail Adresse.',
                compactIcon: true,
                onTap: () => _openPage(
                  MfaManagementScreen(
                    initialAccount: account,
                    accountGateway: _accountGateway,
                    onOpenSupport: widget.onOpenSupport,
                  ),
                  refreshAfterwards: true,
                ),
              ),
              _AccountDivider(),
              _AccountActionTile(
                icon: Icons.manage_history_rounded,
                title: 'Sicherheitsaktivitäten',
                description:
                    'Serverseitig bestätigte Konto- und Sitzungsaktionen ansehen.',
                compactIcon: true,
                enabled: account.userId.isNotEmpty,
                onTap: account.userId.isEmpty
                    ? null
                    : () => _openPage(
                        AccountSecurityActivitiesScreen(userId: account.userId),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AccountSectionCard(
            icon: Icons.devices_rounded,
            title: 'Geräte & Sitzungen',
            children: [
              _AccountActionTile(
                icon: Icons.smartphone_rounded,
                title: 'Aktuelle Sitzung',
                description:
                    '${currentPlatformLabel()} · Letzte Anmeldung ${formatAccountDateTime(account.lastSignInTime)}',
                onTap: () => _openPage(
                  AccountSessionsScreen(
                    account: account,
                    accountGateway: _accountGateway,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AccountSectionCard(
            icon: Icons.support_rounded,
            title: 'Kontowiederherstellung',
            children: [
              _AccountActionTile(
                icon: Icons.restore_rounded,
                title: 'Zugriff wiederherstellen',
                description:
                    'Hilfe bei Passwort, E-Mail Zugriff und Google-Anmeldung.',
                onTap: () => _openPage(
                  AccountRecoveryScreen(
                    account: account,
                    onOpenSupport: widget.onOpenSupport,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AccountSectionCard(
            icon: Icons.warning_amber_rounded,
            title: 'Gefahrenbereich',
            danger: true,
            children: [
              _AccountActionTile(
                icon: Icons.logout_rounded,
                title: 'Abmelden',
                description: 'Dieses Gerät sicher vom Konto abmelden.',
                danger: true,
                onTap: widget.onLogout,
              ),
              _AccountDivider(danger: true),
              _AccountActionTile(
                icon: Icons.delete_forever_rounded,
                title: 'Konto löschen',
                description:
                    'Konto nach ausdrücklicher Bestätigung dauerhaft löschen.',
                danger: true,
                onTap: widget.onRequestAccountDeletion,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.accountGateway,
    required this.initialAccount,
  });

  final AccountAuthGateway accountGateway;
  final AuthAccountSnapshot initialAccount;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late AuthAccountSnapshot _account;
  bool _isSending = false;
  bool _isRefreshing = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _account = widget.initialAccount;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _sendVerification() async {
    if (_isSending || _cooldownSeconds > 0 || _account.isEmailVerified) {
      return;
    }
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      await widget.accountGateway.sendCurrentUserEmailVerification();
      if (!mounted) {
        return;
      }
      _startCooldown();
      setState(() {
        _message = 'Bestätigungslink wurde an ${_account.email} gesendet.';
        _messageIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = accountAuthErrorMessage(error);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Der Bestätigungslink konnte nicht gesendet werden.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
      _message = null;
    });

    try {
      final account = await widget.accountGateway.loadCurrentAccount();
      if (!mounted) {
        return;
      }
      if (account == null) {
        throw FirebaseAuthException(code: 'missing-user');
      }
      setState(() {
        _account = account;
        _message = account.isEmailVerified
            ? 'Deine E-Mail Adresse ist bestätigt.'
            : 'Die E-Mail Adresse ist noch nicht bestätigt.';
        _messageIsError = !account.isEmailVerified;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = accountAuthErrorMessage(error);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Der Status konnte nicht aktualisiert werden.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageFrame(
      title: 'E-Mail bestätigen',
      icon: Icons.mark_email_read_outlined,
      onBack: () => Navigator.of(context).pop(),
      children: [
        _AccountSectionCard(
          icon: Icons.alternate_email_rounded,
          title: 'Konto E-Mail Adresse',
          headerBadge: _account.isEmailVerified
              ? 'Bestätigt'
              : 'Nicht bestätigt',
          headerBadgeColor: _account.isEmailVerified
              ? CaRismaDesignTokens.success
              : CaRismaDesignTokens.danger,
          innerBorderColor: CaRismaDesignTokens.textPrimary.withValues(
            alpha: 0.14,
          ),
          children: [
            _AccountEmailLine(
              icon: Icons.mail_outline_rounded,
              email: _account.email,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_message != null) ...[
          _AccountInlineMessage(message: _message!, isError: _messageIsError),
          const SizedBox(height: 14),
        ],
        if (!_account.isEmailVerified)
          _AccountButton(
            label: _cooldownSeconds > 0
                ? 'Erneut senden in $_cooldownSeconds s'
                : 'Bestätigungslink senden',
            icon: Icons.send_rounded,
            isLoading: _isSending,
            enabled: _cooldownSeconds == 0,
            onTap: _sendVerification,
          ),
        if (!_account.isEmailVerified) const SizedBox(height: 10),
        _AccountButton(
          label: 'Status aktualisieren',
          icon: Icons.refresh_rounded,
          outlined: true,
          isLoading: _isRefreshing,
          onTap: _refreshStatus,
        ),
      ],
    );
  }
}

class PasswordResetRequestScreen extends StatefulWidget {
  const PasswordResetRequestScreen({
    super.key,
    required this.accountGateway,
    required this.account,
  });

  final AccountAuthGateway accountGateway;
  final AuthAccountSnapshot account;

  @override
  State<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends State<PasswordResetRequestScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_isSending || _sent) {
      return;
    }
    if (!widget.account.isEmailVerified) {
      setState(() {
        _message = 'Bestätige zuerst deine E-Mail Adresse.';
        _messageIsError = true;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      await widget.accountGateway.sendCurrentUserPasswordReset(
        enteredEmail: _emailController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sent = true;
        _message =
            'Der Link zum Ändern deines Passworts wurde sicher versendet.';
        _messageIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = accountAuthErrorMessage(error);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Der Link konnte gerade nicht gesendet werden.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageFrame(
      title: 'Passwort ändern',
      icon: Icons.password_rounded,
      onBack: () => Navigator.of(context).pop(),
      children: [
        _AccountSectionCard(
          icon: Icons.lock_outline_rounded,
          title: 'Sicher bestätigen',
          showInnerSurface: false,
          children: [
            Text(
              'Gib zur Bestätigung die E-Mail Adresse deines Kontos ein.',
              style: _secondaryTextStyle(),
            ),
            const SizedBox(height: 12),
            _AccountTextField(
              controller: _emailController,
              label: 'Konto E-Mail Adresse',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              enabled: !_sent,
              onSubmitted: (_) => _sendResetLink(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_message != null) ...[
          _AccountInlineMessage(message: _message!, isError: _messageIsError),
          const SizedBox(height: 14),
        ],
        _AccountButton(
          label: _sent ? 'Link wurde gesendet' : 'Zurücksetzungslink senden',
          icon: _sent ? Icons.check_rounded : Icons.send_rounded,
          isLoading: _isSending,
          enabled: !_sent,
          onTap: _sendResetLink,
        ),
      ],
    );
  }
}

class ChangeAccountEmailScreen extends StatefulWidget {
  const ChangeAccountEmailScreen({
    super.key,
    required this.accountGateway,
    required this.account,
  });

  final AccountAuthGateway accountGateway;
  final AuthAccountSnapshot account;

  @override
  State<ChangeAccountEmailScreen> createState() =>
      _ChangeAccountEmailScreenState();
}

class _ChangeAccountEmailScreenState extends State<ChangeAccountEmailScreen> {
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _repeatEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _newEmailController.dispose();
    _repeatEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _submitted) {
      return;
    }
    final newEmail = _newEmailController.text.trim();
    final repeatedEmail = _repeatEmailController.text.trim();
    if (newEmail.toLowerCase() != repeatedEmail.toLowerCase()) {
      setState(() {
        _message = 'Die beiden E-Mail Adressen stimmen nicht überein.';
        _messageIsError = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    try {
      await widget.accountGateway.requestCurrentUserEmailChange(
        currentPassword: _passwordController.text,
        newEmail: newEmail,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitted = true;
        _message =
            'Bestätigungslink wurde an die neue E-Mail Adresse gesendet. Bis zur Bestätigung bleibt deine bisherige Adresse aktiv.';
        _messageIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = accountAuthErrorMessage(error);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Die E-Mail Änderung konnte nicht vorbereitet werden.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageFrame(
      title: 'E-Mail Adresse ändern',
      icon: Icons.edit_note_rounded,
      onBack: () => Navigator.of(context).pop(),
      children: [
        _AccountSectionCard(
          icon: Icons.mail_lock_outlined,
          title: 'Neue E-Mail Adresse',
          showInnerSurface: false,
          children: [
            _AccountStatusLine(
              icon: Icons.alternate_email_rounded,
              title: 'Aktuell',
              value: widget.account.email,
              titleFlex: 1,
              valueFlex: 4,
              valueFontSize: 14,
            ),
            const SizedBox(height: 12),
            _AccountTextField(
              controller: _newEmailController,
              label: 'Neue E-Mail Adresse',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_submitted,
            ),
            const SizedBox(height: 10),
            _AccountTextField(
              controller: _repeatEmailController,
              label: 'Neue E-Mail Adresse wiederholen',
              icon: Icons.mark_email_read_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_submitted,
            ),
            const SizedBox(height: 10),
            _AccountTextField(
              controller: _passwordController,
              label: 'Aktuelles Passwort',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_submitted,
              suffixIcon: _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              onSuffixTap: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_message != null) ...[
          _AccountInlineMessage(message: _message!, isError: _messageIsError),
          const SizedBox(height: 14),
        ],
        _AccountButton(
          label: _submitted
              ? 'Bestätigung wurde gesendet'
              : 'E-Mail Änderung bestätigen',
          icon: _submitted ? Icons.check_rounded : Icons.verified_user_outlined,
          isLoading: _isSubmitting,
          enabled: !_submitted,
          onTap: _submit,
        ),
      ],
    );
  }
}

class AccountSessionsScreen extends StatefulWidget {
  const AccountSessionsScreen({
    super.key,
    required this.account,
    required this.accountGateway,
  });

  final AuthAccountSnapshot account;
  final AccountAuthGateway accountGateway;

  @override
  State<AccountSessionsScreen> createState() => _AccountSessionsScreenState();
}

class _AccountSessionsScreenState extends State<AccountSessionsScreen> {
  bool _isRevoking = false;
  String? _error;

  Future<void> _revokeSessions() async {
    var currentPassword = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        title: const Text(
          'Alle Sitzungen abmelden?',
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aus Sicherheitsgründen werden alle anderen Sitzungen gemeinsam abgemeldet. Danach musst du dich auch hier neu anmelden.',
              style: TextStyle(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.68),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.account.hasPasswordProvider) ...[
              const SizedBox(height: 14),
              TextField(
                obscureText: true,
                autofocus: true,
                onChanged: (value) => currentPassword = value,
                style: const TextStyle(color: CaRismaDesignTokens.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Aktuelles Passwort',
                  labelStyle: TextStyle(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.62,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.14,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: CaRismaDesignTokens.bluePrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Abbrechen',
              style: TextStyle(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.68),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Alle abmelden',
              style: TextStyle(
                color: CaRismaDesignTokens.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isRevoking = true;
      _error = null;
    });
    try {
      await widget.accountGateway.revokeAllSessions(
        currentPassword: currentPassword,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _error = accountAuthErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Die Sitzungen konnten gerade nicht widerrufen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageFrame(
      title: 'Geräte & Sitzungen',
      icon: Icons.devices_rounded,
      onBack: () => Navigator.of(context).pop(),
      children: [
        _AccountSectionCard(
          icon: Icons.smartphone_rounded,
          title: 'Aktuelle Sitzung',
          children: [
            _AccountStatusLine(
              icon: Icons.phone_android_rounded,
              title: currentPlatformLabel(),
              value: 'Dieses Gerät',
              valueColor: CaRismaDesignTokens.success,
            ),
            _AccountDivider(),
            _AccountStatusLine(
              icon: Icons.schedule_rounded,
              title: 'Letzte Anmeldung',
              value: formatAccountDateTime(widget.account.lastSignInTime),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _AccountInlineMessage(message: _error!, isError: true),
        ],
        const SizedBox(height: 14),
        _AccountButton(
          label: 'Alle Sitzungen abmelden',
          icon: Icons.phonelink_erase_rounded,
          enabled: !_isRevoking,
          isLoading: _isRevoking,
          outlined: true,
          onTap: _revokeSessions,
        ),
      ],
    );
  }
}

class AccountSecurityActivitiesScreen extends StatelessWidget {
  AccountSecurityActivitiesScreen({
    super.key,
    required this.userId,
    AccountSecurityRepository? repository,
  }) : _repository = repository ?? AccountSecurityRepository();

  final String userId;
  final AccountSecurityRepository _repository;

  @override
  Widget build(BuildContext context) {
    return _AccountPageFrame(
      title: 'Sicherheitsaktivitäten',
      icon: Icons.manage_history_rounded,
      onBack: () => Navigator.of(context).pop(),
      children: [
        StreamBuilder<List<AccountSecurityActivity>>(
          stream: _repository.watchActivities(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _AccountNotice(
                icon: Icons.error_outline_rounded,
                text:
                    'Die Sicherheitsaktivitäten konnten gerade nicht geladen werden.',
              );
            }
            if (!snapshot.hasData) {
              return const _AccountLoadingCard();
            }
            final activities = snapshot.data!;
            if (activities.isEmpty) {
              return const _AccountNotice(
                icon: Icons.history_rounded,
                text: 'Noch keine Sicherheitsaktivitäten.',
              );
            }

            return _AccountSectionCard(
              icon: Icons.verified_user_outlined,
              title: 'Serverseitig bestätigt',
              children: [
                for (var index = 0; index < activities.length; index++) ...[
                  _AccountStatusLine(
                    icon: _securityActivityIcon(activities[index].eventType),
                    title: _securityActivityLabel(activities[index].eventType),
                    value:
                        '${_securityPlatformLabel(activities[index].platform)} · ${formatAccountDateTime(activities[index].occurredAt)}',
                  ),
                  if (index != activities.length - 1) _AccountDivider(),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AccountRecoveryScreen extends StatelessWidget {
  const AccountRecoveryScreen({
    super.key,
    required this.account,
    required this.onOpenSupport,
  });

  final AuthAccountSnapshot account;
  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context) {
    return _AccountPageFrame(
      title: 'Kontowiederherstellung',
      icon: Icons.restore_rounded,
      onBack: () => Navigator.of(context).pop(),
      children: [
        _AccountSectionCard(
          icon: Icons.support_agent_rounded,
          title: 'Zugriff wiederherstellen',
          children: [
            _AccountActionTile(
              icon: Icons.password_rounded,
              title: 'Passwort vergessen',
              description: account.hasPasswordProvider
                  ? 'Nutze unter Passwort ändern den kontrollierten E-Mail-Versand.'
                  : _providerManagedPasswordText(account),
              enabled: account.hasPasswordProvider,
            ),
            _AccountDivider(),
            const _AccountActionTile(
              icon: Icons.mark_email_unread_outlined,
              title: 'Kein Zugriff auf die E-Mail',
              description:
                  'Der Support prüft mit dir sichere Möglichkeiten zur Kontowiederherstellung.',
              enabled: false,
              badge: 'Support',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _AccountButton(
          label: 'Support kontaktieren',
          icon: Icons.support_agent_rounded,
          outlined: true,
          onTap: onOpenSupport,
        ),
      ],
    );
  }
}

class _AccountPageFrame extends StatelessWidget {
  const _AccountPageFrame({
    required this.title,
    required this.icon,
    required this.onBack,
    required this.children,
  });

  final String title;
  final IconData icon;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: CaRismaBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboardInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 36 - keyboardInset)
                        .clamp(0.0, double.infinity)
                        .toDouble(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccountHeader(icon: icon, title: title, onBack: onBack),
                      const SizedBox(height: 14),
                      ...children,
                    ],
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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.icon,
    required this.title,
    required this.onBack,
  });

  final IconData icon;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: CaRismaDesignTokens.surfaceDecoration(
        radius: CaRismaDesignTokens.radiusCard,
      ),
      child: Row(
        children: [
          _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          _AccountIconSurface(icon: icon, size: 46, iconSize: 23),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({required this.account});

  final AuthAccountSnapshot account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: CaRismaDesignTokens.surfaceDecoration(
        radius: CaRismaDesignTokens.radiusPanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _AccountIconSurface(
                icon: Icons.person_rounded,
                size: 50,
                iconSize: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        account.email.isEmpty
                            ? 'Keine E-Mail hinterlegt'
                            : account.email,
                        maxLines: 1,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Anmeldung über ${_accountLoginLabel(account)}',
                        maxLines: 1,
                        style: _secondaryTextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AccountMetaBox(
                  label: 'Konto erstellt',
                  value: formatAccountDate(account.creationTime),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AccountMetaBox(
                  label: 'Letzte Anmeldung',
                  value: formatAccountDateTime(account.lastSignInTime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.danger = false,
    this.showInnerSurface = true,
    this.headerBadge,
    this.headerBadgeColor,
    this.innerBorderColor,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool danger;
  final bool showInnerSurface;
  final String? headerBadge;
  final Color? headerBadgeColor;
  final Color? innerBorderColor;

  @override
  Widget build(BuildContext context) {
    final accent = danger
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.bluePrimary;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.card,
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusPanel),
        border: Border.all(
          color: accent.withValues(alpha: danger ? 0.42 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (headerBadge != null) ...[
                const SizedBox(width: 10),
                _AccountBadge(
                  label: headerBadge!,
                  color: headerBadgeColor ?? CaRismaDesignTokens.textSecondary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 13),
          if (showInnerSurface)
            Container(
              decoration: BoxDecoration(
                color: CaRismaDesignTokens.controlSurface,
                borderRadius: BorderRadius.circular(
                  CaRismaDesignTokens.radiusInput,
                ),
                border: Border.all(
                  color:
                      innerBorderColor ??
                      CaRismaDesignTokens.textPrimary.withValues(alpha: 0.05),
                ),
              ),
              child: Column(children: children),
            )
          else
            Column(children: children),
        ],
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.enabled = true,
    this.danger = false,
    this.badge,
    this.compactIcon = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool enabled;
  final bool danger;
  final String? badge;
  final bool compactIcon;

  @override
  Widget build(BuildContext context) {
    final accent = danger
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.bluePrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (compactIcon)
                Icon(icon, color: accent, size: 21)
              else
                _AccountIconSurface(
                  icon: icon,
                  color: accent,
                  size: 42,
                  iconSize: 21,
                ),
              SizedBox(width: compactIcon ? 11 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: danger
                              ? CaRismaDesignTokens.danger
                              : CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(description, style: _secondaryTextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                _AccountBadge(
                  label: badge!,
                  color: CaRismaDesignTokens.textSecondary,
                ),
              ] else if (enabled && onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.52,
                  ),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountEmailLine extends StatelessWidget {
  const _AccountEmailLine({required this.icon, required this.email});

  final IconData icon;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                email,
                maxLines: 1,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStatusLine extends StatelessWidget {
  const _AccountStatusLine({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
    this.titleFlex = 1,
    this.valueFlex = 1,
    this.valueFontSize = 13,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final int titleFlex;
  final int valueFlex;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            flex: titleFlex,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CaRismaDesignTokens.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: valueFlex,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: valueColor ?? CaRismaDesignTokens.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: valueFontSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountNotice extends StatelessWidget {
  const _AccountNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.card,
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 22),
          const SizedBox(width: 11),
          Expanded(child: Text(text, style: _secondaryTextStyle())),
        ],
      ),
    );
  }
}

class _AccountSecurityHintLine extends StatelessWidget {
  const _AccountSecurityHintLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _secondaryTextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInlineMessage extends StatelessWidget {
  const _AccountInlineMessage({required this.message, required this.isError});

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
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 11),
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

class _AccountTextField extends StatelessWidget {
  const _AccountTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.onSuffixTap,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: CaRismaDesignTokens.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: CaRismaDesignTokens.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: CaRismaDesignTokens.bluePrimary),
        suffixIcon: suffixIcon == null
            ? null
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSuffixTap,
                child: Icon(
                  suffixIcon,
                  color: CaRismaDesignTokens.textSecondary,
                ),
              ),
        filled: true,
        fillColor: CaRismaDesignTokens.controlSurface,
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(
          color: CaRismaDesignTokens.bluePrimary,
          width: 1.4,
        ),
        disabledBorder: _inputBorder(),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isLoading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;
    const accent = CaRismaDesignTokens.bluePrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canTap ? onTap : null,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.card,
            borderRadius: BorderRadius.circular(
              CaRismaDesignTokens.radiusInput,
            ),
            border: Border.all(
              color: accent.withValues(alpha: outlined ? 0.84 : 0.52),
              width: outlined ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
          color: CaRismaDesignTokens.controlSurface,
          border: Border.all(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(icon, color: CaRismaDesignTokens.textPrimary, size: 22),
      ),
    );
  }
}

class _AccountIconSurface extends StatelessWidget {
  const _AccountIconSurface({
    required this.icon,
    this.color = CaRismaDesignTokens.bluePrimary,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.07),
        ),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AccountMetaBox extends StatelessWidget {
  const _AccountMetaBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _secondaryTextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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

class _AccountLoadingCard extends StatelessWidget {
  const _AccountLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _AccountNotice(
      icon: Icons.hourglass_top_rounded,
      text: 'Kontodaten werden sicher geladen.',
    );
  }
}

class _AccountErrorCard extends StatelessWidget {
  const _AccountErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountInlineMessage(message: message, isError: true),
        const SizedBox(height: 12),
        _AccountButton(
          label: 'Erneut laden',
          icon: Icons.refresh_rounded,
          outlined: true,
          onTap: onRetry,
        ),
      ],
    );
  }
}

class _AccountDivider extends StatelessWidget {
  const _AccountDivider({this.danger = false});

  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 13),
      color: danger
          ? CaRismaDesignTokens.danger.withValues(alpha: 0.14)
          : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.05),
    );
  }
}

InputBorder _inputBorder({Color? color, double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(CaRismaDesignTokens.radiusInput),
    borderSide: BorderSide(
      color: color ?? CaRismaDesignTokens.textPrimary.withValues(alpha: 0.07),
      width: width,
    ),
  );
}

TextStyle _secondaryTextStyle({double fontSize = 14}) {
  return TextStyle(
    color: CaRismaDesignTokens.textSecondary,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    height: 1.35,
  );
}

String _providerManagedPasswordText(AuthAccountSnapshot account) {
  if (account.isGoogleOnly) {
    return 'Dein Passwort wird über Google verwaltet.';
  }
  if (account.isAppleOnly) {
    return 'Dein Passwort wird über Apple verwaltet.';
  }
  return 'Das Passwort wird über deinen Anmeldeanbieter verwaltet.';
}

String _providerManagedEmailText(AuthAccountSnapshot account) {
  if (account.isGoogleOnly) {
    return 'Deine Anmelde-E-Mail wird über Google verwaltet.';
  }
  if (account.isAppleOnly) {
    return 'Deine Anmelde-E-Mail wird über Apple verwaltet.';
  }
  return 'Die E-Mail wird über deinen Anmeldeanbieter verwaltet.';
}

String _accountLoginLabel(AuthAccountSnapshot account) {
  final labels = <String>[
    if (account.providers.contains(AuthLoginProvider.password))
      'E-Mail Adresse',
    if (account.providers.contains(AuthLoginProvider.google)) 'Google',
    if (account.providers.contains(AuthLoginProvider.apple)) 'Apple',
  ];
  return labels.isEmpty ? 'Nicht verfügbar' : labels.join(' und ');
}

String accountAuthErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Die E-Mail Adresse ist ungültig.',
    'email-already-in-use' =>
      'Diese E-Mail Adresse wird bereits für ein anderes Konto verwendet.',
    'wrong-password' ||
    'invalid-credential' => 'Das eingegebene Passwort ist nicht korrekt.',
    'requires-recent-login' =>
      'Bitte melde dich erneut an und versuche die Aktion danach noch einmal.',
    'aborted-by-user' => 'Die erneute Anmeldung wurde abgebrochen.',
    'provider-already-linked' =>
      'Apple ist bereits mit diesem Konto verknüpft.',
    'credential-already-in-use' || 'account-exists-with-different-credential' =>
      'Diese Apple-Anmeldung gehört bereits zu einem anderen Konto. Melde dich dort zuerst an oder verwende deine bisherige Anmeldemethode.',
    'operation-not-allowed' =>
      'Apple-Anmeldung ist für plaqa noch nicht freigeschaltet.',
    'missing-or-invalid-nonce' || 'invalid-provider-id' =>
      'Apple-Anmeldung ist noch nicht vollständig konfiguriert.',
    'apple-authorization-code-missing' =>
      'Apple hat keinen gültigen Bestätigungscode geliefert. Bitte starte die Kontolöschung erneut.',
    'apple-token-revocation-failed' =>
      'Die Apple-Anmeldung konnte nicht sicher widerrufen werden. Das Konto wurde nicht gelöscht. Bitte versuche es erneut.',
    'reauth-provider-not-supported' =>
      'Diese Anmeldemethode unterstützt die sichere Kontoaktion noch nicht.',
    'server-account-action-failed' =>
      'Die sichere Kontoaktion konnte gerade nicht abgeschlossen werden.',
    'too-many-requests' =>
      'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut.',
    'network-request-failed' =>
      'Netzwerkfehler. Bitte prüfe deine Internetverbindung.',
    'user-disabled' => 'Dieses Nutzerkonto wurde deaktiviert.',
    'email-mismatch' =>
      'Die eingegebene E-Mail Adresse gehört nicht zu diesem Konto.',
    'email-not-verified' => 'Bestätige zuerst deine E-Mail Adresse.',
    'email-unchanged' =>
      'Die neue E-Mail Adresse entspricht deiner aktuellen Adresse.',
    'missing-password' => 'Bitte gib dein aktuelles Passwort ein.',
    'password-managed-by-provider' =>
      'Das Passwort wird über deinen Anmeldeanbieter verwaltet.',
    'email-managed-by-provider' =>
      'Die E-Mail Adresse wird über deinen Anmeldeanbieter verwaltet.',
    'missing-email' => 'Für dieses Konto ist keine E-Mail hinterlegt.',
    'missing-user' || 'user-not-found' =>
      'Deine aktuelle Anmeldung konnte nicht gefunden werden.',
    _ => 'Die Kontoaktion konnte gerade nicht durchgeführt werden.',
  };
}

String formatAccountDate(DateTime? value) {
  if (value == null) {
    return 'Nicht verfügbar';
  }
  final local = value.toLocal();
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year}';
}

String formatAccountDateTime(DateTime? value) {
  if (value == null) {
    return 'Nicht verfügbar';
  }
  final local = value.toLocal();
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year}, '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)} Uhr';
}

String currentPlatformLabel() {
  if (kIsWeb) {
    return 'Webbrowser';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android-Gerät',
    TargetPlatform.iOS => 'iPhone oder iPad',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.windows => 'Windows-Gerät',
    TargetPlatform.linux => 'Linux-Gerät',
    TargetPlatform.fuchsia => 'Dieses Gerät',
  };
}

String _securityActivityLabel(String eventType) {
  return switch (eventType) {
    'sessions_revoked' => 'Sitzungen widerrufen',
    'account_deletion_requested' => 'Kontolöschung angefordert',
    'email_verification_requested' => 'E-Mail Bestätigung angefordert',
    'email_change_requested' => 'E-Mail Änderung angefordert',
    'password_reset_requested' => 'Passwort-Zurücksetzung angefordert',
    'mfa_recovery_requested' => 'MFA-Wiederherstellung angefordert',
    'mfa_recovery_case_opened' => 'Recovery-Fall sicher eröffnet',
    'mfa_recovery_identity_verified' => 'Identität für Recovery geprüft',
    'mfa_recovery_first_approved' => 'Erste Recovery-Freigabe erteilt',
    'mfa_recovery_second_approved' => 'Zweite Recovery-Freigabe erteilt',
    'mfa_recovery_sessions_revoked' => 'Sitzungen für Recovery widerrufen',
    'mfa_recovery_factor_removed' => 'Zweiter Faktor sicher entfernt',
    'mfa_recovery_rejected' => 'MFA-Wiederherstellung abgelehnt',
    'mfa_recovery_completed' => 'MFA-Wiederherstellung abgeschlossen',
    'mfa_recovery_failed' => 'MFA-Wiederherstellung nicht abgeschlossen',
    'login' => 'Neue Anmeldung',
    _ => 'Sicherheitsaktion',
  };
}

IconData _securityActivityIcon(String eventType) {
  return switch (eventType) {
    'sessions_revoked' => Icons.phonelink_erase_rounded,
    'account_deletion_requested' => Icons.delete_forever_rounded,
    'email_verification_requested' => Icons.mark_email_read_outlined,
    'email_change_requested' => Icons.alternate_email_rounded,
    'password_reset_requested' => Icons.password_rounded,
    'mfa_recovery_requested' => Icons.restore_rounded,
    'mfa_recovery_case_opened' => Icons.support_agent_rounded,
    'mfa_recovery_identity_verified' => Icons.badge_outlined,
    'mfa_recovery_first_approved' => Icons.fact_check_outlined,
    'mfa_recovery_second_approved' => Icons.verified_outlined,
    'mfa_recovery_sessions_revoked' => Icons.phonelink_erase_rounded,
    'mfa_recovery_factor_removed' => Icons.no_encryption_outlined,
    'mfa_recovery_rejected' => Icons.gpp_bad_outlined,
    'mfa_recovery_completed' => Icons.verified_user_outlined,
    'mfa_recovery_failed' => Icons.error_outline_rounded,
    'login' => Icons.login_rounded,
    _ => Icons.shield_outlined,
  };
}

String _securityPlatformLabel(String platform) {
  return switch (platform) {
    'android' => 'Android',
    'ios' => 'iPhone oder iPad',
    'web' => 'Webbrowser',
    'windows' => 'Windows',
    'macos' => 'Mac',
    'linux' => 'Linux',
    'server' => 'plaqa-Sicherheit',
    _ => 'Plattform nicht verfügbar',
  };
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
