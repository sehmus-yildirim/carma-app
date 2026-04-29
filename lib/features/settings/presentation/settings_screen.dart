import 'package:flutter/material.dart';

import '../../../shared/legal/legal_versions.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/carma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onLogout,
  });

  final VoidCallback onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyContactRequests = true;
  bool _notifyChats = true;
  bool _notifyReports = true;
  bool _notifyVerification = true;

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title verbinden wir später.'),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Abmelden?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Du wirst lokal abgemeldet und kommst zurück zum Login. Firebase-Logout verbinden wir später.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Abbrechen',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Abmelden',
                style: TextStyle(
                  color: Color(0xFFFF8A8A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    Navigator.of(context).pop();
    widget.onLogout();
  }

  void _openDetailPage({
    required IconData icon,
    required String title,
    required String description,
    required List<_SettingsDetailItem> items,
    ValueChanged<String>? onItemTap,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsDetailScreen(
          icon: icon,
          title: title,
          description: description,
          items: items,
          onItemTap: onItemTap ?? _showComingSoon,
        ),
      ),
    );
  }

  void _openLegalContent(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LegalContentScreen(
          content: _LegalContent.forTitle(title),
        ),
      ),
    );
  }

  void _openAccountSecurity() {
    _openDetailPage(
      icon: Icons.admin_panel_settings_rounded,
      title: 'Konto & Sicherheit',
      description:
      'Verwalte Login, Abmeldung und sicherheitsrelevante Kontoaktionen.',
      items: const [
        _SettingsDetailItem(
          icon: Icons.mail_outline_rounded,
          title: 'E-Mail / Login',
          description: 'Login-Daten anzeigen oder später ändern.',
        ),
        _SettingsDetailItem(
          icon: Icons.lock_outline_rounded,
          title: 'Passwort ändern',
          description: 'Passwortänderung wird später mit Firebase verbunden.',
        ),
        _SettingsDetailItem(
          icon: Icons.phonelink_lock_rounded,
          title: 'Aktive Geräte',
          description: 'Später siehst du hier angemeldete Geräte.',
        ),
        _SettingsDetailItem(
          icon: Icons.logout_rounded,
          title: 'Abmelden',
          description: 'Sicher vom aktuellen Gerät abmelden.',
          isDestructive: true,
        ),
        _SettingsDetailItem(
          icon: Icons.delete_forever_rounded,
          title: 'Konto löschen',
          description:
          'Löscht später Konto, Profil, Fahrzeugdaten und Verifizierungsdaten.',
          isDestructive: true,
        ),
      ],
      onItemTap: (title) {
        if (title == 'Abmelden') {
          _confirmLogout();
          return;
        }

        _showComingSoon(title);
      },
    );
  }

  void _openPrivacy() {
    _openDetailPage(
      icon: Icons.privacy_tip_rounded,
      title: 'Datenschutz',
      description:
      'Kontrolliere deine Daten, Einwilligungen und Datenschutzrechte.',
      items: const [
        _SettingsDetailItem(
          icon: Icons.file_download_outlined,
          title: 'Datenexport anfordern',
          description:
          'Fordere später eine Kopie deiner gespeicherten Daten an.',
        ),
        _SettingsDetailItem(
          icon: Icons.manage_accounts_outlined,
          title: 'Gespeicherte Daten einsehen',
          description: 'Übersicht über Konto-, Profil- und Fahrzeugdaten.',
        ),
        _SettingsDetailItem(
          icon: Icons.block_rounded,
          title: 'Blockierte Nutzer',
          description: 'Verwalte später blockierte Nutzer oder Kennzeichen.',
        ),
        _SettingsDetailItem(
          icon: Icons.fact_check_outlined,
          title: 'Einwilligungen verwalten',
          description: 'Datenschutz- und Kommunikationsfreigaben verwalten.',
        ),
      ],
    );
  }

  void _openSafety() {
    _openDetailPage(
      icon: Icons.shield_rounded,
      title: 'Sicherheit & Missbrauch',
      description:
      'Schutzfunktionen gegen falsche Meldungen, Belästigung und Missbrauch.',
      items: const [
        _SettingsDetailItem(
          icon: Icons.report_problem_outlined,
          title: 'Missbrauch melden',
          description: 'Melde falsche Anfragen, Belästigung oder Fake-Hinweise.',
        ),
        _SettingsDetailItem(
          icon: Icons.rule_rounded,
          title: 'Sicherheitsregeln',
          description: 'Regeln für Kontaktanfragen, Hinweise und Verhalten.',
        ),
        _SettingsDetailItem(
          icon: Icons.person_off_outlined,
          title: 'Nutzer blockieren',
          description: 'Blockierfunktion wird später mit Firebase verbunden.',
        ),
        _SettingsDetailItem(
          icon: Icons.gpp_maybe_outlined,
          title: 'Sperrprüfung',
          description:
          'Informationen zu Verwarnungen, Sperren und Missbrauchsfolgen.',
        ),
      ],
    );
  }

  void _openSupport() {
    _openDetailPage(
      icon: Icons.support_agent_rounded,
      title: 'Support',
      description: 'Hilfe, Feedback und Kontakt zum Carma-Support.',
      items: const [
        _SettingsDetailItem(
          icon: Icons.help_outline_rounded,
          title: 'Hilfe & FAQ',
          description: 'Antworten auf häufige Fragen.',
        ),
        _SettingsDetailItem(
          icon: Icons.bug_report_outlined,
          title: 'Problem melden',
          description: 'Melde technische Fehler oder Darstellungsprobleme.',
        ),
        _SettingsDetailItem(
          icon: Icons.verified_user_outlined,
          title: 'Verifizierungsproblem',
          description: 'Hilfe bei Ausweis, Führerschein oder Fahrzeugschein.',
        ),
        _SettingsDetailItem(
          icon: Icons.feedback_outlined,
          title: 'Feedback senden',
          description: 'Teile Verbesserungsvorschläge für Carma.',
        ),
      ],
    );
  }

  void _openLegal() {
    _openDetailPage(
      icon: Icons.description_rounded,
      title: 'Rechtliches',
      description: 'AGB, Datenschutz, Impressum, Lizenzen und App-Informationen.',
      items: const [
        _SettingsDetailItem(
          icon: Icons.article_outlined,
          title: 'AGB',
          description: 'Allgemeine Geschäftsbedingungen öffnen.',
        ),
        _SettingsDetailItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Datenschutzerklärung',
          description: 'Informationen zur Verarbeitung personenbezogener Daten.',
        ),
        _SettingsDetailItem(
          icon: Icons.business_rounded,
          title: 'Impressum',
          description: 'Anbieterkennzeichnung und Kontaktinformationen.',
        ),
        _SettingsDetailItem(
          icon: Icons.info_outline_rounded,
          title: 'Über Carma',
          description: 'App-Version, Zweck und Projektinformationen.',
        ),
        _SettingsDetailItem(
          icon: Icons.workspace_premium_outlined,
          title: 'Lizenzen',
          description: 'Open-Source-Lizenzen und verwendete Pakete.',
        ),
      ],
      onItemTap: _openLegalContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                112 + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CarmaPageHeader(
                      icon: Icons.settings_rounded,
                      title: 'Einstellungen',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Verwalte Konto, Datenschutz, Sicherheit und App-Informationen.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SettingsInfoCard(),
                    const SizedBox(height: 18),
                    const _SettingsGroupTitle(
                      title: 'Konto',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _SettingsOverviewCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Konto & Sicherheit',
                      description:
                      'Login, Passwort, Abmeldung und Konto löschen.',
                      onTap: _openAccountSecurity,
                    ),
                    const SizedBox(height: 18),
                    const _SettingsGroupTitle(
                      title: 'App',
                      icon: Icons.notifications_none_rounded,
                    ),
                    const SizedBox(height: 10),
                    _NotificationSettingsCard(
                      notifyContactRequests: _notifyContactRequests,
                      notifyChats: _notifyChats,
                      notifyReports: _notifyReports,
                      notifyVerification: _notifyVerification,
                      onContactRequestsChanged: (value) {
                        setState(() {
                          _notifyContactRequests = value;
                        });
                      },
                      onChatsChanged: (value) {
                        setState(() {
                          _notifyChats = value;
                        });
                      },
                      onReportsChanged: (value) {
                        setState(() {
                          _notifyReports = value;
                        });
                      },
                      onVerificationChanged: (value) {
                        setState(() {
                          _notifyVerification = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    const _SettingsGroupTitle(
                      title: 'Schutz & Daten',
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 10),
                    _SettingsOverviewCard(
                      icon: Icons.privacy_tip_rounded,
                      title: 'Datenschutz',
                      description:
                      'Datenexport, gespeicherte Daten und Blockierungen.',
                      onTap: _openPrivacy,
                    ),
                    const SizedBox(height: 14),
                    _SettingsOverviewCard(
                      icon: Icons.shield_rounded,
                      title: 'Sicherheit & Missbrauch',
                      description:
                      'Missbrauch melden, Regeln ansehen und Nutzer blockieren.',
                      onTap: _openSafety,
                    ),
                    const SizedBox(height: 18),
                    const _SettingsGroupTitle(
                      title: 'Hilfe & Rechtliches',
                      icon: Icons.help_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _SettingsOverviewCard(
                      icon: Icons.support_agent_rounded,
                      title: 'Support',
                      description:
                      'Hilfe, Problem melden, Verifizierungsproblem und Feedback.',
                      onTap: _openSupport,
                    ),
                    const SizedBox(height: 14),
                    _SettingsOverviewCard(
                      icon: Icons.description_rounded,
                      title: 'Rechtliches',
                      description:
                      'AGB, Datenschutz, Impressum, Lizenzen und Über Carma.',
                      onTap: _openLegal,
                    ),
                    const SizedBox(height: 18),
                    const _AppVersionCard(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsInfoCard extends StatelessWidget {
  const _SettingsInfoCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: Icons.verified_user_outlined,
            size: 44,
            iconSize: 23,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Carma schützt Fahrzeughalter, Kontaktanfragen und anonyme Hinweise. Sicherheits-, Datenschutz- und Missbrauchsfunktionen werden später serverseitig mit Firebase verbunden.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                height: 1.36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroupTitle extends StatelessWidget {
  const _SettingsGroupTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.72),
          size: 20,
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SettingsOverviewCard extends StatelessWidget {
  const _SettingsOverviewCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CarmaBlueIconBox(
                  icon: icon,
                  size: 50,
                  iconSize: 25,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w700,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({
    required this.notifyContactRequests,
    required this.notifyChats,
    required this.notifyReports,
    required this.notifyVerification,
    required this.onContactRequestsChanged,
    required this.onChatsChanged,
    required this.onReportsChanged,
    required this.onVerificationChanged,
  });

  final bool notifyContactRequests;
  final bool notifyChats;
  final bool notifyReports;
  final bool notifyVerification;

  final ValueChanged<bool> onContactRequestsChanged;
  final ValueChanged<bool> onChatsChanged;
  final ValueChanged<bool> onReportsChanged;
  final ValueChanged<bool> onVerificationChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CarmaBlueIconBox(
                icon: Icons.notifications_active_rounded,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Benachrichtigungen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CarmaSwitchRow(
            icon: Icons.mark_chat_unread_outlined,
            title: 'Kontaktanfragen',
            description: 'Neue eingehende oder angenommene Anfragen.',
            value: notifyContactRequests,
            onChanged: onContactRequestsChanged,
          ),
          const SizedBox(height: 10),
          CarmaSwitchRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chats',
            description: 'Neue Nachrichten aus aktiven Chats.',
            value: notifyChats,
            onChanged: onChatsChanged,
          ),
          const SizedBox(height: 10),
          CarmaSwitchRow(
            icon: Icons.report_outlined,
            title: 'Anonyme Hinweise',
            description: 'Neue sachliche Hinweise zu deinem Fahrzeug.',
            value: notifyReports,
            onChanged: onReportsChanged,
          ),
          const SizedBox(height: 10),
          CarmaSwitchRow(
            icon: Icons.verified_user_outlined,
            title: 'Verifizierung',
            description: 'Statusänderungen zu Konto- und Fahrzeugprüfung.',
            value: notifyVerification,
            onChanged: onVerificationChanged,
          ),
        ],
      ),
    );
  }
}

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.76),
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Carma · Version 1.0.0 · Lokaler MVP',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDetailScreen extends StatelessWidget {
  const _SettingsDetailScreen({
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
    required this.onItemTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<_SettingsDetailItem> items;
  final ValueChanged<String> onItemTap;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                CarmaSubPageHeader(
                  icon: icon,
                  title: title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: List.generate(items.length, (index) {
                      final item = items[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == items.length - 1 ? 0 : 10,
                        ),
                        child: _SettingsDetailTile(
                          item: item,
                          onTap: () => onItemTap(item.title),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalContentScreen extends StatelessWidget {
  const _LegalContentScreen({
    required this.content,
  });

  final _LegalContent content;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                CarmaSubPageHeader(
                  icon: content.icon,
                  title: content.title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                Text(
                  content.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    height: 1.35,
                  ),
                ),
                if (content.versionLabel != null) ...[
                  const SizedBox(height: 18),
                  _LegalVersionCard(
                    versionLabel: content.versionLabel!,
                  ),
                ],
                const SizedBox(height: 18),
                const _LegalDraftNotice(),
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(content.sections.length, (index) {
                      final section = content.sections[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                          index == content.sections.length - 1 ? 0 : 16,
                        ),
                        child: _LegalSectionBlock(section: section),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalVersionCard extends StatelessWidget {
  const _LegalVersionCard({
    required this.versionLabel,
  });

  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CarmaBlueIconBox(
            icon: Icons.verified_outlined,
            size: 42,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              versionLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                height: 1.34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDraftNotice extends StatelessWidget {
  const _LegalDraftNotice();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: Icons.edit_note_rounded,
            size: 42,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Diese Seite ist ein lokaler MVP-Platzhalter. Die finalen Rechtstexte müssen vor Veröffentlichung juristisch geprüft und ersetzt werden.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
                height: 1.34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({
    required this.section,
  });

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              height: 1.36,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalContent {
  const _LegalContent({
    required this.title,
    required this.icon,
    required this.description,
    required this.sections,
    this.versionLabel,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<_LegalSection> sections;
  final String? versionLabel;

  factory _LegalContent.forTitle(String title) {
    return switch (title) {
      'AGB' => const _LegalContent(
        title: 'AGB',
        icon: Icons.article_outlined,
        description:
        'Vorbereitete Struktur für die Allgemeinen Geschäftsbedingungen von Carma.',
        versionLabel: 'Aktuelle AGB-Version: ${LegalVersions.terms}',
        sections: [
          _LegalSection(
            title: 'Geltungsbereich',
            body:
            'Hier werden später die Bedingungen für die Nutzung von Carma beschrieben. Dazu gehören Konto, Profil, Fahrzeugdaten, Kontaktanfragen, Chats und anonyme Hinweise.',
          ),
          _LegalSection(
            title: 'Nutzung der App',
            body:
            'Carma soll eine geschützte Kommunikation rund um Fahrzeuge ermöglichen. Missbrauch, falsche Angaben und belästigende Kontaktaufnahme werden später geregelt.',
          ),
          _LegalSection(
            title: 'Verifizierung',
            body:
            'Die Nutzung bestimmter Funktionen kann später von einer Identitäts- und Fahrzeugprüfung abhängig sein.',
          ),
        ],
      ),
      'Datenschutzerklärung' => const _LegalContent(
        title: 'Datenschutz',
        icon: Icons.privacy_tip_outlined,
        description:
        'Vorbereitete Struktur für Datenschutzinformationen in Carma.',
        versionLabel:
        'Aktuelle Datenschutz-Version: ${LegalVersions.privacy}',
        sections: [
          _LegalSection(
            title: 'Verarbeitete Daten',
            body:
            'Später werden hier Konto-, Profil-, Fahrzeug-, Verifizierungs-, Kontakt- und Kommunikationsdaten beschrieben.',
          ),
          _LegalSection(
            title: 'Zwecke der Verarbeitung',
            body:
            'Daten werden benötigt, um geschützte Kontaktaufnahme, Missbrauchsschutz, Verifizierung und App-Betrieb zu ermöglichen.',
          ),
          _LegalSection(
            title: 'Speicherung und Löschung',
            body:
            'Speicherfristen, Löschkonzepte und Nutzerrechte werden vor Veröffentlichung final definiert.',
          ),
        ],
      ),
      'Impressum' => const _LegalContent(
        title: 'Impressum',
        icon: Icons.business_rounded,
        description:
        'Vorbereitete Anbieterkennzeichnung für die spätere Veröffentlichung.',
        sections: [
          _LegalSection(
            title: 'Anbieter',
            body:
            'Hier werden später Name/Firma, Anschrift und gesetzliche Anbieterinformationen eingetragen.',
          ),
          _LegalSection(
            title: 'Kontakt',
            body:
            'Hier werden später E-Mail-Adresse, Support-Kontakt und weitere Kontaktwege ergänzt.',
          ),
          _LegalSection(
            title: 'Verantwortlichkeit',
            body:
            'Weitere rechtlich erforderliche Angaben werden vor Veröffentlichung ergänzt.',
          ),
        ],
      ),
      'Über Carma' => const _LegalContent(
        title: 'Über Carma',
        icon: Icons.info_outline_rounded,
        description:
        'Kurze Projekt- und App-Informationen für den lokalen MVP.',
        sections: [
          _LegalSection(
            title: 'Was ist Carma?',
            body:
            'Carma ist eine App zur geschützten Kommunikation rund um Fahrzeuge, Kennzeichen, Kontaktanfragen und sachliche Hinweise.',
          ),
          _LegalSection(
            title: 'Aktueller Stand',
            body:
            'Dieser Build ist ein lokaler MVP. Viele Funktionen sind UI-seitig vorbereitet und werden später mit Firebase verbunden.',
          ),
          _LegalSection(
            title: 'Version',
            body: 'Carma · Version 1.0.0 · Lokaler MVP',
          ),
          _LegalSection(
            title: 'Rechtsversionen',
            body:
            'AGB: ${LegalVersions.terms} · Datenschutz: ${LegalVersions.privacy} · Verantwortungsvolle Nutzung: ${LegalVersions.responsibleUse} · Keine Notfallnutzung: ${LegalVersions.noEmergencyUse}',
          ),
        ],
      ),
      'Lizenzen' => const _LegalContent(
        title: 'Lizenzen',
        icon: Icons.workspace_premium_outlined,
        description:
        'Vorbereitete Übersicht für Open-Source-Lizenzen und verwendete Pakete.',
        sections: [
          _LegalSection(
            title: 'Flutter & Dart',
            body:
            'Carma wird mit Flutter und Dart entwickelt. Lizenzinformationen werden später vollständig über die App-Lizenzübersicht ergänzt.',
          ),
          _LegalSection(
            title: 'Pakete',
            body:
            'Verwendete Pakete wie Firebase, Image Picker und weitere Abhängigkeiten werden vor Veröffentlichung geprüft und dokumentiert.',
          ),
          _LegalSection(
            title: 'Lizenzübersicht',
            body:
            'Eine native Flutter-Lizenzseite kann später zusätzlich über showLicensePage eingebunden werden.',
          ),
        ],
      ),
      _ => _LegalContent(
        title: title,
        icon: Icons.description_rounded,
        description: 'Vorbereitete Rechtliches-Seite.',
        sections: const [
          _LegalSection(
            title: 'Noch nicht final',
            body:
            'Diese Seite wird später mit finalen Inhalten und juristischer Prüfung ergänzt.',
          ),
        ],
      ),
    };
  }
}

class _LegalSection {
  const _LegalSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _SettingsDetailItem {
  const _SettingsDetailItem({
    required this.icon,
    required this.title,
    required this.description,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDestructive;
}

class _SettingsDetailTile extends StatelessWidget {
  const _SettingsDetailTile({
    required this.item,
    required this.onTap,
  });

  final _SettingsDetailItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor =
    item.isDestructive ? const Color(0xFFFF8A8A) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: item.isDestructive
                  ? const Color(0xFFFF8A8A).withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              CarmaBlueIconBox(
                icon: item.icon,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.66),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}