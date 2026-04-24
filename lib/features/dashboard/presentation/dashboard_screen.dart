import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carma'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Home',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sende eine Kontaktanfrage, wenn du eine Person über ein registriertes Fahrzeug erreichen möchtest.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kontaktanfrage',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Die Kennzeichenfunktion wird später so gebaut, dass keine privaten Daten öffentlich angezeigt werden.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Kontaktanfrage starten'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Datenschutz zuerst'),
                subtitle: const Text(
                  'Chats entstehen erst nach Annahme einer Anfrage.',
                ),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}