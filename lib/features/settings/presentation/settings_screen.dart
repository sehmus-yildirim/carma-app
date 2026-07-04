import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/legal/legal_versions.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_page_header.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/carisma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/notification_settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.userState,
    required this.onLogout,
  });

  final AppUserState userState;
  final VoidCallback onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationSettingsRepository _notificationSettingsRepository =
      NotificationSettingsRepository();

  bool _notifyContactRequests = true;
  bool _notifyChats = true;
  bool _notifyReports = true;
  bool _notifyVerification = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title ist noch nicht verfügbar.')));
  }

  void _showSettingsInfo({
    required String title,
    required IconData icon,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(icon, color: const Color(0xFF63D5FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              height: 1.42,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '$title\n\n$body'));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title wurde kopiert.')),
                );
              },
              child: const Text(
                'Kopieren',
                style: TextStyle(
                  color: Color(0xFF63D5FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Schließen',
                style: TextStyle(
                  color: Color(0xFF63D5FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCopyDraftDialog({
    required String title,
    required IconData icon,
    required String hint,
    required String emptyMessage,
    required String copiedMessage,
    required String Function(String message) buildDraft,
  }) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(icon, color: const Color(0xFF63D5FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            cursorColor: const Color(0xFF63D5FF),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontWeight: FontWeight.w700,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF63D5FF)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Abbrechen',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final message = controller.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(emptyMessage)));
                  return;
                }

                Clipboard.setData(ClipboardData(text: buildDraft(message)));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(copiedMessage)));
              },
              child: const Text(
                'Kopieren',
                style: TextStyle(
                  color: Color(0xFF63D5FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSettingsInfo(String title) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email?.trim();
    final uid = firebaseUser?.uid.trim().isNotEmpty == true
        ? firebaseUser!.uid.trim()
        : widget.userState.userId;

    switch (title) {
      case 'Aktive Geräte':
        _showSettingsInfo(
          title: 'Aktive Geräte',
          icon: Icons.phonelink_lock_rounded,
          body:
              'Aktuell ist nur dieses Gerät in der App sichtbar.\n\n'
              'Die vollständige Geräteverwaltung mit Sitzungen, Geräte-Namen und Abmelden einzelner Geräte benötigt eine serverseitige Sitzungsliste.',
        );
        return;
      case 'Konto löschen':
        _showCopyDraftDialog(
          title: 'Konto löschen',
          icon: Icons.delete_forever_rounded,
          hint:
              'Schreibe kurz, dass du dein Konto löschen möchtest. Beispiel: Ich möchte mein Konto vollständig löschen.',
          emptyMessage:
              'Bitte bestätige kurz, dass du dein Konto löschen möchtest.',
          copiedMessage: 'Löschanfrage wurde kopiert.',
          buildDraft: (message) =>
              'Konto löschen anfordern\n'
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Bestätigung: $message\n\n'
              'Hinweis: Profil, Fahrzeugdaten, Verifizierungsdaten, Chatbezüge und gespeicherte Dateien müssen rechtlich korrekt geprüft und entfernt werden.',
        );
        return;
      case 'Datenexport anfordern':
        _showCopyDraftDialog(
          title: 'Datenexport',
          icon: Icons.file_download_outlined,
          hint: 'Optionaler Hinweis, z. B. welche Daten du brauchst',
          emptyMessage: 'Schreibe kurz, welche Daten du anfordern möchtest.',
          copiedMessage: 'Datenexport-Anfrage wurde kopiert.',
          buildDraft: (message) =>
              'Datenexport anfordern\n'
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Hinweis: $message',
        );
        return;
      case 'Gespeicherte Daten einsehen':
        _showSettingsInfo(
          title: 'Gespeicherte Daten',
          icon: Icons.manage_accounts_outlined,
          body:
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Suchkontingent: ${widget.userState.searchCredit.remaining} von ${widget.userState.searchCredit.limit} verfügbar.\n\n'
              'Profil-, Fahrzeug-, Chat- und Hinweis-Daten werden in den jeweiligen App-Bereichen angezeigt.',
        );
        return;
      case 'Blockierte Nutzer':
      case 'Nutzer blockieren':
        _showSettingsInfo(
          title: 'Blockierte Nutzer',
          icon: Icons.block_rounded,
          body:
              'Blockierte Nutzer und Kennzeichen werden hier gesammelt verwaltet, sobald die Blockierliste serverseitig angebunden ist.\n\n'
              'Blockieren selbst erfolgt direkt im jeweiligen Chat oder Kontaktkontext.',
        );
        return;
      case 'Einwilligungen verwalten':
        _showSettingsInfo(
          title: 'Einwilligungen',
          icon: Icons.fact_check_outlined,
          body:
              'Aktuelle Versionen:\n'
              'AGB: ${LegalVersions.terms}\n'
              'Datenschutz: ${LegalVersions.privacy}\n'
              'Verantwortungsvolle Nutzung: ${LegalVersions.responsibleUse}\n'
              'Keine Notfallnutzung: ${LegalVersions.noEmergencyUse}\n\n'
              'Eine vollständige Verwaltung der Einwilligungen wird für den Release mit Konto- und Rechtetexten verbunden.',
        );
        return;
      case 'Missbrauch melden':
        _showCopyDraftDialog(
          title: 'Missbrauch melden',
          icon: Icons.report_problem_outlined,
          hint:
              'Beschreibe kurz den Vorfall, z. B. falsche Anfrage, Belästigung oder missbräuchliche Nutzung.',
          emptyMessage: 'Beschreibe kurz, was passiert ist.',
          copiedMessage: 'Missbrauchsmeldung wurde kopiert.',
          buildDraft: (message) =>
              'Missbrauch melden\n'
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Beschreibung: $message',
        );
        return;
      case 'Sicherheitsregeln':
        _showSettingsInfo(
          title: 'Sicherheitsregeln',
          icon: Icons.rule_rounded,
          body:
              'Nutze CaRisma nur für sachliche Kontaktaufnahme rund um Fahrzeuge.\n\n'
              'Nicht erlaubt sind Belästigung, falsche Meldungen, Drohungen, Spam, Veröffentlichung fremder Daten oder missbräuchliche Kennzeichen-Suchen.\n\n'
              'Bei Missbrauch können Funktionen eingeschränkt oder Konten gesperrt werden.',
        );
        return;
      case 'Sperrprüfung':
        _showSettingsInfo(
          title: 'Sperrprüfung',
          icon: Icons.gpp_maybe_outlined,
          body:
              'Aktuell liegt keine lokale Sperrinformation vor.\n\n'
              'Verwarnungen, Einschränkungen und Sperren werden serverseitig geprüft und hier nachvollziehbar angezeigt.',
        );
        return;
      case 'Hilfe & FAQ':
        _showSettingsInfo(
          title: 'Hilfe & FAQ',
          icon: Icons.help_outline_rounded,
          body:
              'Häufige Fragen:\n\n'
              '1. Kontaktanfragen erscheinen im Chatbereich.\n'
              '2. Hinweise im Melden-Bereich sind anonym und sachlich gedacht.\n'
              '3. Profil und Fahrzeug müssen für wichtige Funktionen verifiziert werden.\n'
              '4. Storys und Chats sind nur für angenommene Kontakte vorgesehen.',
        );
        return;
      case 'Problem melden':
        _showCopyDraftDialog(
          title: 'Problem melden',
          icon: Icons.bug_report_outlined,
          hint:
              'Was wolltest du tun? Was ist passiert? In welchem Bereich warst du?',
          emptyMessage: 'Beschreibe kurz das Problem.',
          copiedMessage: 'Problembericht wurde kopiert.',
          buildDraft: (message) =>
              'Problem melden\n'
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Beschreibung: $message',
        );
        return;
      case 'Verifizierungsproblem':
        _showCopyDraftDialog(
          title: 'Verifizierungsproblem',
          icon: Icons.verified_user_outlined,
          hint:
              'Beschreibe, welches Dokument oder welcher Schritt nicht funktioniert.',
          emptyMessage: 'Beschreibe kurz dein Verifizierungsproblem.',
          copiedMessage: 'Verifizierungsanfrage wurde kopiert.',
          buildDraft: (message) =>
              'Verifizierungsproblem\n'
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Beschreibung: $message',
        );
        return;
      case 'Feedback senden':
        _showCopyDraftDialog(
          title: 'Feedback senden',
          icon: Icons.feedback_outlined,
          hint: 'Was gefällt dir, was fehlt dir oder was sollte besser werden?',
          emptyMessage: 'Schreibe kurz dein Feedback.',
          copiedMessage: 'Feedback wurde kopiert.',
          buildDraft: (message) =>
              'Feedback senden\n'
              'Konto: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}\n'
              'UID: $uid\n'
              'Feedback: $message',
        );
        return;
      default:
        _showComingSoon(title);
    }
  }

  void _updateNotificationPreference({
    required String title,
    required bool value,
    required ValueChanged<bool> applyValue,
  }) {
    setState(() {
      applyValue(value);
    });

    _saveNotificationSettings(title);
  }

  Future<void> _loadNotificationSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    try {
      final settings = await _notificationSettingsRepository.load(userId);
      if (!mounted) {
        return;
      }

      setState(() {
        _notifyContactRequests = settings.contactRequests;
        _notifyChats = settings.chats;
        _notifyReports = settings.reports;
        _notifyVerification = settings.verification;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mitteilungseinstellungen konnten nicht geladen werden.',
          ),
        ),
      );
    }
  }

  Future<void> _saveNotificationSettings(String title) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Melde dich erneut an, um diese Einstellung zu speichern.',
          ),
        ),
      );
      return;
    }

    final settings = NotificationSettings(
      contactRequests: _notifyContactRequests,
      chats: _notifyChats,
      reports: _notifyReports,
      verification: _notifyVerification,
    );

    try {
      await _notificationSettingsRepository.save(
        userId: userId,
        settings: settings,
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title wurde gespeichert.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mitteilungseinstellung konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Du wirst von diesem Gerät abgemeldet und kommst zurück zum Login.',
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

  void _showAccountLoginInfo() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email?.trim();
    final userId = firebaseUser?.uid.trim();
    final emailVerified = firebaseUser?.emailVerified == true;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'E-Mail / Login',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Text(
            [
              'E-Mail: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}',
              'Status: ${emailVerified ? 'verifiziert' : 'nicht verifiziert'}',
              'UID: ${userId?.isNotEmpty == true ? userId : widget.userState.userId}',
            ].join('\n'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          actions: [
            if (!emailVerified)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _sendEmailVerificationLink();
                },
                child: const Text(
                  'Bestätigen',
                  style: TextStyle(
                    color: Color(0xFF63D5FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                final accountInfo = [
                  'E-Mail: ${email?.isNotEmpty == true ? email : 'Nicht verfügbar'}',
                  'Status: ${emailVerified ? 'verifiziert' : 'nicht verifiziert'}',
                  'UID: ${userId?.isNotEmpty == true ? userId : widget.userState.userId}',
                ].join('\n');

                Clipboard.setData(ClipboardData(text: accountInfo));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kontodaten wurden kopiert.')),
                );
              },
              child: const Text(
                'Kopieren',
                style: TextStyle(
                  color: Color(0xFF63D5FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Schließen',
                style: TextStyle(
                  color: Color(0xFF63D5FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendEmailVerificationLink() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim();

    if (user == null || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Für dieses Konto ist keine E-Mail-Adresse hinterlegt.',
          ),
        ),
      );
      return;
    }

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser?.emailVerified == true) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deine E-Mail-Adresse ist bestätigt.')),
      );
      return;
    }

    try {
      await refreshedUser?.sendEmailVerification();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bestätigungslink wurde an $email gesendet.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapEmailVerificationError(error))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der Bestätigungslink konnte gerade nicht gesendet werden.',
          ),
        ),
      );
    }
  }

  Future<void> _sendPasswordResetLink() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim();

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Für dieses Konto ist keine E-Mail-Adresse hinterlegt.',
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ein Link zum Zurücksetzen wurde an $email gesendet.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapPasswordResetError(error))));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der Link zum Zurücksetzen konnte gerade nicht gesendet werden.',
          ),
        ),
      );
    }
  }

  String _mapPasswordResetError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Die E-Mail-Adresse ist ungültig.';
      case 'user-disabled':
        return 'Dieses Nutzerkonto wurde deaktiviert.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      default:
        return error.message ??
            'Der Link zum Zurücksetzen konnte gerade nicht gesendet werden.';
    }
  }

  String _mapEmailVerificationError(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Zu viele Anfragen. Bitte warte kurz und versuche es erneut.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfe deine Internetverbindung.';
      case 'user-disabled':
        return 'Dieses Nutzerkonto wurde deaktiviert.';
      default:
        return error.message ??
            'Der Bestätigungslink konnte gerade nicht gesendet werden.';
    }
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
    if (title == 'Lizenzen') {
      showLicensePage(
        context: context,
        applicationName: CaRismaAppConfig.appName,
        applicationVersion: CaRismaAppConfig.appVersionLabel,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _LegalContentScreen(content: _LegalContent.forTitle(title)),
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
          description: 'Angemeldete E-Mail und Konto-ID anzeigen.',
        ),
        _SettingsDetailItem(
          icon: Icons.lock_outline_rounded,
          title: 'Passwort ändern',
          description: 'Link zum Zurücksetzen per E-Mail senden.',
        ),
        _SettingsDetailItem(
          icon: Icons.mark_email_read_outlined,
          title: 'E-Mail bestätigen',
          description: 'Bestätigungslink erneut senden.',
        ),
        _SettingsDetailItem(
          icon: Icons.phonelink_lock_rounded,
          title: 'Aktive Geräte',
          description: 'Angemeldete Geräte und Sitzungen anzeigen.',
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
              'Konto, Profil, Fahrzeugdaten und Verifizierungsdaten entfernen.',
          isDestructive: true,
        ),
      ],
      onItemTap: (title) {
        if (title == 'E-Mail / Login') {
          _showAccountLoginInfo();
          return;
        }

        if (title == 'Passwort ändern') {
          _sendPasswordResetLink();
          return;
        }

        if (title == 'E-Mail bestätigen') {
          _sendEmailVerificationLink();
          return;
        }

        if (title == 'Abmelden') {
          _confirmLogout();
          return;
        }

        _openSettingsInfo(title);
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
          description: 'Kopie deiner gespeicherten Daten anfordern.',
        ),
        _SettingsDetailItem(
          icon: Icons.manage_accounts_outlined,
          title: 'Gespeicherte Daten einsehen',
          description: 'Übersicht über Konto-, Profil- und Fahrzeugdaten.',
        ),
        _SettingsDetailItem(
          icon: Icons.block_rounded,
          title: 'Blockierte Nutzer',
          description: 'Blockierte Nutzer oder Kennzeichen verwalten.',
        ),
        _SettingsDetailItem(
          icon: Icons.fact_check_outlined,
          title: 'Einwilligungen verwalten',
          description: 'Datenschutz- und Kommunikationsfreigaben verwalten.',
        ),
      ],
      onItemTap: (title) {
        if (title == 'Datenexport anfordern' ||
            title == 'Gespeicherte Daten einsehen' ||
            title == 'Blockierte Nutzer' ||
            title == 'Einwilligungen verwalten') {
          _openSettingsInfo(title);
          return;
        }

        _showComingSoon(title);
      },
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
          description:
              'Melde falsche Anfragen, Belästigung oder Fake-Hinweise.',
        ),
        _SettingsDetailItem(
          icon: Icons.rule_rounded,
          title: 'Sicherheitsregeln',
          description: 'Regeln für Kontaktanfragen, Hinweise und Verhalten.',
        ),
        _SettingsDetailItem(
          icon: Icons.person_off_outlined,
          title: 'Nutzer blockieren',
          description: 'Blockierte Nutzer und Kennzeichen verwalten.',
        ),
        _SettingsDetailItem(
          icon: Icons.gpp_maybe_outlined,
          title: 'Sperrprüfung',
          description:
              'Informationen zu Verwarnungen, Sperren und Missbrauchsfolgen.',
        ),
      ],
      onItemTap: (title) {
        if (title == 'Missbrauch melden' ||
            title == 'Sicherheitsregeln' ||
            title == 'Nutzer blockieren' ||
            title == 'Sperrprüfung') {
          _openSettingsInfo(title);
          return;
        }

        _showComingSoon(title);
      },
    );
  }

  void _openSupport() {
    _openDetailPage(
      icon: Icons.support_agent_rounded,
      title: 'Support',
      description: 'Hilfe, Feedback und Kontakt zum CaRisma-Support.',
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
          description: 'Teile Verbesserungsvorschläge für CaRisma.',
        ),
      ],
      onItemTap: (title) {
        if (title == 'Hilfe & FAQ' ||
            title == 'Problem melden' ||
            title == 'Verifizierungsproblem' ||
            title == 'Feedback senden') {
          _openSettingsInfo(title);
          return;
        }

        _showComingSoon(title);
      },
    );
  }

  void _openLegal() {
    _openDetailPage(
      icon: Icons.description_rounded,
      title: 'Rechtliches',
      description:
          'AGB, Datenschutz, Impressum, Lizenzen und App-Informationen.',
      items: const [
        _SettingsDetailItem(
          icon: Icons.article_outlined,
          title: 'AGB',
          description: 'Allgemeine Geschäftsbedingungen öffnen.',
        ),
        _SettingsDetailItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Datenschutzerklärung',
          description:
              'Informationen zur Verarbeitung personenbezogener Daten.',
        ),
        _SettingsDetailItem(
          icon: Icons.business_rounded,
          title: 'Impressum',
          description: 'Anbieterkennzeichnung und Kontaktinformationen.',
        ),
        _SettingsDetailItem(
          icon: Icons.info_outline_rounded,
          title: 'Über CaRisma',
          description: 'App-Version, Zweck und Projektinformationen.',
        ),
        _SettingsDetailItem(
          icon: Icons.workspace_premium_outlined,
          title: 'Lizenzen',
          description: 'Open-Source-Lizenzen und verwendete Pakete öffnen.',
        ),
      ],
      onItemTap: _openLegalContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CaRismaBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CaRismaPageHeader(
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
                    _SettingsGroupCard(
                      title: 'Konto',
                      icon: Icons.person_outline_rounded,
                      children: [
                        _SettingsRow(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Konto & Sicherheit',
                          description:
                              'Login, Passwort, Abmeldung und Konto löschen.',
                          onTap: _openAccountSecurity,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsGroupCard(
                      title: 'App & Mitteilungen',
                      icon: Icons.notifications_active_rounded,
                      children: [
                        CaRismaSwitchRow(
                          icon: Icons.mark_chat_unread_outlined,
                          title: 'Kontaktanfragen',
                          description:
                              'Neue eingehende oder angenommene Anfragen.',
                          value: _notifyContactRequests,
                          onChanged: (value) {
                            _updateNotificationPreference(
                              title: 'Kontaktanfragen',
                              value: value,
                              applyValue: (nextValue) {
                                _notifyContactRequests = nextValue;
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        CaRismaSwitchRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Chats',
                          description: 'Neue Nachrichten aus aktiven Chats.',
                          value: _notifyChats,
                          onChanged: (value) {
                            _updateNotificationPreference(
                              title: 'Chats',
                              value: value,
                              applyValue: (nextValue) {
                                _notifyChats = nextValue;
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        CaRismaSwitchRow(
                          icon: Icons.report_outlined,
                          title: 'Anonyme Hinweise',
                          description:
                              'Neue sachliche Hinweise zu deinem Fahrzeug.',
                          value: _notifyReports,
                          onChanged: (value) {
                            _updateNotificationPreference(
                              title: 'Anonyme Hinweise',
                              value: value,
                              applyValue: (nextValue) {
                                _notifyReports = nextValue;
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        CaRismaSwitchRow(
                          icon: Icons.verified_user_outlined,
                          title: 'Verifizierung',
                          description:
                              'Statusänderungen zu Konto- und Fahrzeugprüfung.',
                          value: _notifyVerification,
                          onChanged: (value) {
                            _updateNotificationPreference(
                              title: 'Verifizierung',
                              value: value,
                              applyValue: (nextValue) {
                                _notifyVerification = nextValue;
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsGroupCard(
                      title: 'Schutz & Daten',
                      icon: Icons.shield_outlined,
                      children: [
                        _SettingsRow(
                          icon: Icons.privacy_tip_rounded,
                          title: 'Datenschutz',
                          description:
                              'Datenexport, gespeicherte Daten und Blockierungen.',
                          onTap: _openPrivacy,
                        ),
                        const SizedBox(height: 10),
                        _SettingsRow(
                          icon: Icons.shield_rounded,
                          title: 'Sicherheit & Missbrauch',
                          description:
                              'Missbrauch melden, Regeln ansehen und Nutzer blockieren.',
                          onTap: _openSafety,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsGroupCard(
                      title: 'Hilfe & Rechtliches',
                      icon: Icons.help_outline_rounded,
                      children: [
                        _SettingsRow(
                          icon: Icons.support_agent_rounded,
                          title: 'Support',
                          description:
                              'Hilfe, Problem melden, Verifizierungsproblem und Feedback.',
                          onTap: _openSupport,
                        ),
                        const SizedBox(height: 10),
                        _SettingsRow(
                          icon: Icons.description_rounded,
                          title: 'Rechtliches',
                          description:
                              'AGB, Datenschutz, Impressum, Lizenzen und Über CaRisma.',
                          onTap: _openLegal,
                        ),
                      ],
                    ),
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

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E7BFF), Color(0xFF0B5EF5)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: const Color(0xFF1E7BFF), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(children: children),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              CaRismaBlueIconBox(icon: icon, size: 44, iconSize: 22),
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
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
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

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          final appInfo = [
            CaRismaAppConfig.appName,
            CaRismaAppConfig.appVersionLabel,
            'AGB: ${LegalVersions.terms}',
            'Datenschutz: ${LegalVersions.privacy}',
            'Verantwortungsvolle Nutzung: ${LegalVersions.responsibleUse}',
            'Keine Notfallnutzung: ${LegalVersions.noEmergencyUse}',
          ].join('\n');

          Clipboard.setData(ClipboardData(text: appInfo));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App-Informationen wurden kopiert.')),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B5EF5), Color(0xFF1E7BFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1E7BFF).withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_activity_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  CaRismaAppConfig.appVersionLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.copy_rounded,
                color: Colors.white.withValues(alpha: 0.58),
                size: 20,
              ),
            ],
          ),
        ),
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

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaSubPageHeader(
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
  const _LegalContentScreen({required this.content});

  final _LegalContent content;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final legalText = [
      content.title,
      content.description,
      if (content.versionLabel != null) content.versionLabel!,
      ...content.sections.map((section) => '${section.title}\n${section.body}'),
    ].join('\n\n');

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaSubPageHeader(
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
                  _LegalVersionCard(versionLabel: content.versionLabel!),
                ],
                const SizedBox(height: 18),
                const _LegalDraftNotice(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: legalText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${content.title} wurde kopiert.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Text kopieren'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF63D5FF),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(content.sections.length, (index) {
                      final section = content.sections[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == content.sections.length - 1 ? 0 : 16,
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
  const _LegalVersionCard({required this.versionLabel});

  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CaRismaBlueIconBox(
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
          CaRismaBlueIconBox(
            icon: Icons.edit_note_rounded,
            size: 42,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Diese Seite ist ein Entwurf. Die finalen Rechtstexte müssen vor Veröffentlichung juristisch geprüft und ersetzt werden.',
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
  const _LegalSectionBlock({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
        description: 'Entwurf der wichtigsten Nutzungsregeln für CaRisma.',
        versionLabel: 'Aktuelle AGB-Version: ${LegalVersions.terms}',
        sections: [
          _LegalSection(
            title: 'Geltungsbereich',
            body:
                'Diese Regeln beziehen sich auf Konto, Profil, Fahrzeugdaten, Kennzeichen-Suche, Kontaktanfragen, Chats, Storys und anonyme Hinweise innerhalb von CaRisma.',
          ),
          _LegalSection(
            title: 'Nutzung der App',
            body:
                'CaRisma ist für sachliche, geschützte Kommunikation rund um Fahrzeuge gedacht. Missbrauch, falsche Angaben, Belästigung, Spam und zweckfremde Kontaktaufnahme sind nicht erlaubt.',
          ),
          _LegalSection(
            title: 'Verifizierung',
            body:
                'Bestimmte Funktionen können von einer Identitäts-, Führerschein- oder Fahrzeugprüfung abhängig sein, damit Kontakte und Hinweise verantwortungsvoll genutzt werden.',
          ),
        ],
      ),
      'Datenschutzerklärung' => const _LegalContent(
        title: 'Datenschutz',
        icon: Icons.privacy_tip_outlined,
        description: 'Entwurf der Datenschutzinformationen für CaRisma.',
        versionLabel: 'Aktuelle Datenschutz-Version: ${LegalVersions.privacy}',
        sections: [
          _LegalSection(
            title: 'Verarbeitete Daten',
            body:
                'CaRisma verarbeitet Konto-, Profil-, Fahrzeug-, Verifizierungs-, Kontakt-, Hinweis- und Kommunikationsdaten, soweit sie für die jeweilige Funktion benötigt werden.',
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
            'Anbieterkennzeichnung für die Veröffentlichung von CaRisma.',
        sections: [
          _LegalSection(
            title: 'Anbieter',
            body:
                'Name/Firma, Anschrift und gesetzlich erforderliche Anbieterinformationen werden vor der Veröffentlichung vollständig eingetragen.',
          ),
          _LegalSection(
            title: 'Kontakt',
            body:
                'E-Mail-Adresse, Support-Kontakt und weitere Kontaktwege werden vor der Veröffentlichung vollständig ergänzt.',
          ),
          _LegalSection(
            title: 'Verantwortlichkeit',
            body:
                'Weitere rechtlich erforderliche Angaben werden vor Veröffentlichung ergänzt.',
          ),
        ],
      ),
      'Über CaRisma' => _LegalContent(
        title: 'Über CaRisma',
        icon: Icons.info_outline_rounded,
        description: 'Projekt- und App-Informationen zu CaRisma.',
        sections: [
          const _LegalSection(
            title: 'Was ist CaRisma?',
            body:
                'CaRisma ist eine App zur geschützten Kommunikation rund um Fahrzeuge, Kennzeichen, Kontaktanfragen und sachliche Hinweise.',
          ),
          const _LegalSection(
            title: 'Aktueller Stand',
            body:
                'Dieser Build befindet sich in aktiver Entwicklung. Die App wird Schritt für Schritt mit Firebase, sicheren Regeln und finaler Qualitätssicherung verbunden.',
          ),
          _LegalSection(
            title: 'Version',
            body: CaRismaAppConfig.appVersionLabel,
          ),
          const _LegalSection(
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
            'Übersicht für Open-Source-Lizenzen und verwendete Pakete.',
        sections: [
          _LegalSection(
            title: 'Flutter & Dart',
            body:
                'CaRisma wird mit Flutter und Dart entwickelt. Die Lizenzinformationen werden über die App-Lizenzübersicht bereitgestellt.',
          ),
          _LegalSection(
            title: 'Pakete',
            body:
                'Verwendete Pakete wie Firebase, Image Picker und weitere Abhängigkeiten werden vor Veröffentlichung geprüft und dokumentiert.',
          ),
          _LegalSection(
            title: 'Lizenzübersicht',
            body:
                'Die native Flutter-Lizenzseite zeigt die verwendeten Open-Source-Lizenzen innerhalb der App an.',
          ),
        ],
      ),
      _ => _LegalContent(
        title: title,
        icon: Icons.description_rounded,
        description: 'Rechtliche Informationen zu CaRisma.',
        sections: const [
          _LegalSection(
            title: 'Entwurf',
            body:
                'Diese Seite wird vor Veröffentlichung mit finalen Inhalten und juristischer Prüfung ergänzt.',
          ),
        ],
      ),
    };
  }
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

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
  const _SettingsDetailTile({required this.item, required this.onTap});

  final _SettingsDetailItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = item.isDestructive
        ? const Color(0xFFFF8A8A)
        : Colors.white;

    final iconBoxDecoration = item.isDestructive
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF4D4F).withValues(alpha: 0.30),
                const Color(0xFFFF8A8A).withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFF8A8A).withValues(alpha: 0.30),
            ),
          )
        : null;

    final iconColor = item.isDestructive
        ? const Color(0xFFFF8A8A)
        : Colors.white;

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
              item.isDestructive
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: iconBoxDecoration,
                      child: Icon(item.icon, color: iconColor, size: 22),
                    )
                  : CaRismaBlueIconBox(icon: item.icon, size: 44, iconSize: 22),
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
                color: item.isDestructive
                    ? const Color(0xFFFF8A8A).withValues(alpha: 0.60)
                    : Colors.white.withValues(alpha: 0.66),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
