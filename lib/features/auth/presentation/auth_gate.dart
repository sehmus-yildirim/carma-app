import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carma_models.dart';
import '../../home/presentation/app_shell.dart';
import '../domain/registration_legal_consent_builder.dart';
import 'auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  AppUserState _buildUserState(User user) {
    final legalConsents = RegistrationLegalConsentBuilder.buildLocalConsents(
      userId: user.uid,
    );

    return AppUserState.localRegistered(
      userId: user.uid,
      legalConsents: legalConsents,
    ).markOnboardingCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          return AppShell(
            userState: _buildUserState(user),
            onLogout: _signOut,
          );
        }

        return const AuthScreen();
      },
    );
  }
}