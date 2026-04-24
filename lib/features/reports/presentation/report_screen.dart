import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Melden'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Anonyme Meldung',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sende später einen neutralen Hinweis, z. B. wenn ein Fenster offen ist, Licht an ist oder eine Einfahrt blockiert wird.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Hinweis senden'),
                subtitle: const Text('Diese Funktion wird später sicher umgesetzt.'),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}