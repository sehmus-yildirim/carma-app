import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Einstellungen',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Benachrichtigungen'),
                subtitle: const Text('Push-Einstellungen folgen später.'),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Datenschutz'),
                subtitle: const Text('Privatsphäre und Sichtbarkeit verwalten.'),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Rechtliches'),
                subtitle: const Text('AGB und Datenschutzerklärung.'),
                onTap: () {},
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
            ),
          ],
        ),
      ),
    );
  }
}