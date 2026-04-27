import 'package:flutter/material.dart';

import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_page_header.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/carma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

  void _openDetailPage({
    required IconData icon,
    required String title,
    required String description,
    required List<_SettingsDetailItem> items,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsDetailScreen(
          icon: icon,
          title: title,
          description: description,
          items: items,
          onItemTap: _showComingSoon,
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
        ),
        _SettingsDetailItem(
          icon: Icons.delete_forever_rounded,
          title: 'Konto löschen',
          description:
          'Löscht später Konto, Profil, Fahrzeugdaten und Verifizierungsdaten.',
          isDestructive: true,
        ),
      ],
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
      description: 'AGB, Datenschutz, Impressum und App-Informationen.',
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
          description: 'App-Version, Lizenzen und Projektinformationen.',
        ),
      ],
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
                    const _SafetyNoticeCard(),
                    const SizedBox(height: 18),
                    _SettingsOverviewCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Konto & Sicherheit',
                      description:
                      'Login, Passwort, Abmeldung und Konto löschen.',
                      onTap: _openAccountSecurity,
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
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
                      'AGB, Datenschutz, Impressum und Über Carma.',
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

class _SafetyNoticeCard extends StatelessWidget {
  const _SafetyNoticeCard();

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
              'Carma · Version 1.0.0',
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