import 'package:flutter/services.dart';

import 'user_settings_repository.dart';

class AppRuntimePreferences {
  AppRuntimePreferences._();

  static final AppRuntimePreferences instance = AppRuntimePreferences._();

  AppPreferenceSettings _settings = const AppPreferenceSettings();

  AppPreferenceSettings get settings => _settings;
  bool get hapticsEnabled => _settings.hapticsEnabled;
  bool get messageSoundsEnabled => _settings.messageSoundsEnabled;

  void apply(AppPreferenceSettings settings) {
    _settings = settings;
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
    await SystemSound.play(SystemSoundType.alert);
  }
}
