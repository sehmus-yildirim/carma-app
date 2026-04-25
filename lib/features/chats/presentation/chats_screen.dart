import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/glass_card.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _ChatsContent(),
        ),
      ),
    );
  }
}

class _ChatsContent extends StatelessWidget {
  const _ChatsContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const Text(
          'Chats',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hier erscheinen später Kontaktanfragen und angenommene Gespräche.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        const _RequestsCard(),
        const SizedBox(height: 16),
        const _ChatsEmptyState(),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          opacity: 0.08,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Ein Chat wird erst geöffnet, wenn eine Kontaktanfrage angenommen wurde.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestsCard extends StatelessWidget {
  const _RequestsCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontaktanfragen',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Noch keine offenen Anfragen',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
            child: Text(
              'Wenn dich jemand über ein registriertes Fahrzeug kontaktieren möchte, kannst du die Anfrage hier annehmen oder ablehnen.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatsEmptyState extends StatelessWidget {
  const _ChatsEmptyState();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Noch keine Chats',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sobald eine Anfrage angenommen wurde, erscheint der Chat hier.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Neue Unterhaltung bald verfügbar'),
          ),
        ],
      ),
    );
  }
}