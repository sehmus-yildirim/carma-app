import 'package:flutter/material.dart';

import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/glass_card.dart';

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
      body: CaRismaBackground(
        child: SafeArea(
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: const GlassCard(
                    padding: EdgeInsets.all(24),
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
                              'Diese AGB regeln die Nutzung der CaRisma App. CaRisma ist eine kontaktorientierte App im Fahrzeugkontext. Nutzer können sich registrieren, Profile pflegen, Kontaktanfragen senden, chatten und Meldungen übermitteln.',
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
                              'Nutzer sind für die von ihnen versendeten Nachrichten, Meldungen und Inhalte selbst verantwortlich. CaRisma behält sich vor, rechtswidrige oder missbräuchliche Inhalte zu prüfen, zu sperren oder zu entfernen.',
                        ),
                        _LegalSection(
                          title: '5. Meldesystem',
                          body:
                              'Das Meldesystem dient der anonymen Übermittlung fahrzeugbezogener Hinweise. Es darf nicht für Beleidigungen, Falschmeldungen oder rechtswidrige Inhalte verwendet werden.',
                        ),
                        _LegalSection(
                          title: '6. Verfügbarkeit',
                          body:
                              'CaRisma bemüht sich um eine möglichst unterbrechungsfreie Verfügbarkeit der Dienste. Eine ständige und fehlerfreie Verfügbarkeit kann jedoch nicht garantiert werden.',
                        ),
                        _LegalSection(
                          title: '7. Sperrung und Kündigung',
                          body:
                              'CaRisma kann Nutzerkonten bei Verstößen gegen diese AGB oder bei Verdacht auf Missbrauch vorübergehend einschränken oder dauerhaft sperren.',
                        ),
                        _LegalSection(
                          title: '8. Haftung',
                          body:
                              'CaRisma haftet im gesetzlichen Rahmen. Für von Nutzern bereitgestellte Inhalte oder Kommunikation zwischen Nutzern übernimmt CaRisma keine Verantwortung.',
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
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

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
