import 'package:flutter/foundation.dart';

class CaRismaAppConfig {
  const CaRismaAppConfig._();

  static const String appName = 'plaqa';
  static const String appVersion = '1.0.0';
  static const String buildLabel = String.fromEnvironment(
    'PLAQA_BUILD_LABEL',
    defaultValue: kReleaseMode ? 'Release' : 'Lokaler MVP',
  );

  static const String websiteUrl = 'https://plaqa.de';
  static const String authActionUrl = 'https://auth.plaqa.de/auth/action';
  static const String generalEmail = 'info@plaqa.de';
  static const String noReplyEmail = 'no-reply@plaqa.de';
  static const String supportEmail = 'support@plaqa.de';
  static const String privacyEmail = 'privacy@plaqa.de';
  static const String partnersEmail = 'partners@plaqa.de';

  static const String localUserId = 'local-user';

  static const bool useMockPlateSearch = kDebugMode;
  static const int defaultSearchRadiusKm = 5;

  static const bool storeScreenshotMode =
      kDebugMode && bool.fromEnvironment('PLAQA_STORE_SCREENSHOTS');
  static const String storeDemoDisplayName = 'Plaqa Nutzer';
  static const String storeDemoShortName = 'Plaqa N.';
  static const String storeDemoPlate = 'HH-PQ 2026';

  // Launch setting: keep the quota implementation available, but do not
  // restrict contact requests while the community is being established.
  static const bool enforceMonthlyContactRequestLimit = false;

  static const String firebaseRegion = 'europe-west3';

  static String get appVersionLabel {
    return '$appName · Version $appVersion · $buildLabel';
  }
}
