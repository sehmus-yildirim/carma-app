import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import '../../../shared/legal/legal_versions.dart';
import '../../../shared/models/legal_consent.dart';

class DataRightsRequestDraftBuilder {
  const DataRightsRequestDraftBuilder._();

  static const String deletionConfirmation = 'KONTO LÖSCHEN';

  static bool isDeletionConfirmed({
    required String confirmationText,
    required bool acceptedConsequences,
  }) {
    return acceptedConsequences &&
        confirmationText.trim().toUpperCase() == deletionConfirmation;
  }

  static String buildExportRequest({
    required String appVersion,
    required String userId,
    String? email,
    String? note,
  }) {
    final normalizedEmail = _availableValue(email);
    final normalizedNote = note?.trim();

    return 'Datenexport anfordern\n'
        'App: $appVersion\n'
        'Konto: $normalizedEmail\n'
        'UID: $userId\n'
        'Hinweis: ${normalizedNote?.isNotEmpty == true ? normalizedNote : 'Kein zusätzlicher Hinweis.'}\n\n'
        'Dies ist eine Anfrage. Die Exportdatei wird nicht automatisch in der App erstellt.';
  }

  static String buildDeletionRequest({
    required String appVersion,
    required String userId,
    required String confirmationText,
    required bool acceptedConsequences,
    String? email,
  }) {
    if (!isDeletionConfirmed(
      confirmationText: confirmationText,
      acceptedConsequences: acceptedConsequences,
    )) {
      throw ArgumentError('Die Kontolöschung wurde nicht eindeutig bestätigt.');
    }

    return 'Konto löschen anfordern\n'
        'App: $appVersion\n'
        'Konto: ${_availableValue(email)}\n'
        'UID: $userId\n'
        'Bestätigung: $deletionConfirmation\n\n'
        'Dies ist eine Löschanfrage. Eine Löschung erfolgt erst nach sicherer Prüfung und unter Beachtung gesetzlicher Aufbewahrungsfristen.';
  }

  static String _availableValue(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? 'Nicht verfügbar' : normalized;
  }
}

class LegalConsentVersionStatus {
  const LegalConsentVersionStatus({
    required this.type,
    required this.label,
    required this.currentVersion,
    this.acceptedVersion,
    this.acceptedAt,
  });

  final LegalConsentType type;
  final String label;
  final String currentVersion;
  final String? acceptedVersion;
  final DateTime? acceptedAt;

  bool get isAvailable => acceptedVersion?.trim().isNotEmpty == true;
  bool get isCurrent => isAvailable && acceptedVersion == currentVersion;
}

class LegalConsentStatusResolver {
  const LegalConsentStatusResolver._();

  static List<LegalConsentVersionStatus> resolve(
    Iterable<LegalConsent> consents,
  ) {
    final latestByType = <LegalConsentType, LegalConsent>{};
    for (final consent in consents) {
      final current = latestByType[consent.type];
      if (current == null || consent.acceptedAt.isAfter(current.acceptedAt)) {
        latestByType[consent.type] = consent;
      }
    }

    return LegalConsentType.values
        .map((type) {
          final accepted = latestByType[type];
          return LegalConsentVersionStatus(
            type: type,
            label: _labelFor(type),
            currentVersion: _currentVersionFor(type),
            acceptedVersion: accepted?.version,
            acceptedAt: accepted?.acceptedAt,
          );
        })
        .toList(growable: false);
  }

  static String _labelFor(LegalConsentType type) {
    return switch (type) {
      LegalConsentType.terms => 'AGB',
      LegalConsentType.privacy => 'Datenschutz',
      LegalConsentType.responsibleUse => 'Verantwortungsvolle Nutzung',
      LegalConsentType.noEmergencyUse => 'Keine Notfallnutzung',
    };
  }

  static String _currentVersionFor(LegalConsentType type) {
    return switch (type) {
      LegalConsentType.terms => LegalVersions.terms,
      LegalConsentType.privacy => LegalVersions.privacy,
      LegalConsentType.responsibleUse => LegalVersions.responsibleUse,
      LegalConsentType.noEmergencyUse => LegalVersions.noEmergencyUse,
    };
  }
}

class VisibilitySettings {
  const VisibilitySettings({
    this.profileVisibility = 'contacts',
    this.plateSearchVisibility = 'contacts',
    this.showVehicle = false,
    this.showRegion = false,
    this.showPlate = false,
    this.allowContactRequests = true,
  });

  final String profileVisibility;
  final String plateSearchVisibility;
  final bool showVehicle;
  final bool showRegion;
  final bool showPlate;
  final bool allowContactRequests;

  factory VisibilitySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const VisibilitySettings();
    return VisibilitySettings(
      profileVisibility: data['profileVisibility'] as String? ?? 'contacts',
      plateSearchVisibility:
          data['plateSearchVisibility'] as String? ?? 'contacts',
      showVehicle: data['showVehicle'] as bool? ?? false,
      showRegion: data['showRegion'] as bool? ?? false,
      showPlate: data['showPlate'] as bool? ?? false,
      allowContactRequests: data['allowContactRequests'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore({required String userId}) {
    return {
      'userId': userId,
      'profileVisibility': profileVisibility,
      'plateSearchVisibility': plateSearchVisibility,
      'showVehicle': showVehicle,
      'showRegion': showRegion,
      'showPlate': showPlate,
      'allowContactRequests': allowContactRequests,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  VisibilitySettings copyWith({
    String? profileVisibility,
    String? plateSearchVisibility,
    bool? showVehicle,
    bool? showRegion,
    bool? showPlate,
    bool? allowContactRequests,
  }) {
    return VisibilitySettings(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      plateSearchVisibility:
          plateSearchVisibility ?? this.plateSearchVisibility,
      showVehicle: showVehicle ?? this.showVehicle,
      showRegion: showRegion ?? this.showRegion,
      showPlate: showPlate ?? this.showPlate,
      allowContactRequests: allowContactRequests ?? this.allowContactRequests,
    );
  }
}

class ContactFilterSettings {
  const ContactFilterSettings({
    this.requireVerifiedRequester = false,
    this.allowedContactReasons = const <String>[
      'vehicle_question',
      'compliment',
      'meet_and_drive',
      'get_to_know',
    ],
    this.autoRejectUnverified = false,
    this.contactRequestQuietModeUntil,
  });

  final bool requireVerifiedRequester;
  final List<String> allowedContactReasons;
  final bool autoRejectUnverified;
  final DateTime? contactRequestQuietModeUntil;

  factory ContactFilterSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ContactFilterSettings();
    final until = data['contactRequestQuietModeUntil'];
    return ContactFilterSettings(
      requireVerifiedRequester:
          data['requireVerifiedRequester'] as bool? ?? false,
      allowedContactReasons:
          (data['allowedContactReasons'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[
            'vehicle_question',
            'compliment',
            'meet_and_drive',
            'get_to_know',
          ],
      autoRejectUnverified: data['autoRejectUnverified'] as bool? ?? false,
      contactRequestQuietModeUntil: until is Timestamp ? until.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore({required String userId}) {
    return {
      'userId': userId,
      'requireVerifiedRequester': requireVerifiedRequester,
      'allowedContactReasons': allowedContactReasons,
      'autoRejectUnverified': autoRejectUnverified,
      'contactRequestQuietModeUntil': contactRequestQuietModeUntil == null
          ? null
          : Timestamp.fromDate(contactRequestQuietModeUntil!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ContactFilterSettings copyWith({
    bool? requireVerifiedRequester,
    List<String>? allowedContactReasons,
    bool? autoRejectUnverified,
    DateTime? contactRequestQuietModeUntil,
    bool clearQuietMode = false,
  }) {
    return ContactFilterSettings(
      requireVerifiedRequester:
          requireVerifiedRequester ?? this.requireVerifiedRequester,
      allowedContactReasons:
          allowedContactReasons ?? this.allowedContactReasons,
      autoRejectUnverified: autoRejectUnverified ?? this.autoRejectUnverified,
      contactRequestQuietModeUntil: clearQuietMode
          ? null
          : contactRequestQuietModeUntil ?? this.contactRequestQuietModeUntil,
    );
  }
}

class ChatPrivacySettings {
  const ChatPrivacySettings({
    this.readReceiptsEnabled = true,
    this.onlineStatusEnabled = false,
    this.autoSaveMedia = false,
    this.defaultViewOnceMedia = false,
  });

  final bool readReceiptsEnabled;
  final bool onlineStatusEnabled;
  final bool autoSaveMedia;
  final bool defaultViewOnceMedia;

  factory ChatPrivacySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ChatPrivacySettings();
    return ChatPrivacySettings(
      readReceiptsEnabled: data['readReceiptsEnabled'] as bool? ?? true,
      onlineStatusEnabled: data['onlineStatusEnabled'] as bool? ?? false,
      autoSaveMedia: data['autoSaveMedia'] as bool? ?? false,
      defaultViewOnceMedia: data['defaultViewOnceMedia'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore({required String userId}) {
    return {
      'userId': userId,
      'readReceiptsEnabled': readReceiptsEnabled,
      'onlineStatusEnabled': onlineStatusEnabled,
      'autoSaveMedia': autoSaveMedia,
      'defaultViewOnceMedia': defaultViewOnceMedia,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ChatPrivacySettings copyWith({
    bool? readReceiptsEnabled,
    bool? onlineStatusEnabled,
    bool? autoSaveMedia,
    bool? defaultViewOnceMedia,
  }) {
    return ChatPrivacySettings(
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      onlineStatusEnabled: onlineStatusEnabled ?? this.onlineStatusEnabled,
      autoSaveMedia: autoSaveMedia ?? this.autoSaveMedia,
      defaultViewOnceMedia: defaultViewOnceMedia ?? this.defaultViewOnceMedia,
    );
  }
}

class StoryPrivacySettings {
  const StoryPrivacySettings({
    this.storyVisibility = 'contacts',
    this.excludedStoryUserIds = const <String>[],
    this.storyRepliesEnabled = true,
    this.defaultStoryVehicleData = false,
  });

  final String storyVisibility;
  final List<String> excludedStoryUserIds;
  final bool storyRepliesEnabled;
  final bool defaultStoryVehicleData;

  factory StoryPrivacySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const StoryPrivacySettings();
    return StoryPrivacySettings(
      storyVisibility: data['storyVisibility'] as String? ?? 'contacts',
      excludedStoryUserIds:
          (data['excludedStoryUserIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      storyRepliesEnabled: data['storyRepliesEnabled'] as bool? ?? true,
      defaultStoryVehicleData:
          data['defaultStoryVehicleData'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore({required String userId}) {
    return {
      'userId': userId,
      'storyVisibility': storyVisibility,
      'excludedStoryUserIds': excludedStoryUserIds,
      'storyRepliesEnabled': storyRepliesEnabled,
      'defaultStoryVehicleData': defaultStoryVehicleData,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  StoryPrivacySettings copyWith({
    String? storyVisibility,
    List<String>? excludedStoryUserIds,
    bool? storyRepliesEnabled,
    bool? defaultStoryVehicleData,
  }) {
    return StoryPrivacySettings(
      storyVisibility: storyVisibility ?? this.storyVisibility,
      excludedStoryUserIds: excludedStoryUserIds ?? this.excludedStoryUserIds,
      storyRepliesEnabled: storyRepliesEnabled ?? this.storyRepliesEnabled,
      defaultStoryVehicleData:
          defaultStoryVehicleData ?? this.defaultStoryVehicleData,
    );
  }
}

class AppPreferenceSettings {
  const AppPreferenceSettings({
    this.languageCode = 'de',
    this.themeMode = 'dark',
    this.hapticsEnabled = true,
    this.messageSoundsEnabled = true,
    this.distanceUnit = 'km',
    this.defaultPlateCountry = 'DE',
  });

  final String languageCode;
  final String themeMode;
  final bool hapticsEnabled;
  final bool messageSoundsEnabled;
  final String distanceUnit;
  final String defaultPlateCountry;

  factory AppPreferenceSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AppPreferenceSettings();
    return AppPreferenceSettings(
      languageCode: data['languageCode'] as String? ?? 'de',
      themeMode: data['themeMode'] as String? ?? 'dark',
      hapticsEnabled: data['hapticsEnabled'] as bool? ?? true,
      messageSoundsEnabled: data['messageSoundsEnabled'] as bool? ?? true,
      distanceUnit: data['distanceUnit'] as String? ?? 'km',
      defaultPlateCountry: data['defaultPlateCountry'] as String? ?? 'DE',
    );
  }

  Map<String, dynamic> toFirestore({required String userId}) {
    return {
      'userId': userId,
      'languageCode': languageCode,
      'themeMode': themeMode,
      'hapticsEnabled': hapticsEnabled,
      'messageSoundsEnabled': messageSoundsEnabled,
      'distanceUnit': distanceUnit,
      'defaultPlateCountry': defaultPlateCountry,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppPreferenceSettings copyWith({
    String? languageCode,
    String? themeMode,
    bool? hapticsEnabled,
    bool? messageSoundsEnabled,
    String? distanceUnit,
    String? defaultPlateCountry,
  }) {
    return AppPreferenceSettings(
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      messageSoundsEnabled: messageSoundsEnabled ?? this.messageSoundsEnabled,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      defaultPlateCountry: defaultPlateCountry ?? this.defaultPlateCountry,
    );
  }
}

class UserSettingsBundle {
  const UserSettingsBundle({
    this.visibility = const VisibilitySettings(),
    this.contactFilters = const ContactFilterSettings(),
    this.chatPrivacy = const ChatPrivacySettings(),
    this.storyPrivacy = const StoryPrivacySettings(),
    this.appPreferences = const AppPreferenceSettings(),
  });

  final VisibilitySettings visibility;
  final ContactFilterSettings contactFilters;
  final ChatPrivacySettings chatPrivacy;
  final StoryPrivacySettings storyPrivacy;
  final AppPreferenceSettings appPreferences;
}

class UserSettingsRepository {
  UserSettingsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<UserSettingsBundle> load(String userId) async {
    final snapshots = await Future.wait([
      _document(userId, 'visibility').get(),
      _document(userId, 'contact_filters').get(),
      _document(userId, 'chat_privacy').get(),
      _document(userId, 'story_privacy').get(),
      _document(userId, 'app_preferences').get(),
    ]);

    return UserSettingsBundle(
      visibility: VisibilitySettings.fromMap(snapshots[0].data()),
      contactFilters: ContactFilterSettings.fromMap(snapshots[1].data()),
      chatPrivacy: ChatPrivacySettings.fromMap(snapshots[2].data()),
      storyPrivacy: StoryPrivacySettings.fromMap(snapshots[3].data()),
      appPreferences: AppPreferenceSettings.fromMap(snapshots[4].data()),
    );
  }

  Future<void> saveVisibility(String userId, VisibilitySettings settings) {
    return _save(userId, 'visibility', settings.toFirestore(userId: userId));
  }

  Future<void> saveContactFilters(
    String userId,
    ContactFilterSettings settings,
  ) {
    return _save(
      userId,
      'contact_filters',
      settings.toFirestore(userId: userId),
    );
  }

  Future<void> saveChatPrivacy(String userId, ChatPrivacySettings settings) {
    return _save(userId, 'chat_privacy', settings.toFirestore(userId: userId));
  }

  Future<void> saveStoryPrivacy(String userId, StoryPrivacySettings settings) {
    return _save(userId, 'story_privacy', settings.toFirestore(userId: userId));
  }

  Future<void> saveAppPreferences(
    String userId,
    AppPreferenceSettings settings,
  ) {
    return _save(
      userId,
      'app_preferences',
      settings.toFirestore(userId: userId),
    );
  }

  Future<void> _save(
    String userId,
    String settingsId,
    Map<String, dynamic> data,
  ) {
    return _document(userId, settingsId).set(data, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _document(
    String userId,
    String settingsId,
  ) {
    return _firestore.doc(
      '${CaRismaFirestorePaths.user(userId)}/'
      '${CaRismaFirestoreCollections.settings}/$settingsId',
    );
  }
}

class AccountSecurityActivity {
  const AccountSecurityActivity({
    required this.id,
    required this.eventType,
    required this.occurredAt,
    required this.platform,
    required this.status,
  });

  final String id;
  final String eventType;
  final DateTime occurredAt;
  final String platform;
  final String status;

  factory AccountSecurityActivity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final occurredAt = data['occurredAt'];
    return AccountSecurityActivity(
      id: snapshot.id,
      eventType: data['eventType'] as String? ?? 'unknown',
      occurredAt: occurredAt is Timestamp
          ? occurredAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      platform: data['platform'] as String? ?? 'unknown',
      status: data['status'] as String? ?? 'unknown',
    );
  }
}

class AccountSecurityRepository {
  AccountSecurityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AccountSecurityActivity>> watchActivities(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<List<AccountSecurityActivity>>.value(
        const <AccountSecurityActivity>[],
      );
    }

    return _firestore
        .collection(
          '${CaRismaFirestorePaths.user(normalizedUserId)}/'
          'security_activities',
        )
        .orderBy('occurredAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AccountSecurityActivity.fromFirestore)
              .toList(growable: false),
        );
  }
}
