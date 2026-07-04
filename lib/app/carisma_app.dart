import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate_screen.dart';
import '../shared/theme/carisma_theme.dart';

class CaRismaApp extends StatelessWidget {
  const CaRismaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaRisma',
      debugShowCheckedModeBanner: false,
      theme: CaRismaTheme.darkTheme(),
      home: const AuthGateScreen(),
    );
  }
}
