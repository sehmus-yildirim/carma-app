import 'dart:ui';

import 'package:flutter/material.dart';

const Color _privacyCard = Color(0x1AFFFFFF);
const Color _privacyBorder = Color(0x33FFFFFF);

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Datenschutz'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const _LegalBackground(),
          SafeArea(
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: const _LegalGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Datenschutzerklärung',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Stand: Entwurf / Entwicklungsphase',
                            style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 24),
                          _PrivacySection(
                            title: '1. Verantwortlicher',
                            body:
                            'Diese Datenschutzerklärung informiert darüber, welche personenbezogenen Daten im Rahmen der Nutzung der Carma App verarbeitet werden. Die finalen Angaben zum Verantwortlichen ergänzen wir vor dem Release vollständig.',
                          ),
                          _PrivacySection(
                            title: '2. Welche Daten verarbeitet werden',
                            body:
                            'Je nach Nutzung der App können u. a. folgende Daten verarbeitet werden: E-Mail-Adresse, Authentifizierungsdaten, Profildaten, optionale Fahrzeugdaten, Nachrichteninhalte, Meldedaten sowie technische Nutzungsdaten.',
                          ),
                          _PrivacySection(
                            title: '3. Zweck der Verarbeitung',
                            body:
                            'Die Datenverarbeitung erfolgt, um die Nutzeranmeldung, die Profilerstellung, Kontaktanfragen, Chats, Meldungen, Sicherheit, Missbrauchsschutz und den technischen Betrieb der App zu ermöglichen.',
                          ),
                          _PrivacySection(
                            title: '4. Firebase und technische Dienstleister',
                            body:
                            'Carma verwendet Firebase-Dienste wie Firebase Auth und Cloud Firestore. Später können weitere Dienste wie Storage, Cloud Messaging, Analytics und Crashlytics hinzukommen. Dabei werden Daten im erforderlichen Umfang verarbeitet.',
                          ),
                          _PrivacySection(
                            title: '5. Sichtbarkeit von Daten',
                            body:
                            'Private Kontodaten und öffentliche Profildaten sollen getrennt gespeichert werden. Nicht alle Profildaten sind öffentlich sichtbar. Der Zugriff wird durch Security Rules und App-Logik eingeschränkt.',
                          ),
                          _PrivacySection(
                            title: '6. Speicherdauer',
                            body:
                            'Daten werden nur so lange gespeichert, wie es für die Bereitstellung der Funktionen, zur Sicherheit oder aufgrund gesetzlicher Pflichten erforderlich ist. Details werden vor dem Release finalisiert.',
                          ),
                          _PrivacySection(
                            title: '7. Rechte der Nutzer',
                            body:
                            'Nutzer haben grundsätzlich Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung, Widerspruch und Datenübertragbarkeit im Rahmen der geltenden gesetzlichen Bestimmungen.',
                          ),
                          _PrivacySection(
                            title: '8. Spätere dynamische Aktualisierung',
                            body:
                            'Später werden wir AGB und Datenschutz zentral hosten oder aus einer zentralen Quelle laden. Dann werden Änderungen automatisch in der App sichtbar, ohne dass du den kompletten Screen neu bauen musst.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalBackground extends StatelessWidget {
  const _LegalBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B0D12),
                Color(0xFF080A0F),
                Color(0xFF05070B),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.34),
        ),
      ],
    );
  }
}

class _LegalGlassCard extends StatelessWidget {
  const _LegalGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _privacyCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _privacyBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}