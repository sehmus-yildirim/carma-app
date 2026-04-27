import 'package:flutter/material.dart';

import 'features/auth/presentation/auth_flow_screen.dart';

void main() {
  runApp(const CarmaAuthPreviewApp());
}

class CarmaAuthPreviewApp extends StatelessWidget {
  const CarmaAuthPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carma Auth Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
      ),
      home: const AuthFlowScreen(),
    );
  }
}