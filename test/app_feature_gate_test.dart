import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/domain/app_feature_gate.dart';
import 'package:plaqa/shared/models/carisma_models.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 27, 10);

  List<LegalConsent> requiredConsents(String userId) {
    return LegalConsentType.values
        .map(
          (type) => LegalConsent(
            id: type.name,
            userId: userId,
            type: type,
            version: '1.0',
            acceptedAt: timestamp,
          ),
        )
        .toList();
  }

  AppUserState state({
    AccountState accountState = AccountState.onboardingCompleted,
    String? reason,
    List<LegalConsent>? consents,
    List<ModerationAction> moderationActions = const [],
  }) {
    const userId = 'user-a';
    return AppUserState(
      userId: userId,
      accountStatus: AccountStatus(
        userId: userId,
        state: accountState,
        createdAt: timestamp,
        updatedAt: timestamp,
        reason: reason,
      ),
      searchCredit: const SearchCredit(
        userId: userId,
        used: 2,
        limit: 2,
        resetPeriod: SearchCreditResetPeriod.monthly,
      ),
      legalConsents: consents ?? requiredConsents(userId),
      moderationActions: moderationActions,
    );
  }

  group('AppFeatureGate', () {
    test('allows launch plate searches despite exhausted legacy quota', () {
      final decision = AppFeatureGate.evaluate(
        userState: state(),
        feature: AppFeature.plateSearch,
      );

      expect(decision.isAllowed, isTrue);
      expect(decision.reason, isNull);
    });

    test('requires all legal consents before app access', () {
      final decision = AppFeatureGate.evaluate(
        userState: state(consents: const []),
        feature: AppFeature.appAccess,
      );

      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('Nutzungsbedingungen'));
    });

    test('requires onboarding for search, contact, reports and chat', () {
      final registered = state(accountState: AccountState.registered);

      for (final feature in const [
        AppFeature.plateSearch,
        AppFeature.contactRequest,
        AppFeature.anonymousReport,
        AppFeature.chat,
      ]) {
        final decision = AppFeatureGate.evaluate(
          userState: registered,
          feature: feature,
        );
        expect(decision.isAllowed, isFalse, reason: feature.name);
        expect(decision.reason, contains('Onboarding'), reason: feature.name);
      }
    });

    test('propagates an account restriction reason', () {
      final restricted = state(
        accountState: AccountState.restricted,
        reason: 'Manuelle Sicherheitsprüfung',
      );

      for (final feature in const [
        AppFeature.plateSearch,
        AppFeature.contactRequest,
        AppFeature.anonymousReport,
        AppFeature.chat,
      ]) {
        final decision = AppFeatureGate.evaluate(
          userState: restricted,
          feature: feature,
        );
        expect(decision.isAllowed, isFalse, reason: feature.name);
        expect(
          decision.reason,
          'Manuelle Sicherheitsprüfung',
          reason: feature.name,
        );
      }
    });

    test('blocks suspended and deleted accounts', () {
      final suspended = AppFeatureGate.evaluate(
        userState: state(
          accountState: AccountState.suspended,
          reason: 'Vorübergehend gesperrt',
        ),
        feature: AppFeature.appAccess,
      );
      final deleted = AppFeatureGate.evaluate(
        userState: state(accountState: AccountState.deleted),
        feature: AppFeature.appAccess,
      );

      expect(suspended.isAllowed, isFalse);
      expect(suspended.reason, 'Vorübergehend gesperrt');
      expect(deleted.isAllowed, isFalse);
      expect(deleted.reason, contains('gelöscht'));
    });

    test('blocks feature access during an active moderation restriction', () {
      final action = ModerationAction.localRestriction(
        userId: 'user-a',
        reason: ModerationReason.spam,
        now: timestamp,
        endsAt: DateTime.utc(2099),
      );
      final restricted = state(moderationActions: [action]);

      expect(restricted.canUseApp, isTrue);
      expect(restricted.canSearchPlates, isFalse);
      expect(restricted.canRequestContact, isFalse);
      expect(restricted.canSendReports, isFalse);
    });

    test('reports verification states with precise reasons', () {
      final pending = AppFeatureGate.evaluate(
        userState: state(accountState: AccountState.verificationPending),
        feature: AppFeature.profileVerification,
      );
      final verified = AppFeatureGate.evaluate(
        userState: state(accountState: AccountState.verified),
        feature: AppFeature.profileVerification,
      );
      final eligible = AppFeatureGate.evaluate(
        userState: state(),
        feature: AppFeature.profileVerification,
      );

      expect(pending.isAllowed, isFalse);
      expect(pending.reason, contains('bereits geprüft'));
      expect(verified.isAllowed, isFalse);
      expect(verified.reason, contains('bereits verifiziert'));
      expect(eligible.isAllowed, isTrue);
    });
  });
}
