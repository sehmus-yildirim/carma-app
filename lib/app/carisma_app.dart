import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/presentation/auth_gate_screen.dart';
import '../features/settings/data/app_runtime_preferences.dart';
import '../shared/theme/carisma_design_tokens.dart';
import '../shared/theme/carisma_theme.dart';

class CaRismaApp extends StatelessWidget {
  const CaRismaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppRuntimePreferences.instance,
      builder: (context, _) {
        PlaqaAdaptiveColor.useBrightness(Brightness.dark);
        return MaterialApp(
          title: 'plaqa',
          debugShowCheckedModeBanner: false,
          theme: CaRismaTheme.darkTheme(),
          darkTheme: CaRismaTheme.darkTheme(),
          themeMode: ThemeMode.dark,
          scrollBehavior: const _CaRismaScrollBehavior(),
          builder: (context, child) {
            PlaqaAdaptiveColor.useBrightness(Brightness.dark);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGateScreen(),
        );
      },
    );
  }
}

class _CaRismaScrollBehavior extends MaterialScrollBehavior {
  const _CaRismaScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
