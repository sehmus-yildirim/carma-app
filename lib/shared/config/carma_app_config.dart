class CarmaAppConfig {
  const CarmaAppConfig._();

  static const String appName = 'Carma';
  static const String appVersion = '1.0.0';
  static const String buildLabel = 'Lokaler MVP';

  static const String localUserId = 'local-user';

  static const bool useMockPlateSearch = true;
  static const int defaultSearchRadiusKm = 5;

  static const String firebaseRegion = 'europe-west3';

  static String get appVersionLabel {
    return '$appName · Version $appVersion · $buildLabel';
  }
}