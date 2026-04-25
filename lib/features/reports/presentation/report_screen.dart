import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _ReportContent(),
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const Text(
          'Melden',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sende später einen neutralen Hinweis an einen registrierten Fahrzeughalter, ohne deine Identität öffentlich sichtbar zu machen.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        const _ReportInfoCard(),
        const SizedBox(height: 16),
        const _ReportCategoriesCard(),
        const SizedBox(height: 16),
        const _ReportDraftCard(),
      ],
    );
  }
}

class _ReportInfoCard extends StatelessWidget {
  const _ReportInfoCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diskret und sicher',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Meldungen sollen helfen, ohne Konflikte zu erzeugen. Carma zeigt keine privaten Absenderdaten öffentlich an.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.4,
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

class _ReportCategoriesCard extends StatelessWidget {
  const _ReportCategoriesCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hinweis auswählen',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Diese Optionen werden später mit echter Sendelogik verbunden.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          const _ReportCategoryTile(
            icon: Icons.garage_outlined,
            title: 'Einfahrt blockiert',
            subtitle: 'Fahrzeug steht ungünstig oder blockiert eine Zufahrt.',
          ),
          const SizedBox(height: 10),
          const _ReportCategoryTile(
            icon: Icons.window_outlined,
            title: 'Fenster offen',
            subtitle: 'Ein Fenster oder Schiebedach scheint offen zu sein.',
          ),
          const SizedBox(height: 10),
          const _ReportCategoryTile(
            icon: Icons.lightbulb_outline,
            title: 'Licht angelassen',
            subtitle: 'Licht ist an und könnte die Batterie entladen.',
          ),
          const SizedBox(height: 10),
          const _ReportCategoryTile(
            icon: Icons.more_horiz,
            title: 'Sonstiger Hinweis',
            subtitle: 'Ein neutraler Hinweis, der nicht in die Kategorien passt.',
          ),
        ],
      ),
    );
  }
}

class _ReportCategoryTile extends StatelessWidget {
  const _ReportCategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.13),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            height: 1.35,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        onTap: () {},
      ),
    );
  }
}

class _ReportDraftCard extends StatelessWidget {
  const _ReportDraftCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Neue Meldung',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Kennzeichen',
              hintText: 'z. B. B AB 1234',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Hinweis',
              hintText: 'Kurze neutrale Beschreibung',
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Meldung bald verfügbar'),
          ),
        ],
      ),
    );
  }
}