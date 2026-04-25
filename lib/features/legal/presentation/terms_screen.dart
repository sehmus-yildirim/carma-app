import 'dart:ui';

import 'package:flutter/material.dart';

const Color _termsCard = Color(0x1AFFFFFF);
const Color _termsBorder = Color(0x33FFFFFF);

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AGB'),
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
                            'Allgemeine Geschäftsbedingungen',
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
                          _LegalSection(
                            title: '1. Geltungsbereich',
                            body:
                            'Diese AGB regeln die Nutzung der Carma App. Carma ist eine kontaktorientierte App im Fahrzeugkontext. Nutzer können sich registrieren, Profile pflegen, Kontaktanfragen senden, chatten und Meldungen übermitteln.',
                          ),
                          _LegalSection(
                            title: '2. Nutzerkonto',
                            body:
                            'Für die Nutzung bestimmter Funktionen ist ein registriertes Nutzerkonto erforderlich. Nutzer sind verpflichtet, bei der Registrierung wahrheitsgemäße Angaben zu machen und ihre Zugangsdaten sicher aufzubewahren.',
                          ),
                          _LegalSection(
                            title: '3. Zulässige Nutzung',
                            body:
                            'Die App darf nur im Rahmen der geltenden Gesetze und dieser AGB genutzt werden. Missbrauch, Belästigung, Spam, Täuschung, Hassrede, Drohungen oder die unbefugte Nutzung fremder Daten sind untersagt.',
                          ),
                          _LegalSection(
                            title: '4. Inhalte und Kommunikation',
                            body:
                            'Nutzer sind für die von ihnen versendeten Nachrichten, Meldungen und Inhalte selbst verantwortlich. Carma behält sich vor, rechtswidrige oder missbräuchliche Inhalte zu prüfen, zu sperren oder zu entfernen.',
                          ),
                          _LegalSection(
                            title: '5. Meldesystem',
                            body:
                            'Das Meldesystem dient der anonymen Übermittlung fahrzeugbezogener Hinweise. Es darf nicht für Beleidigungen, Falschmeldungen oder rechtswidrige Inhalte verwendet werden.',
                          ),
                          _LegalSection(
                            title: '6. Verfügbarkeit',
                            body:
                            'Carma bemüht sich um eine möglichst unterbrechungsfreie Verfügbarkeit der Dienste. Eine ständige und fehlerfreie Verfügbarkeit kann jedoch nicht garantiert werden.',
                          ),
                          _LegalSection(
                            title: '7. Sperrung und Kündigung',
                            body:
                            'Carma kann Nutzerkonten bei Verstößen gegen diese AGB oder bei Verdacht auf Missbrauch vorübergehend einschränken oder dauerhaft sperren.',
                          ),
                          _LegalSection(
                            title: '8. Haftung',
                            body:
                            'Carma haftet im gesetzlichen Rahmen. Für von Nutzern bereitgestellte Inhalte oder Kommunikation zwischen Nutzern übernimmt Carma keine Verantwortung.',
                          ),
                          _LegalSection(
                            title: '9. Änderungen',
                            body:
                            'Diese AGB können künftig angepasst werden. Später werden wir die finalen AGB zentral hosten oder dynamisch laden, damit Änderungen automatisch in der App sichtbar sind.',
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
            color: _termsCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _termsBorder),
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

class _LegalSection extends StatelessWidget {
  const _LegalSection({
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