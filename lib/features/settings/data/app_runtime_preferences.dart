import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_settings_repository.dart';

class AppRuntimePreferences extends ChangeNotifier {
  AppRuntimePreferences._();

  static final AppRuntimePreferences instance = AppRuntimePreferences._();
  static const MethodChannel _nativeChannel = MethodChannel('plaqa/chat_tools');
  static const String _themeModeKey = 'plaqa.theme_mode';

  AppPreferenceSettings _settings = const AppPreferenceSettings();

  AppPreferenceSettings get settings => _settings;
  bool get hapticsEnabled => _settings.hapticsEnabled;
  bool get messageSoundsEnabled => _settings.messageSoundsEnabled;
  ThemeMode get materialThemeMode => switch (_settings.themeMode) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final themeMode = _normalizeThemeMode(preferences.getString(_themeModeKey));
    _settings = _settings.copyWith(themeMode: themeMode);
  }

  void apply(AppPreferenceSettings settings) {
    final normalized = settings.copyWith(
      themeMode: _normalizeThemeMode(settings.themeMode),
    );
    if (_hasSameValues(_settings, normalized)) return;
    _settings = normalized;
    notifyListeners();
  }

  Future<void> applyAndPersist(AppPreferenceSettings settings) async {
    apply(settings);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, _settings.themeMode);
  }

  static String _normalizeThemeMode(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'light' => 'light',
      'system' => 'system',
      _ => 'dark',
    };
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
