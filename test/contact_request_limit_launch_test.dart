import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/config/carisma_app_config.dart';
import 'package:plaqa/shared/domain/app_feature_gate.dart';
import 'package:plaqa/shared/models/carisma_models.dart';

void main() {
  test('launch mode keeps plate search available after quota exhaustion', () {
    final timestamp = DateTime(2026, 8, 20);
    final userId = 'launch-user';
    final state = AppUserState(
      userId: userId,
      accountStatus: AccountStatus(
        userId: userId,
        state: AccountState.onboardingCompleted,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      searchCredit: SearchCredit(
        userId: userId,
        used: 2,
        limit: 2,
        resetPeriod: SearchCreditResetPeriod.monthly,
      ),
      legalConsents: LegalConsentType.values
          .map(
            (type) => LegalConsent(
              id: type.name,
              userId: userId,
              type: type,
              version: '1.0',
              acceptedAt: timestamp,
            ),
          )
          .toList(),
    );

    expect(CaRismaAppConfig.enforceMonthlyContactRequestLimit, isFalse);
    expect(state.searchCredit.hasRemaining, isFalse);
    expect(state.canSearchPlates, isTrue);
    expect(
      AppFeatureGate.evaluate(
        userState: state,
        feature: AppFeature.plateSearch,
      ).isAllowed,
      isTrue,
    );
  });

  test('search brand card keeps a compact undistorted logo layout', () {
    final source = File(
      'lib/features/home/presentation/dashboard_screen.dart',
    ).readAsStringSync();
    final brandCard = source.substring(
      source.indexOf('class _SearchBrandCard'),
      source.indexOf('class _SearchUserAvatar'),
    );

    expect(brandCard, contains('height: 46'));
    expect(brandCard, contains('scale: 1.18'));
    expect(brandCard, contains('fit: BoxFit.contain'));
    expect(brandCard, contains('alignment: Alignment.center'));
    expect(brandCard, isNot(contains('decoration: BoxDecoration')));
  });
}
