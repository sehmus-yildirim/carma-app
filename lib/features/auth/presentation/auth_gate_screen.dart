import 'package:flutter/material.dart';

import '../../../shared/config/carma_app_config.dart';
import '../../../shared/models/carma_models.dart';
import '../../home/presentation/app_shell.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import '../domain/registration_legal_consent_builder.dart';
import 'auth_flow_screen.dart';

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
  AppUserState? _appUserState;

  bool get _isAuthenticated {
    return _appUserState != null;
  }

  bool get _isOnboardingCompleted {
    return _appUserState?.accountStatus.isOnboardingCompleted ?? false;
  }

  AppUserState _buildLocalUserState() {
    final userId = CarmaAppConfig.localUserId;
    final now = DateTime.now();

    final legalConsents = RegistrationLegalConsentBuilder.buildLocalConsents(
      userId: userId,
    );

    final baseState = AppUserState.localRegistered(
      userId: userId,
      legalConsents: legalConsents,
      now: now,
    ).markOnboardingCompleted();

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

  void _completeAuth() {
    setState(() {
      _appUserState = _buildLocalUserState();
    });
  }

  void _completeOnboarding() {
    final currentState = _appUserState;

    if (currentState == null) {
      return;
    }

    setState(() {
      _appUserState = currentState.markOnboardingCompleted();
    });
  }

  void _backToAuth() {
    setState(() {
      _appUserState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !_isAuthenticated
          ? AuthFlowScreen(
        key: const ValueKey('auth_flow'),
        onAuthFinished: _completeAuth,
      )
          : !_isOnboardingCompleted
          ? OnboardingFlowScreen(
        key: const ValueKey('onboarding_flow'),
        onCompleted: _completeOnboarding,
        onBack: _backToAuth,
      )
          : AppShell(
        key: const ValueKey('app_shell'),
        userState: _appUserState!,
        onLogout: _backToAuth,
      ),
    );
  }
}