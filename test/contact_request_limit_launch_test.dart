import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/config/carisma_app_config.dart';
import 'package:plaqa/shared/domain/app_feature_gate.dart';
import 'package:plaqa/shared/models/carisma_models.dart';
import 'package:plaqa/features/auth/domain/registration_legal_consent_builder.dart';

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
      legalConsents: RegistrationLegalConsentBuilder.buildLocalConsents(
        userId: userId,
        acceptedAt: timestamp,
      ),
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

  test('plate search screen follows the disabled launch quota', () {
    final source = File(
      'lib/features/plate_search/presentation/plate_search_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('!CaRismaAppConfig.enforceMonthlyContactRequestLimit ||'),
    );
    expect(
      source,
      contains('if (CaRismaAppConfig.enforceMonthlyContactRequestLimit) ...['),
    );
  });
}
