import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'user_settings_repository.dart';

class AppRuntimePreferences extends ChangeNotifier {
  AppRuntimePreferences._();

  static final AppRuntimePreferences instance = AppRuntimePreferences._();
  static const MethodChannel _nativeChannel = MethodChannel('plaqa/chat_tools');

  AppPreferenceSettings _settings = const AppPreferenceSettings();

  AppPreferenceSettings get settings => _settings;
  bool get hapticsEnabled => _settings.hapticsEnabled;
  bool get messageSoundsEnabled => _settings.messageSoundsEnabled;

  void apply(AppPreferenceSettings settings) {
    if (_hasSameValues(_settings, settings)) return;
    _settings = settings;
    notifyListeners();
  }

  bool _hasSameValues(
    AppPreferenceSettings current,
    AppPreferenceSettings next,
  ) {
    return current.languageCode == next.languageCode &&
        current.themeMode == next.themeMode &&
        current.hapticsEnabled == next.hapticsEnabled &&
        current.messageSoundsEnabled == next.messageSoundsEnabled &&
        current.distanceUnit == next.distanceUnit &&
        current.defaultPlateCountry == next.defaultPlateCountry;
  }

  Future<void> selectionClick() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> lightImpact() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> mediumImpact() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> playMessageSound() async {
    if (!messageSoundsEnabled) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeChannel.invokeMethod<bool>('playMessageSound');
      } on PlatformException {
        // A missing native sound should never interrupt an active chat.
      } on MissingPluginException {
        // Hot reload can temporarily keep an older Android channel alive.
      }
      return;
    }

    await SystemSound.play(SystemSoundType.alert);
  }
}
