import 'account_status.dart';
import 'legal_consent.dart';
import 'moderation_action.dart';
import 'search_credit.dart';

class AppUserState {
  const AppUserState({
    required this.userId,
    required this.accountStatus,
    required this.searchCredit,
    this.legalConsents = const [],
    this.moderationActions = const [],
  });

  final String userId;
  final AccountStatus accountStatus;
  final SearchCredit searchCredit;
  final List<LegalConsent> legalConsents;
  final List<ModerationAction> moderationActions;

  bool get canUseApp {
    return accountStatus.canUseApp && !_hasActiveBlockingModeration;
  }

  bool get canSearchPlates {
    return canUseApp &&
        accountStatus.canSearchPlates &&
        searchCredit.hasRemaining &&
        !_hasActiveFeatureRestriction;
  }

  bool get canSendReports {
    return canUseApp &&
        accountStatus.canSendReports &&
        !_hasActiveFeatureRestriction;
  }

  bool get canRequestContact {
    return canUseApp &&
        accountStatus.canRequestContact &&
        !_hasActiveFeatureRestriction;
  }

  bool get hasAcceptedTerms {
    return legalConsents.any(
          (consent) => consent.type == LegalConsentType.terms,
    );
  }

  bool get hasAcceptedPrivacy {
    return legalConsents.any(
          (consent) => consent.type == LegalConsentType.privacy,
    );
  }

  bool get hasAcceptedResponsibleUse {
    return legalConsents.any(
          (consent) => consent.type == LegalConsentType.responsibleUse,
    );
  }

  bool get hasAcceptedNoEmergencyUse {
    return legalConsents.any(
          (consent) => consent.type == LegalConsentType.noEmergencyUse,
    );
  }

  bool get hasRequiredLegalConsents {
    return hasAcceptedTerms &&
        hasAcceptedPrivacy &&
        hasAcceptedResponsibleUse &&
        hasAcceptedNoEmergencyUse;
  }

  bool get hasActiveModeration {
    return moderationActions.any((action) => action.isActive);
  }

  bool get _hasActiveBlockingModeration {
    return moderationActions.any(
          (action) => action.isActive && action.blocksAccount,
    );
  }

  bool get _hasActiveFeatureRestriction {
    return moderationActions.any(
          (action) => action.isActive && action.restrictsFeatures,
    );
  }

  List<ModerationAction> get activeModerationActions {
    return moderationActions.where((action) => action.isActive).toList();
  }

  AppUserState copyWith({
    String? userId,
    AccountStatus? accountStatus,
    SearchCredit? searchCredit,
    List<LegalConsent>? legalConsents,
    List<ModerationAction>? moderationActions,
  }) {
    return AppUserState(
      userId: userId ?? this.userId,
      accountStatus: accountStatus ?? this.accountStatus,
      searchCredit: searchCredit ?? this.searchCredit,
      legalConsents: legalConsents ?? this.legalConsents,
      moderationActions: moderationActions ?? this.moderationActions,
    );
  }

  AppUserState markOnboardingCompleted() {
    return copyWith(
      accountStatus: accountStatus.markOnboardingCompleted(),
    );
  }

  AppUserState markVerificationPending() {
    return copyWith(
      accountStatus: accountStatus.markVerificationPending(),
    );
  }

  AppUserState markVerified() {
    return copyWith(
      accountStatus: accountStatus.markVerified(),
    );
  }

  AppUserState consumeSearchCredit() {
    return copyWith(
      searchCredit: searchCredit.consume(),
    );
  }

  AppUserState addLegalConsents(List<LegalConsent> consents) {
    return copyWith(
      legalConsents: [
        ...legalConsents,
        ...consents,
      ],
    );
  }

  AppUserState addModerationAction(ModerationAction action) {
    return copyWith(
      moderationActions: [
        ...moderationActions,
        action,
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'accountStatus': accountStatus.toMap(),
      'searchCredit': searchCredit.toMap(),
      'legalConsents': legalConsents.map((consent) => consent.toMap()).toList(),
      'moderationActions':
      moderationActions.map((action) => action.toMap()).toList(),
      'canUseApp': canUseApp,
      'canSearchPlates': canSearchPlates,
      'canSendReports': canSendReports,
      'canRequestContact': canRequestContact,
      'hasRequiredLegalConsents': hasRequiredLegalConsents,
    };
  }

  factory AppUserState.fromMap(Map<String, dynamic> map) {
    final legalConsentValues = map['legalConsents'];
    final moderationActionValues = map['moderationActions'];

    return AppUserState(
      userId: map['userId'] as String? ?? '',
      accountStatus: AccountStatus.fromMap(
        Map<String, dynamic>.from(
          map['accountStatus'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      searchCredit: SearchCredit.fromMap(
        Map<String, dynamic>.from(
          map['searchCredit'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      legalConsents: legalConsentValues is List
          ? legalConsentValues
          .whereType<Map>()
          .map(
            (value) => LegalConsent.fromMap(
          Map<String, dynamic>.from(value),
        ),
      )
          .toList()
          : const [],
      moderationActions: moderationActionValues is List
          ? moderationActionValues
          .whereType<Map>()
          .map(
            (value) => ModerationAction.fromMap(
          Map<String, dynamic>.from(value),
        ),
      )
          .toList()
          : const [],
    );
  }

  factory AppUserState.localRegistered({
    required String userId,
    List<LegalConsent> legalConsents = const [],
    DateTime? now,
  }) {
    return AppUserState(
      userId: userId,
      accountStatus: AccountStatus.localRegistered(
        userId: userId,
        now: now,
      ),
      searchCredit: SearchCredit.freeDefault(
        userId: userId,
      ),
      legalConsents: legalConsents,
    );
  }

  @override
  String toString() {
    return 'AppUserState(userId: $userId, canUseApp: $canUseApp, canSearchPlates: $canSearchPlates)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppUserState &&
            runtimeType == other.runtimeType &&
            userId == other.userId &&
            accountStatus == other.accountStatus &&
            searchCredit == other.searchCredit &&
            _listEquals(legalConsents, other.legalConsents) &&
            _listEquals(moderationActions, other.moderationActions);
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      accountStatus,
      searchCredit,
      Object.hashAll(legalConsents),
      Object.hashAll(moderationActions),
    );
  }

  static bool _listEquals<T>(List<T> first, List<T> second) {
    if (identical(first, second)) {
      return true;
    }

    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }
}