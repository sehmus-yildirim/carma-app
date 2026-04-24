import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';

class CarmaApp extends StatelessWidget {
  const CarmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}