import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carma_models.dart';
import '../../home/presentation/app_shell.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import '../data/auth_service.dart';
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
  final AuthService _authService = AuthService();

  final Set<String> _onboardingCompletedUserIds = <String>{};

  AppUserState _buildUserState(User user) {
    final userId = user.uid;
    final now = DateTime.now();

    final legalConsents = RegistrationLegalConsentBuilder.buildLocalConsents(
      userId: userId,
    );

    var baseState = AppUserState.localRegistered(
      userId: userId,
      legalConsents: legalConsents,
      now: now,
    );

    if (_onboardingCompletedUserIds.contains(userId)) {
      baseState = baseState.markOnboardingCompleted();
    } else {
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

  void _completeOnboarding(String userId) {
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
    });
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
    final userState = _buildUserState(user);
    final isOnboardingCompleted = userState.accountStatus.isOnboardingCompleted;

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
  }
}
