import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate_screen.dart';
import '../shared/theme/carisma_theme.dart';

class CaRismaApp extends StatelessWidget {
  const CaRismaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'plaqa',
      debugShowCheckedModeBanner: false,
      theme: CaRismaTheme.darkTheme(),
      scrollBehavior: const _CaRismaScrollBehavior(),
      home: const AuthGateScreen(),
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
