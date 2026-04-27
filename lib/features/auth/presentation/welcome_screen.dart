import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_primary_button.dart';
import '../../../shared/widgets/carma_secondary_button.dart';
import '../../../shared/widgets/glass_card.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    this.onLoginPressed,
    this.onRegisterPressed,
  });

  final VoidCallback? onLoginPressed;
  final VoidCallback? onRegisterPressed;

  void _showComingSoonMessage(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label verbinden wir im nächsten Schritt.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28 + keyboardInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CarmaPageHeader(
                icon: Icons.directions_car_filled_rounded,
                title: 'Willkommen',
              ),
              const SizedBox(height: 22),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CarmaBlueIconBox(
                      icon: Icons.shield_rounded,
                      size: 58,
                      iconSize: 30,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Carma verbindet Fahrzeughalter sicher über Kennzeichen.',
                      style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Suchen, Hinweise senden, Kontaktanfragen verwalten und dein Fahrzeug verifizieren – alles in einem geschützten Flow.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _WelcomeNoticeCard(),
              const SizedBox(height: 18),
              const _WelcomeBenefitCard(
                icon: Icons.search_rounded,
                title: 'Kennzeichen suchen',
                description:
                'Finde registrierte Nutzer in deiner Nähe über ein vollständiges Kennzeichen.',
              ),
              const SizedBox(height: 10),
              const _WelcomeBenefitCard(
                icon: Icons.report_outlined,
                title: 'Anonyme Hinweise',
                description:
                'Sende sachliche Hinweise an Fahrzeughalter, ohne deine Identität offenzulegen.',
              ),
              const SizedBox(height: 10),
              const _WelcomeBenefitCard(
                icon: Icons.lock_outline_rounded,
                title: 'Verifizierte Profile',
                description:
                'Name, Fahrzeug und Dokumente werden später geschützt geprüft.',
              ),
              const SizedBox(height: 22),
              CarmaPrimaryButton(
                label: 'Einloggen',
                icon: Icons.login_rounded,
                onPressed: onLoginPressed ??
                        () => _showComingSoonMessage(context, 'Login'),
              ),
              const SizedBox(height: 12),
              CarmaSecondaryButton(
                label: 'Konto erstellen',
                icon: Icons.person_add_alt_1_rounded,
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                onPressed: onRegisterPressed ??
                        () => _showComingSoonMessage(context, 'Registrierung'),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Noch ohne Firebase verbunden – aktuell bauen wir den Auth- und Onboarding-Flow als Layout auf.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeNoticeCard extends StatelessWidget {
  const _WelcomeNoticeCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CarmaBlueIconBox(
            icon: Icons.verified_user_outlined,
            size: 42,
            iconSize: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Für volle Nutzung wird dein Profil später mit Fahrzeug und Dokumenten verifiziert.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBenefitCard extends StatelessWidget {
  const _WelcomeBenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: icon,
            size: 46,
            iconSize: 23,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}