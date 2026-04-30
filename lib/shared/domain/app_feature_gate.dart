import '../models/carma_models.dart';

enum AppFeature {
  appAccess,
  plateSearch,
  contactRequest,
  anonymousReport,
  chat,
  profileVerification,
}

class AppFeatureGate {
  const AppFeatureGate._();

  static AppFeatureDecision evaluate({
    required AppUserState userState,
    required AppFeature feature,
  }) {
    return switch (feature) {
      AppFeature.appAccess => _evaluateAppAccess(userState),
      AppFeature.plateSearch => _evaluatePlateSearch(userState),
      AppFeature.contactRequest => _evaluateContactRequest(userState),
      AppFeature.anonymousReport => _evaluateAnonymousReport(userState),
      AppFeature.chat => _evaluateChat(userState),
      AppFeature.profileVerification => _evaluateProfileVerification(userState),
    };
  }

  static AppFeatureDecision _evaluateAppAccess(AppUserState userState) {
    if (userState.accountStatus.isDeleted) {
      return const AppFeatureDecision.blocked(
        reason: 'Dieses Konto wurde gelöscht.',
      );
    }

    if (userState.accountStatus.isSuspended) {
      return AppFeatureDecision.blocked(
        reason: userState.accountStatus.reason ??
            'Dieses Konto ist aktuell gesperrt.',
      );
    }

    if (!userState.hasRequiredLegalConsents) {
      return const AppFeatureDecision.blocked(
        reason: 'Bitte akzeptiere zuerst die erforderlichen Nutzungsbedingungen.',
      );
    }

    return const AppFeatureDecision.allowed();
  }

  static AppFeatureDecision _evaluatePlateSearch(AppUserState userState) {
    final appAccess = _evaluateAppAccess(userState);

    if (!appAccess.isAllowed) {
      return appAccess;
    }

    if (!userState.accountStatus.isOnboardingCompleted) {
      return const AppFeatureDecision.blocked(
        reason: 'Bitte schließe zuerst das Onboarding ab.',
      );
    }

    if (userState.accountStatus.isRestricted) {
      return AppFeatureDecision.blocked(
        reason: userState.accountStatus.reason ??
            'Dein Konto ist aktuell eingeschränkt.',
      );
    }

    if (!userState.searchCredit.hasRemaining) {
      return const AppFeatureDecision.blocked(
        reason: 'Du hast dein kostenloses Suchlimit erreicht.',
      );
    }

    if (!userState.canSearchPlates) {
      return const AppFeatureDecision.blocked(
        reason: 'Die Kennzeichen-Suche ist aktuell nicht verfügbar.',
      );
    }

    return const AppFeatureDecision.allowed();
  }

  static AppFeatureDecision _evaluateContactRequest(AppUserState userState) {
    final appAccess = _evaluateAppAccess(userState);

    if (!appAccess.isAllowed) {
      return appAccess;
    }

    if (!userState.accountStatus.isOnboardingCompleted) {
      return const AppFeatureDecision.blocked(
        reason: 'Bitte schließe zuerst das Onboarding ab.',
      );
    }

    if (userState.accountStatus.isRestricted) {
      return AppFeatureDecision.blocked(
        reason: userState.accountStatus.reason ??
            'Dein Konto ist aktuell eingeschränkt.',
      );
    }

    if (!userState.canRequestContact) {
      return const AppFeatureDecision.blocked(
        reason: 'Kontaktanfragen sind aktuell nicht verfügbar.',
      );
    }

    return const AppFeatureDecision.allowed();
  }

  static AppFeatureDecision _evaluateAnonymousReport(AppUserState userState) {
    final appAccess = _evaluateAppAccess(userState);

    if (!appAccess.isAllowed) {
      return appAccess;
    }

    if (!userState.accountStatus.isOnboardingCompleted) {
      return const AppFeatureDecision.blocked(
        reason: 'Bitte schließe zuerst das Onboarding ab.',
      );
    }

    if (userState.accountStatus.isRestricted) {
      return AppFeatureDecision.blocked(
        reason: userState.accountStatus.reason ??
            'Dein Konto ist aktuell eingeschränkt.',
      );
    }

    if (!userState.canSendReports) {
      return const AppFeatureDecision.blocked(
        reason: 'Anonyme Hinweise sind aktuell nicht verfügbar.',
      );
    }

    return const AppFeatureDecision.allowed();
  }

  static AppFeatureDecision _evaluateChat(AppUserState userState) {
    final appAccess = _evaluateAppAccess(userState);

    if (!appAccess.isAllowed) {
      return appAccess;
    }

    if (!userState.accountStatus.isOnboardingCompleted) {
      return const AppFeatureDecision.blocked(
        reason: 'Bitte schließe zuerst das Onboarding ab.',
      );
    }

    if (userState.accountStatus.isRestricted) {
      return AppFeatureDecision.blocked(
        reason: userState.accountStatus.reason ??
            'Dein Konto ist aktuell eingeschränkt.',
      );
    }

    return const AppFeatureDecision.allowed();
  }

  static AppFeatureDecision _evaluateProfileVerification(
      AppUserState userState,
      ) {
    final appAccess = _evaluateAppAccess(userState);

    if (!appAccess.isAllowed) {
      return appAccess;
    }

    if (userState.accountStatus.isVerified) {
      return const AppFeatureDecision.blocked(
        reason: 'Dieses Profil ist bereits verifiziert.',
      );
    }

    if (userState.accountStatus.isVerificationPending) {
      return const AppFeatureDecision.blocked(
        reason: 'Die Verifizierung wird bereits geprüft.',
      );
    }

    return const AppFeatureDecision.allowed();
  }
}

class AppFeatureDecision {
  const AppFeatureDecision._({
    required this.isAllowed,
    this.reason,
  });

  const AppFeatureDecision.allowed()
      : this._(
    isAllowed: true,
  );

  const AppFeatureDecision.blocked({
    required String reason,
  }) : this._(
    isAllowed: false,
    reason: reason,
  );

  final bool isAllowed;
  final String? reason;
}