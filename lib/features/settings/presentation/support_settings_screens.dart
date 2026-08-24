import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/carisma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/support_request_repository.dart';

class SupportFaqScreen extends StatefulWidget {
  const SupportFaqScreen({super.key});

  @override
  State<SupportFaqScreen> createState() => _SupportFaqScreenState();
}

class _SupportFaqScreenState extends State<SupportFaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const _entries = <_FaqEntry>[
    _FaqEntry(
      question: 'Wie bestätige oder ändere ich meine E-Mail Adresse?',
      answer:
          'Öffne Einstellungen, Konto und danach Konto & Sicherheit. Dort kannst du den Status aktualisieren, eine neue Bestätigungs-E-Mail anfordern oder deine Adresse kontrolliert ändern.',
      keywords: 'konto login email anmeldung',
    ),
    _FaqEntry(
      question: 'Wie funktioniert die Verifizierung?',
      answer:
          'Du entscheidest selbst: Mit dem Fahrzeugschein bestätigst du dein Fahrzeug und schaltest Kontaktanfragen frei. Ein Ausweis, Reisepass oder Aufenthaltstitel bestätigt zusätzlich freiwillig deine Identität. Dokumentbilder bleiben privat.',
      keywords: 'profil dokument ausweis fahrzeugschein stufen',
    ),
    _FaqEntry(
      question: 'Warum wird ein Kennzeichen nicht gefunden?',
      answer:
          'Ein Kennzeichen ist nur auffindbar, wenn es aktiv ist, der Besitzer die Suche erlaubt, der Standort aktuell genug ist und die Entfernung innerhalb des unterstützten Radius liegt.',
      keywords: 'suche kennzeichen standort radius',
    ),
    _FaqEntry(
      question: 'Wann entsteht ein Chat?',
      answer:
          'Zuerst wird eine Kontaktanfrage gesendet. Erst wenn der Empfänger sie annimmt, erscheint der Chat bei beiden Nutzern und Nachrichten können ausgetauscht werden.',
      keywords: 'chat kontaktanfrage annehmen nachricht',
    ),
    _FaqEntry(
      question: 'Wer kann meine Story sehen?',
      answer:
          'Das richtet sich nach deiner Story-Sichtbarkeit und den ausgeschlossenen Nutzern. Abgelaufene Storys werden nach 24 Stunden nicht mehr angezeigt.',
      keywords: 'story sichtbarkeit ausschließen 24 stunden',
    ),
    _FaqEntry(
      question: 'Wie schütze ich mich vor unerwünschten Kontakten?',
      answer:
          'Du kannst Nutzer blockieren, Kontaktanfragen pausieren und Vorfälle melden. Blockierte Chats erlauben keine neuen Nachrichten oder Anhänge.',
      keywords: 'sicherheit blockieren melden missbrauch',
    ),
    _FaqEntry(
      question: 'Welche Daten sind öffentlich?',
      answer:
          'Öffentlich sind ausschließlich die von dir freigegebenen Profil-, Fahrzeug-, Regions- und Kennzeichenangaben. E-Mail, Telefonnummer, Geburtsdatum und Dokumente bleiben privat.',
      keywords: 'datenschutz öffentlich privat daten',
    ),
    _FaqEntry(
      question: 'Wie lange bleibt eine Kontaktanfrage aktiv?',
      answer:
          'Eine Kontaktanfrage läuft nach 48 Stunden ab. Danach kann sie nicht mehr angenommen werden. Du kannst eine gesendete Anfrage vorher zurückziehen; der Empfänger kann sie annehmen oder ablehnen.',
      keywords: 'anfrage ablauf 48 stunden zurückziehen ablehnen',
    ),
    _FaqEntry(
      question: 'Wie verwalte ich mehrere Fahrzeuge?',
      answer:
          'Unter Einstellungen, Profil & Verifizierung und Fahrzeuge kannst du weitere Fahrzeuge hinterlegen. Das Hauptfahrzeug bestimmt die Darstellung im Profil; jedes aktive und freigegebene Kennzeichen kann unabhängig davon gesucht werden.',
      keywords: 'fahrzeug hauptfahrzeug kennzeichen hinzufügen verwalten',
    ),
    _FaqEntry(
      question: 'Warum kann ich keine Fotos oder Sprachmemos senden?',
      answer:
          'Prüfe unter Einstellungen, Schutz & Daten und App-Berechtigungen den Zugriff auf Kamera, Mikrofon und Medien. Dauerhaft abgelehnte Rechte kannst du direkt in den App-Einstellungen deines Geräts wieder erlauben.',
      keywords: 'foto video sprachmemo kamera mikrofon galerie berechtigung',
    ),
    _FaqEntry(
      question: 'Was passiert mit ablaufenden Dokumenten?',
      answer:
          'Vor dem Ablauf deines Identitätsnachweises erinnert dich plaqa an die Erneuerung. Du reichst nur diesen Nachweis erneut ein; ein weiterhin bestätigtes Fahrzeug bleibt erhalten.',
      keywords: 'dokument ausweis ablauf erneuern erinnerung',
    ),
    _FaqEntry(
      question: 'Wie ändere ich meine Privatsphäre?',
      answer:
          'Unter Einstellungen und Privatsphäre steuerst du Auffindbarkeit, Kontaktanfragen, Chat-Privatsphäre und Story-Sichtbarkeit. Änderungen werden erst übernommen, wenn du im jeweiligen Bereich auf Einstellungen speichern tippst.',
      keywords:
          'privatsphäre sichtbarkeit chat story kontaktanfragen speichern',
    ),
    _FaqEntry(
      question: 'Wie fordere ich meine Daten an oder lösche mein Konto?',
      answer:
          'Den Datenexport findest du unter Schutz & Daten und Datenschutz. Die Kontolöschung liegt getrennt unter Konto & Sicherheit und erfordert eine erneute Bestätigung, damit sie nicht versehentlich ausgelöst wird.',
      keywords: 'datenexport konto löschen datenschutz sicherheit',
    ),
    _FaqEntry(
      question: 'Wie aktiviere ich den Zwei-Faktor-Schutz?',
      answer:
          'Öffne Einstellungen, Konto & Sicherheit und Kontoschutz. Dort kannst du nach erneuter Anmeldung eine Mobiltelefonnummer bestätigen und später auch wieder kontrolliert entfernen.',
      keywords: 'zwei faktor sms telefon sicherheit mfa',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final entries = _entries
        .where((entry) {
          if (normalizedQuery.isEmpty) return true;
          return '${entry.question} ${entry.answer} ${entry.keywords}'
              .toLowerCase()
              .contains(normalizedQuery);
        })
        .toList(growable: false);

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              CaRismaSubPageHeader(
                icon: Icons.help_outline_rounded,
                title: 'Hilfe & FAQ',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Hilfe durchsuchen',
                  hintText: 'Zum Beispiel: Verifizierung',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const CaRismaMessageCard(
                  icon: Icons.search_off_rounded,
                  message:
                      'Dazu haben wir noch keinen Hilfeartikel. Du kannst dein Anliegen über Support melden.',
                )
              else
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: NoSplash.splashFactory,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          iconColor: CaRismaDesignTokens.bluePrimary,
                          collapsedIconColor: CaRismaDesignTokens.textSecondary,
                          title: Text(
                            entry.question,
                            style: const TextStyle(
                              color: CaRismaDesignTokens.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.answer,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.42,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({
    super.key,
    required this.type,
    this.repository,
    this.technicalReference,
  });

  final SupportRequestType type;
  final SupportRequestRepository? repository;
  final SupportTechnicalReference? technicalReference;

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  late final SupportRequestRepository _repository;
  late String _category;
  bool _allowContact = true;
  bool _isSubmitting = false;
  String? _error;

  List<String> get _categories {
    return switch (widget.type) {
      SupportRequestType.problem => const [
        'Funktion funktioniert nicht',
        'Darstellung oder Bedienung',
        'Absturz oder Fehlermeldung',
        'Berechtigung oder Upload',
        'Anderes technisches Problem',
      ],
      SupportRequestType.verification => const [
        'Identitätsnachweis',
        'Fahrzeugnachweis',
        'Prüfstatus',
        'Abgelehnte Verifizierung',
        'Anderes Verifizierungsproblem',
      ],
      SupportRequestType.safety => const [
        'Schutz von Minderjährigen',
        'Belästigung oder Bedrohung',
        'Problematischer Inhalt',
        'Verdächtiges Profil oder Verhalten',
        'Anderes Sicherheitsproblem',
      ],
      SupportRequestType.feedback => const [
        'Verbesserungsvorschlag',
        'Neue Idee',
        'Design und Bedienung',
        'Datenschutz und Sicherheit',
        'Allgemeines Feedback',
      ],
    };
  }

  String get _title => switch (widget.type) {
    SupportRequestType.problem => 'Problem melden',
    SupportRequestType.verification => 'Verifizierungsproblem',
    SupportRequestType.safety => 'Sicherheitsproblem melden',
    SupportRequestType.feedback => 'Feedback senden',
  };

  IconData get _icon => switch (widget.type) {
    SupportRequestType.problem => Icons.bug_report_outlined,
    SupportRequestType.verification => Icons.verified_user_outlined,
    SupportRequestType.safety => Icons.health_and_safety_outlined,
    SupportRequestType.feedback => Icons.feedback_outlined,
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupportRequestRepository();
    _category = _categories.first;
    final group = widget.technicalReference?.referenceGroup;
    if (widget.type == SupportRequestType.verification && group != null) {
      _category = switch (group) {
        'identity' => 'Identitätsnachweis',
        'driverLicense' => 'Nicht mehr verwendeter Altnachweis',
        'vehicle' => 'Fahrzeugnachweis',
        _ => _category,
      };
      _areaController.text = 'Dokumentenverifizierung';
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _error = 'Melde dich erneut an, um dein Anliegen zu senden.',
      );
      return;
    }

    final draft = SupportRequestDraft(
      type: widget.type,
      category: _category,
      affectedArea: _areaController.text,
      description: _descriptionController.text,
      reproductionSteps: _stepsController.text,
      allowContact: _allowContact,
      technicalReference: widget.technicalReference,
    );
    if (!draft.isValid) {
      setState(() {
        _error = 'Beschreibe dein Anliegen bitte mit mindestens 20 Zeichen.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _repository.submit(
        userId: user.uid,
        accountEmail: user.email,
        draft: draft,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dein Anliegen wurde sicher übermittelt.'),
        ),
      );
      Navigator.of(context).pop();
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Dein Anliegen konnte gerade nicht gesendet werden. Bitte versuche es erneut.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + keyboardInset),
            children: [
              CaRismaSubPageHeader(
                icon: _icon,
                title: _title,
                titleFontSize: switch (widget.type) {
                  SupportRequestType.verification => 17.5,
                  SupportRequestType.safety => 16,
                  _ => null,
                },
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.type == SupportRequestType.safety) ...[
                      const CaRismaMessageCard(
                        icon: Icons.shield_outlined,
                        message:
                            'Beschreibe den betroffenen Bereich. Sende keine mutmaßlich rechtswidrigen Bilder oder Videos über normale Supportwege. Bei unmittelbarer Gefahr wende dich direkt an Polizei oder Notruf.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      dropdownColor: CaRismaDesignTokens.card,
                      decoration: const InputDecoration(
                        labelText: 'Kategorie',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _areaController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Betroffener Bereich',
                        hintText: 'Zum Beispiel: Chat, Profil oder Beitrag',
                        prefixIcon: Icon(Icons.grid_view_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung',
                        hintText:
                            'Was ist passiert oder was möchtest du verbessern?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (widget.type == SupportRequestType.problem) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _stepsController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Schritte bis zum Fehler · optional',
                          hintText: 'Beschreibe kurz, wie der Fehler entsteht.',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    CaRismaSwitchRow(
                      icon: Icons.mark_email_read_outlined,
                      title: 'Rückfrage erlauben',
                      description:
                          'Der Support darf dich über deine Konto-E-Mail kontaktieren.',
                      value: _allowContact,
                      enabled: true,
                      onChanged: (value) =>
                          setState(() => _allowContact = value),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                CaRismaMessageCard(
                  icon: Icons.error_outline_rounded,
                  message: _error!,
                ),
              ],
              const SizedBox(height: 16),
              CaRismaPrimaryButton(
                label: 'Sicher senden',
                loadingLabel: 'Wird gesendet...',
                icon: Icons.send_rounded,
                isLoading: _isSubmitting,
                surfaceOutlined: true,
                showShadow: false,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({
    required this.question,
    required this.answer,
    required this.keywords,
  });

  final String question;
  final String answer;
  final String keywords;
}
