import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate.dart';
import '../shared/theme/carma_theme.dart';

class CarmaApp extends StatelessWidget {
  const CarmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carma',
      debugShowCheckedModeBanner: false,
      theme: CarmaTheme.darkTheme(),
      home: const AuthGate(),
    );
  }
}