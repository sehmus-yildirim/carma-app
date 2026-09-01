import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../home/presentation/app_shell.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../settings/data/app_runtime_preferences.dart';
import '../../settings/data/user_settings_repository.dart';
import '../data/auth_service.dart';
import '../data/legal_consent_repository.dart';
import '../data/search_credit_repository.dart';
import '../data/user_profile_repository.dart';
import '../domain/registration_legal_consent_builder.dart';
import 'auth_flow_screen.dart';
import 'legal_consent_renewal_screen.dart';

enum _LocalTestMode {
  normal,
  searchLimitReached,
  verificationPending,
  verified,
  restricted,
  suspended,
}

const _LocalTestMode _localTestMode = _LocalTestMode.normal;

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService();
  final UserProfileRepository _userProfileRepository = UserProfileRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final SearchCreditRepository _searchCreditRepository =
      SearchCreditRepository();
  final LegalConsentRepository _legalConsentRepository =
      LegalConsentRepository();
  final UserSettingsRepository _userSettingsRepository =
      UserSettingsRepository();

  final Set<String> _onboardingCompletedUserIds = <String>{};
  final Set<String> _verificationDismissedUserIds = <String>{};
  final Map<String, List<LegalConsent>> _legalConsentsByUserId =
      <String, List<LegalConsent>>{};
  String? _provisioningUserId;
  Future<void>? _provisioningFuture;
  bool _isSendingVerificationEmail = false;
  bool _isRefreshingVerificationStatus = false;
  String? _verificationMessage;

  AppUserState _buildUserState(User user) {
    final userId = user.uid;
    final now = DateTime.now();

    final legalConsents = _legalConsentsByUserId[userId] ?? const [];

    var baseState = AppUserState.localRegistered(
      userId: userId,
      legalConsents: legalConsents,
      now: now,
    );

    if (_onboardingCompletedUserIds.contains(userId)) {
      baseState = baseState.markOnboardingCompleted();
    }

    return switch (_localTestMode) {
      _LocalTestMode.normal => baseState,
      _LocalTestMode.searchLimitReached => baseState.copyWith(
        searchCredit: baseState.searchCredit.copyWith(
          used: baseState.searchCredit.limit,
          updatedAt: now,
        ),
      ),
      _LocalTestMode.verificationPending => baseState.markVerificationPending(),
      _LocalTestMode.verified => baseState.markVerified(),
      _LocalTestMode.restricted => baseState.copyWith(
        accountStatus: baseState.accountStatus.restrict(
          reason: 'Lokaler Test: Konto eingeschränkt.',
          until: now.add(const Duration(days: 7)),
        ),
        moderationActions: [
          ...baseState.moderationActions,
          ModerationAction.localRestriction(
            userId: userId,
            reason: ModerationReason.other,
            endsAt: now.add(const Duration(days: 7)),
            note: 'Lokaler Testmodus: Feature-Einschränkung aktiv.',
            now: now,
          ),
        ],
      ),
      _LocalTestMode.suspended => baseState.copyWith(
        accountStatus: baseState.accountStatus.suspend(
          reason: 'Lokaler Test: Konto gesperrt.',
        ),
        moderationActions: [
          ...baseState.moderationActions,
          ModerationAction.localSuspension(
            userId: userId,
            reason: ModerationReason.other,
            note: 'Lokaler Testmodus: Kontosperre aktiv.',
            now: now,
          ),
        ],
      ),
    };
  }

  Future<void> _completeOnboarding(String userId) async {
    await _userProfileRepository.completeOnboarding(userId);
    if (!mounted) return;

    setState(() {
      _onboardingCompletedUserIds.add(userId);
    });
  }

  Future<void> _logout() async {
    await _authService.signOut();

    if (!mounted) {
      return;
    }

    setState(() {
      _onboardingCompletedUserIds.clear();
      _verificationDismissedUserIds.clear();
      _legalConsentsByUserId.clear();
      _provisioningUserId = null;
      _provisioningFuture = null;
      _verificationMessage = null;
    });
  }

  bool _needsEmailVerificationNotice(User user) {
    final email = user.email?.trim() ?? '';
    final isPasswordAccount = user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );

    return email.isNotEmpty &&
        isPasswordAccount &&
        !user.emailVerified &&
        !_verificationDismissedUserIds.contains(user.uid);
  }

  void _continueWithUnverifiedEmail(User user) {
    setState(() {
      _verificationDismissedUserIds.add(user.uid);
      _verificationMessage = null;
    });
  }

  Future<void> _resendVerificationEmail(User user) async {
    if (_isSendingVerificationEmail) {
      return;
    }

    setState(() {
      _isSendingVerificationEmail = true;
      _verificationMessage = null;
    });

    try {
      await _authService.sendEmailVerification(user);

      if (!mounted) {
        return;
      }

      setState(() {
        _verificationMessage =
            'Wir haben dir eine neue Bestätigungs-E-Mail gesendet.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationMessage = _mapEmailVerificationError(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationMessage =
            'Die Bestätigungs-E-Mail konnte gerade nicht gesendet werden.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerificationEmail = false;
        });
      }
    }
  }

  Future<void> _refreshVerificationStatus(User user) async {
    if (_isRefreshingVerificationStatus) {
      return;
    }

    setState(() {
      _isRefreshingVerificationStatus = true;
      _verificationMessage = null;
    });

    try {
      final refreshedUser = await _authService.reloadCurrentUser();

      if (!mounted) {
        return;
      }

      if (refreshedUser?.emailVerified ?? false) {
        setState(() {
          _verificationDismissedUserIds.add(user.uid);
          _verificationMessage = 'E-Mail-Adresse bestätigt.';
        });
        return;
      }

      setState(() {
        _verificationMessage = 'Deine E-Mail-Adresse ist noch nicht bestätigt.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationMessage = _mapEmailVerificationError(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationMessage =
            'Der Verifikationsstatus konnte gerade nicht aktualisiert werden.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingVerificationStatus = false;
        });
      }
    }
  }

  String _mapEmailVerificationError(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Bitte warte kurz, bevor du eine neue E-Mail anforderst.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      case 'user-token-expired':
        return 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';
      default:
        return 'Die E-Mail-Bestätigung konnte gerade nicht verarbeitet werden.';
    }
  }

  Future<void> _ensureAuthenticatedUserIsReady(User user) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        await _provisionAuthenticatedUser(user);
        return;
      } on FirebaseException catch (error) {
        final isLastAttempt = attempt == 2;
        final isRetryable =
            error.code == 'unavailable' || error.code == 'deadline-exceeded';
        if (!isRetryable || isLastAttempt) {
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }

  Future<void> _provisionAuthenticatedUser(User user) async {
    await _userProfileRepository.createProfileForUser(user);
    final onboardingCompleted = await _userProfileRepository
        .isOnboardingCompleted(user.uid);
    if (onboardingCompleted) {
      _onboardingCompletedUserIds.add(user.uid);
    } else {
      _onboardingCompletedUserIds.remove(user.uid);
    }
    await _profileRepository.createProfileIfMissing(user);
    await _searchCreditRepository.createSearchCreditIfMissing(userId: user.uid);
    _legalConsentsByUserId[user.uid] = await _legalConsentRepository
        .loadConsents(user.uid);
    final settings = await _userSettingsRepository.load(user.uid);
    AppRuntimePreferences.instance.apply(settings.appPreferences);
  }

  Future<void> _retryProvisioning(User user) async {
    setState(() {
      _provisioningUserId = user.uid;
      _provisioningFuture = _ensureAuthenticatedUserIsReady(user);
    });
  }

  Future<void> _provisioningFor(User user) {
    if (_provisioningUserId != user.uid || _provisioningFuture == null) {
      _provisioningUserId = user.uid;
      _provisioningFuture = _ensureAuthenticatedUserIsReady(user);
    }

    return _provisioningFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: user == null
              ? const AuthFlowScreen(key: ValueKey('auth_flow'))
              : _buildAuthenticatedArea(user),
        );
      },
    );
  }

  Widget _buildAuthenticatedArea(User user) {
    return FutureBuilder<void>(
      key: ValueKey('auth_provisioning_${user.uid}'),
      future: _provisioningFor(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildProvisioningLoading();
        }

        if (snapshot.hasError) {
          return _buildProvisioningError(user);
        }

        final userState = _buildUserState(user);
        if (!userState.hasRequiredLegalConsents) {
          return LegalConsentRenewalScreen(
            key: ValueKey('legal_consent_renewal_${user.uid}'),
            onAccept: () => _acceptCurrentLegalConsents(user),
            onLogout: _logout,
          );
        }

        if (_needsEmailVerificationNotice(user)) {
          return _buildEmailVerificationNotice(user);
        }
        final isOnboardingCompleted =
            userState.accountStatus.isOnboardingCompleted;

        if (!isOnboardingCompleted) {
          return OnboardingFlowScreen(
            key: const ValueKey('onboarding_flow'),
            onCompleted: () => _completeOnboarding(user.uid),
            onBack: _logout,
          );
        }

        return AppShell(
          key: const ValueKey('app_shell'),
          userState: userState,
          onLogout: _logout,
        );
      },
    );
  }

  Future<void> _acceptCurrentLegalConsents(User user) async {
    await _legalConsentRepository.saveConsents(
      userId: user.uid,
      consents: RegistrationLegalConsentBuilder.buildLocalConsents(
        userId: user.uid,
      ),
      source: 'renewal',
    );
    final consents = await _legalConsentRepository.loadConsents(user.uid);
    if (!mounted) return;
    setState(() {
      _legalConsentsByUserId[user.uid] = consents;
    });
  }

  Widget _buildProvisioningLoading() {
    return const CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(
            color: CaRismaDesignTokens.bluePrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildProvisioningError(User user) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: CaRismaDesignTokens.surfaceDecoration(
                  radius: CaRismaDesignTokens.radiusPanel,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: CaRismaDesignTokens.bluePrimary,
                        size: 36,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Konto wird vorbereitet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Deine Basisdaten konnten gerade nicht vollständig angelegt werden. Bitte versuche es erneut.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CaRismaDesignTokens.textSecondary,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: CaRismaDesignTokens.bluePrimary,
                          foregroundColor: CaRismaDesignTokens.textPrimary,
                        ),
                        onPressed: () => _retryProvisioning(user),
                        child: const Text('Erneut versuchen'),
                      ),
                      TextButton(
                        onPressed: _logout,
                        child: const Text(
                          'Abmelden',
                          style: TextStyle(
                            color: CaRismaDesignTokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailVerificationNotice(User user) {
    final email = user.email?.trim() ?? 'deine E-Mail-Adresse';
    final busy = _isSendingVerificationEmail || _isRefreshingVerificationStatus;

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: CaRismaDesignTokens.surfaceDecoration(
                  radius: CaRismaDesignTokens.radiusPanel,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.mark_email_unread_rounded,
                        color: CaRismaDesignTokens.bluePrimary,
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'E-Mail bestätigen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bitte bestätige $email über den Link in deiner E-Mail. Du kannst plaqa im MVP schon nutzen, solltest die Bestätigung aber zeitnah abschließen.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textSecondary,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_verificationMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _verificationMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CaRismaDesignTokens.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      CaRismaPrimaryButton(
                        label: 'Weiter zur App',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => _continueWithUnverifiedEmail(user),
                        isEnabled: !busy,
                        surfaceOutlined: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        borderRadius: 22,
                        iconSize: 23,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _VerificationActionButton(
                              label: 'E-Mail erneut senden',
                              icon: Icons.mark_email_unread_rounded,
                              isLoading: _isSendingVerificationEmail,
                              isEnabled: !busy,
                              onPressed: () => _resendVerificationEmail(user),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _VerificationActionButton(
                              label: 'Status aktualisieren',
                              icon: Icons.refresh_rounded,
                              isLoading: _isRefreshingVerificationStatus,
                              isEnabled: !busy,
                              onPressed: () => _refreshVerificationStatus(user),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : _logout,
                        child: const Text(
                          'Abmelden',
                          style: TextStyle(
                            color: CaRismaDesignTokens.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationActionButton extends StatelessWidget {
  const _VerificationActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isEnabled,
    required this.isLoading,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final canTap = isEnabled && !isLoading;

    return Opacity(
      opacity: canTap ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: CaRismaDesignTokens.controlSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLoading ? Icons.hourglass_top_rounded : icon,
                  color: CaRismaDesignTokens.bluePrimary,
                  size: 22,
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
