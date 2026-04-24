import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/user_profile_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UserProfileRepository _userProfileRepository = UserProfileRepository();

  bool _isSyncingProfile = true;
  String? _profileErrorMessage;

  @override
  void initState() {
    super.initState();
    _ensureUserProfile();
  }

  Future<void> _ensureUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isSyncingProfile = false;
      });
      return;
    }

    try {
      await _userProfileRepository.createProfileForUser(user);

      if (!mounted) return;

      setState(() {
        _isSyncingProfile = false;
        _profileErrorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSyncingProfile = false;
        _profileErrorMessage =
        'Profil konnte nicht mit Firestore synchronisiert werden.';
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Unbekannter Nutzer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carma'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Ausloggen',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Du bist eingeloggt.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              if (_isSyncingProfile)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Profil wird synchronisiert...'),
                  ],
                )
              else if (_profileErrorMessage != null)
                Text(
                  _profileErrorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Text(
                  'Profil ist mit Firestore verbunden.',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}