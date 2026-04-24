import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CarmaApp());
}

class CarmaApp extends StatelessWidget {
  const CarmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carma',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Carma'),
        ),
        body: const Center(
          child: Text(
            'Carma Firebase connected',
            style: TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}