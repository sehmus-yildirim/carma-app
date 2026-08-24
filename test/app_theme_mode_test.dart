import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/settings/data/app_runtime_preferences.dart';
import 'package:plaqa/features/settings/data/user_settings_repository.dart';
import 'package:plaqa/features/settings/presentation/privacy_comfort_settings_screens.dart';
import 'package:plaqa/shared/theme/carisma_design_tokens.dart';
import 'package:plaqa/shared/theme/carisma_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme mode is locked to dark and legacy values are reset', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'plaqa.theme_mode': 'light',
    });

    await AppRuntimePreferences.instance.initialize();
    expect(AppRuntimePreferences.instance.materialThemeMode, ThemeMode.dark);
    expect(AppRuntimePreferences.instance.settings.themeMode, 'dark');

    final systemSettings = AppRuntimePreferences.instance.settings.copyWith(
      themeMode: 'system',
    );
    await AppRuntimePreferences.instance.applyAndPersist(systemSettings);

    expect(AppRuntimePreferences.instance.materialThemeMode, ThemeMode.dark);
    expect(AppRuntimePreferences.instance.settings.themeMode, 'dark');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('plaqa.theme_mode'), 'dark');
  });

  testWidgets('app comfort exposes design as a future feature', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppComfortSettingsScreen(
          initialSettings: const AppPreferenceSettings(themeMode: 'light'),
          onChanged: (_, _) async => true,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Design'), 500);
    expect(find.text('Design'), findsOneWidget);
    expect(
      find.text('Weitere Designs erscheinen in einer späteren Version.'),
      findsOneWidget,
    );
    expect(find.text('Hell'), findsNothing);
    expect(find.text('System'), findsNothing);
    expect(find.text('Dunkel'), findsNothing);
  });

  test('Firestore preference accepts light and rejects unknown modes', () {
    expect(
      AppPreferenceSettings.fromMap(const <String, dynamic>{
        'themeMode': 'light',
      }).themeMode,
      'light',
    );
    expect(
      AppPreferenceSettings.fromMap(const <String, dynamic>{
        'themeMode': 'sepia',
      }).themeMode,
      'dark',
    );
  });

  test('light and dark themes keep distinct accessible surfaces', () {
    final light = CaRismaTheme.lightTheme();
    final dark = CaRismaTheme.darkTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));

    PlaqaAdaptiveColor.useBrightness(Brightness.light);
    expect(
      CaRismaDesignTokens.textPrimary.toARGB32(),
      const Color(0xFF101828).toARGB32(),
    );
    PlaqaAdaptiveColor.useBrightness(Brightness.dark);
    expect(
      CaRismaDesignTokens.textPrimary.toARGB32(),
      const Color(0xFFF4F7FB).toARGB32(),
    );
  });

  test('core text and accent combinations meet readable contrast', () {
    expect(
      _contrastRatio(const Color(0xFF101828), const Color(0xFFF7F9FC)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(const Color(0xFFF4F7FB), const Color(0xFF05070D)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        CaRismaDesignTokens.onAccent,
        CaRismaDesignTokens.bluePrimary,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrastRatio(Color first, Color second) {
  final firstIsLighter = first.computeLuminance() >= second.computeLuminance();
  final lighter = firstIsLighter ? first : second;
  final darker = firstIsLighter ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
