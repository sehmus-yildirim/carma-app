import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/carisma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chats/data/chat_repository.dart';
import '../data/user_settings_repository.dart';

typedef VisibilitySettingsChanged =
    Future<void> Function(String title, VisibilitySettings settings);
typedef ContactFilterSettingsChanged =
    Future<void> Function(String title, ContactFilterSettings settings);
typedef StoryPrivacySettingsChanged =
    Future<void> Function(String title, StoryPrivacySettings settings);
typedef AppPreferenceSettingsChanged =
    Future<void> Function(String title, AppPreferenceSettings settings);

class VisibilitySettingsScreen extends StatefulWidget {
  const VisibilitySettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final VisibilitySettings initialSettings;
  final VisibilitySettingsChanged onChanged;

  @override
  State<VisibilitySettingsScreen> createState() =>
      _VisibilitySettingsScreenState();
}

class _VisibilitySettingsScreenState extends State<VisibilitySettingsScreen> {
  late VisibilitySettings _settings = widget.initialSettings;

  Future<void> _update(String title, VisibilitySettings settings) async {
    setState(() => _settings = settings);
    await widget.onChanged(title, settings);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      icon: Icons.visibility_outlined,
      title: 'Sichtbarkeit',
      description:
          'Bestimme, wer dich finden darf und welche Fahrzeugdaten öffentlich erscheinen.',
      children: [
        _ChoiceSection(
          title: 'Öffentliches Profil',
          icon: Icons.account_circle_outlined,
          value: _settings.profileVisibility,
          options: const [
            _ChoiceOption(
              value: 'contacts',
              label: 'Kontakte',
              description: 'Nur angenommene Kontakte sehen dein Profil.',
            ),
            _ChoiceOption(
              value: 'onlyMe',
              label: 'Nur ich',
              description: 'Dein Profil bleibt für andere verborgen.',
            ),
          ],
          onChanged: (value) => _update(
            'Profil-Sichtbarkeit',
            _settings.copyWith(profileVisibility: value),
          ),
        ),
        const SizedBox(height: 12),
        _ChoiceSection(
          title: 'Kennzeichen-Suche',
          icon: Icons.search_rounded,
          value: _settings.plateSearchVisibility,
          options: const [
            _ChoiceOption(
              value: 'contacts',
              label: 'Auffindbar',
              description:
                  'Dein aktives Kennzeichen kann unter den sicheren Suchregeln gefunden werden.',
            ),
            _ChoiceOption(
              value: 'onlyMe',
              label: 'Nicht auffindbar',
              description: 'Andere Nutzer finden dein Kennzeichen nicht.',
            ),
          ],
          onChanged: (value) => _update(
            'Kennzeichen-Sichtbarkeit',
            _settings.copyWith(plateSearchVisibility: value),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              CaRismaSwitchRow(
                icon: Icons.directions_car_outlined,
                title: 'Fahrzeug zeigen',
                description: 'Marke und Modell öffentlich freigeben.',
                value: _settings.showVehicle,
                enabled: true,
                onChanged: (value) => _update(
                  'Fahrzeug-Sichtbarkeit',
                  _settings.copyWith(showVehicle: value),
                ),
              ),
              const SizedBox(height: 10),
              CaRismaSwitchRow(
                icon: Icons.location_city_outlined,
                title: 'Region zeigen',
                description: 'Nur deine grobe öffentliche Region anzeigen.',
                value: _settings.showRegion,
                enabled: true,
                onChanged: (value) => _update(
                  'Region-Sichtbarkeit',
                  _settings.copyWith(showRegion: value),
                ),
              ),
              const SizedBox(height: 10),
              CaRismaSwitchRow(
                icon: Icons.pin_outlined,
                title: 'Kennzeichen zeigen',
                description:
                    'Das Kennzeichen nur in erlaubten Bereichen anzeigen.',
                value: _settings.showPlate,
                enabled: true,
                onChanged: (value) => _update(
                  'Kennzeichen-Freigabe',
                  _settings.copyWith(showPlate: value),
                ),
              ),
              const SizedBox(height: 10),
              CaRismaSwitchRow(
                icon: Icons.mark_chat_unread_outlined,
                title: 'Kontaktanfragen',
                description: 'Neue Kontaktanfragen grundsätzlich erlauben.',
                value: _settings.allowContactRequests,
                enabled: true,
                onChanged: (value) => _update(
                  'Kontaktanfragen',
                  _settings.copyWith(allowContactRequests: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const CaRismaMessageCard(
          icon: Icons.lock_outline_rounded,
          message:
              'E-Mail Adresse, Telefonnummer, Geburtsdatum und Dokumente bleiben immer privat.',
        ),
      ],
    );
  }
}

class ContactRequestSettingsScreen extends StatefulWidget {
  const ContactRequestSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final ContactFilterSettings initialSettings;
  final ContactFilterSettingsChanged onChanged;

  @override
  State<ContactRequestSettingsScreen> createState() =>
      _ContactRequestSettingsScreenState();
}

class _ContactRequestSettingsScreenState
    extends State<ContactRequestSettingsScreen> {
  late ContactFilterSettings _settings = widget.initialSettings;

  static const _reasons = <_ReasonOption>[
    _ReasonOption(
      id: 'vehicle_question',
      icon: Icons.directions_car_outlined,
      title: 'Frage zum Fahrzeug',
    ),
    _ReasonOption(
      id: 'compliment',
      icon: Icons.thumb_up_alt_outlined,
      title: 'Kompliment',
    ),
    _ReasonOption(
      id: 'meet_and_drive',
      icon: Icons.route_outlined,
      title: 'Treffen & Ausfahrt',
    ),
    _ReasonOption(
      id: 'get_to_know',
      icon: Icons.favorite_border_rounded,
      title: 'Kennenlernen',
    ),
  ];

  Future<void> _update(String title, ContactFilterSettings settings) async {
    setState(() => _settings = settings);
    await widget.onChanged(title, settings);
  }

  Future<void> _toggleReason(String reason, bool selected) async {
    final reasons = _settings.allowedContactReasons.toSet();
    selected ? reasons.add(reason) : reasons.remove(reason);
    if (reasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mindestens ein Anfragegrund muss erlaubt bleiben.'),
        ),
      );
      return;
    }
    await _update(
      'Anfragegründe',
      _settings.copyWith(allowedContactReasons: reasons.toList()..sort()),
    );
  }

  String get _quietModeValue {
    final until = _settings.contactRequestQuietModeUntil;
    if (until == null || !until.isAfter(DateTime.now())) return 'off';
    return until.difference(DateTime.now()).inHours > 30 ? '7d' : '24h';
  }

  Future<void> _setQuietMode(String value) async {
    final now = DateTime.now();
    await _update(
      'Ruhemodus',
      _settings.copyWith(
        contactRequestQuietModeUntil: switch (value) {
          '24h' => now.add(const Duration(hours: 24)),
          '7d' => now.add(const Duration(days: 7)),
          _ => null,
        },
        clearQuietMode: value == 'off',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Kontaktanfragen',
      description:
          'Lege fest, wer dir aus welchem Anlass eine Anfrage senden darf.',
      children: [
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              CaRismaSwitchRow(
                icon: Icons.verified_user_outlined,
                title: 'Nur verifizierte Nutzer',
                description: 'Anfragen nur von verifizierten Konten zulassen.',
                value: _settings.requireVerifiedRequester,
                enabled: true,
                onChanged: (value) => _update(
                  'Verifizierungsfilter',
                  _settings.copyWith(requireVerifiedRequester: value),
                ),
              ),
              const SizedBox(height: 10),
              CaRismaSwitchRow(
                icon: Icons.gpp_bad_outlined,
                title: 'Automatisch ablehnen',
                description:
                    'Anfragen unverifizierter Nutzer direkt zurückweisen.',
                value: _settings.autoRejectUnverified,
                enabled: true,
                onChanged: (value) => _update(
                  'Automatische Ablehnung',
                  _settings.copyWith(autoRejectUnverified: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.forum_outlined,
                title: 'Erlaubte Anfragegründe',
              ),
              const SizedBox(height: 10),
              ..._reasons.map(
                (reason) => _CheckOptionTile(
                  icon: reason.icon,
                  title: reason.title,
                  selected: _settings.allowedContactReasons.contains(reason.id),
                  onChanged: (selected) => _toggleReason(reason.id, selected),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ChoiceSection(
          title: 'Ruhemodus',
          icon: Icons.nights_stay_outlined,
          value: _quietModeValue,
          options: const [
            _ChoiceOption(
              value: 'off',
              label: 'Aus',
              description: 'Neue Anfragen werden normal zugestellt.',
            ),
            _ChoiceOption(
              value: '24h',
              label: '24 Stunden',
              description: 'Neue Anfragen vorübergehend pausieren.',
            ),
            _ChoiceOption(
              value: '7d',
              label: '7 Tage',
              description: 'Eine Woche lang keine neuen Anfragen.',
            ),
          ],
          onChanged: _setQuietMode,
        ),
        const SizedBox(height: 12),
        const CaRismaMessageCard(
          icon: Icons.security_rounded,
          message:
              'Diese Regeln werden bei neuen Kontaktanfragen serverseitig geprüft.',
        ),
      ],
    );
  }
}

class StoryPrivacySettingsScreen extends StatefulWidget {
  const StoryPrivacySettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final StoryPrivacySettings initialSettings;
  final StoryPrivacySettingsChanged onChanged;

  @override
  State<StoryPrivacySettingsScreen> createState() =>
      _StoryPrivacySettingsScreenState();
}

class _StoryPrivacySettingsScreenState
    extends State<StoryPrivacySettingsScreen> {
  late StoryPrivacySettings _settings = widget.initialSettings;

  Future<void> _update(String title, StoryPrivacySettings settings) async {
    setState(() => _settings = settings);
    await widget.onChanged(title, settings);
  }

  Future<void> _openExclusions() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => _StoryExclusionsScreen(
          initiallyExcluded: _settings.excludedStoryUserIds.toSet(),
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _update(
      'Story-Ausschlüsse',
      _settings.copyWith(excludedStoryUserIds: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      icon: Icons.auto_stories_outlined,
      title: 'Story-Einstellungen',
      description:
          'Steuere Zielgruppe, Antworten und Fahrzeugdaten für neue Storys.',
      children: [
        _ChoiceSection(
          title: 'Wer darf meine Story sehen?',
          icon: Icons.visibility_outlined,
          value: _settings.storyVisibility,
          options: const [
            _ChoiceOption(
              value: 'contacts',
              label: 'Kontakte',
              description: 'Aktive Kontakte sehen deine Story.',
            ),
            _ChoiceOption(
              value: 'onlyMe',
              label: 'Nur ich',
              description: 'Die Story bleibt nur für dich sichtbar.',
            ),
          ],
          onChanged: (value) => _update(
            'Story-Sichtbarkeit',
            _settings.copyWith(storyVisibility: value),
          ),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.person_off_outlined,
          title: 'Nutzer ausschließen',
          description: _settings.excludedStoryUserIds.isEmpty
              ? 'Niemand ist ausgeschlossen.'
              : '${_settings.excludedStoryUserIds.length} Nutzer ausgeschlossen',
          onTap: _openExclusions,
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              CaRismaSwitchRow(
                icon: Icons.reply_outlined,
                title: 'Story-Antworten',
                description: 'Antworten auf neue Storys erlauben.',
                value: _settings.storyRepliesEnabled,
                enabled: true,
                onChanged: (value) => _update(
                  'Story-Antworten',
                  _settings.copyWith(storyRepliesEnabled: value),
                ),
              ),
              const SizedBox(height: 10),
              CaRismaSwitchRow(
                icon: Icons.directions_car_outlined,
                title: 'Fahrzeugdaten als Standard',
                description:
                    'Bei neuen Storys einen freigegebenen Fahrzeug-Sticker vorbereiten.',
                value: _settings.defaultStoryVehicleData,
                enabled: true,
                onChanged: (value) => _update(
                  'Story-Fahrzeugdaten',
                  _settings.copyWith(defaultStoryVehicleData: value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppComfortSettingsScreen extends StatefulWidget {
  const AppComfortSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final AppPreferenceSettings initialSettings;
  final AppPreferenceSettingsChanged onChanged;

  @override
  State<AppComfortSettingsScreen> createState() =>
      _AppComfortSettingsScreenState();
}

class _AppComfortSettingsScreenState extends State<AppComfortSettingsScreen> {
  late AppPreferenceSettings _settings = widget.initialSettings;

  Future<void> _update(String title, AppPreferenceSettings settings) async {
    setState(() => _settings = settings);
    await widget.onChanged(title, settings);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      icon: Icons.tune_rounded,
      title: 'App-Komfort',
      description: 'Passe Rückmeldungen und den Start der DACH-Bereiche an.',
      children: [
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              CaRismaSwitchRow(
                icon: Icons.vibration_rounded,
                title: 'Haptik',
                description:
                    'Vibrationen bei unterstützten Gesten und Aktionen.',
                value: _settings.hapticsEnabled,
                enabled: true,
                onChanged: (value) => _update(
                  'Haptik',
                  _settings.copyWith(hapticsEnabled: value),
                ),
              ),
              const SizedBox(height: 10),
              CaRismaSwitchRow(
                icon: Icons.volume_up_outlined,
                title: 'Nachrichtentöne',
                description: 'Ton bei neu eingehenden Chatnachrichten.',
                value: _settings.messageSoundsEnabled,
                enabled: true,
                onChanged: (value) => _update(
                  'Nachrichtentöne',
                  _settings.copyWith(messageSoundsEnabled: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ChoiceSection(
          title: 'Standardland für Kennzeichen',
          icon: Icons.flag_outlined,
          value: _settings.defaultPlateCountry,
          options: const [
            _ChoiceOption(
              value: 'DE',
              label: 'Deutschland',
              description: 'Suchen und Melden starten mit Deutschland.',
            ),
            _ChoiceOption(
              value: 'AT',
              label: 'Österreich',
              description: 'Suchen und Melden starten mit Österreich.',
            ),
            _ChoiceOption(
              value: 'CH',
              label: 'Schweiz',
              description: 'Suchen und Melden starten mit der Schweiz.',
            ),
          ],
          onChanged: (value) => _update(
            'Standardland',
            _settings.copyWith(defaultPlateCountry: value),
          ),
        ),
        const SizedBox(height: 12),
        const _ReadOnlyStatusCard(
          icon: Icons.language_rounded,
          title: 'Sprache',
          value: 'Deutsch',
          description:
              'Weitere Sprachen folgen erst nach einer vollständigen professionellen Übersetzung.',
        ),
        const SizedBox(height: 10),
        const _ReadOnlyStatusCard(
          icon: Icons.dark_mode_outlined,
          title: 'Design',
          value: 'Dunkel',
          description:
              'Das aktuelle plaqa-Design bleibt konsistent dunkel. Ein Hellmodus wird erst nach kompletter App-Migration angeboten.',
        ),
        const SizedBox(height: 12),
        const CaRismaMessageCard(
          icon: Icons.public_rounded,
          message:
              'DACH steht für Deutschland, Österreich und die Schweiz. Entfernungen werden in Kilometern angezeigt.',
        ),
      ],
    );
  }
}

class _StoryExclusionsScreen extends StatefulWidget {
  const _StoryExclusionsScreen({required this.initiallyExcluded});

  final Set<String> initiallyExcluded;

  @override
  State<_StoryExclusionsScreen> createState() => _StoryExclusionsScreenState();
}

class _StoryExclusionsScreenState extends State<_StoryExclusionsScreen> {
  final FirestoreChatRepository _repository = FirestoreChatRepository();
  final Set<String> _excluded = <String>{};

  @override
  void initState() {
    super.initState();
    _excluded.addAll(widget.initiallyExcluded);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _SettingsPage(
      icon: Icons.person_off_outlined,
      title: 'Story ausschließen',
      description:
          'Ausgeschlossene Kontakte sehen deine nächsten Storys nicht.',
      onBack: () => Navigator.of(context).pop(_excluded.toList()..sort()),
      children: [
        if (userId.isEmpty)
          const CaRismaMessageCard(
            icon: Icons.lock_outline_rounded,
            message: 'Melde dich erneut an, um Ausschlüsse zu verwalten.',
          )
        else
          StreamBuilder<List<ChatRecord>>(
            stream: _repository.watchChats(userId: userId),
            builder: (context, snapshot) {
              final chats = (snapshot.data ?? const <ChatRecord>[])
                  .where((chat) => chat.isActive)
                  .toList(growable: false);
              if (snapshot.hasError) {
                return const CaRismaMessageCard(
                  icon: Icons.error_outline_rounded,
                  message: 'Kontakte konnten gerade nicht geladen werden.',
                );
              }
              if (chats.isEmpty) {
                return const CaRismaMessageCard(
                  icon: Icons.people_outline_rounded,
                  message: 'Noch keine aktiven Kontakte vorhanden.',
                );
              }
              return GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: chats
                      .map((chat) {
                        final otherId = chat.otherParticipantIdFor(userId);
                        if (otherId == null) return const SizedBox.shrink();
                        return _CheckOptionTile(
                          icon: Icons.person_outline_rounded,
                          title: chat.displayNameFor(userId),
                          selected: _excluded.contains(otherId),
                          onChanged: (selected) {
                            setState(() {
                              selected
                                  ? _excluded.add(otherId)
                                  : _excluded.remove(otherId);
                            });
                          },
                        );
                      })
                      .toList(growable: false),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.onBack,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              CaRismaSubPageHeader(
                icon: icon,
                title: title,
                onBack: onBack ?? () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              Text(
                description,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final String value;
  final List<_ChoiceOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: icon, title: title),
          const SizedBox(height: 10),
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoiceTile(
                option: option,
                selected: value == option.value,
                onTap: () => onChanged(option.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ChoiceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? CaRismaDesignTokens.bluePrimary
                  : Colors.white.withValues(alpha: 0.10),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? CaRismaDesignTokens.bluePrimary
                    : CaRismaDesignTokens.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.description,
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckOptionTile extends StatelessWidget {
  const _CheckOptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: CaRismaDesignTokens.bluePrimary,
              checkColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CaRismaBlueIconBox(icon: icon, size: 46, iconSize: 23),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: CaRismaDesignTokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyStatusCard extends StatelessWidget {
  const _ReadOnlyStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CaRismaBlueIconBox(icon: icon, size: 46, iconSize: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        color: CaRismaDesignTokens.bluePrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.32,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption({
    required this.value,
    required this.label,
    required this.description,
  });

  final String value;
  final String label;
  final String description;
}

class _ReasonOption {
  const _ReasonOption({
    required this.id,
    required this.icon,
    required this.title,
  });

  final String id;
  final IconData icon;
  final String title;
}
