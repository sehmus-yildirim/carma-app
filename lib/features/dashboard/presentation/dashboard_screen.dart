import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _DashboardContent(),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const _HomeHeader(),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Kontaktanfrage starten',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Gib später ein Kennzeichen ein, um eine Anfrage an einen registrierten Fahrzeughalter zu senden. Private Daten bleiben geschützt, bis die Anfrage angenommen wird.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              const _PlatePreviewCard(),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: null,
                icon: Icon(Icons.lock_outline),
                label: Text('Kontaktanfrage bald verfügbar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          opacity: 0.08,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.privacy_tip_outlined, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Carma zeigt keine persönlichen Daten öffentlich an. Erst nach Annahme einer Anfrage entsteht ein Chat.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Schnellzugriff',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        const _QuickActionsGrid(),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/carma_logo.png',
            width: 54,
            height: 54,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Willkommen bei',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Text(
                'Carma',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 18,
          opacity: 0.08,
          child: const Icon(Icons.notifications_none, color: Colors.white),
        ),
      ],
    );
  }
}

class _PlatePreviewCard extends StatelessWidget {
  const _PlatePreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: const Center(
              child: Text(
                'D',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Kennzeichen eingeben',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 18,
            color: Colors.white.withValues(alpha: 0.54),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.chat_bubble_outline,
                title: 'Chats',
                subtitle: 'Nachrichten',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.report_outlined,
                title: 'Melden',
                subtitle: 'Hinweise senden',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.person_outline,
                title: 'Profil',
                subtitle: 'Daten pflegen',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.settings_outlined,
                title: 'Einstellungen',
                subtitle: 'Privatsphäre',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}