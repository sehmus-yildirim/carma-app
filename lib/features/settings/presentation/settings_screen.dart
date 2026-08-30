import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/legal/legal_versions.dart';
import '../../../shared/models/carisma_models.dart';
import '../../../shared/notifications/push_notification_service.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_auth_brand_header.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/carisma_switch_row.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/data/auth_service.dart';
import '../../chats/data/chat_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/app_permission_service.dart';
import '../data/app_runtime_preferences.dart';
import '../data/notification_settings_repository.dart';
import '../data/support_request_repository.dart';
import '../data/user_settings_repository.dart';
import 'account_security_screen.dart';
import 'data_rights_settings_screens.dart';
import 'licenses_settings_screen.dart';
import 'profile_verification_settings_screen.dart';
import 'privacy_comfort_settings_screens.dart';
import 'support_settings_screens.dart';

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
  final UserSettingsRepository _userSettingsRepository =
      UserSettingsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _notifyContactRequests = true;
  bool _notifyChats = true;
  bool _notifyReports = true;
  bool _notifyVerification = true;
  VisibilitySettings _visibilitySettings = const VisibilitySettings();
  ContactFilterSettings _contactFilterSettings = const ContactFilterSettings();
  ChatPrivacySettings _chatPrivacySettings = const ChatPrivacySettings();
  StoryPrivacySettings _storyPrivacySettings = const StoryPrivacySettings();
  AppPreferenceSettings _appPreferenceSettings = const AppPreferenceSettings();

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _loadUserSettings();
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
          backgroundColor: CaRismaDesignTokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(icon, color: CaRismaDesignTokens.bluePrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            body,
            style: TextStyle(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              height: 1.42,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Schließen',
                style: TextStyle(
                  color: CaRismaDesignTokens.bluePrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccountDeletionRequestDialog() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte melde dich erneut an.')),
      );
      return;
    }
    final account = AuthAccountSnapshot.fromUser(firebaseUser);
    final deletionScrollController = ScrollController();
    final passwordController = TextEditingController();
    final confirmationFieldKey = GlobalKey();
    var acceptedConsequences = false;
    var confirmationText = '';
    var isDeleting = false;
    var passwordVisible = false;
    String? deletionError;

    void revealConfirmationField() {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        final fieldContext = confirmationFieldKey.currentContext;
        if (fieldContext == null || !fieldContext.mounted) return;
        Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.05,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final confirmed = DataRightsRequestDraftBuilder.isDeletionConfirmed(
              confirmationText: confirmationText,
              acceptedConsequences: acceptedConsequences,
            );

            return AlertDialog(
              backgroundColor: CaRismaDesignTokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: CaRismaDesignTokens.danger.withValues(alpha: 0.34),
                ),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.delete_forever_rounded,
                    color: CaRismaDesignTokens.danger,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Konto löschen',
                      style: TextStyle(
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                controller: deletionScrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SettingsDialogStatusCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: CaRismaDesignTokens.danger,
                      title: 'Diese Aktion ist weitreichend',
                      body:
                          'Betroffen sind Profil, Fahrzeuge und Kennzeichen, Chats und Anfragen, Hinweise, Storys und Medien. Gesetzliche Aufbewahrungsfristen können eine sofortige vollständige Löschung einzelner Daten verhindern.',
                    ),
                    const SizedBox(height: 12),
                    if (account.hasAppleProvider) ...[
                      const _SettingsDialogStatusCard(
                        icon: Icons.apple,
                        iconColor: CaRismaDesignTokens.bluePrimary,
                        title: 'Apple-Anmeldung bestätigen',
                        body:
                            'Vor der Löschung öffnet sich Apple einmal zur sicheren Bestätigung. Dabei wird die Apple-Verknüpfung widerrufen; ein App-Passwort ist nicht erforderlich.',
                      ),
                      const SizedBox(height: 12),
                    ] else if (account.hasPasswordProvider) ...[
                      TextField(
                        controller: passwordController,
                        onTap: revealConfirmationField,
                        enabled: !isDeleting,
                        obscureText: !passwordVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                        cursorColor: CaRismaDesignTokens.danger,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Aktuelles Passwort',
                          labelStyle: TextStyle(
                            color: CaRismaDesignTokens.textPrimary.withValues(
                              alpha: 0.62,
                            ),
                          ),
                          filled: true,
                          fillColor: CaRismaDesignTokens.controlSurface,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: CaRismaDesignTokens.textPrimary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: CaRismaDesignTokens.danger,
                            ),
                          ),
                          suffixIcon: IconButton(
                            tooltip: passwordVisible
                                ? 'Passwort ausblenden'
                                : 'Passwort anzeigen',
                            onPressed: isDeleting
                                ? null
                                : () => setDialogState(
                                    () => passwordVisible = !passwordVisible,
                                  ),
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: CaRismaDesignTokens.textPrimary.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else if (account.isGoogleOnly) ...[
                      const _SettingsDialogStatusCard(
                        icon: Icons.security_rounded,
                        iconColor: CaRismaDesignTokens.bluePrimary,
                        title: 'Google-Anmeldung bestätigen',
                        body:
                            'Vor der Löschung öffnet sich Google einmal zur sicheren Bestätigung deiner Anmeldung.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      key: confirmationFieldKey,
                      decoration: BoxDecoration(
                        color: CaRismaDesignTokens.controlSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CaRismaDesignTokens.textPrimary.withValues(
                            alpha: 0.10,
                          ),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: acceptedConsequences,
                        onChanged: (value) => setDialogState(
                          () => acceptedConsequences = value ?? false,
                        ),
                        activeColor: CaRismaDesignTokens.danger,
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Ich habe die Folgen der Löschanfrage verstanden.',
                          maxLines: 2,
                          style: TextStyle(
                            color: CaRismaDesignTokens.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: CaRismaDesignTokens.controlSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CaRismaDesignTokens.danger,
                          width: 1.4,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 11, 16, 0),
                            child: Text(
                              'Zur Bestätigung:',
                              style: TextStyle(
                                color: CaRismaDesignTokens.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextField(
                            onTap: revealConfirmationField,
                            scrollPadding: const EdgeInsets.only(bottom: 120),
                            onChanged: (value) => setDialogState(() {
                              confirmationText = value;
                              deletionError = null;
                            }),
                            enabled: !isDeleting,
                            cursorColor: CaRismaDesignTokens.danger,
                            style: const TextStyle(
                              color: CaRismaDesignTokens.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              hintText: 'KONTO LÖSCHEN',
                              hintStyle: TextStyle(
                                color: CaRismaDesignTokens.textPrimary
                                    .withValues(alpha: 0.42),
                                fontWeight: FontWeight.w800,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 11),
                            child: Text(
                              'Hier ins Feld schreiben',
                              style: TextStyle(
                                color: CaRismaDesignTokens.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (deletionError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        deletionError!,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.danger,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Dein Anmeldekonto wird dauerhaft gelöscht. Die vollständige Bereinigung verbleibender App-Daten erfolgt unter Beachtung gesetzlicher Aufbewahrungsfristen.',
                      style: TextStyle(
                        color: CaRismaDesignTokens.textPrimary.withValues(
                          alpha: 0.58,
                        ),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Abbrechen',
                    style: TextStyle(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.72,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: confirmed && !isDeleting
                      ? () async {
                          setDialogState(() {
                            isDeleting = true;
                            deletionError = null;
                          });
                          try {
                            await AuthService().deleteCurrentUser(
                              currentPassword: passwordController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } on FirebaseAuthException catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              deletionError = accountAuthErrorMessage(error);
                              isDeleting = false;
                            });
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              deletionError =
                                  'Das Konto konnte gerade nicht gelöscht werden.';
                              isDeleting = false;
                            });
                          }
                        }
                      : null,
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CaRismaDesignTokens.danger,
                          ),
                        )
                      : Text(
                          'Konto löschen',
                          style: TextStyle(
                            color: confirmed
                                ? CaRismaDesignTokens.danger
                                : CaRismaDesignTokens.textPrimary.withValues(
                                    alpha: 0.30,
                                  ),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      deletionScrollController.dispose();
      passwordController.dispose();
    });
  }

  void _openStatusOverviewScreen({
    required String title,
    required IconData icon,
    required String intro,
    required List<_SettingsStatusLine> items,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsStatusOverviewScreen(
          title: title,
          icon: icon,
          intro: intro,
          items: items,
        ),
      ),
    );
  }

  void _openLegalConsentStatusScreen() {
    final statuses = LegalConsentStatusResolver.resolve(
      widget.userState.legalConsents,
    );

    _openStatusOverviewScreen(
      title: 'Einwilligungen',
      icon: Icons.fact_check_outlined,
      intro:
          'Hier siehst du die aktuell gültige Version und die zuletzt in deinem Konto gespeicherte Zustimmung.',
      items: statuses
          .map((status) {
            final acceptedAt = status.acceptedAt;
            final acceptedDate = acceptedAt == null
                ? null
                : '${acceptedAt.day.toString().padLeft(2, '0')}.${acceptedAt.month.toString().padLeft(2, '0')}.${acceptedAt.year}';
            final acceptedVersion = status.isAvailable
                ? status.acceptedVersion!
                : 'Noch nicht verfügbar';
            final statusText = status.isCurrent
                ? 'Aktuell'
                : status.isAvailable
                ? 'Prüfung nötig'
                : 'Nicht verfügbar';
            final statusColor = status.isCurrent
                ? CaRismaDesignTokens.success
                : status.isAvailable
                ? CaRismaDesignTokens.danger
                : CaRismaDesignTokens.textMuted;

            return _SettingsStatusLine(
              icon: status.isCurrent
                  ? Icons.verified_rounded
                  : Icons.info_outline_rounded,
              title: status.label,
              body:
                  'Aktuell gültig: ${status.currentVersion}\nBestätigt: $acceptedVersion${acceptedDate == null ? '' : ' am $acceptedDate'}',
              status: statusText,
              statusColor: statusColor,
            );
          })
          .toList(growable: false),
    );
  }

  void _openPrivacyPreferencesStatusScreen() {
    String enabledLabel(bool value) => value ? 'Aktiv' : 'Deaktiviert';
    String requesterFilterLabel(ContactRequesterVerificationLevel value) =>
        switch (value) {
          ContactRequesterVerificationLevel.all => 'Alle',
          ContactRequesterVerificationLevel.vehicleVerified =>
            'Fahrzeug bestätigt',
          ContactRequesterVerificationLevel.identityVerified =>
            'Identität bestätigt',
        };
    String visibilityLabel(String value) => switch (value) {
      'public' => 'Öffentlich',
      'onlyMe' => 'Nur ich',
      _ => 'Kontakte',
    };

    _openStatusOverviewScreen(
      title: 'Präferenzen',
      icon: Icons.privacy_tip_outlined,
      intro:
          'Deine gespeicherten Einstellungen für Sichtbarkeit und Privatsphäre.',
      items: [
        _SettingsStatusLine(
          icon: Icons.visibility_outlined,
          title: 'Sichtbarkeit',
          body:
              'Profil: ${visibilityLabel(_visibilitySettings.profileVisibility)} · Kennzeichen-Suche: ${visibilityLabel(_visibilitySettings.plateSearchVisibility)}',
          status: 'Gespeichert',
          statusColor: CaRismaDesignTokens.bluePrimary,
        ),
        _SettingsStatusLine(
          icon: Icons.directions_car_outlined,
          title: 'Öffentliche Fahrzeugdaten',
          body:
              'Fahrzeug ${enabledLabel(_visibilitySettings.showVehicle)} · Region ${enabledLabel(_visibilitySettings.showRegion)} · Kennzeichen ${enabledLabel(_visibilitySettings.showPlate)}',
          status: 'Gespeichert',
          statusColor: CaRismaDesignTokens.bluePrimary,
        ),
        _SettingsStatusLine(
          icon: Icons.mark_chat_read_outlined,
          title: 'Chat-Privatsphäre',
          body:
              'Lesebestätigungen ${enabledLabel(_chatPrivacySettings.readReceiptsEnabled)} · Einmal-Ansehen als Standard ${enabledLabel(_chatPrivacySettings.defaultViewOnceMedia)}',
          status: 'In App verwendet',
          statusColor: CaRismaDesignTokens.success,
        ),
        _SettingsStatusLine(
          icon: Icons.auto_stories_outlined,
          title: 'Story-Sichtbarkeit',
          body:
              '${visibilityLabel(_storyPrivacySettings.storyVisibility)} · ${_storyPrivacySettings.excludedStoryUserIds.length} ausgeschlossene Nutzer · Antworten ${enabledLabel(_storyPrivacySettings.storyRepliesEnabled)}',
          status: 'In App verwendet',
          statusColor: CaRismaDesignTokens.success,
        ),
        _SettingsStatusLine(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Kontaktanfrage',
          body:
              'Anfragen ${enabledLabel(_visibilitySettings.allowContactRequests)} · Filter: ${requesterFilterLabel(_contactFilterSettings.requesterVerificationLevel)}',
          status: 'Serverseitig geprüft',
          statusColor: CaRismaDesignTokens.success,
        ),
      ],
    );
  }

  void _openSettingsInfo(String title) {
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
        _showAccountDeletionRequestDialog();
        return;
      case 'Datenexport anfordern':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DataExportRequestScreen(),
          ),
        );
        return;
      case 'Gespeicherte Daten einsehen':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                StoredDataOverviewScreen(userState: widget.userState),
          ),
        );
        return;
      case 'Blockierte Nutzer':
      case 'Nutzer blockieren':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _BlockedChatsSettingsScreen(),
          ),
        );
        return;
      case 'Einwilligungen verwalten':
        _openLegalConsentStatusScreen();
        return;
      case 'Datenschutz-Präferenzen':
        _openPrivacyPreferencesStatusScreen();
        return;
      case 'Werbung & Tracking':
        _openStatusOverviewScreen(
          title: 'Werbung & Tracking',
          icon: Icons.ads_click_outlined,
          intro:
              'Hier siehst du transparent, welche Werbe- und Trackingfunktionen plaqa aktuell verwendet.',
          items: const [
            _SettingsStatusLine(
              icon: Icons.do_not_disturb_alt_rounded,
              title: 'Personalisierte Werbung',
              body: 'plaqa zeigt aktuell keine personalisierte Werbung.',
              status: 'Nicht genutzt',
              statusColor: CaRismaDesignTokens.success,
            ),
            _SettingsStatusLine(
              icon: Icons.track_changes_outlined,
              title: 'Werbetracking',
              body: 'Es werden aktuell keine Daten für Werbetracking genutzt.',
              status: 'Nicht genutzt',
              statusColor: CaRismaDesignTokens.success,
            ),
            _SettingsStatusLine(
              icon: Icons.policy_outlined,
              title: 'Zukünftige Änderungen',
              body:
                  'Neue Analyse-, Werbe- oder Trackingfunktionen werden vor ihrer Nutzung transparent erklärt und rechtlich geprüft.',
              status: 'Transparent',
              statusColor: CaRismaDesignTokens.bluePrimary,
            ),
          ],
        );
        return;
      case 'App-Berechtigungen':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _AppPermissionsSettingsScreen(),
          ),
        );
        return;
      case 'Profil-Sichtbarkeit':
        _showSettingsInfo(
          title: 'Profil-Sichtbarkeit',
          icon: Icons.visibility_outlined,
          body:
              'Du bestimmst später, wer dein öffentliches Profil sehen darf.\n\n'
              'Für den MVP gilt: Fremde Profile dürfen nur öffentliche Felder anzeigen. Private Daten wie E-Mail, Telefonnummer, Dokumente und genaue Standortdaten bleiben verborgen.',
        );
        return;
      case 'Kennzeichen finden':
        _showSettingsInfo(
          title: 'Kennzeichen finden',
          icon: Icons.search_rounded,
          body:
              'Diese Einstellung bereitet vor, wer dich über dein Kennzeichen finden darf.\n\n'
              'Für den Release muss diese Auswahl serverseitig in der Kennzeichen-Suche erzwungen werden, damit deaktivierte Profile nicht gefunden werden.',
        );
        return;
      case 'Öffentliche Fahrzeugdaten':
        _showSettingsInfo(
          title: 'Öffentliche Fahrzeugdaten',
          icon: Icons.directions_car_outlined,
          body:
              'Fahrzeug, Region und Kennzeichen sollen nur angezeigt werden, wenn du die jeweilige Sichtbarkeit freigibst.\n\n'
              'Sensible Konto-, Dokument- und Verifizierungsdaten werden nicht in öffentliche Profile kopiert.',
        );
        return;
      case 'Kontaktanfragen erlauben':
        _showSettingsInfo(
          title: 'Kontaktanfragen erlauben',
          icon: Icons.mark_chat_unread_outlined,
          body:
              'Hier kannst du später Kontaktanfragen pausieren oder wieder erlauben.\n\n'
              'Damit das sicher wirkt, muss die Suche und Anfrage-Erstellung serverseitig prüfen, ob Kontaktanfragen erlaubt sind.',
        );
        return;
      case 'Nur verifizierte Nutzer':
        _showSettingsInfo(
          title: 'Nur verifizierte Nutzer',
          icon: Icons.verified_user_outlined,
          body:
              'Du kannst Anfragen auf Nutzer mit bestätigtem Fahrzeug oder zusätzlich bestätigter Identität begrenzen. Die Auswahl wird beim Erstellen der Anfrage serverseitig geprüft.',
        );
        return;
      case 'Anfragegründe':
        _showSettingsInfo(
          title: 'Anfragegründe',
          icon: Icons.chat_bubble_outline_rounded,
          body:
              'Aktuell stehen alle angebotenen Anfragegründe zur Verfügung. Eine individuelle Einschränkung einzelner Gründe ist noch nicht aktiv.',
        );
        return;
      case 'Automatisch ablehnen':
        _showSettingsInfo(
          title: 'Automatisch ablehnen',
          icon: Icons.do_not_disturb_on_outlined,
          body:
              'Diese Option bereitet vor, Anfragen automatisch abzulehnen, wenn Mindestbedingungen fehlen, zum Beispiel Verifizierung oder erlaubter Anfragegrund.\n\n'
              'Die Entscheidung darf später nicht allein in der App passieren, sondern muss serverseitig umgesetzt werden.',
        );
        return;
      case 'Ruhemodus':
        _showSettingsInfo(
          title: 'Ruhemodus',
          icon: Icons.nightlight_round,
          body:
              'Der Ruhemodus pausiert künftig neue Kontaktanfragen für eine gewählte Zeit.\n\n'
              'Bis zur Backend-Anbindung ist dies eine vorbereitete Datenschutzoption und blockiert noch keine echten Anfragen.',
        );
        return;
      case 'Lesebestätigungen':
        _showSettingsInfo(
          title: 'Lesebestätigungen',
          icon: Icons.done_all_rounded,
          body:
              'Hier wird vorbereitet, ob andere Nutzer sehen dürfen, dass du Nachrichten gelesen hast.\n\n'
              'Aktuell ist die Chat-Statuslogik aktiv. Eine Nutzeroption muss später mit den Chat-Regeln sauber verbunden werden.',
        );
        return;
      case 'Online-Status':
        _showSettingsInfo(
          title: 'Online-Status',
          icon: Icons.circle_outlined,
          body:
              'Online- und Zuletzt-aktiv-Anzeige ist für plaqa vorbereitet, aber noch nicht als öffentliche Funktion aktiv.\n\n'
              'Wenn sie später kommt, muss sie hier deaktivierbar sein.',
        );
        return;
      case 'Medien automatisch speichern':
        _showSettingsInfo(
          title: 'Medien automatisch speichern',
          icon: Icons.perm_media_outlined,
          body:
              'Diese Option bereitet vor, ob empfangene Chat-Medien automatisch lokal gespeichert werden.\n\n'
              'Aktuell werden Medien nicht ungefragt als eigene Galerie-Automatik beworben.',
        );
        return;
      case 'Einmal ansehen Standard':
        _showSettingsInfo(
          title: 'Einmal ansehen Standard',
          icon: Icons.looks_one_outlined,
          body:
              'Hier kannst du später festlegen, ob Fotos und Videos standardmäßig als Einmal-ansehen gesendet werden.\n\n'
              'Die konkrete Auswahl bleibt im Chat weiterhin sichtbar entscheidbar.',
        );
        return;
      case 'Story-Sichtbarkeit':
        _showSettingsInfo(
          title: 'Story-Sichtbarkeit',
          icon: Icons.auto_stories_outlined,
          body:
              'Diese Option bereitet vor, wer deine Story sehen darf.\n\n'
              'Storys werden aktuell über berechtigte Viewer abgesichert. Eine sichtbare Nutzerliste muss später mit diesen Viewer-Regeln verbunden werden.',
        );
        return;
      case 'Story-Nutzer ausschließen':
        _showSettingsInfo(
          title: 'Story-Nutzer ausschließen',
          icon: Icons.person_remove_outlined,
          body:
              'Hier kannst du später einzelne Nutzer von deinen Storys ausschließen.\n\n'
              'Die Sperre muss serverseitig mit Story-Viewern und blockierten Nutzern abgeglichen werden.',
        );
        return;
      case 'Story-Antworten':
        _showSettingsInfo(
          title: 'Story-Antworten',
          icon: Icons.reply_outlined,
          body:
              'Diese Einstellung bereitet vor, ob Kontakte auf deine Story antworten dürfen.\n\n'
              'Antworten dürfen später nur für erlaubte Kontakte und aktive Chats möglich sein.',
        );
        return;
      case 'Fahrzeugdaten in Storys':
        _showSettingsInfo(
          title: 'Fahrzeugdaten in Storys',
          icon: Icons.directions_car_filled_outlined,
          body:
              'Du kannst später voreinstellen, ob Storys automatisch Fahrzeugdaten enthalten dürfen.\n\n'
              'Aktuell entscheidest du beim Erstellen einer Story bewusst über Sticker und sichtbare Inhalte.',
        );
        return;
      case 'Missbrauch melden':
        _openSupportRequest(SupportRequestType.safety);
        return;
      case 'Sicherheitsregeln':
        _showSettingsInfo(
          title: 'Sicherheitsregeln',
          icon: Icons.rule_rounded,
          body:
              'Nutze plaqa nur für sachliche Kontaktaufnahme rund um Fahrzeuge.\n\n'
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
      case 'Gemeldete Vorfälle':
        _showSettingsInfo(
          title: 'Gemeldete Vorfälle',
          icon: Icons.assignment_outlined,
          body:
              'Hier werden künftig deine gemeldeten Sicherheits- und Missbrauchsvorfälle nachvollziehbar angezeigt.\n\n'
              'Aktuell werden keine Produktionsdaten lokal geladen. Für den Release braucht dieser Bereich eine sichere serverseitige Übersicht.',
        );
        return;
      case 'Konto-Warnungen':
        _showSettingsInfo(
          title: 'Konto-Warnungen',
          icon: Icons.warning_amber_rounded,
          body:
              'Warnungen, Einschränkungen und Sperrstatus sollen hier transparent erscheinen.\n\n'
              'Der Status muss serverseitig gesetzt werden und darf nicht vom Client manipulierbar sein.',
        );
        return;
      case 'Vertrauensstatus':
        _showSettingsInfo(
          title: 'Vertrauensstatus',
          icon: Icons.verified_outlined,
          body:
              'Der Vertrauensstatus bündelt später Verifizierung, Missbrauchsfälle und Kontosicherheit.\n\n'
              'Aktuell zeigt plaqa Verifizierung und Sicherheitsinformationen getrennt an.',
        );
        return;
      case 'Missbrauchsschutz':
        _showSettingsInfo(
          title: 'Missbrauchsschutz',
          icon: Icons.security_rounded,
          body:
              'plaqa schützt Kontaktanfragen, Hinweise und Chats durch Zugriffsschutz, Blockierungen, Limits und manuelle Prüfpfade.\n\n'
              'Falsche Meldungen, Spam, Belästigung und Veröffentlichung fremder Daten können zu Einschränkungen oder Kontosperren führen.',
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
              '3. Ein bestätigtes Fahrzeug ist nur für Kontaktanfragen über die Kennzeichensuche erforderlich.\n'
              '4. Storys und Chats sind nur für angenommene Kontakte vorgesehen.',
        );
        return;
      case 'Sprache':
        _showSettingsInfo(
          title: 'Sprache',
          icon: Icons.language_rounded,
          body:
              'Deutsch ist aktuell die aktive Sprache.\n\n'
              'Englisch und Türkisch sind sinnvoll vorbereitet, werden aber erst nach vollständiger Übersetzung und QA aktiviert.',
        );
        return;
      case 'Designmodus':
        _showSettingsInfo(
          title: 'Designmodus',
          icon: Icons.dark_mode_outlined,
          body:
              'plaqa nutzt aktuell bewusst den dunklen Premium-Modus.\n\n'
              'Systemmodus oder weitere Designs können später ergänzt werden, sollten aber das aktuelle plaqa-Design nicht verwässern.',
        );
        return;
      case 'Haptik & Töne':
        _showSettingsInfo(
          title: 'Haptik & Töne',
          icon: Icons.vibration_rounded,
          body:
              'Vibration, Haptik und Nachrichtentöne sind als Komfortbereich vorbereitet.\n\n'
              'Eine echte Einstellung muss später mit den jeweiligen Chat- und Benachrichtigungsevents verbunden werden.',
        );
        return;
      case 'Entfernung & Standardland':
        _showSettingsInfo(
          title: 'Entfernung & Standardland',
          icon: Icons.explore_outlined,
          body:
              'Entfernungen werden für plaqa in Kilometern gedacht.\n\n'
              'Das Standardland für Kennzeichen kann später auf Deutschland, Österreich oder Schweiz gesetzt werden. Bis dahin bleibt die Auswahl direkt im jeweiligen Bereich sichtbar.',
        );
        return;
      case 'Problem melden':
        _openSupportRequest(SupportRequestType.problem);
        return;
      case 'Verifizierungsproblem':
        _openSupportRequest(SupportRequestType.verification);
        return;
      case 'Feedback senden':
        _openSupportRequest(SupportRequestType.feedback);
        return;
      default:
        _showComingSoon(title);
    }
  }

  Future<void> _updateNotificationPreference({
    required bool value,
    required ValueChanged<bool> applyValue,
  }) async {
    if (value) {
      final allowed = await PushNotificationService.instance
          .requestPermissionAndSync();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erlaube Mitteilungen in den Systemeinstellungen, um sie zu aktivieren.',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      applyValue(value);
    });

    await _saveNotificationSettings();
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

  Future<void> _loadUserSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    try {
      final settings = await _userSettingsRepository.load(userId);
      if (!mounted) {
        return;
      }

      setState(() {
        _visibilitySettings = settings.visibility;
        _contactFilterSettings = settings.contactFilters;
        _chatPrivacySettings = settings.chatPrivacy;
        _storyPrivacySettings = settings.storyPrivacy;
        _appPreferenceSettings = settings.appPreferences;
      });
      await AppRuntimePreferences.instance.applyAndPersist(
        settings.appPreferences,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Datenschutz- und Komforteinstellungen konnten nicht geladen werden.',
          ),
        ),
      );
    }
  }

  Future<void> _saveNotificationSettings() async {
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

  Future<bool> _saveVisibilitySettings(
    String title,
    VisibilitySettings settings,
  ) {
    return _saveUserSettings(
      title: title,
      applyValue: () => _visibilitySettings = settings,
      save: (userId) => Future.wait([
        _userSettingsRepository.saveVisibility(userId, settings),
        _profileRepository.applyVisibilitySettings(
          uid: userId,
          profileVisibility: settings.profileVisibility,
          showVehicle: settings.showVehicle,
          showRegion: settings.showRegion,
          showPlate: settings.showPlate,
          allowContactRequests: settings.allowContactRequests,
        ),
      ]),
    );
  }

  Future<bool> _saveContactFilterSettings(
    String title,
    ContactFilterSettings settings,
  ) {
    return _saveUserSettings(
      title: title,
      applyValue: () => _contactFilterSettings = settings,
      save: (userId) =>
          _userSettingsRepository.saveContactFilters(userId, settings),
    );
  }

  Future<bool> _saveChatPrivacySettings(
    String title,
    ChatPrivacySettings settings,
  ) {
    return _saveUserSettings(
      title: title,
      applyValue: () => _chatPrivacySettings = settings,
      save: (userId) =>
          _userSettingsRepository.saveChatPrivacy(userId, settings),
    );
  }

  Future<bool> _saveStoryPrivacySettings(
    String title,
    StoryPrivacySettings settings,
  ) {
    return _saveUserSettings(
      title: title,
      applyValue: () => _storyPrivacySettings = settings,
      save: (userId) =>
          _userSettingsRepository.saveStoryPrivacy(userId, settings),
    );
  }

  Future<bool> _saveAppPreferenceSettings(
    String title,
    AppPreferenceSettings settings,
  ) {
    return _saveUserSettings(
      title: title,
      applyValue: () {
        _appPreferenceSettings = settings;
        AppRuntimePreferences.instance.apply(settings);
      },
      save: (userId) =>
          _userSettingsRepository.saveAppPreferences(userId, settings),
    );
  }

  Future<bool> _saveUserSettings({
    required String title,
    required VoidCallback applyValue,
    required Future<void> Function(String userId) save,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Melde dich erneut an, um diese Einstellung zu speichern.',
          ),
        ),
      );
      return false;
    }

    setState(applyValue);

    try {
      await save(userId);
      if (!mounted) {
        return false;
      }
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      await _loadUserSettings();
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$title konnte nicht gespeichert werden. Bitte versuche es erneut.',
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: CaRismaDesignTokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Abmelden?',
            style: TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Du wirst von diesem Gerät abgemeldet und kommst zurück zum Login.',
            style: TextStyle(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.78),
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
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.74,
                  ),
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
    String? description,
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CaRismaLicensesScreen()),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaRismaLegalContentScreen.forTitle(title: title),
      ),
    );
  }

  void _openAccountSecurity() {
    final currentUser = FirebaseAuth.instance.currentUser;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountSecurityScreen(
          initialAccount: currentUser == null
              ? null
              : AuthAccountSnapshot.fromUser(currentUser),
          onLogout: _confirmLogout,
          onRequestAccountDeletion: () {
            _showAccountDeletionRequestDialog();
          },
          onOpenSupport: _openSupport,
        ),
      ),
    );
  }

  void _openProfileManagement(ProfileSettingsArea area) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (area) {
          ProfileSettingsArea.personalData => ProfileScreen(
            userState: widget.userState,
            initialEntry: ProfileEditorEntry.personalData,
          ),
          ProfileSettingsArea.documents => ProfileScreen(
            userState: widget.userState,
            initialEntry: ProfileEditorEntry.documents,
          ),
          ProfileSettingsArea.vehicles => ProfileVerificationSettingsScreen(
            userState: widget.userState,
            area: ProfileSettingsArea.vehicles,
          ),
        },
      ),
    );
  }

  void _openVisibilityAndDiscovery() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisibilitySettingsScreen(
          initialSettings: _visibilitySettings,
          onChanged: _saveVisibilitySettings,
        ),
      ),
    );
  }

  void _openContactRequestFilters() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactRequestSettingsScreen(
          initialSettings: _contactFilterSettings,
          onChanged: _saveContactFilterSettings,
        ),
      ),
    );
  }

  void _openChatPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPrivacySettingsScreen(
          initialSettings: _chatPrivacySettings,
          onChanged: _saveChatPrivacySettings,
        ),
      ),
    );
  }

  void _openStoryPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPrivacySettingsScreen(
          initialSettings: _storyPrivacySettings,
          onChanged: _saveStoryPrivacySettings,
        ),
      ),
    );
  }

  void _openPrivacy() {
    _openDetailPage(
      icon: Icons.privacy_tip_rounded,
      title: 'Datenschutz',
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
        _SettingsDetailItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Datenschutz-Präferenzen',
          description:
              'Sichtbarkeit, Kontaktaufnahme und Privatsphäre bündeln.',
        ),
        _SettingsDetailItem(
          icon: Icons.ads_click_outlined,
          title: 'Werbung & Tracking',
          description: 'Aktuellen Status zu Werbung und Tracking anzeigen.',
        ),
      ],
      onItemTap: (title) {
        if (title == 'Datenexport anfordern' ||
            title == 'Gespeicherte Daten einsehen' ||
            title == 'Blockierte Nutzer' ||
            title == 'Einwilligungen verwalten' ||
            title == 'Datenschutz-Präferenzen' ||
            title == 'Werbung & Tracking') {
          _openSettingsInfo(title);
          return;
        }

        _showComingSoon(title);
      },
    );
  }

  void _openSafetyCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _SafetyCenterSettingsScreen(userState: widget.userState),
      ),
    );
  }

  void _openAppComfort() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppComfortSettingsScreen(
          initialSettings: _appPreferenceSettings,
          onChanged: _saveAppPreferenceSettings,
        ),
      ),
    );
  }

  void _openSupportRequest(SupportRequestType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SupportRequestScreen(type: type)),
    );
  }

  void _openSupport() {
    _openDetailPage(
      icon: Icons.support_agent_rounded,
      title: 'Support',
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
          icon: Icons.health_and_safety_outlined,
          title: 'Sicherheitsproblem melden',
          description:
              'Missbrauch, Bedrohungen oder gefährdende Inhalte melden.',
        ),
        _SettingsDetailItem(
          icon: Icons.verified_user_outlined,
          title: 'Verifizierungsproblem',
          description: 'Hilfe bei Identitäts- oder Fahrzeugnachweisen.',
        ),
        _SettingsDetailItem(
          icon: Icons.feedback_outlined,
          title: 'Feedback senden',
          description: 'Teile Verbesserungsvorschläge für plaqa.',
        ),
      ],
      onItemTap: (title) {
        final Widget screen = switch (title) {
          'Hilfe & FAQ' => const SupportFaqScreen(),
          'Problem melden' => const SupportRequestScreen(
            type: SupportRequestType.problem,
          ),
          'Sicherheitsproblem melden' => const SupportRequestScreen(
            type: SupportRequestType.safety,
          ),
          'Verifizierungsproblem' => const SupportRequestScreen(
            type: SupportRequestType.verification,
          ),
          'Feedback senden' => const SupportRequestScreen(
            type: SupportRequestType.feedback,
          ),
          _ => const SupportFaqScreen(),
        };
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen));
      },
    );
  }

  void _openLegal() {
    _openDetailPage(
      icon: Icons.description_rounded,
      title: 'Rechtliches',
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
          icon: Icons.shield_outlined,
          title: 'Community-Richtlinien',
          description: 'Verhaltensregeln und Schutz vor Missbrauch.',
        ),
        _SettingsDetailItem(
          icon: Icons.business_rounded,
          title: 'Impressum',
          description: 'Anbieterkennzeichnung und Kontaktinformationen.',
        ),
        _SettingsDetailItem(
          icon: Icons.info_outline_rounded,
          title: 'Über plaqa',
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
    final contentTopInset = CaRismaDesignTokens.mainScreenTopInset + 8;
    final contentBottomInset =
        CaRismaDesignTokens.mainScreenBottomInset + keyboardInset;

    return CaRismaBackground(
      child: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                contentTopInset,
                20,
                contentBottomInset,
              ),
              sliver: SliverList.list(
                children: [
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
                    title: 'Profil & Verifizierung',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _SettingsRow(
                        icon: Icons.person_rounded,
                        title: 'Persönliche Daten',
                        description:
                            'Name, Profilbild und persönliche Angaben bearbeiten.',
                        onTap: () => _openProfileManagement(
                          ProfileSettingsArea.personalData,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.upload_file_rounded,
                        title: 'Dokumente hochladen',
                        description:
                            'Identität und Fahrzeugbezug sicher nachweisen.',
                        onTap: () => _openProfileManagement(
                          ProfileSettingsArea.documents,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.directions_car_rounded,
                        title: 'Fahrzeuge & Kennzeichen',
                        description:
                            'Fahrzeug, Kennzeichen und Sichtbarkeit verwalten.',
                        onTap: () => _openProfileManagement(
                          ProfileSettingsArea.vehicles,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SettingsGroupCard(
                    title: 'Privatsphäre',
                    icon: Icons.visibility_outlined,
                    children: [
                      _SettingsRow(
                        icon: Icons.visibility_outlined,
                        title: 'Sichtbarkeit',
                        description:
                            'Profil, Kennzeichen, Fahrzeugdaten und Anfragen steuern.',
                        onTap: _openVisibilityAndDiscovery,
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.filter_alt_outlined,
                        title: 'Kontaktanfragen',
                        description:
                            'Verifizierung, Anfragegründe und Ruhemodus vorbereiten.',
                        onTap: _openContactRequestFilters,
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        title: 'Chat-Privatsphäre',
                        description:
                            'Lesebestätigungen, Medien und Einmal-ansehen steuern.',
                        onTap: _openChatPrivacy,
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.auto_stories_outlined,
                        title: 'Story-Einstellungen',
                        description:
                            'Story-Sichtbarkeit, Antworten und Fahrzeugdaten vorbereiten.',
                        onTap: _openStoryPrivacy,
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
                            value: value,
                            applyValue: (nextValue) {
                              _notifyVerification = nextValue;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.tune_rounded,
                        title: 'App-Komfort',
                        description:
                            'Sprache, Design, Haptik und Standardland vorbereiten.',
                        onTap: _openAppComfort,
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
                        icon: Icons.tune_rounded,
                        title: 'App-Berechtigungen',
                        description:
                            'Kamera, Mikrofon, Standort, Kontakte, Medien und Mitteilungen.',
                        onTap: () => _openSettingsInfo('App-Berechtigungen'),
                      ),
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Sicherheitscenter',
                        description:
                            'Blockierungen, Vorfälle, Warnungen und Missbrauchsschutz.',
                        onTap: _openSafetyCenter,
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
                            'AGB, Datenschutz, Community-Richtlinien, Impressum, Lizenzen und Über plaqa.',
                        onTap: _openLegal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _AppVersionCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupCard extends StatefulWidget {
  const _SettingsGroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  State<_SettingsGroupCard> createState() => _SettingsGroupCardState();
}

class _SettingsGroupCardState extends State<_SettingsGroupCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _isExpanded,
            label: '${widget.title} ${_isExpanded ? 'einklappen' : 'öffnen'}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            CaRismaDesignTokens.bluePrimary,
                            CaRismaDesignTokens.bluePrimary,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.icon,
                      color: CaRismaDesignTokens.bluePrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: CaRismaDesignTokens.textPrimary.withValues(
                          alpha: 0.72,
                        ),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(children: widget.children),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
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
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
            ),
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
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CaRismaDesignTokens.textPrimary.withValues(
                          alpha: 0.66,
                        ),
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
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.66),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsStatusLine {
  const _SettingsStatusLine({
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
    required this.statusColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final String status;
  final Color statusColor;
}

class _SettingsStatusOverviewScreen extends StatelessWidget {
  const _SettingsStatusOverviewScreen({
    required this.title,
    required this.icon,
    required this.intro,
    required this.items,
  });

  final String title;
  final IconData icon;
  final String intro;
  final List<_SettingsStatusLine> items;

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
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      intro,
                      style: TextStyle(
                        color: CaRismaDesignTokens.textPrimary.withValues(
                          alpha: 0.72,
                        ),
                        fontWeight: FontWeight.w700,
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SettingsDialogStatusCard(
                          icon: item.icon,
                          iconColor: item.statusColor,
                          title: item.title,
                          body: item.body,
                          status: item.status,
                          statusColor: item.statusColor,
                          boxedIcon: true,
                        ),
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

class _SettingsDialogStatusCard extends StatelessWidget {
  const _SettingsDialogStatusCard({
    required this.icon,
    required this.title,
    required this.body,
    this.iconColor = CaRismaDesignTokens.bluePrimary,
    this.status,
    this.statusColor = CaRismaDesignTokens.bluePrimary,
    this.boxedIcon = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String? status;
  final Color statusColor;
  final bool boxedIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (boxedIcon)
            CaRismaBlueIconBox(icon: icon, size: 44, iconSize: 22)
          else
            Icon(icon, color: iconColor, size: 22),
          SizedBox(width: boxedIcon ? 12 : 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: CaRismaDesignTokens.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    if (status case final value?) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.66,
                    ),
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                    fontSize: 12.5,
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

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.10,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/plaqa_app_icon.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                '${CaRismaAppConfig.appName} · Version ${CaRismaAppConfig.appVersion}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.72,
                  ),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppPermissionsSettingsScreen extends StatefulWidget {
  const _AppPermissionsSettingsScreen();

  @override
  State<_AppPermissionsSettingsScreen> createState() =>
      _AppPermissionsSettingsScreenState();
}

class _AppPermissionsSettingsScreenState
    extends State<_AppPermissionsSettingsScreen>
    with WidgetsBindingObserver {
  final AppPermissionService _permissionService = AppPermissionService();

  AppPermissionSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isOpeningSettings = false;

  static const List<_AppPermissionDefinition> _definitions = [
    _AppPermissionDefinition(
      kind: AppPermissionKind.camera,
      icon: Icons.camera_alt_outlined,
      title: 'Kamera',
      description: 'Storys, Chatmedien und Meldefotos aufnehmen.',
    ),
    _AppPermissionDefinition(
      kind: AppPermissionKind.microphone,
      icon: Icons.mic_none_rounded,
      title: 'Mikrofon',
      description: 'Sprachmemos und Videos mit Ton aufnehmen.',
    ),
    _AppPermissionDefinition(
      kind: AppPermissionKind.location,
      icon: Icons.location_on_outlined,
      title: 'Standort',
      description:
          'Kennzeichensuche im Radius, Standortnachrichten und Hinweisort.',
    ),
    _AppPermissionDefinition(
      kind: AppPermissionKind.media,
      icon: Icons.photo_library_outlined,
      title: 'Fotos und Videos',
      description: 'Aktiv ausgewählte Medien aus der Galerie verwenden.',
    ),
    _AppPermissionDefinition(
      kind: AppPermissionKind.contacts,
      icon: Icons.contact_phone_outlined,
      title: 'Kontakte',
      description: 'Nur aktiv ausgewählte Kontaktinformationen teilen.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOpeningSettings) {
      _loadStatus();
    }
    if (state == AppLifecycleState.resumed && _isOpeningSettings) {
      setState(() => _isOpeningSettings = false);
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final snapshot = await _permissionService.loadStatus();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } on AppPermissionServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openSystemSettings() async {
    if (_isOpeningSettings) return;
    setState(() => _isOpeningSettings = true);

    try {
      await _permissionService.openSystemSettings();
    } on AppPermissionServiceException catch (error) {
      if (!mounted) return;
      setState(() => _isOpeningSettings = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: CaRismaSubPageHeader(
                  icon: Icons.tune_rounded,
                  title: 'App-Berechtigungen',
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: CaRismaDesignTokens.bluePrimary,
                  backgroundColor: CaRismaDesignTokens.card,
                  onRefresh: _loadStatus,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                    children: [
                      if (_isLoading && snapshot == null)
                        const _AppPermissionLoadingCard()
                      else if (_errorMessage case final error?)
                        _AppPermissionErrorCard(
                          message: error,
                          onRetry: _loadStatus,
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: List.generate(_definitions.length, (
                              index,
                            ) {
                              final definition = _definitions[index];
                              final state =
                                  snapshot?.stateOf(definition.kind) ??
                                  AppPermissionState.unavailable;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _definitions.length - 1
                                      ? 0
                                      : 10,
                                ),
                                child: _AppPermissionTile(
                                  definition: definition,
                                  state: state,
                                ),
                              );
                            }),
                          ),
                        ),
                      const SizedBox(height: 14),
                      _AppPermissionActionButton(
                        icon: Icons.refresh_rounded,
                        label: _isLoading
                            ? 'Status wird aktualisiert'
                            : 'Status aktualisieren',
                        enabled: !_isLoading,
                        onTap: _loadStatus,
                      ),
                      const SizedBox(height: 10),
                      _AppPermissionActionButton(
                        icon: Icons.settings_outlined,
                        label: 'App-Einstellungen öffnen',
                        enabled: !_isOpeningSettings,
                        isPrimary: true,
                        onTap: _openSystemSettings,
                      ),
                    ],
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

class _AppPermissionDefinition {
  const _AppPermissionDefinition({
    required this.kind,
    required this.icon,
    required this.title,
    required this.description,
  });

  final AppPermissionKind kind;
  final IconData icon;
  final String title;
  final String description;
}

class _AppPermissionTile extends StatelessWidget {
  const _AppPermissionTile({required this.definition, required this.state});

  final _AppPermissionDefinition definition;
  final AppPermissionState state;

  String get _statusLabel => switch (state) {
    AppPermissionState.granted => 'Erlaubt',
    AppPermissionState.denied => 'Nicht erlaubt',
    AppPermissionState.restricted => 'Eingeschränkt',
    AppPermissionState.permanentlyDenied => 'Dauerhaft abgelehnt',
    AppPermissionState.notDetermined => 'Noch nicht angefragt',
    AppPermissionState.notRequired => 'Nicht erforderlich',
    AppPermissionState.unavailable => 'Nicht verfügbar',
  };

  Color get _statusColor => switch (state) {
    AppPermissionState.granted => CaRismaDesignTokens.success,
    AppPermissionState.denied ||
    AppPermissionState.permanentlyDenied => CaRismaDesignTokens.danger,
    AppPermissionState.restricted ||
    AppPermissionState.notRequired => CaRismaDesignTokens.bluePrimary,
    AppPermissionState.notDetermined ||
    AppPermissionState.unavailable => CaRismaDesignTokens.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CaRismaBlueIconBox(icon: definition.icon, size: 44, iconSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  definition.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.64,
                    ),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusColor.withValues(alpha: 0.46),
                    ),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
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

class _AppPermissionActionButton extends StatelessWidget {
  const _AppPermissionActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? CaRismaDesignTokens.bluePrimary
        : CaRismaDesignTokens.textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: isPrimary ? 0.92 : 0.42),
              width: isPrimary ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled
                        ? Colors.white
                        : CaRismaDesignTokens.textPrimary.withValues(
                            alpha: 0.42,
                          ),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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

class _AppPermissionLoadingCard extends StatelessWidget {
  const _AppPermissionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.all(22),
      child: Center(
        child: CircularProgressIndicator(
          color: CaRismaDesignTokens.bluePrimary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

class _AppPermissionErrorCard extends StatelessWidget {
  const _AppPermissionErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: CaRismaDesignTokens.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.74),
                fontWeight: FontWeight.w700,
                height: 1.34,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: const Icon(
              Icons.refresh_rounded,
              color: CaRismaDesignTokens.bluePrimary,
            ),
            tooltip: 'Erneut versuchen',
          ),
        ],
      ),
    );
  }
}

class _SafetyCenterSettingsScreen extends StatefulWidget {
  const _SafetyCenterSettingsScreen({required this.userState});

  final AppUserState userState;

  @override
  State<_SafetyCenterSettingsScreen> createState() =>
      _SafetyCenterSettingsScreenState();
}

class _SafetyCenterSettingsScreenState
    extends State<_SafetyCenterSettingsScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final Set<String> _busyChatIds = <String>{};

  String get _currentUserId {
    final authUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return authUserId.isNotEmpty ? authUserId : widget.userState.userId;
  }

  Future<void> _unblock(ChatRecord chat) async {
    final userId = _currentUserId.trim();

    if (userId.isEmpty || _busyChatIds.contains(chat.id)) return;

    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Kontakt entblocken?',
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          '${chat.displayNameFor(userId)} kann dir danach wieder Nachrichten senden.',
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.76),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              overlayColor: Colors.transparent,
              foregroundColor: CaRismaDesignTokens.textPrimary.withValues(
                alpha: 0.78,
              ),
            ),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CaRismaDesignTokens.bluePrimary,
              foregroundColor: Colors.white,
              overlayColor: Colors.transparent,
            ),
            child: const Text('Entblocken'),
          ),
        ],
      ),
    );

    if (shouldUnblock != true || !mounted) return;

    setState(() => _busyChatIds.add(chat.id));

    try {
      await _chatRepository.unblockChat(chatId: chat.id, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Kontakt wurde entblockt.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der Kontakt konnte nicht entblockt werden. Bitte versuche es erneut.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyChatIds.remove(chat.id));
      }
    }
  }

  String _accountStatusTitle() {
    final status = widget.userState.accountStatus;

    if (status.isSuspended) return 'Konto gesperrt';
    if (status.isRestricted) return 'Konto eingeschränkt';
    if (status.isDeleted) return 'Konto gelöscht';
    return 'Konto aktiv';
  }

  String _accountStatusDescription() {
    final status = widget.userState.accountStatus;
    final reason = status.reason?.trim();
    final parts = <String>['Status: ${status.stateLabel}'];

    if (reason != null && reason.isNotEmpty) {
      parts.add('Grund: $reason');
    }
    if (status.restrictedUntil != null) {
      parts.add('Einschränkung bis ${_formatDateTime(status.restrictedUntil)}');
    }
    if (status.suspendedUntil != null) {
      parts.add('Sperre bis ${_formatDateTime(status.suspendedUntil)}');
    }

    return parts.join('\n');
  }

  String _trustStatusDescription() {
    final status = widget.userState.accountStatus;

    if (status.isVerified) {
      return 'Dein Konto ist verifiziert. Sicherheitswarnungen werden separat angezeigt.';
    }
    if (status.isVerificationPending) {
      return 'Deine Verifizierung ist ausstehend. Der endgültige Vertrauensstatus folgt nach Prüfung.';
    }
    return 'Dein Konto ist noch nicht verifiziert. Private Dokumente bleiben geschützt und werden nur für die Prüfung verwendet.';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Datum nicht verfügbar';

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year}, $hour:$minute Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final userId = _currentUserId.trim();
    final stream = userId.isEmpty
        ? Stream<List<ChatRecord>>.value(const <ChatRecord>[])
        : _chatRepository.watchBlockedChats(userId: userId);
    final activeModerationActions = widget.userState.activeModerationActions;
    final warningActions = activeModerationActions
        .where(
          (action) =>
              action.type == ModerationActionType.warning ||
              action.type == ModerationActionType.restriction ||
              action.type == ModerationActionType.suspension ||
              action.type == ModerationActionType.accountDeletion ||
              action.type == ModerationActionType.manualReview,
        )
        .toList();
    final incidentActions = activeModerationActions
        .where(
          (action) =>
              action.type == ModerationActionType.reportConfirmed ||
              action.type == ModerationActionType.reportDismissed,
        )
        .toList();

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              CaRismaDesignTokens.mainScreenBottomInset + 10 + keyboardInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaSubPageHeader(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Sicherheitscenter',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _SecurityCenterInfoTile(
                        icon: widget.userState.canUseApp
                            ? Icons.verified_user_outlined
                            : Icons.gpp_maybe_outlined,
                        title: _accountStatusTitle(),
                        description: _accountStatusDescription(),
                        accentColor: widget.userState.canUseApp
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 10),
                      _SecurityCenterInfoTile(
                        icon: Icons.verified_outlined,
                        title: 'Vertrauensstatus',
                        description: _trustStatusDescription(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SecurityCenterSectionCard(
                  icon: Icons.block_rounded,
                  title: 'Blockierte Nutzer/Chats',
                  child: StreamBuilder<List<ChatRecord>>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: CaRismaDesignTokens.bluePrimary,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return const _SecurityCenterInfoTile(
                          icon: Icons.cloud_off_rounded,
                          title: 'Blockierungen nicht geladen',
                          description:
                              'Bitte prüfe deine Verbindung und versuche es erneut.',
                        );
                      }

                      final blockedChats =
                          snapshot.data ?? const <ChatRecord>[];

                      if (blockedChats.isEmpty) {
                        return const _SecurityCenterInfoTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Keine blockierten Nutzer',
                          description:
                              'Blockierte Kontakte und Chats werden hier angezeigt.',
                        );
                      }

                      return Column(
                        children: List.generate(blockedChats.length, (index) {
                          final chat = blockedChats[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == blockedChats.length - 1 ? 0 : 10,
                            ),
                            child: _SecurityBlockedChatTile(
                              chat: chat,
                              userId: userId,
                              isBusy: _busyChatIds.contains(chat.id),
                              onUnblock: () => _unblock(chat),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _SecurityCenterSectionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Warnungen & Vorfälle',
                  child: Column(
                    children: [
                      if (warningActions.isEmpty)
                        const _SecurityCenterInfoTile(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Keine Konto-Warnungen',
                          description:
                              'Aktuell liegen keine aktiven Warnungen, Einschränkungen oder Sperren vor.',
                          accentColor: Color(0xFF22C55E),
                        )
                      else
                        ...warningActions.map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SecurityCenterInfoTile(
                              icon: Icons.warning_amber_rounded,
                              title: action.typeLabel,
                              description:
                                  '${action.reasonLabel}\n${_formatDateTime(action.createdAt)}',
                              accentColor: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      if (warningActions.isEmpty) const SizedBox(height: 10),
                      _SecurityCenterInfoTile(
                        icon: Icons.assignment_outlined,
                        title: incidentActions.isEmpty
                            ? 'Keine gemeldeten Vorfälle'
                            : 'Gemeldete Vorfälle',
                        description: incidentActions.isEmpty
                            ? 'Es gibt aktuell keine sichtbaren Sicherheits- oder Missbrauchsvorfälle.'
                            : incidentActions
                                  .map(
                                    (action) =>
                                        '${action.typeLabel}: ${action.reasonLabel}',
                                  )
                                  .join('\n'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _SecurityCenterSectionCard(
                  icon: Icons.rule_rounded,
                  title: 'Missbrauchsschutz',
                  child: Column(
                    children: [
                      _SecurityCenterInfoTile(
                        icon: Icons.edit_note_rounded,
                        title: 'Sachlich bleiben',
                        description:
                            'Hinweise und Anfragen müssen echt, respektvoll und nachvollziehbar sein.',
                      ),
                      SizedBox(height: 10),
                      _SecurityCenterInfoTile(
                        icon: Icons.block_rounded,
                        title: 'Blockierungen wirken sofort',
                        description:
                            'Blockierte Nutzer können in diesem Chat keine neuen Nachrichten oder Anhänge senden.',
                      ),
                      SizedBox(height: 10),
                      _SecurityCenterInfoTile(
                        icon: Icons.report_problem_outlined,
                        title: 'Meldungen werden geprüft',
                        description:
                            'Missbrauch kann zu Einschränkungen oder einer Sperrung des Kontos führen.',
                      ),
                    ],
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

class _SecurityCenterSectionCard extends StatelessWidget {
  const _SecurityCenterSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SecurityCenterInfoTile extends StatelessWidget {
  const _SecurityCenterInfoTile({
    required this.icon,
    required this.title,
    required this.description,
    this.accentColor = CaRismaDesignTokens.bluePrimary,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: CaRismaDesignTokens.card,
              border: Border.all(color: accentColor.withValues(alpha: 0.34)),
            ),
            child: Icon(icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.66,
                    ),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
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

class _SecurityBlockedChatTile extends StatelessWidget {
  const _SecurityBlockedChatTile({
    required this.chat,
    required this.userId,
    required this.isBusy,
    required this.onUnblock,
  });

  final ChatRecord chat;
  final String userId;
  final bool isBusy;
  final VoidCallback onUnblock;

  String _formatBlockedAt(DateTime? value) {
    if (value == null) return 'Blockiert';

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return 'Blockiert seit $day.$month.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = chat.profilePhotoUrlFor(userId)?.trim() ?? '';
    final vehicle = <String>[
      chat.vehicleModelLabel.trim(),
      chat.displayPlate?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          _BlockedChatAvatar(
            imageUrl: imageUrl,
            label: chat.displayNameFor(userId),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.displayNameFor(userId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.isEmpty ? _formatBlockedAt(chat.blockedAt) : vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.64,
                    ),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (vehicle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatBlockedAt(chat.blockedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.48,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: isBusy ? null : onUnblock,
            style: OutlinedButton.styleFrom(
              foregroundColor: CaRismaDesignTokens.bluePrimary,
              side: BorderSide(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              overlayColor: Colors.transparent,
            ),
            child: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CaRismaDesignTokens.bluePrimary,
                    ),
                  )
                : const Text(
                    'Entblocken',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BlockedChatsSettingsScreen extends StatefulWidget {
  const _BlockedChatsSettingsScreen();

  @override
  State<_BlockedChatsSettingsScreen> createState() =>
      _BlockedChatsSettingsScreenState();
}

class _BlockedChatsSettingsScreenState
    extends State<_BlockedChatsSettingsScreen> {
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();
  final Set<String> _busyChatIds = <String>{};

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _unblock(ChatRecord chat) async {
    final userId = _currentUserId.trim();

    if (userId.isEmpty || _busyChatIds.contains(chat.id)) return;

    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Kontakt entblocken?',
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          '${chat.displayNameFor(userId)} kann dir danach wieder Nachrichten senden.',
          style: TextStyle(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.76),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entblocken'),
          ),
        ],
      ),
    );

    if (shouldUnblock != true || !mounted) return;

    setState(() => _busyChatIds.add(chat.id));

    try {
      await _chatRepository.unblockChat(chatId: chat.id, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Kontakt wurde entblockt.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der Kontakt konnte nicht entblockt werden. Bitte versuche es erneut.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyChatIds.remove(chat.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId.trim();
    final stream = userId.isEmpty
        ? Stream<List<ChatRecord>>.value(const <ChatRecord>[])
        : _chatRepository.watchBlockedChats(userId: userId);

    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: CaRismaSubPageHeader(
                  icon: Icons.block_rounded,
                  title: 'Blockierte Nutzer',
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ChatRecord>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: CaRismaDesignTokens.bluePrimary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const _BlockedChatsEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title:
                            'Blockierte Kontakte konnten nicht geladen werden',
                        description:
                            'Bitte prüfe deine Verbindung und versuche es erneut.',
                      );
                    }

                    final blockedChats = snapshot.data ?? const <ChatRecord>[];

                    if (blockedChats.isEmpty) {
                      return const _BlockedChatsEmptyState(
                        icon: Icons.person_outline_rounded,
                        title: 'Keine blockierten Nutzer',
                        description:
                            'Blockierte Kontakte werden hier angezeigt.',
                      );
                    }

                    return ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        CaRismaDesignTokens.mainScreenBottomInset + 10,
                      ),
                      itemCount: blockedChats.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chat = blockedChats[index];
                        final imageUrl =
                            chat.profilePhotoUrlFor(userId)?.trim() ?? '';
                        final details = <String>[
                          chat.vehicleModelLabel.trim(),
                          chat.displayPlate?.trim() ?? '',
                        ].where((value) => value.isNotEmpty).join(' · ');
                        final isBusy = _busyChatIds.contains(chat.id);

                        return GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              _BlockedChatAvatar(
                                imageUrl: imageUrl,
                                label: chat.displayNameFor(userId),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chat.displayNameFor(userId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: CaRismaDesignTokens.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (details.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        details,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: CaRismaDesignTokens.textPrimary
                                              .withValues(alpha: 0.62),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: isBusy ? null : () => _unblock(chat),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      CaRismaDesignTokens.bluePrimary,
                                  side: BorderSide(
                                    color: CaRismaDesignTokens.textPrimary
                                        .withValues(alpha: 0.14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  overlayColor: Colors.transparent,
                                ),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              CaRismaDesignTokens.bluePrimary,
                                        ),
                                      )
                                    : const Text(
                                        'Entblocken',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedChatAvatar extends StatelessWidget {
  const _BlockedChatAvatar({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fallback = label.trim().isEmpty
        ? '?'
        : label.trim().characters.first.toUpperCase();

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Center(
              child: Text(
                fallback,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  fallback,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _BlockedChatsEmptyState extends StatelessWidget {
  const _BlockedChatsEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 38),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CaRismaDesignTokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDetailScreen extends StatelessWidget {
  const _SettingsDetailScreen({
    required this.icon,
    required this.title,
    this.description,
    required this.items,
    required this.onItemTap,
  });

  final IconData icon;
  final String title;
  final String? description;
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
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              CaRismaDesignTokens.mainScreenBottomInset + 10 + keyboardInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaRismaSubPageHeader(
                  icon: icon,
                  title: title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                if (description case final text?) ...[
                  const SizedBox(height: 18),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: CaRismaDesignTokens.textPrimary.withValues(
                        alpha: 0.78,
                      ),
                      fontWeight: FontWeight.w700,
                      fontSize: 16.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 18),
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

class CaRismaLegalContentScreen extends StatefulWidget {
  CaRismaLegalContentScreen.forTitle({super.key, required String title})
    : _content = _LegalContent.forTitle(title);

  final _LegalContent _content;

  @override
  State<CaRismaLegalContentScreen> createState() =>
      _CaRismaLegalContentScreenState();
}

class _CaRismaLegalContentScreenState extends State<CaRismaLegalContentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  _LegalContent get _content => widget._content;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > 320;
    if (shouldShow == _showScrollToTop) {
      return;
    }

    setState(() => _showScrollToTop = shouldShow);
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        const CaRismaAuthBrandHeader(),
                        CaRismaAuthBackButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            color: CaRismaDesignTokens.bluePrimary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _content.versionLabel ?? _content.title,
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: CaRismaDesignTokens.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(_content.sections.length, (index) {
                      final section = _content.sections[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _content.sections.length - 1
                              ? 0
                              : 12,
                        ),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: _LegalSectionBlock(section: section),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              if (_showScrollToTop)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: CaRismaAuthBackButton(
                    onTap: _scrollToTop,
                    icon: Icons.arrow_upward_rounded,
                    semanticLabel: 'Nach oben',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: CaRismaDesignTokens.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          section.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
            height: 1.36,
          ),
        ),
      ],
    );
  }
}

class _LegalContent {
  const _LegalContent({
    required this.title,
    required this.icon,
    required this.sections,
    this.versionLabel,
  });

  final String title;
  final IconData icon;
  final List<_LegalSection> sections;
  final String? versionLabel;

  factory _LegalContent.forTitle(String title) {
    return switch (title) {
      'AGB' => const _LegalContent(
        title: 'AGB',
        icon: Icons.description_outlined,
        versionLabel: 'Aktuelle AGB-Version: ${LegalVersions.terms}',
        sections: [
          _LegalSection(
            title: 'Stand und Version',
            body:
                r'''Allgemeine Geschäftsbedingungen und Nutzungsbedingungen für plaqa

Stand: 22. August 2026
Version: 1.0.0''',
          ),
          _LegalSection(
            title: '1. Anbieter und Geltungsbereich',
            body: r'''1.1 Anbieter

Anbieter der mobilen App „plaqa“ ist:

Sehmus Yildirim
Auftreten unter der Bezeichnung plaqa
Bremer Straße 254e
21077 Hamburg
Deutschland

E-Mail: info@plaqa.de
Website: plaqa.de

nachfolgend „plaqa“, „Betreiber“ oder „wir“ genannt.

1.2 Geltungsbereich

Diese Allgemeinen Geschäftsbedingungen und Nutzungsbedingungen, nachfolgend „Nutzungsbedingungen“, gelten für die Registrierung und Nutzung der mobilen App plaqa sowie der damit verbundenen Dienste.

Sie regeln das Vertragsverhältnis zwischen plaqa und den registrierten Nutzern.

Abweichende Bedingungen eines Nutzers gelten nur, wenn plaqa ihrer Geltung ausdrücklich in Textform zugestimmt hat.

1.3 Einbeziehung der Nutzungsbedingungen

Der Nutzer muss diesen Nutzungsbedingungen bei der Registrierung ausdrücklich zustimmen. Die Nutzungsbedingungen können vor der Zustimmung eingesehen und gespeichert werden.

Mit Abschluss der Registrierung kommt zwischen plaqa und dem Nutzer ein Nutzungsvertrag zustande.

1.4 Weitere rechtliche Informationen

Ergänzend gelten insbesondere:

* die Datenschutzerklärung,
* das Impressum,
* gegebenenfalls Community-Richtlinien,
* gegebenenfalls besondere Bedingungen für kostenpflichtige Funktionen,
* gegebenenfalls App-Store-Bedingungen des jeweiligen Plattformanbieters.

Bei Widersprüchen zwischen diesen Nutzungsbedingungen und besonderen Bedingungen für eine bestimmte kostenpflichtige Leistung gehen die besonderen Bedingungen für diese Leistung vor.''',
          ),
          _LegalSection(
            title: '2. Gegenstand der App',
            body: r'''2.1 Zweck von plaqa

plaqa ist eine mobile Kommunikationsplattform zur geschützten Kontaktaufnahme rund um Fahrzeuge und Kennzeichen.

Die App kann insbesondere folgende Funktionen bereitstellen:

* Registrierung und Benutzerkonto,
* Nutzerprofile,
* Profilbilder,
* Fahrzeug- und Kennzeichendaten,
* freiwillige Verifizierung,
* Kennzeichen-Suche,
* Kontaktanfragen,
* Chats nach Annahme einer Kontaktanfrage,
* Storys,
* fahrzeugbezogene Hinweise und Meldungen,
* Standortfunktionen,
* Foto-, Kamera-, Video- und Mikrofonfunktionen,
* Teilen aktiv ausgewählter Kontakte und Dokumente,
* Blockier-, Melde-, Moderations- und Sicherheitsfunktionen.

Der konkrete Funktionsumfang richtet sich nach der jeweils verfügbaren App-Version, dem Betriebssystem, dem Land, den Geräteeinstellungen und gegebenenfalls dem gewählten Leistungsumfang.

2.2 Keine Garantie für Kontakt oder Auffindbarkeit

plaqa schuldet die technische Bereitstellung der jeweils angebotenen Funktionen im Rahmen dieser Nutzungsbedingungen.

plaqa schuldet insbesondere nicht:

* dass ein bestimmtes Kennzeichen registriert oder auffindbar ist,
* dass ein Suchergebnis angezeigt wird,
* dass ein Nutzer eine Kontaktanfrage annimmt,
* dass eine Nachricht gelesen oder beantwortet wird,
* dass eine Kontaktaufnahme erfolgreich ist,
* dass Nutzerangaben vollständig, richtig oder aktuell sind,
* dass sich ein Fahrzeug oder Nutzer tatsächlich an einem angezeigten oder angenommenen Ort befindet,
* dass ein Hinweis inhaltlich richtig ist,
* dass ein Konflikt zwischen Nutzern gelöst wird.

2.3 Keine Notfall- oder Behördendienstleistung

plaqa ist keine Notruf-, Warn-, Polizei-, Feuerwehr-, Rettungsdienst-, Pannenhilfe-, Abschlepp- oder Rechtsberatungs-App.

plaqa:

* nimmt keine Notrufe entgegen,
* alarmiert nicht automatisch Behörden oder Rettungskräfte,
* veranlasst keine Abschlepp- oder Pannenhilfe,
* ersetzt keine Unfallmeldung,
* ersetzt keine Strafanzeige,
* ersetzt keine Rechtsberatung,
* garantiert keine sofortige Kenntnisnahme einer Nachricht,
* überwacht keine Fahrzeuge oder Verkehrsgefahren in Echtzeit.

Bei Unfällen, Straftaten, akuten Gefahren, medizinischen Notfällen, Brandgefahren oder dringenden Verkehrsbehinderungen müssen Nutzer unmittelbar die zuständigen Behörden, Rettungsdienste oder sonstigen zuständigen Stellen kontaktieren.

Nutzer dürfen sich in dringenden Situationen nicht allein auf plaqa verlassen.''',
          ),
          _LegalSection(
            title: '3. Registrierung und Benutzerkonto',
            body: r'''3.1 Erforderlichkeit eines Kontos

Für die Nutzung wesentlicher Funktionen ist ein persönliches Benutzerkonto erforderlich.

Mehrere persönliche Konten sind nicht generell ausgeschlossen.

Mehrfachkonten zur Umgehung von Sperren, Beschränkungen, Blockierungen, Anfragelimits oder Sicherheitsmaßnahmen sind unzulässig.

3.2 Richtige Angaben

Der Nutzer ist verpflichtet, bei der Registrierung und während der Nutzung richtige, vollständige und aktuelle Angaben zu machen.

Der Nutzer darf insbesondere:

* keine fremde Identität verwenden,
* keine fremde E-Mail-Adresse unberechtigt verwenden,
* keine falsche Berechtigung für ein Fahrzeug behaupten,
* keine irreführenden Profil- oder Verifizierungsangaben machen,
* keine Daten verwenden, durch die eine Verwechslung mit einer anderen Person beabsichtigt wird.

Änderungen wesentlicher Angaben sind unverzüglich im Benutzerkonto zu aktualisieren, soweit die App eine entsprechende Funktion anbietet.

3.3 Persönliche Nutzung und Zugangsschutz

Das Benutzerkonto ist persönlich und darf nicht ohne Zustimmung von plaqa übertragen, verkauft, vermietet oder Dritten dauerhaft überlassen werden.

Der Nutzer muss:

* sichere Zugangsdaten verwenden,
* Zugangsdaten geheim halten,
* sein Endgerät angemessen schützen,
* unbefugte Zugriffe unverzüglich melden,
* sich auf fremden oder öffentlich zugänglichen Geräten abmelden.

Handlungen, die über das Konto vorgenommen werden, werden dem Kontoinhaber zugerechnet, soweit er sie selbst vorgenommen oder schuldhaft ermöglicht hat. Dies gilt nicht, wenn der Nutzer den Missbrauch nicht zu vertreten hat.

3.4 Sicherheitsmaßnahmen

plaqa darf angemessene Sicherheitsmaßnahmen verlangen, insbesondere:

* Bestätigung der E-Mail-Adresse,
* erneute Anmeldung,
* Passwortänderung,
* Mehrfaktor-Authentifizierung,
* Sicherheitsabfrage,
* Verifizierung bestimmter Angaben,
* vorübergehende Einschränkung auffälliger Zugriffe.

Bestehen konkrete Anhaltspunkte für einen unbefugten Zugriff, kann das Konto vorsorglich eingeschränkt werden, bis der Sachverhalt geklärt ist.''',
          ),
          _LegalSection(
            title: '4. Mindestalter und Nutzungsvoraussetzungen',
            body: r'''4.1 Mindestalter

Die Nutzung von plaqa ist nur Personen gestattet, die mindestens 16 Jahre alt sind.

plaqa richtet sich nicht an Kinder. Die Altersgrenze gilt für alle Konten und Community-Funktionen.

4.2 Minderjährige Nutzer

Sofern eine Nutzung durch Minderjährige zugelassen wird, dürfen diese plaqa nur nutzen, wenn:

* die gesetzlichen Voraussetzungen erfüllt sind,
* erforderliche Zustimmungen der Erziehungsberechtigten vorliegen,
* sie die Bedeutung der Nutzung und der Datenverarbeitung verstehen können,
* keine altersbedingten Einschränkungen des App Stores entgegenstehen.

plaqa kann einen angemessenen Alters- oder Zustimmungsnachweis verlangen, wenn konkrete Zweifel an der Erfüllung der Altersvoraussetzungen bestehen.

4.3 Weitere Voraussetzungen

Der Nutzer muss:

* geschäftsfähig oder wirksam vertreten sein,
* über ein kompatibles Endgerät verfügen,
* eine Internetverbindung besitzen,
* die erforderlichen Betriebssystemberechtigungen erteilen, soweit er entsprechende Funktionen nutzen möchte,
* diese Nutzungsbedingungen und die Datenschutzerklärung zur Kenntnis nehmen.

Einzelne Funktionen können ohne Standort-, Kamera-, Mikrofon-, Medien- oder Dateiberechtigung nicht oder nur eingeschränkt nutzbar sein.''',
          ),
          _LegalSection(
            title: '5. Allgemeine Nutzerpflichten',
            body: r'''5.1 Rechtmäßige und verantwortungsvolle Nutzung

Nutzer müssen plaqa rechtmäßig, sachlich und verantwortungsvoll verwenden.

Sie dürfen die App ausschließlich im Rahmen der vorgesehenen Funktionen und Zwecke nutzen.

5.2 Verantwortung für Angaben und Inhalte

Nutzer sind für die von ihnen:

* eingegebenen,
* hinterlegten,
* hochgeladenen,
* veröffentlichten,
* geteilten,
* übermittelten oder
* verlinkten

Angaben und Inhalte verantwortlich.

Dies umfasst insbesondere Profilangaben, Fahrzeugdaten, Kennzeichen, Bilder, Videos, Texte, Sprachnachrichten, Dokumente, Standortangaben, Kontaktinformationen, Storys, Chatnachrichten und Hinweise.

5.3 Rechte an Inhalten

Nutzer dürfen nur Inhalte verwenden, wenn sie:

* selbst Urheber oder Rechteinhaber sind,
* eine ausreichende Erlaubnis besitzen,
* auf einer sonstigen gesetzlichen Grundlage zur Nutzung berechtigt sind.

Nutzer müssen insbesondere Persönlichkeitsrechte, Datenschutzrechte, Urheberrechte, Markenrechte, Eigentumsrechte, Geschäftsgeheimnisse und sonstige Rechte Dritter beachten.

5.4 Schutz anderer Personen

Nutzer dürfen andere Personen nicht:

* belästigen,
* verfolgen,
* überwachen,
* bedrohen,
* einschüchtern,
* täuschen,
* beleidigen,
* erpressen,
* diskriminieren,
* öffentlich bloßstellen,
* gegen ihren erkennbaren Willen wiederholt kontaktieren.

5.5 Umgang mit empfangenen Informationen

Informationen, die Nutzer über plaqa erhalten, dürfen nur für den jeweiligen zulässigen Kommunikationszweck verwendet werden.

Insbesondere dürfen empfangene Kennzeichen-, Standort-, Profil- oder Kontaktdaten nicht:

* außerhalb des erforderlichen Zwecks gesammelt,
* systematisch ausgewertet,
* veröffentlicht,
* verkauft,
* für unerlaubte Werbung genutzt,
* zur Erstellung von Bewegungs- oder Persönlichkeitsprofilen verwendet,
* mit anderen Datenbeständen unzulässig zusammengeführt werden.''',
          ),
          _LegalSection(
            title: '6. Fahrzeugdaten und Kennzeichen',
            body: r'''6.1 Zulässige Fahrzeugangaben

Nutzer dürfen nur Fahrzeuge und Kennzeichen hinterlegen, die:

* ihnen gehören,
* von ihnen rechtmäßig genutzt werden,
* oder für deren Eintragung eine ausreichende Zustimmung oder Berechtigung besteht.

6.2 Keine Halterauskunft

plaqa stellt keine amtliche Halterauskunft bereit.

Ein in der App hinterlegtes Kennzeichen beweist nicht:

* das Eigentum am Fahrzeug,
* die Haltereigenschaft,
* die tatsächliche Verfügungsberechtigung,
* die Identität des aktuellen Fahrers,
* die Richtigkeit oder Aktualität der Fahrzeugangaben.

6.3 Verbotene Verwendung

Unzulässig sind insbesondere:

* Eintragung fremder Kennzeichen ohne Berechtigung,
* Vortäuschung einer Fahrzeugzuordnung,
* Nutzung von Kennzeichen zur Überwachung einer Person,
* systematische Suche nach bestimmten Personen,
* Erstellung von Bewegungsprofilen,
* Sammlung oder Weiterverkauf von Kennzeichendaten,
* automatisierte oder massenhafte Abfragen,
* Umgehung von Such-, Zeit-, Radius- oder Anfragelimits.

6.4 Prüfung und Nachweis

plaqa darf bei konkreten Zweifeln an einer Fahrzeugzuordnung einen angemessenen Nachweis verlangen.

Kann eine erforderliche Berechtigung nicht nachgewiesen werden, darf plaqa:

* die Fahrzeugangabe entfernen,
* das Kennzeichen sperren,
* die zugehörigen Funktionen einschränken,
* das Benutzerkonto vorübergehend oder dauerhaft sperren.''',
          ),
          _LegalSection(
            title: '7. Kennzeichen-Suche und Kontaktanfragen',
            body: r'''7.1 Zweck der Suche

Die Kennzeichen-Suche dient dazu, im Rahmen der vorgesehenen technischen und räumlich-zeitlichen Voraussetzungen eine geschützte Kontaktanfrage an ein zugeordnetes Nutzerkonto zu ermöglichen.

7.2 Räumliche und zeitliche Begrenzung

Die Suche kann insbesondere anhand eines räumlichen Radius und eines zeitlichen Aktivitätsfensters begrenzt werden.

Vorgesehen sind derzeit ungefähr:

* ein Suchradius von fünf Kilometern,
* ein Standort- oder Aktivitätsfenster von einer Stunde.

Der Server begrenzt den angeforderten Suchradius auf höchstens fünf Kilometer und berücksichtigt nur Fahrzeugstandorte, die höchstens eine Stunde alt sind. Die Entfernung wird aus den übermittelten Koordinaten berechnet.

Diese Werte stellen keine Garantie für eine genaue Position, Entfernung, Anwesenheit oder zeitliche Zuordnung dar.

7.3 Zulässiger Anlass

Kontaktanfragen dürfen nur bei einem berechtigten, nachvollziehbaren und sachlichen Anlass versendet werden.

Die App darf nicht genutzt werden, um andere Nutzer aus bloßer Neugier, zu Werbezwecken, zur Partnersuche oder gegen ihren erkennbaren Willen zu kontaktieren. plaqa ist keine Dating-App; Kontaktanfragen müssen einen sachlichen Fahrzeug- oder Community-Bezug haben.

7.4 Keine wiederholten unerwünschten Anfragen

Wurde eine Anfrage:

* abgelehnt,
* blockiert,
* als unerwünscht gemeldet,
* oder nicht innerhalb der vorgesehenen Zeit angenommen,

darf der Absender nicht durch weitere Konten, veränderte Kennzeichenangaben oder andere Funktionen versuchen, die Entscheidung zu umgehen.

7.5 Anfragelimits

plaqa darf angemessene Anfragelimits, Wartezeiten, Spamfilter und Sicherheitsbeschränkungen einsetzen.

Diese können insbesondere von folgenden Umständen abhängen:

* Anzahl vorheriger Anfragen,
* Ablehnungsquote,
* Meldungen,
* Kontostatus,
* Verifizierungsstatus,
* auffälligen Nutzungsmustern,
* technischen Sicherheitsmerkmalen.

Die Einzelheiten dürfen aus Sicherheitsgründen teilweise vertraulich bleiben, soweit Nutzer dadurch nicht unangemessen benachteiligt werden.''',
          ),
          _LegalSection(
            title: '8. Chat, Storys und sonstige Nutzerinhalte',
            body: r'''8.1 Chat

Ein Chat kann grundsätzlich erst nach Annahme einer Kontaktanfrage eröffnet werden.

Im Chat dürfen Nutzer je nach Funktionsumfang insbesondere Textnachrichten, Bilder, Videos, Sprachnachrichten, Dokumente, Standorte oder aktiv ausgewählte Kontaktdaten senden.

Der Nutzer muss vor jedem Versand prüfen, ob er zur Weitergabe berechtigt ist.

8.2 Verbotene Chatinhalte

Unzulässig sind insbesondere:

* Drohungen,
* Belästigungen,
* Beleidigungen,
* Erpressungen,
* Betrugsversuche,
* sexuelle Belästigung,
* Hassrede,
* Spam,
* unerlaubte Werbung,
* Schadsoftware,
* rechtswidrige Dateien,
* intime Inhalte ohne Einwilligung,
* Aufnahmen ohne erforderliche Zustimmung,
* vertrauliche oder fremde personenbezogene Daten ohne Rechtsgrundlage.

8.3 Storys

Storys können insbesondere aus Fotos, Videos, Texten, Stickern sowie Fahrzeug- oder Standortinformationen bestehen.

Nach der vorgesehenen Funktionsweise:

* sind Storys grundsätzlich 24 Stunden sichtbar,
* werden Storys grundsätzlich nur angenommenen Kontakten angezeigt,
* können Story-Aufrufe gespeichert und dem Ersteller angezeigt werden.

Storys erhalten beim Speichern einen Ablaufzeitpunkt nach 24 Stunden. Zugriffsregeln begrenzen die Sichtbarkeit auf die vorgesehene Zielgruppe; Aufrufe können dem Ersteller angezeigt werden. Screenshots werden nicht technisch verhindert.

Die zeitlich begrenzte Sichtbarkeit bedeutet nicht, dass Empfänger Storys nicht durch Screenshots, Bildschirmaufnahmen oder andere Mittel speichern können.

plaqa kann nicht garantieren, dass veröffentlichte Inhalte nach ihrer Anzeige nicht von anderen Nutzern gespeichert oder weiterverbreitet werden.

8.4 Inhalte Dritter

Ohne ausreichende Einwilligung oder sonstige Rechtsgrundlage dürfen Nutzer insbesondere keine Inhalte veröffentlichen, die:

* fremde Personen identifizierbar zeigen,
* private Gespräche offenlegen,
* fremde Kennzeichen gezielt hervorheben,
* private Anschriften oder Standorte offenlegen,
* vertrauliche Dokumente enthalten,
* Kinder oder besonders schutzbedürftige Personen beeinträchtigen,
* Rechte Dritter verletzen.

8.5 Keine allgemeine Vorabprüfung

plaqa ist nicht verpflichtet, sämtliche Nutzerinhalte vor ihrer Veröffentlichung oder Übermittlung allgemein zu kontrollieren.

plaqa kann Inhalte jedoch nach einer Meldung, bei einem konkreten Verdacht, durch Stichproben oder durch technische Sicherheitsmechanismen prüfen, soweit dies rechtlich zulässig ist.''',
          ),
          _LegalSection(
            title: '9. Verifizierung',
            body: r'''9.1 Zweck

plaqa kann eine freiwillige oder für bestimmte Funktionen erforderliche Verifizierung anbieten.

Die Verifizierung kann sich insbesondere beziehen auf:

* Identität,
* E-Mail-Adresse,
* Alter,
* Fahrzeugberechtigung,
* Kennzeichenzuordnung.

9.2 Verifizierungsunterlagen

Je nach Verfahren können Nutzer aufgefordert werden, Dokumente oder Aufnahmen bereitzustellen.

Nutzer dürfen:

* nur echte und unveränderte Nachweise verwenden,
* keine Dokumente anderer Personen ohne Berechtigung verwenden,
* keine Angaben manipulieren oder verdecken, soweit diese für die Prüfung erforderlich sind,
* nur die ausdrücklich angeforderten Informationen übermitteln.

Nicht benötigte Angaben sollen geschwärzt werden, soweit plaqa dies im jeweiligen Verfahren zulässt.

9.3 Bedeutung der Verifizierung

Eine erfolgreiche Verifizierung bestätigt nur, dass die im jeweiligen Prüfverfahren festgelegten Merkmale mit ausreichender Plausibilität geprüft wurden.

Sie ist keine Garantie dafür, dass:

* sämtliche Nutzerangaben richtig sind,
* die Person jederzeit das hinterlegte Fahrzeug führt,
* der Nutzer zuverlässig oder rechtstreu handelt,
* keine missbräuchliche Nutzung stattfindet,
* das Fahrzeug rechtlich oder technisch mangelfrei ist.

9.4 Ablehnung und Widerruf

plaqa darf eine Verifizierung ablehnen, zurücksetzen oder widerrufen, wenn:

* erforderliche Nachweise fehlen,
* Angaben widersprüchlich sind,
* Dokumente unleserlich oder offensichtlich verändert sind,
* konkrete Zweifel an der Echtheit bestehen,
* die geprüften Voraussetzungen später entfallen,
* der Verifizierungsstatus missbräuchlich verwendet wird.

Soweit möglich und rechtlich zulässig, wird der Nutzer über die wesentlichen Gründe informiert.''',
          ),
          _LegalSection(
            title: '10. Fahrzeugbezogene Hinweise und Meldungen',
            body: r'''10.1 Zulässige Hinweise

Hinweise müssen:

* einen nachvollziehbaren Fahrzeugbezug haben,
* nach bestem Wissen wahrheitsgemäß sein,
* sachlich formuliert sein,
* auf das erforderliche Maß beschränkt sein,
* einen zulässigen Zweck verfolgen.

10.2 Anonyme oder pseudonyme Darstellung

Ein Hinweis kann für den Empfänger ohne sichtbaren Absender oder unter einer pseudonymen Darstellung erscheinen.

Dies bedeutet nicht, dass der Hinweis gegenüber plaqa technisch vollständig anonym ist.

plaqa darf einen Hinweis intern mit Nutzerkonto, Nutzer-ID, Zeitstempel und Sicherheitsinformationen verknüpfen, soweit dies für:

* Betrieb,
* Sicherheit,
* Missbrauchsschutz,
* Bearbeitung von Beschwerden,
* Nachweisführung,
* Rechtsverteidigung,
* Erfüllung gesetzlicher Pflichten

erforderlich und zulässig ist.

10.3 Unzulässige Hinweise

Verboten sind insbesondere:

* bewusst falsche Tatsachenbehauptungen,
* falsche Anschuldigungen,
* Beleidigungen,
* Drohungen,
* Diskriminierungen,
* Rufschädigungen,
* Denunziationen,
* wiederholte unerwünschte Meldungen,
* erfundene Gefahren,
* öffentliche Bloßstellung,
* Veröffentlichung privater Informationen,
* Verwendung als Druck- oder Erpressungsmittel.

10.4 Keine Tatsachengarantie

plaqa prüft nicht zwingend jeden Hinweis vor der Übermittlung.

plaqa übernimmt keine Gewähr dafür, dass ein Hinweis:

* zutreffend,
* vollständig,
* aktuell,
* berechtigt oder
* rechtlich verwertbar

ist.

Nutzer dürfen Hinweise nicht ungeprüft als Beweis oder amtliche Feststellung behandeln.''',
          ),
          _LegalSection(
            title: '11. Verbotene Nutzung',
            body:
                r'''Unabhängig von weiteren Regelungen ist insbesondere untersagt:

1. die Nutzung zu rechtswidrigen Zwecken;
2. Stalking, Nachstellung, Überwachung oder systematische Verfolgung von Personen oder Fahrzeugen;
3. Belästigung, Bedrohung, Einschüchterung, Beleidigung, Erpressung oder Täuschung;
4. falsche Anschuldigungen oder bewusst unwahre Tatsachenbehauptungen;
5. Veröffentlichung oder Weitergabe fremder personenbezogener Daten ohne Rechtsgrundlage;
6. Hochladen rechtswidriger, extremistischer, volksverhetzender, gewaltverherrlichender oder diskriminierender Inhalte;
7. Verbreitung sexualisierter Inhalte ohne Einwilligung oder von Inhalten, die Minderjährige sexualisieren oder gefährden;
8. Verletzung von Urheber-, Marken-, Persönlichkeits-, Datenschutz- oder sonstigen Rechten;
9. Einsatz für unerlaubte Werbung, Spam, Kettennachrichten oder betrügerische Angebote;
10. automatisierte Nutzung durch Bots, Scraper, Crawler oder nicht genehmigte Schnittstellen;
11. Massenabfragen, Datensammlung, Datenhandel oder Erstellung eigener Kennzeichen- und Bewegungsdatenbanken;''',
          ),
          _LegalSection(
            title:
                '12. Umgehung von Sperren, Blockierungen, Altersgrenzen, Verifizierungen oder technischen Schutzmechanismen;',
            body: r'''''',
          ),
          _LegalSection(
            title:
                '13. Manipulation der Standortbestimmung oder anderer technischer Informationen zum Zweck der Täuschung oder Umgehung;',
            body: r'''''',
          ),
          _LegalSection(
            title:
                '14. Hochladen von Schadsoftware oder sonstige Beeinträchtigung der App-Infrastruktur;',
            body: r'''''',
          ),
          _LegalSection(
            title:
                '15. Ausspähen fremder Konten oder unbefugter Zugriff auf Systeme und Daten;',
            body: r'''''',
          ),
          _LegalSection(
            title:
                '16. Vortäuschung einer Verbindung zu plaqa, Behörden, Rettungsdiensten oder anderen Organisationen;',
            body: r'''''',
          ),
          _LegalSection(
            title:
                '17. Nutzung von plaqa für Notrufe oder zur Vortäuschung einer behördlichen Meldung;',
            body: r'''''',
          ),
          _LegalSection(
            title:
                '18. Anstiftung, Unterstützung oder Versuch einer der genannten Handlungen.',
            body: r'''12. Moderation, Meldung, Sperrung und Löschung

12.1 Meldefunktion

Nutzer können Inhalte, Nachrichten, Hinweise oder Konten über die vorgesehene Meldefunktion oder über support@plaqa.de melden.

Eine Meldung sollte möglichst enthalten:

* den betroffenen Inhalt oder Nutzer,
* den Grund der Meldung,
* eine nachvollziehbare Beschreibung,
* gegebenenfalls geeignete Nachweise.

Meldungen dürfen nicht missbräuchlich, automatisiert oder wissentlich falsch erfolgen.

12.2 Prüfverfahren

plaqa kann gemeldete oder auffällige Inhalte und Vorgänge prüfen.

Die Prüfung kann abhängig vom Einzelfall erfolgen durch:

* menschliche Prüfung,
* technische Regeln,
* Spam- und Sicherheitsfilter,
* automatisierte Erkennung auffälliger Nutzungsmuster,
* Kombination technischer und menschlicher Verfahren.

Aktuell unterstützen Zugriffsregeln, Eingabeprüfungen, Rate-Limits und Sicherheitsprotokolle die Missbrauchserkennung. Eine ausschließlich automatisierte abschließende Moderationsentscheidung ist nicht vorgesehen.

Eine technische Kennzeichnung oder automatische Einschränkung ist nicht zwingend eine abschließende rechtliche Bewertung.

12.3 Mögliche Maßnahmen

Bei einem Verstoß, einem begründeten Verdacht oder einer konkreten Gefährdung darf plaqa unter Berücksichtigung der Umstände insbesondere:

* Inhalte ausblenden,
* Inhalte entfernen,
* die Verbreitung einschränken,
* Kontakt- oder Suchfunktionen begrenzen,
* Anfragelimits verschärfen,
* Verwarnungen aussprechen,
* eine erneute Verifizierung verlangen,
* einzelne Funktionen vorübergehend sperren,
* das Konto vorübergehend sperren,
* das Konto dauerhaft kündigen,
* technische Nachweise sichern,
* andere betroffene Nutzer warnen, soweit dies erforderlich und zulässig ist,
* rechtliche Schritte einleiten,
* Informationen an zuständige Stellen übermitteln, soweit hierfür eine Rechtsgrundlage besteht.

12.4 Verhältnismäßigkeit

Bei der Auswahl einer Maßnahme berücksichtigt plaqa insbesondere:

* Art und Schwere des Verstoßes,
* Auswirkungen auf Betroffene,
* Verschulden,
* Häufigkeit und Wiederholung,
* vorherige Verwarnungen,
* Gefahr weiterer Schäden,
* Schutz Minderjähriger,
* Notwendigkeit der Beweissicherung,
* gesetzliche Anforderungen.

Bei geringfügigen oder erstmaligen Verstößen soll grundsätzlich eine mildere Maßnahme gewählt werden, soweit dies angesichts der Umstände vertretbar ist.

Bei schweren Verstößen, akuten Gefahren, Straftaten, Stalking, Drohungen, Identitätsmissbrauch oder gezielter Umgehung von Schutzmaßnahmen kann eine sofortige Sperrung ohne vorherige Verwarnung erfolgen.

12.5 Information über Maßnahmen

Soweit gesetzlich vorgeschrieben und keine gesetzlichen oder sicherheitsbezogenen Gründe entgegenstehen, informiert plaqa den betroffenen Nutzer über:

* die getroffene Maßnahme,
* den wesentlichen Grund,
* die Dauer,
* gegebenenfalls verfügbare Beschwerdemöglichkeiten.

Eine Begründung kann eingeschränkt werden, soweit dies erforderlich ist, um:

* Ermittlungen nicht zu gefährden,
* Rechte anderer Personen zu schützen,
* Sicherheitsmechanismen nicht offenzulegen,
* gesetzlichen Vorgaben zu entsprechen.

12.6 Beschwerde gegen Maßnahmen

Nutzer können gegen eine Moderations-, Einschränkungs- oder Sperrentscheidung Beschwerde einlegen:

E-Mail: support@plaqa.de

In der App: Einstellungen > Hilfe & Rechtliches > Support > Problem melden.

Beschwerden werden ohne zugesagte feste Bearbeitungsfrist so zeitnah wie möglich geprüft.

Die Beschwerde muss den betroffenen Vorgang und die Gründe enthalten, aus denen die Entscheidung nach Ansicht des Nutzers fehlerhaft ist.

plaqa prüft die Beschwerde sorgfältig und entscheidet unter Berücksichtigung der verfügbaren Informationen erneut. Gesetzlich vorgeschriebene Begründungs-, Beschwerde- und Rechtsschutzmöglichkeiten bleiben unberührt.

12.7 Behörden und rechtliche Schritte

plaqa darf Inhalte und Daten an Gerichte, Behörden, Strafverfolgungsstellen oder andere zuständige Stellen übermitteln, wenn:

* eine gesetzliche Verpflichtung besteht,
* eine rechtmäßige behördliche oder gerichtliche Anordnung vorliegt,
* dies zur Geltendmachung, Ausübung oder Verteidigung rechtlicher Ansprüche erforderlich und zulässig ist,
* dies in einem gesetzlich zulässigen Ausnahmefall zum Schutz betroffener Personen erforderlich ist.

Eine beliebige private Aufforderung führt nicht automatisch zur Offenlegung von Nutzerdaten.

13. Verfügbarkeit und Änderungen der App

13.1 Verfügbarkeit

plaqa bemüht sich um eine möglichst störungsfreie Verfügbarkeit.

Eine ununterbrochene, fehlerfreie und jederzeitige Verfügbarkeit wird jedoch nicht geschuldet.

Vorübergehende Einschränkungen können insbesondere entstehen durch:

* Wartung,
* Sicherheitsupdates,
* technische Störungen,
* Ausfälle von Netzwerken oder Drittanbietern,
* höhere Gewalt,
* notwendige Schutzmaßnahmen,
* Änderungen gesetzlicher oder behördlicher Anforderungen.

13.2 Wartung und Sicherheit

plaqa darf den Betrieb vorübergehend einschränken, soweit dies erforderlich ist für:

* Wartung,
* Fehlerbehebung,
* Sicherheitsmaßnahmen,
* Schutz vor Angriffen,
* Datenmigration,
* technische Weiterentwicklung.

Planbare wesentliche Unterbrechungen werden, soweit zumutbar, vorab angekündigt.

13.3 Änderungen des Funktionsumfangs

plaqa darf kostenlose Funktionen aus sachlichen Gründen ändern, erweitern, ersetzen oder einstellen.

Sachliche Gründe können insbesondere sein:

* technische Weiterentwicklung,
* Verbesserung der Sicherheit,
* Verhinderung von Missbrauch,
* geringe Nutzung einer Funktion,
* technische oder wirtschaftliche Unzumutbarkeit,
* Wegfall eines Drittanbieterdienstes,
* Änderungen von App-Store-Vorgaben,
* gesetzliche oder behördliche Anforderungen.

Dabei werden die berechtigten Interessen der Nutzer berücksichtigt.

Wesentliche Kernfunktionen werden nicht ohne sachlichen Grund so eingeschränkt, dass der Vertragszweck für den Nutzer vollständig entfällt.

Bei einer erheblichen nachteiligen Änderung wird der Nutzer, soweit zumutbar und rechtlich erforderlich, vorab informiert. Der Nutzer kann den Vertrag durch Kontolöschung oder Kündigung beenden.

13.4 Keine Pflicht zur dauerhaften Fortführung

Bei einem kostenlosen Dienst besteht kein Anspruch darauf, dass plaqa oder eine bestimmte kostenlose Funktion zeitlich unbegrenzt angeboten wird.

Gesetzliche Ansprüche und bereits wirksam erworbene Rechte bleiben unberührt.

14. Kostenlose und zukünftige kostenpflichtige Funktionen

14.1 Aktueller Stand

Die derzeit angebotenen Grundfunktionen sind nach dem gegenwärtigen Planungsstand kostenlos.

Die aktuelle App-Version enthält keine In-App-Käufe, Abonnements oder sonstigen kostenpflichtigen App-Funktionen.

14.2 Zukünftige kostenpflichtige Leistungen

plaqa kann zukünftig kostenpflichtige Funktionen, In-App-Käufe oder Abonnements anbieten.

Ein kostenpflichtiger Vertrag entsteht nur, wenn:

* die Leistung deutlich als kostenpflichtig gekennzeichnet ist,
* der Gesamtpreis und gegebenenfalls die Laufzeit angezeigt werden,
* der Nutzer den Kauf ausdrücklich bestätigt,
* die gesetzlichen Informationspflichten erfüllt werden.

Die bloße Registrierung oder Nutzung kostenloser Funktionen begründet keine Zahlungspflicht.

14.3 Besondere Bedingungen

Für kostenpflichtige Funktionen können zusätzliche Vertragsbedingungen gelten. Diese werden vor Abschluss des Kaufs angezeigt.

Gesetzliche Verbraucherrechte, insbesondere Informations-, Gewährleistungs- und gegebenenfalls Widerrufsrechte, bleiben unberührt.

14.4 Abrechnung über App Stores

Käufe können über den jeweiligen App Store abgewickelt werden.

Für Zahlung, Abrechnung, Rückerstattung und Verwaltung können ergänzend die Bedingungen des jeweiligen App Stores gelten.

Zwingende Ansprüche des Nutzers gegenüber plaqa werden dadurch nicht ausgeschlossen.

14.5 Preisänderungen

Preise bestehender Abonnements dürfen nur nach den gesetzlichen und vertraglichen Voraussetzungen geändert werden.

Der Nutzer wird über eine beabsichtigte Preisänderung rechtzeitig informiert, soweit dies erforderlich ist.

Eine Preisänderung gilt nicht allein deshalb als angenommen, weil der Nutzer ihr nicht widerspricht, sofern eine solche Zustimmungswirkung nicht ausdrücklich gesetzlich zulässig und wirksam vereinbart ist.

Vor einer späteren Einführung kostenpflichtiger Funktionen werden gesonderte Preis-, Laufzeit-, Kündigungs- und gegebenenfalls Widerrufsbedingungen bereitgestellt.

15. Rechte an Inhalten und Nutzungsrechte

15.1 Rechte des Nutzers

Der Nutzer behält seine bestehenden Rechte an den von ihm bereitgestellten Inhalten.

plaqa erwirbt kein Eigentum an Nutzerinhalten.

15.2 Erforderliches Nutzungsrecht

Der Nutzer räumt plaqa für die Dauer und den Umfang der Bereitstellung des jeweiligen Inhalts ein einfaches, nicht ausschließliches, grundsätzlich unentgeltliches, räumlich auf den Betrieb des Dienstes beschränktes Recht ein, den Inhalt technisch zu:

* speichern,
* vervielfältigen,
* übertragen,
* formatieren,
* komprimieren,
* darstellen,
* den vom Nutzer bestimmten Empfängern zugänglich machen,
* zur Bereitstellung auf unterschiedlichen Endgeräten anpassen.

Das Nutzungsrecht ist ausschließlich auf Zwecke beschränkt, die erforderlich sind für:

* Betrieb der App,
* Erfüllung der vom Nutzer gewählten Funktion,
* Datensicherung,
* Sicherheit,
* Moderation,
* Bearbeitung von Meldungen,
* Erfüllung gesetzlicher Pflichten,
* Geltendmachung oder Verteidigung rechtlicher Ansprüche.

Eine Nutzung für externe Werbung, Verkauf fremder Produkte oder ein Training allgemeiner KI-Modelle erfolgt nicht allein aufgrund dieser Klausel.

15.3 Ende des Nutzungsrechts

Das Nutzungsrecht endet grundsätzlich, wenn der Inhalt rechtmäßig gelöscht wurde und für den Betrieb nicht mehr erforderlich ist.

Es kann im erforderlichen Umfang fortbestehen, wenn:

* der Inhalt von anderen Nutzern rechtmäßig weiter gespeichert wird,
* gesetzliche Aufbewahrungspflichten bestehen,
* eine Meldung oder ein Rechtsstreit anhängig ist,
* Beweissicherung erforderlich ist,
* der Inhalt vorübergehend in Sicherungskopien enthalten ist.

15.4 Freistellung bei Rechtsverletzungen

Verletzt ein Nutzer schuldhaft Rechte Dritter oder gesetzliche Pflichten, stellt er plaqa von berechtigten Ansprüchen Dritter frei, soweit der Nutzer die Rechtsverletzung zu vertreten hat.

Die Freistellung umfasst nur erforderliche und angemessene Kosten der Rechtsverteidigung.

plaqa wird den Nutzer über geltend gemachte Ansprüche unverzüglich informieren und ihm, soweit rechtlich und tatsächlich möglich, Gelegenheit zur Mitwirkung an der Verteidigung geben.

Die Freistellung gilt nicht, soweit plaqa die Rechtsverletzung selbst zu vertreten hat.

16. Datenschutz

Informationen über die Verarbeitung personenbezogener Daten enthält die gesonderte Datenschutzerklärung.

Die Datenschutzerklärung ist kein Bestandteil dieser Nutzungsbedingungen, soweit sie ausschließlich der Erfüllung gesetzlicher Informationspflichten dient.

Nutzer müssen bei der Verwendung personenbezogener Daten anderer Personen selbst prüfen, ob sie zur Erhebung, Veröffentlichung oder Weitergabe berechtigt sind.

Die Nutzung der App entbindet Nutzer nicht von eigenen datenschutzrechtlichen Pflichten.

17. Haftung des Betreibers

17.1 Unbeschränkte Haftung

plaqa haftet unbeschränkt:

* bei Vorsatz und grober Fahrlässigkeit,
* bei schuldhafter Verletzung von Leben, Körper oder Gesundheit,
* nach dem Produkthaftungsgesetz,
* im Umfang einer ausdrücklich übernommenen Garantie,
* bei arglistigem Verschweigen eines Mangels,
* in sonstigen Fällen zwingender gesetzlicher Haftung.

17.2 Leicht fahrlässige Verletzung wesentlicher Vertragspflichten

Bei leicht fahrlässiger Verletzung einer wesentlichen Vertragspflicht haftet plaqa auf den vertragstypischen, bei Vertragsschluss vorhersehbaren Schaden.

Wesentliche Vertragspflichten sind solche Pflichten, deren Erfüllung die ordnungsgemäße Durchführung des Vertrags überhaupt erst ermöglicht und auf deren Einhaltung der Nutzer regelmäßig vertrauen darf.

17.3 Sonstige leichte Fahrlässigkeit

Im Übrigen ist die Haftung für leicht fahrlässig verursachte Schäden ausgeschlossen, soweit gesetzlich zulässig.

Die Haftungsausschlüsse und -beschränkungen gelten entsprechend für gesetzliche Vertreter, Beschäftigte und Erfüllungsgehilfen von plaqa.

17.4 Nutzerinhalte und Nutzerangaben

plaqa macht sich Nutzerinhalte nicht allein dadurch zu eigen, dass sie über die App gespeichert oder übertragen werden.

Soweit plaqa keine gesetzliche Prüfpflicht trifft und keine Kenntnis von einer konkreten Rechtsverletzung hat, haftet plaqa für fremde Nutzerinhalte nur nach den jeweils anwendbaren gesetzlichen Vorschriften.

Nach Kenntniserlangung werden erforderliche und zumutbare Maßnahmen geprüft.

17.5 Keine Garantie für Nutzer und Fahrzeuge

plaqa übernimmt keine Garantie für:

* Identität, Vertrauenswürdigkeit oder Verhalten eines Nutzers,
* Richtigkeit von Profil-, Fahrzeug- oder Kennzeichenangaben,
* Eigentum oder Berechtigung an einem Fahrzeug,
* Richtigkeit von Standortdaten,
* Richtigkeit von Meldungen,
* Zustand oder Sicherheit eines Fahrzeugs,
* Erfolg oder Folgen einer Kontaktaufnahme.

Eine Verifizierung beschränkt sich auf die im jeweiligen Verfahren geprüften Merkmale.

17.6 Verhalten zwischen Nutzern

Nutzer handeln eigenverantwortlich.

plaqa ist grundsätzlich nicht Partei von Vereinbarungen, Treffen oder sonstigen Rechtsgeschäften zwischen Nutzern.

plaqa haftet nicht allein deshalb für das Verhalten eines Nutzers, weil der Kontakt über die App zustande gekommen ist.

Eigene gesetzliche Pflichten von plaqa bleiben unberührt.

17.7 Datenverlust

Soweit der Nutzer für eine angemessene eigene Sicherung von Daten verantwortlich ist, ist die Haftung bei leicht fahrlässigem Datenverlust auf den Wiederherstellungsaufwand beschränkt, der bei ordnungsgemäßer und regelmäßiger Datensicherung typischerweise entstanden wäre.

Diese Regelung gilt nicht für Daten, deren alleinige Sicherung nach dem Vertragszweck plaqa obliegt, oder soweit eine eigene Sicherung durch den Nutzer nicht möglich oder nicht zumutbar ist.

18. Haftung und Verantwortung der Nutzer

18.1 Eigenverantwortung

Der Nutzer trägt die Verantwortung für seine Handlungen, Angaben, Inhalte, Kontaktanfragen, Nachrichten, Storys und Hinweise.

18.2 Schäden durch Pflichtverletzungen

Verletzt ein Nutzer schuldhaft diese Nutzungsbedingungen oder Rechte Dritter, ist er nach den gesetzlichen Vorschriften zum Ersatz des daraus entstehenden Schadens verpflichtet.

18.3 Meldung von Sicherheitsvorfällen

Nutzer müssen plaqa unverzüglich informieren, wenn sie Kenntnis erhalten von:

* unbefugtem Kontozugriff,
* Identitätsmissbrauch,
* missbräuchlicher Verwendung ihres Kennzeichens,
* schwerwiegenden Drohungen,
* Sicherheitslücken,
* manipulierten oder gefälschten Verifizierungen.

Die Meldung ist an support@plaqa.de zu richten oder über die vorgesehene App-Funktion abzugeben.''',
          ),
          _LegalSection(
            title: '19. Account-Löschung, Kündigung und Vertragsende',
            body: r'''19.1 Kündigung durch den Nutzer

Der Nutzer kann den unentgeltlichen Nutzungsvertrag jederzeit ohne Einhaltung einer Frist kündigen.

Die Kündigung erfolgt durch:

* Löschung des Kontos unter Einstellungen > Konto > Konto & Sicherheit > Gefahrenbereich > Konto löschen oder
* eine eindeutige Erklärung an support@plaqa.de.

Die bloße Deinstallation der App beendet den Nutzungsvertrag nicht zwingend und löscht das Benutzerkonto nicht automatisch.

19.2 Ordentliche Kündigung durch plaqa

plaqa kann einen unentgeltlichen Nutzungsvertrag ordentlich mit einer den Umständen angemessenen Frist kündigen, soweit keine abweichenden gesetzlichen Vorgaben gelten. Eine feste vertragliche Kündigungsfrist wird für die kostenlose App derzeit nicht zugesagt.

Eine ordentliche Kündigung darf nicht treuwidrig oder diskriminierend erfolgen.

19.3 Außerordentliche Kündigung

Beide Parteien können den Vertrag aus wichtigem Grund ohne Einhaltung einer Frist kündigen.

Ein wichtiger Grund für plaqa kann insbesondere vorliegen bei:

* schwerwiegendem oder wiederholtem Verstoß gegen diese Bedingungen,
* Stalking, Bedrohung oder Belästigung,
* Identitäts- oder Fahrzeugtäuschung,
* falschen oder manipulierten Verifizierungsunterlagen,
* rechtswidrigen Inhalten,
* Umgehung einer Sperre,
* Angriffen auf die App oder andere Konten,
* betrügerischer Nutzung,
* konkreter Gefahr für Nutzer oder Dritte.

Soweit zumutbar, wird vor einer außerordentlichen Kündigung eine Warnung oder Gelegenheit zur Abhilfe erteilt. Dies gilt nicht, wenn:

* eine Abhilfe offensichtlich nicht zu erwarten ist,
* der Verstoß besonders schwerwiegend ist,
* eine sofortige Maßnahme zum Schutz anderer erforderlich ist,
* gesetzliche oder behördliche Gründe entgegenstehen.

19.4 Folgen der Beendigung

Nach Vertragsende kann:

* der Zugang gesperrt werden,
* das Profil entfernt werden,
* die Fahrzeugzuordnung aufgehoben werden,
* die Sichtbarkeit von Inhalten enden,
* eine Löschung oder Anonymisierung nach der Datenschutzerklärung erfolgen.

Daten können befristet gespeichert bleiben, soweit dies erforderlich ist für:

* gesetzliche Aufbewahrungspflichten,
* Bearbeitung von Meldungen,
* Missbrauchsschutz,
* Durchsetzung von Sperren,
* Rechtsverteidigung,
* Beweissicherung,
* technische Backups.

19.5 Inhalte bei anderen Nutzern

Nachrichten oder Inhalte, die bereits an andere Nutzer übermittelt wurden, können dort abhängig von der technischen und rechtlichen Ausgestaltung weiterhin sichtbar bleiben.

Bei einer Kontolöschung werden eigene Konto-, Profil-, Fahrzeug-, Story- und Mediendaten entfernt. Gemeinsame Chats werden gesperrt und das gelöschte Konto pseudonymisiert; bereits übermittelte Textnachrichten können für den anderen Chatteilnehmer als Inhalt eines gelöschten Kontos erhalten bleiben, während zugehörige Medienverweise entfernt werden.

19.6 Kostenpflichtige Leistungen

Für kostenpflichtige Leistungen gelten die vor Vertragsschluss mitgeteilten Laufzeiten und Kündigungsbedingungen.

Die Kontolöschung beendet ein über einen App Store abgeschlossenes Abonnement möglicherweise nicht automatisch. Nutzer müssen ein solches Abonnement gegebenenfalls zusätzlich in ihrem App-Store-Konto kündigen.''',
          ),
          _LegalSection(
            title: '20. App Stores und Drittanbieter',
            body: r'''20.1 App Stores

plaqa kann über den jeweiligen App Store bereitgestellt werden.

Der jeweilige App-Store-Anbieter ist nicht Vertragspartner des Nutzungsvertrags über die von plaqa betriebenen App-Funktionen, soweit nicht ausdrücklich etwas anderes angegeben wird.

Für:

* Download,
* Installation,
* Updates,
* App-Store-Konto,
* Zahlungsabwicklung,
* Rückerstattung,
* Gerätevoraussetzungen

können ergänzende Bedingungen des App Stores gelten.

20.2 Drittanbieterdienste

plaqa kann technische Dienste Dritter einsetzen, insbesondere für:

* Authentifizierung,
* Hosting,
* Datenspeicherung,
* Push-Benachrichtigungen,
* Karten- oder Standortfunktionen,
* Verifizierung,
* Zahlungsabwicklung.

Die Verfügbarkeit einzelner Funktionen kann von diesen Drittanbietern abhängen.

plaqa haftet für eigenes Auswahl-, Organisations- oder Überwachungsverschulden nach den gesetzlichen Bestimmungen. Eine darüber hinausgehende Garantie für die dauerhafte Verfügbarkeit unabhängiger Drittanbieterdienste wird nicht übernommen.

20.3 Externe Links

Externe Links können zu Diensten Dritter führen. Für deren Inhalte und Leistungen ist grundsätzlich der jeweilige Anbieter verantwortlich.

plaqa prüft externe Angebote bei der Verlinkung im zumutbaren Umfang, übernimmt aber keine allgemeine dauerhafte Kontrollpflicht.''',
          ),
          _LegalSection(
            title: '21. Änderungen der Nutzungsbedingungen',
            body: r'''21.1 Änderungsgründe

plaqa darf diese Nutzungsbedingungen für die Zukunft ändern, wenn hierfür ein sachlicher Grund besteht.

Sachliche Gründe können insbesondere sein:

* Änderungen gesetzlicher Vorschriften,
* neue behördliche oder gerichtliche Anforderungen,
* Sicherheitsanforderungen,
* Einführung neuer Funktionen,
* technische Änderungen,
* Schließung unbeabsichtigter Regelungslücken,
* Anpassung an neue Missbrauchsformen,
* Änderungen von App-Store- oder Drittanbieteranforderungen.

Änderungen dürfen das vertragliche Gleichgewicht nicht unangemessen zulasten der Nutzer verschieben.

21.2 Information

Über wesentliche Änderungen werden Nutzer rechtzeitig vor ihrem Inkrafttreten in klarer und verständlicher Form informiert.

Die Mitteilung enthält:

* die geänderten Regelungen oder einen zugänglichen Vergleich,
* das Datum des Inkrafttretens,
* gegebenenfalls bestehende Kündigungs- oder Widerspruchsmöglichkeiten.

21.3 Erneute Zustimmung

Soweit eine Änderung eine ausdrückliche Zustimmung erfordert, wird plaqa diese einholen.

Eine unterlassene Reaktion des Nutzers gilt nicht ohne Weiteres als Zustimmung.

plaqa kann die weitere Nutzung einer wesentlich geänderten oder neuen Funktion von einer ausdrücklichen Zustimmung zu den dafür erforderlichen Bedingungen abhängig machen.

21.4 Ablehnung einer Änderung

Lehnt der Nutzer eine erforderliche Änderung ab, kann er den Nutzungsvertrag vor Inkrafttreten der Änderung beenden.

plaqa kann den Vertrag ordentlich kündigen, wenn eine Fortführung unter den bisherigen Bedingungen technisch, rechtlich oder wirtschaftlich nicht zumutbar ist. Bereits entstandene Rechte des Nutzers bleiben unberührt.''',
          ),
          _LegalSection(
            title: '22. Verbraucherstreitbeilegung',
            body:
                r'''Informationen zu einer gesetzlich erforderlichen Teilnahme an Verbraucherstreitbeilegungsverfahren werden in der jeweils aktuellen Fassung des Impressums bereitgestellt.

Die frühere europäische Plattform zur Online-Streitbeilegung wird nicht als aktive Streitbeilegungsplattform angegeben.''',
          ),
          _LegalSection(
            title: '23. Anwendbares Recht',
            body:
                r'''Es gilt das Recht der Bundesrepublik Deutschland unter Ausschluss des UN-Kaufrechts.

Bei Verbrauchern gilt diese Rechtswahl nur, soweit ihnen dadurch nicht der Schutz entzogen wird, der ihnen durch zwingende Vorschriften des Staates ihres gewöhnlichen Aufenthalts gewährt wird.

Zwingende verbraucherschützende Vorschriften bleiben unberührt.''',
          ),
          _LegalSection(
            title: '24. Gerichtsstand und Schlussbestimmungen',
            body: r'''24.1 Gerichtsstand

Für Verbraucher gelten die gesetzlichen Gerichtsstandsregelungen.

Ist der Nutzer Kaufmann, eine juristische Person des öffentlichen Rechts oder ein öffentlich-rechtliches Sondervermögen, ist – soweit gesetzlich zulässig – Hamburg Gerichtsstand für alle Streitigkeiten aus dem Vertragsverhältnis.

Dasselbe gilt, soweit gesetzlich zulässig, wenn der Nutzer keinen allgemeinen Gerichtsstand in Deutschland oder einem Mitgliedstaat der Europäischen Union hat oder seinen Wohnsitz nach Vertragsschluss ins Ausland verlegt und kein zwingender Verbrauchergerichtsstand entgegensteht.

24.2 Vertragssprache

Vertragssprache ist Deutsch.

Derzeit werden keine verbindlichen Übersetzungen angeboten. Falls später freiwillige Übersetzungen bereitgestellt werden, bleibt die deutsche Fassung maßgeblich, soweit zwingende Verbraucherrechte nichts anderes verlangen.

24.3 Individualvereinbarungen

Individuelle Vereinbarungen zwischen plaqa und einem Nutzer haben Vorrang vor diesen Nutzungsbedingungen.

24.4 Unwirksame Bestimmungen

Sollte eine Bestimmung dieser Nutzungsbedingungen ganz oder teilweise unwirksam oder undurchführbar sein oder werden, bleiben die übrigen Bestimmungen wirksam.

An die Stelle der unwirksamen oder undurchführbaren Bestimmung treten die gesetzlichen Vorschriften.

Eine unwirksame Klausel wird nicht automatisch durch eine für plaqa wirtschaftlich möglichst günstige Regelung ersetzt.''',
          ),
          _LegalSection(
            title: '25. Kontakt und aktuelle Fassung',
            body:
                r'''Die jeweils aktuelle Fassung dieser Nutzungsbedingungen ist in der App und unter https://plaqa.de/nutzungsbedingungen/ verfügbar.

Fragen zu den Bedingungen können an info@plaqa.de, Sicherheits- und Supportanfragen an support@plaqa.de gerichtet werden. Wesentliche Änderungen werden den Nutzern in geeigneter Form mitgeteilt.''',
          ),
        ],
      ),
      'Datenschutzerklärung' => const _LegalContent(
        title: 'Datenschutz',
        icon: Icons.privacy_tip_outlined,
        versionLabel: 'Aktuelle Datenschutz-Version: ${LegalVersions.privacy}',
        sections: [
          _LegalSection(
            title: 'Stand und Version',
            body: r'''Datenschutzerklärung für die mobile App „plaqa“

Stand: 22. August 2026
Version: 1.0.0''',
          ),
          _LegalSection(
            title: '1. Geltungsbereich und Zweck dieser Datenschutzerklärung',
            body:
                r'''Diese Datenschutzerklärung informiert darüber, wie personenbezogene Daten bei der Nutzung der mobilen App „plaqa“, der zugehörigen Website und der damit verbundenen Dienste verarbeitet werden.

plaqa ist eine mobile Anwendung zur geschützten Kontaktaufnahme rund um Fahrzeuge und Kennzeichen. Nutzer können insbesondere:

* ein Benutzerkonto erstellen,
* ein Profil anlegen,
* Fahrzeug- und Kennzeichendaten hinterlegen,
* innerhalb der vorgesehenen Suchparameter nach Kennzeichen suchen,
* Kontaktanfragen senden und empfangen,
* nach Annahme einer Kontaktanfrage miteinander chatten,
* Storys veröffentlichen,
* fahrzeugbezogene Hinweise oder Meldungen übermitteln,
* freiwillige Nachweise zur Verifizierung hochladen,
* Medien, Dokumente, Standortinformationen oder andere Inhalte teilen, soweit die jeweilige Funktion dies ermöglicht.

Diese Datenschutzerklärung beschreibt sowohl die Datenverarbeitung durch den Betreiber als auch die Verantwortung der Nutzer für Inhalte, die sie selbst eingeben, hochladen, veröffentlichen oder an andere Nutzer senden.

Wichtig: plaqa ist keine Notruf-, Polizei-, Feuerwehr-, Rettungsdienst-, Abschlepp-, Pannenhilfe- oder Rechtsberatungs-App. Bei Gefahr für Personen oder Sachen, bei Unfällen, Straftaten, akuten Verkehrsbehinderungen oder sonstigen Notfällen müssen unmittelbar die zuständigen Behörden, Rettungsdienste, Pannenhilfen oder sonstigen verantwortlichen Stellen kontaktiert werden.''',
          ),
          _LegalSection(
            title: '2. Verantwortlicher',
            body:
                r'''Verantwortlicher im Sinne der Datenschutz-Grundverordnung ist:

Sehmus Yildirim
Auftreten unter der Bezeichnung plaqa
Bremer Straße 254e
21077 Hamburg
Deutschland

E-Mail: info@plaqa.de
Website: plaqa.de''',
          ),
          _LegalSection(
            title: '3. Datenschutzkontakt',
            body:
                r'''Anfragen zum Datenschutz, zu Betroffenenrechten oder zur Verarbeitung personenbezogener Daten können gerichtet werden an:

E-Mail: privacy@plaqa.de

Diese Adresse ist die zentrale Kontaktstelle für Datenschutzanfragen. Falls künftig ein Datenschutzbeauftragter benannt wird, werden dessen Kontaktdaten in dieser Erklärung ergänzt.''',
          ),
          _LegalSection(
            title: '4. Begriffsbestimmungen',
            body:
                r'''Personenbezogene Daten sind alle Informationen, die sich auf eine identifizierte oder identifizierbare natürliche Person beziehen. Dazu können insbesondere Name, E-Mail-Adresse, Nutzer-ID, Profilbild, Standortdaten, Kommunikationsinhalte, technische Kennungen, Fahrzeugdaten und – abhängig vom jeweiligen Zusammenhang – auch Kennzeichen gehören.

Verarbeitung bezeichnet jeden Vorgang im Zusammenhang mit personenbezogenen Daten, insbesondere das Erheben, Speichern, Ordnen, Verwenden, Übermitteln, Anzeigen, Einschränken oder Löschen.

Pseudonymisierte Daten sind Daten, die ohne zusätzliche Informationen nicht unmittelbar einer bestimmten Person zugeordnet werden können. Eine Pseudonymisierung bedeutet nicht, dass die Daten anonym sind.

Anonyme oder anonym dargestellte Hinweise können für den Empfänger ohne sichtbare Absenderidentität erscheinen. Sie können intern dennoch einer Nutzer-ID, einem Benutzerkonto, technischen Protokollen oder sonstigen Sicherheitsinformationen zugeordnet werden, soweit dies für Betrieb, Sicherheit, Missbrauchsabwehr, Nachweisführung oder gesetzliche Pflichten erforderlich und zulässig ist.''',
          ),
          _LegalSection(
            title: '5. Grundsätze der Datenverarbeitung',
            body:
                r'''Wir verarbeiten personenbezogene Daten nur, soweit hierfür eine gesetzliche Grundlage besteht. Dabei berücksichtigen wir insbesondere die Grundsätze der:

* Rechtmäßigkeit, Verarbeitung nach Treu und Glauben und Transparenz,
* Zweckbindung,
* Datenminimierung,
* Richtigkeit,
* Speicherbegrenzung,
* Integrität und Vertraulichkeit,
* Rechenschaftspflicht.

Es werden nur solche Daten verarbeitet, die für den jeweiligen Zweck erforderlich sind oder die Nutzer freiwillig im Rahmen einer verfügbaren Funktion bereitstellen.

Bestimmte App-Funktionen können ohne die hierfür benötigten Daten oder Berechtigungen nicht oder nur eingeschränkt genutzt werden.''',
          ),
          _LegalSection(
            title: '6. Rechtsgrundlagen der Verarbeitung',
            body:
                r'''Je nach Funktion und Verarbeitungsvorgang stützen wir die Verarbeitung insbesondere auf folgende Rechtsgrundlagen:

6.1 Vertragserfüllung und vorvertragliche Maßnahmen

Art. 6 Abs. 1 lit. b DSGVO ist Rechtsgrundlage, soweit die Verarbeitung erforderlich ist, um:

* das Benutzerkonto bereitzustellen,
* Registrierung und Anmeldung durchzuführen,
* Profile und Fahrzeuge zu verwalten,
* Kennzeichensuchen technisch auszuführen,
* Kontaktanfragen zu übermitteln,
* Chats und Storys bereitzustellen,
* Hinweise oder Meldungen zuzustellen,
* In-App-Käufe oder sonstige gebuchte Leistungen abzuwickeln,
* Supportanfragen zu bearbeiten,
* die vom Nutzer angeforderten App-Funktionen zur Verfügung zu stellen.

6.2 Einwilligung

Art. 6 Abs. 1 lit. a DSGVO ist Rechtsgrundlage, wenn Nutzer ausdrücklich in eine Datenverarbeitung einwilligen, insbesondere möglicherweise bei:

* optionalen Standortfunktionen,
* optionalen Push-Benachrichtigungen,
* Zugriffen auf Kamera, Mikrofon, Fotos, Dateien oder Kontakte,
* freiwilligen Verifizierungsverfahren,
* optionaler Analyse oder Reichweitenmessung,
* optionaler Crash- oder Diagnosedatenerhebung, soweit dafür eine Einwilligung erforderlich ist,
* sonstigen freiwilligen Funktionen.

Soweit für den Zugriff auf oder die Speicherung von Informationen auf dem Endgerät eine Einwilligung erforderlich ist, wird zusätzlich die einschlägige Rechtsgrundlage des TDDDG berücksichtigt.

Eine Einwilligung ist freiwillig und kann jederzeit mit Wirkung für die Zukunft widerrufen werden. Die Rechtmäßigkeit der bis zum Widerruf erfolgten Verarbeitung bleibt unberührt.

Berechtigungen können außerdem über die Einstellungen des Betriebssystems verwaltet oder entzogen werden. Der Entzug einer Berechtigung kann dazu führen, dass einzelne Funktionen nicht mehr oder nur eingeschränkt verfügbar sind.

6.3 Berechtigte Interessen

Art. 6 Abs. 1 lit. f DSGVO ist Rechtsgrundlage, soweit die Verarbeitung zur Wahrung unserer berechtigten Interessen oder berechtigter Interessen Dritter erforderlich ist und keine überwiegenden Interessen oder Rechte der betroffenen Person entgegenstehen.

Unsere berechtigten Interessen können insbesondere sein:

* sicherer und stabiler Betrieb der App,
* Schutz von Nutzerkonten und Systemen,
* Erkennung und Verhinderung von Missbrauch, Betrug, Spam, Belästigung, Stalking, Bedrohungen oder Manipulationen,
* Durchsetzung unserer Nutzungsbedingungen,
* Schutz betroffener Nutzer und Dritter,
* Untersuchung gemeldeter Inhalte und Vorfälle,
* Nachweis von Vorgängen, Einwilligungen, Anfragen und Sicherheitsereignissen,
* Verhinderung mehrfacher oder automatisierter Kontaktanfragen,
* Fehleranalyse und technische Fehlerbehebung,
* Abwehr, Geltendmachung oder Verteidigung rechtlicher Ansprüche,
* Verbesserung der Zuverlässigkeit und Sicherheit der App,
* Schutz vor unberechtigten Zugriffen,
* interne Prüfung auffälliger Nutzungsmuster.

Soweit wir uns auf berechtigte Interessen stützen, nehmen wir eine Interessenabwägung vor. Nutzer können einer solchen Verarbeitung nach Maßgabe von Art. 21 DSGVO widersprechen.

6.4 Gesetzliche Pflichten

Art. 6 Abs. 1 lit. c DSGVO ist Rechtsgrundlage, wenn die Verarbeitung zur Erfüllung einer gesetzlichen Pflicht erforderlich ist, insbesondere zur:

* Erfüllung steuer- und handelsrechtlicher Aufbewahrungspflichten,
* Bearbeitung gesetzlicher Auskunfts-, Lösch- oder Nachweispflichten,
* Mitwirkung gegenüber Gerichten, Behörden oder Strafverfolgungsstellen, soweit eine rechtmäßige Verpflichtung besteht,
* Erfüllung datenschutzrechtlicher Dokumentations- und Rechenschaftspflichten,
* Behandlung von Datenschutzverletzungen,
* Umsetzung vollziehbarer behördlicher oder gerichtlicher Anordnungen.

6.5 Schutz lebenswichtiger Interessen

In seltenen Ausnahmefällen kann Art. 6 Abs. 1 lit. d DSGVO einschlägig sein, wenn die Verarbeitung zum Schutz lebenswichtiger Interessen einer Person erforderlich ist und keine andere geeignete Rechtsgrundlage rechtzeitig zur Verfügung steht.

Dies begründet keine allgemeine Überwachungs-, Rettungs- oder Notfallpflicht von plaqa.

6.6 Rechtsansprüche

Soweit besondere Kategorien personenbezogener Daten betroffen sein sollten, kann eine Verarbeitung zusätzlich auf Art. 9 Abs. 2 DSGVO gestützt werden müssen, insbesondere bei ausdrücklicher Einwilligung oder zur Geltendmachung, Ausübung oder Verteidigung von Rechtsansprüchen.

plaqa fordert im regulären Funktionsumfang keine Angaben zu Gesundheit, Religion, politischer Meinung, sexueller Orientierung oder anderen besonderen Kategorien personenbezogener Daten an. Nutzer sollen solche Angaben nicht in freie Texte, Medien oder Nachrichten aufnehmen, sofern dies für die gewählte Funktion nicht zwingend erforderlich ist.''',
          ),
          _LegalSection(
            title: '7. Registrierung und Benutzerkonto',
            body:
                r'''Zur Erstellung und Verwaltung eines Benutzerkontos können insbesondere folgende Daten verarbeitet werden:

* E-Mail-Adresse,
* Passwort oder Authentifizierungsnachweis,
* Firebase-Authentifizierungs-ID beziehungsweise Nutzer-ID,
* Registrierungszeitpunkt,
* Login- und Sitzungsdaten,
* Bestätigungs- und Verifizierungsstatus,
* Zeitpunkte sicherheitsrelevanter Kontoaktivitäten,
* technische Geräte- und Sicherheitsinformationen,
* gegebenenfalls Angaben zur Altersbestätigung,
* gegebenenfalls Informationen zu gesperrten oder eingeschränkten Konten.

Passwörter werden über den eingesetzten Authentifizierungsdienst verarbeitet. Wir beabsichtigen nicht, Passwörter im Klartext einzusehen oder zu speichern.

Die Anmeldung wird über Firebase Authentication bereitgestellt. Unterstützt werden E-Mail und Passwort sowie Google-Anmeldung. E-Mail-Bestätigung, Passwort-Zurücksetzung und optionaler SMS-Zwei-Faktor-Schutz werden über diesen Dienst abgewickelt. plaqa speichert Passwörter nicht im eigenen Firestore-Datenbestand.

Die Verarbeitung erfolgt grundsätzlich zur Bereitstellung des Kontos und der App-Funktionen nach Art. 6 Abs. 1 lit. b DSGVO. Sicherheits- und Missbrauchsdaten können zusätzlich auf Art. 6 Abs. 1 lit. f DSGVO gestützt werden.

Nutzer müssen bei der Registrierung richtige und aktuelle Angaben machen. Die Verwendung fremder Identitäten, unberechtigter E-Mail-Adressen oder täuschender Angaben ist unzulässig.''',
          ),
          _LegalSection(
            title: '8. Anmeldung über externe Anbieter',
            body:
                r'''Neben E-Mail und Passwort kann die Anmeldung über Google verwendet werden. Auf unterstützten Apple-Geräten wird außerdem „Mit Apple fortfahren“ angeboten, sobald die erforderliche Apple-Konfiguration vollständig aktiviert ist.

Bei der Google-Anmeldung können Google und plaqa Informationen austauschen, zum Beispiel:

* externe Nutzerkennung,
* Name,
* E-Mail-Adresse,
* Profilbild,
* Authentifizierungsstatus,
* Login-Zeitpunkt,
* technische Sicherheitsdaten.

Die Anmeldung dient der Kontobereitstellung und Kontosicherheit. Ergänzend gelten die Datenschutzhinweise von Google unter https://policies.google.com/privacy. Eine Verarbeitung in den USA kann insbesondere bei Firebase Authentication stattfinden.''',
          ),
          _LegalSection(
            title: '9. Profildaten',
            body:
                r'''Nutzer können abhängig vom Funktionsumfang folgende Profildaten hinterlegen:

* Anzeigename,
* Vor- und Nachname, soweit vorgesehen,
* Profilbild,
* Profilbeschreibung,
* Fahrzeugmarke,
* Fahrzeugmodell,
* Fahrzeugfarbe,
* Kennzeichen,
* Land oder Kennzeichenstaat,
* Sichtbarkeitseinstellungen,
* Einstellungen zu Kontaktanfragen,
* Einstellungen zu anonymen oder pseudonymen Hinweisen,
* Verifizierungsstatus,
* weitere freiwillige Profilangaben.

Welche Angaben anderen Nutzern angezeigt werden, hängt von der jeweiligen Funktion, den Sichtbarkeitseinstellungen und dem Kontaktstatus ab.

Nutzer müssen berücksichtigen, dass Profil-, Fahrzeug- und Kennzeichendaten je nach gewählter Funktion für andere Nutzer sichtbar oder über die App auffindbar sein können. Es darf nicht davon ausgegangen werden, dass sichtbare Inhalte vertraulich bleiben.

Die Verarbeitung erfolgt grundsätzlich zur Vertragserfüllung nach Art. 6 Abs. 1 lit. b DSGVO. Freiwillige Zusatzangaben können auf einer Einwilligung oder der aktiven Entscheidung des Nutzers beruhen.

Nutzer dürfen nur Daten zu Fahrzeugen hinterlegen, die sie rechtmäßig verwenden dürfen oder für deren Eintragung eine ausreichende Berechtigung besteht. Das Eintragen fremder Kennzeichen zur Täuschung, Überwachung, Belästigung oder Umgehung von Schutzmechanismen ist verboten.''',
          ),
          _LegalSection(
            title: '10. Kennzeichen als personenbezogenes Datum',
            body:
                r'''Ein Fahrzeugkennzeichen kann insbesondere in Verbindung mit weiteren Informationen einen Bezug zu einer identifizierbaren Person herstellen. Kennzeichen werden daher innerhalb von plaqa grundsätzlich als schutzbedürftige Daten behandelt.

Kennzeichen können verarbeitet werden, um:

* ein Fahrzeug einem Nutzerkonto zuzuordnen,
* Suchanfragen auszuführen,
* Kontaktanfragen zuzuordnen,
* fahrzeugbezogene Hinweise zu übermitteln,
* Missbrauch und Mehrfachanfragen zu verhindern,
* Nachweise über sicherheitsrelevante Vorgänge zu führen,
* gemeldete Vorfälle zu untersuchen.

Kennzeichen dürfen nicht dazu verwendet werden, Personen systematisch zu verfolgen, Bewegungsprofile zu erstellen, Halterdaten unberechtigt zu ermitteln, Personen zu belästigen oder sonstige rechtswidrige Zwecke zu verfolgen.''',
          ),
          _LegalSection(
            title: '11. Verifizierung und lokaler Dokumentabgleich',
            body:
                r'''plaqa kann einen freiwilligen oder für bestimmte Funktionen erforderlichen Dokumentdatenabgleich anbieten. Im aktuellen Verfahren werden ausschließlich die Vorderseite eines Personalausweises oder Aufenthaltstitels beziehungsweise die Datenseite eines Reisepasses sowie die Vorderseite der Zulassungsbescheinigung Teil I mit der Kamera aufgenommen oder bewusst aus der Galerie ausgewählt und lokal ausgerichtet. Führerschein, Selfie, Rückseiten und beliebige Datei-Uploads werden nicht verlangt.

Bildqualität und Texterkennung werden auf dem Gerät verarbeitet. Dokumentbilder, Roh-OCR-Blöcke, Dokumentnummern, Lichtbilder, Anschriften, Staatsangehörigkeiten, maschinenlesbare Rohzeilen und die Unterschriftsgrafik werden nicht dauerhaft an plaqa übertragen oder gespeichert. Temporäre lokale Aufnahmen werden nach Abschluss, Abbruch, Abmeldung oder spätestens beim nächsten App-Start gelöscht.

Für den Identitätsabgleich können dauerhaft privat gespeichert werden:

* Vorname beziehungsweise Vornamen,
* Nachname,
* Geburtsdatum,
* Ablaufdatum,
* Dokumentart,
* Verifizierungsstatus und Prüfzeitpunkte,
* technische Verfahrens-, Parser-, Datenschutz- und Assurance-Versionen.

Kennzeichen sowie Haltername aus den Feldern C.1.1 und C.1.2 werden nur vorübergehend zum Datenabgleich verwendet. C.1.1 und C.1.2 werden danach nicht dauerhaft gespeichert. Für Fahrzeuge, bei denen der Nutzer nicht selbst als Halter eingetragen ist, wird eine Eigenerklärung verlangt. Gespeichert werden der Erklärungstext beziehungsweise dessen Prüfsumme, Version, Annahmezeitpunkt, Fahrzeugbezug, Zuordnungsart und eine serverseitig erstellte private PDF. Die gezeichnete Unterschrift wird nur für die PDF-Erzeugung verarbeitet und nicht als separate Grafik gespeichert.

Der Abgleich bestätigt ausschließlich, dass aus den fotografierten Dokumentseiten ausgelesene Daten zueinander passen und die angegebenen Dokumentdaten zum Prüfzeitpunkt gültig erscheinen. Er ist keine amtliche Echtheitsprüfung, keine Registerabfrage und kein Nachweis von Eigentum oder zukünftiger Berechtigung. Manipulierte Aufnahmen oder unzutreffende Angaben können technisch nicht in jedem Fall erkannt werden.

Beim Ablauf eines Identitätsdokuments, bei relevanten Änderungen der Identitäts- oder Fahrzeugdaten, bei Entfernung eines Fahrzeugs, Widerruf einer Nutzungsberechtigung oder Kontolöschung wird der abhängige Status zurückgesetzt oder widerrufen. Eine erneute Prüfung kann erforderlich sein.

Rechtsgrundlage und endgültige Formulierung müssen vor einer Produktivfreigabe juristisch für den konkreten Einsatz geprüft werden. In Betracht kommen abhängig vom Zweck insbesondere Art. 6 Abs. 1 lit. b, lit. a oder lit. f DSGVO. Verifizierungsdaten und Erklärungs-PDFs sind nicht allgemein öffentlich sichtbar.''',
          ),
          _LegalSection(
            title: '12. Kennzeichen-Suche und räumlich-zeitliche Begrenzung',
            body:
                r'''Bei der Kennzeichen-Suche können insbesondere folgende Daten verarbeitet werden:

* eingegebenes Kennzeichen,
* Nutzer-ID des Suchenden,
* Zeitpunkt der Suche,
* Standort oder räumlicher Suchbereich,
* Suchradius,
* Aktivitäts- oder Anwesenheitszeitraum,
* Suchergebnis,
* technische Sicherheits- und Missbrauchsinformationen.

Nach der vorgesehenen Funktionsweise soll die Suche grundsätzlich auf einen Radius von ungefähr fünf Kilometern und ein Standort- oder Aktivitätsfenster von ungefähr einer Stunde begrenzt sein.

Der Server begrenzt den Suchradius auf höchstens fünf Kilometer und berücksichtigt nur gespeicherte Fahrzeugstandorte, die höchstens eine Stunde alt sind. Die Entfernung wird anhand der übermittelten Koordinaten berechnet; eine Anfrage außerhalb dieser Grenzen liefert kein Trefferprofil.

Die Angaben „ungefähr fünf Kilometer“ und „ungefähr eine Stunde“ sind keine Garantie für eine exakte Entfernung, Position oder Anwesenheit. Standortdaten können technisch ungenau, verzögert, manipuliert oder nicht verfügbar sein. Suchergebnisse dürfen nicht als verlässlicher Beweis dafür verstanden werden, dass sich eine Person oder ein Fahrzeug zu einem bestimmten Zeitpunkt an einem bestimmten Ort befand.

Die Suche darf ausschließlich für berechtigte und sachliche Kontaktzwecke verwendet werden. Verboten sind insbesondere:

* Stalking oder Nachverfolgung,
* Belästigung,
* Einschüchterung oder Bedrohung,
* Ausspähen von Personen,
* Erstellung von Bewegungsprofilen,
* massenhafte oder automatisierte Suchanfragen,
* Recherche aus Neugier ohne berechtigten Anlass,
* kommerzielle Werbung ohne Einwilligung,
* Täuschung oder Identitätsmissbrauch,
* Umgehung von Sperren oder Privatsphäre-Einstellungen.''',
          ),
          _LegalSection(
            title: '13. Kontaktanfragen',
            body:
                r'''Bei Kontaktanfragen können insbesondere verarbeitet werden:

* Nutzer-ID des Absenders,
* Nutzer-ID des Empfängers,
* betroffenes Kennzeichen oder Fahrzeug,
* Zeitpunkt der Anfrage,
* Anfragegrund oder Nachricht, soweit vorgesehen,
* Status der Anfrage,
* Annahme, Ablehnung, Rücknahme oder Ablauf,
* Sperr- oder Meldeinformationen,
* technische Sicherheits- und Missbrauchsdaten.

Nutzer sind dafür verantwortlich, dass für ihre Anfrage ein berechtigter und sachlicher Anlass besteht. Wiederholte, automatisierte, täuschende, aufdringliche oder missbräuchliche Kontaktanfragen sind verboten.

Zur Verhinderung von Missbrauch können abgelehnte, zurückgezogene, abgelaufene oder blockierte Anfragen für einen begrenzten Zeitraum gespeichert werden. Dies kann erforderlich sein, um Mehrfachanfragen, Sperrumgehungen, Belästigung oder andere Verstöße zu erkennen.

Kontaktanfragen bleiben mit ihrem Status gespeichert, bis sie im Rahmen der jeweiligen Funktion oder bei der Kontolöschung entfernt werden. Eine darüber hinausgehende feste Aufbewahrungsfrist wird derzeit nicht zugesagt. Sicherheitsbezogene Vorgänge können nur so lange erhalten bleiben, wie dies für Missbrauchsabwehr, Beschwerden oder gesetzliche Pflichten erforderlich ist.''',
          ),
          _LegalSection(
            title: '14. Chat und Kommunikationsinhalte',
            body:
                r'''Nach Annahme einer Kontaktanfrage können Nutzer miteinander kommunizieren. Dabei können insbesondere verarbeitet werden:

* Textnachrichten,
* Absender und Empfänger,
* Zeitstempel,
* Zustellstatus,
* Lesestatus,
* Reaktionen,
* Antwortbezüge,
* Fotos und Videos,
* Dokumente und Dateien,
* Sprachnachrichten,
* Standortinformationen,
* aktiv ausgewählte Kontaktdaten,
* technische Nachrichtenmetadaten,
* Melde-, Sperr- und Moderationsinformationen.

Chatinhalte werden gespeichert und den beteiligten Nutzern angezeigt, soweit dies zur Bereitstellung der Chatfunktion erforderlich ist.

Nutzer entscheiden selbst, welche Inhalte sie versenden. Sie müssen vor dem Versand prüfen, ob sie zur Weitergabe berechtigt sind.

Im Chat sind insbesondere verboten:

* Belästigung,
* Stalking,
* Drohungen,
* Beleidigungen,
* Erpressung,
* Täuschung,
* Betrug,
* Spam,
* unerlaubte Werbung,
* Hassrede,
* sexuelle Belästigung,
* Veröffentlichung vertraulicher Informationen,
* rechtswidrige Bild-, Video- oder Audioaufnahmen,
* Inhalte, die Rechte Dritter verletzen,
* strafbare oder sonstige rechtswidrige Inhalte,
* Schadsoftware oder schädliche Dateien.

Chatinhalte werden nicht allein deshalb automatisch als vertraulich oder rechtlich privilegiert behandelt, weil sie in einem privaten Chat versendet werden. Empfänger können Inhalte technisch speichern, fotografieren, weiterleiten oder anderweitig verwenden. plaqa kann ein solches Verhalten nicht in jedem Fall verhindern.

Bei einer Meldung, einem konkreten Missbrauchsverdacht, einer Sicherheitsprüfung oder einer rechtlichen Verpflichtung können gemeldete oder relevante Chatdaten durch hierzu berechtigte Personen geprüft werden, soweit dies erforderlich und rechtlich zulässig ist.

Inhalte können gesperrt, ausgeblendet, gelöscht, gesichert oder rechtlich ausgewertet werden, wenn konkrete Anhaltspunkte für Verstöße bestehen.

Chats werden gespeichert, bis sie nach den angebotenen Löschfunktionen oder im Zuge einer Kontolöschung verarbeitet werden. Eine lokale oder einseitige Löschung entfernt Inhalte nicht automatisch aus dem Konto des anderen Teilnehmers. Bei einer Kontolöschung wird das gelöschte Konto in gemeinsamen Chats pseudonymisiert; zugehörige Medienverweise werden entfernt, Textnachrichten können als Inhalt eines gelöschten Kontos erhalten bleiben.

Chats sind durch Anmeldung, Teilnehmerprüfung und serverseitige Zugriffsregeln geschützt, aber nicht Ende-zu-Ende verschlüsselt.''',
          ),
          _LegalSection(
            title: '15. Storys',
            body:
                r'''Nutzer können abhängig vom Funktionsumfang Storys mit folgenden Inhalten veröffentlichen:

* Fotos,
* Videos,
* Text,
* Sticker,
* Statusinformationen,
* Fahrzeugsticker,
* Standortsticker,
* sonstige Medien oder Gestaltungselemente.

Nach der vorgesehenen Funktion sind Storys grundsätzlich für 24 Stunden sichtbar und nur für angenommene Kontakte zugänglich.

Storys erhalten beim Speichern einen Ablaufzeitpunkt nach 24 Stunden. Firestore- und Storage-Regeln beschränken den Zugriff auf den Eigentümer und die gespeicherte Zielgruppe; eine geplante Wartungsfunktion entfernt abgelaufene Story-Dokumente und zugehörige Medien. Screenshots werden weder verhindert noch zuverlässig erkannt.

Bei Storys können verarbeitet werden:

* Story-Inhalt,
* Nutzer-ID des Veröffentlichenden,
* Veröffentlichungs- und Ablaufzeitpunkt,
* Sichtbarkeitskreis,
* Aufrufe,
* Nutzer-IDs der Betrachter,
* Reaktionen,
* Meldeinformationen,
* Standort- oder Fahrzeugangaben, falls eingefügt.

Story-Aufrufe können gespeichert und dem veröffentlichenden Nutzer angezeigt werden.

Die Sichtbarkeit von 24 Stunden bedeutet nicht zwingend, dass sämtliche technischen Kopien, Protokolle, Meldedaten oder Sicherungen unmittelbar nach 24 Stunden gelöscht sind. Gemeldete Inhalte, Sicherheitskopien oder beweisrelevante Daten können unter den in dieser Datenschutzerklärung beschriebenen Voraussetzungen länger gespeichert bleiben.

Nutzer dürfen nur Inhalte veröffentlichen, an denen sie die erforderlichen Rechte besitzen. Insbesondere dürfen ohne ausreichende Rechtsgrundlage oder Einwilligung keine Inhalte veröffentlicht werden, die:

* fremde Personen erkennbar zeigen,
* fremde Kennzeichen hervorheben,
* private Anschriften oder Standorte offenlegen,
* Kinder oder andere besonders schutzbedürftige Personen zeigen,
* vertrauliche Dokumente oder Nachrichten enthalten,
* Urheber-, Marken-, Persönlichkeits- oder Datenschutzrechte verletzen,
* beleidigend, bedrohlich, diskriminierend oder rechtswidrig sind.''',
          ),
          _LegalSection(
            title: '16. Fahrzeugbezogene Hinweise und Meldungen',
            body:
                r'''Nutzer können fahrzeugbezogene Hinweise oder Meldungen senden. Dabei können insbesondere verarbeitet werden:

* Nutzer-ID des Absenders,
* Empfänger oder betroffenes Nutzerkonto,
* Kennzeichen oder Fahrzeugbezug,
* Inhalt der Meldung,
* Zeitpunkt,
* gegebenenfalls Standortbezug,
* Anhänge,
* Zustellstatus,
* Melde- und Moderationsdaten,
* technische Sicherheitsinformationen.

Ein Hinweis kann für den Empfänger anonym oder pseudonym dargestellt werden. Dies bedeutet nicht, dass der Hinweis gegenüber plaqa technisch anonym ist.

Zur Sicherheit, Missbrauchsabwehr und Nachweisführung können Hinweise intern insbesondere mit folgenden Informationen verknüpft werden:

* Nutzerkonto,
* interner Nutzer-ID,
* Zeitstempel,
* betroffenem Kennzeichen,
* technischen Protokollen,
* IP-Adresse, soweit technisch erfasst,
* Geräte- oder Sitzungsinformationen,
* vorherigen Meldungen oder Sperren.

Solche Zuordnungen werden nicht ohne Grund gegenüber anderen Nutzern offengelegt. Eine Offenlegung kann jedoch erfolgen, soweit:

* der Nutzer eingewilligt hat,
* dies zur Bearbeitung einer Meldung erforderlich ist,
* eine gesetzliche Pflicht besteht,
* eine vollziehbare behördliche oder gerichtliche Anordnung vorliegt,
* dies zur Geltendmachung, Ausübung oder Verteidigung rechtlicher Ansprüche erforderlich und zulässig ist,
* der Schutz lebenswichtiger Interessen dies in einem Ausnahmefall erfordert.

Verboten sind insbesondere:

* bewusst falsche Meldungen,
* Beleidigungen,
* Drohungen,
* Rufschädigung,
* Denunziation,
* Belästigung,
* wiederholte unerwünschte Hinweise,
* Vortäuschung von Gefahren,
* Diskriminierung,
* Erpressung,
* Veröffentlichung privater oder vertraulicher Informationen,
* sonstige rechtswidrige oder missbräuchliche Meldungen.

plaqa prüft nicht zwingend jede Meldung vor der Zustellung und übernimmt keine Gewähr für deren Richtigkeit. Empfänger dürfen Hinweise nicht ungeprüft als Tatsachenbeweis verwenden.

Bei akuter Gefahr, einem Unfall, einer Straftat oder einer dringenden Verkehrsbehinderung ist unmittelbar die zuständige Stelle zu kontaktieren. plaqa ersetzt insbesondere nicht Polizei, Feuerwehr, Rettungsdienst, Ordnungsbehörde, Pannenhilfe oder Abschleppdienst.''',
          ),
          _LegalSection(
            title: '17. Standortdaten',
            body:
                r'''Standortdaten können verarbeitet werden, wenn Nutzer eine standortbezogene Funktion aktiv verwenden und die erforderliche Berechtigung erteilen.

Dies kann insbesondere folgende Funktionen betreffen:

* Kennzeichen-Suche,
* räumliche Begrenzung von Kontaktmöglichkeiten,
* fahrzeugbezogene Hinweise,
* Standortanhänge im Chat,
* Standortsticker in Storys,
* Sicherheits- und Missbrauchsprüfung.

Abhängig von Gerät, Betriebssystem und Berechtigung können insbesondere verarbeitet werden:

* genauer oder ungefährer Standort,
* Breiten- und Längengrad,
* Genauigkeitswert,
* Zeitpunkt der Standortbestimmung,
* Bewegungs- oder Aktivitätsstatus, soweit technisch aktiviert,
* IP-basierte ungefähre Standortinformationen,
* Metadaten einer aktiv geteilten Datei oder Aufnahme.

plaqa beabsichtigt nicht, ohne Funktionsbezug dauerhafte Bewegungsprofile zu erstellen. Die App fordert keine Berechtigung für Standortzugriff im Hintergrund an. Standort wird erst bei einer aktiv ausgelösten Funktion abgefragt. Für Kennzeichensuche, Fahrzeugstandort, Chatstandort oder Meldung können exakte Breiten- und Längengrade gespeichert werden; ein Geohash ist im aktuellen Ablauf nicht erforderlich.

Der für die Kennzeichensuche gespeicherte Fahrzeugstandort wird nach einer Stunde nicht mehr als aktueller Treffer berücksichtigt. Andere aktiv geteilte Standortangaben bleiben Bestandteil des jeweiligen Chats oder Meldevorgangs, bis dieser gelöscht, anonymisiert oder aus einem berechtigten Sicherheits- oder Rechtsgrund nicht mehr benötigt wird.

Standortangaben können ungenau, veraltet oder technisch manipuliert sein. Sie dürfen nicht als Garantie für den tatsächlichen Aufenthaltsort einer Person oder eines Fahrzeugs verstanden werden.

Nutzer können Standortberechtigungen in den Einstellungen ihres Betriebssystems verwalten. Wird die Berechtigung entzogen, können standortbezogene Funktionen eingeschränkt oder nicht mehr nutzbar sein.''',
          ),
          _LegalSection(
            title: '18. Kamera, Fotos, Videos, Mikrofon, Kontakte und Dateien',
            body:
                r'''Je nach aktiv genutzter Funktion kann die App Zugriff auf folgende Gerätefunktionen anfordern:

18.1 Kamera und Medienbibliothek

Für:

* Profilbilder,
* Storys,
* Chat-Anhänge,
* Hinweise oder Meldungen,
* Verifizierungsdokumente,
* Videoaufnahmen.

18.2 Mikrofon

Für:

* Sprachnachrichten,
* Videos mit Ton,
* sonstige Audiofunktionen.

18.3 Kontakte

Kontaktdaten sollen nur verarbeitet werden, wenn ein Nutzer aktiv einen Kontakt auswählt und im Chat teilt.

Auf unterstützten Geräten verwendet die App dafür den systemseitigen Kontaktauswahldialog. Sie fordert keinen allgemeinen Zugriff auf das gesamte Adressbuch an und speichert nur den vom Nutzer ausgewählten Namen und die ausgewählte Telefonnummer in der Nachricht.

18.4 Dateien und Dokumente

Dokumente oder Dateien werden verarbeitet, wenn der Nutzer sie aktiv auswählt, hochlädt oder versendet.

Nutzer bestimmen selbst, welche Inhalte sie bereitstellen. Sie müssen vor dem Upload prüfen, ob:

* sie die erforderlichen Rechte besitzen,
* keine unbeteiligten Dritten unzulässig erkennbar sind,
* keine unnötigen sensiblen Daten enthalten sind,
* keine Rechte Dritter verletzt werden,
* der Inhalt für den jeweiligen Zweck erforderlich ist.

Berechtigungen können über das Betriebssystem entzogen werden. Bereits hochgeladene Inhalte werden dadurch nicht automatisch gelöscht.''',
          ),
          _LegalSection(
            title: '19. Push-Benachrichtigungen',
            body:
                r'''Push-Benachrichtigungen werden technisch über Firebase Cloud Messaging vorbereitet. Erst wenn Nutzer App-Mitteilungen bewusst aktivieren und die Systemberechtigung erteilen, kann ein gerätebezogenes Registrierungstoken privat dem jeweiligen Konto zugeordnet werden. Der Versand über Apple-Geräte setzt zusätzlich die noch abzuschließende APNs-Konfiguration voraus.

Dabei können insbesondere folgende Daten verarbeitet werden:

* Push-Token beziehungsweise FCM-Registrierungstoken,
* App-Instanz oder Installationskennung,
* Gerätetyp,
* Betriebssystem,
* Sprache,
* Benachrichtigungseinstellungen,
* technische Versand- und Zustellinformationen,
* Bezug zum Nutzerkonto.

Push-Benachrichtigungen können unter anderem über neue Kontaktanfragen, Nachrichten, Story-Aktivitäten, Sicherheitshinweise oder Kontovorgänge informieren.

Nutzer können Push-Benachrichtigungen in den App- oder Betriebssystemeinstellungen deaktivieren. Vor einer späteren Aktivierung werden Vorschautexte auf dem Sperrbildschirm sowie Token-Löschung bei Abmeldung und Kontolöschung technisch festgelegt und diese Erklärung aktualisiert.''',
          ),
          _LegalSection(
            title: '20. Technische Betriebs-, Protokoll- und Sicherheitsdaten',
            body:
                r'''Beim Zugriff auf die App und die verbundenen Server können technisch erforderliche Daten verarbeitet werden, insbesondere:

* IP-Adresse,
* Datum und Uhrzeit des Zugriffs,
* App-Version,
* Gerätetyp,
* Gerätehersteller und Gerätemodell,
* Betriebssystem und Betriebssystemversion,
* Sprache und Zeitzone,
* Netzwerkstatus,
* Firebase- oder Installationskennung,
* Sitzungs- und Authentifizierungsdaten,
* aufgerufene Funktion,
* Fehlermeldungen,
* Server- und Sicherheitsprotokolle,
* fehlgeschlagene Anmeldeversuche,
* Sperr-, Melde- oder Missbrauchsinformationen,
* technische Zustell- und Synchronisationsdaten.

Diese Daten werden verarbeitet, um:

* die App technisch bereitzustellen,
* Fehler zu erkennen und zu beheben,
* Angriffe und unberechtigte Zugriffe zu erkennen,
* Missbrauch zu verhindern,
* Systemstabilität sicherzustellen,
* Supportfälle zu untersuchen,
* rechtliche Ansprüche nachzuweisen oder abzuwehren.

Rechtsgrundlage ist regelmäßig Art. 6 Abs. 1 lit. b oder lit. f DSGVO.

Firebase und Google Cloud erzeugen für Authentifizierung, Functions, Hosting und Sicherheitsprüfungen technische Betriebsprotokolle nach den jeweiligen Diensteinstellungen. plaqa legt hierfür keine pauschale eigene Frist fest. Protokolle werden nur so lange verarbeitet, wie dies für Betrieb, Fehleranalyse, Sicherheit, Missbrauchsabwehr oder gesetzliche Nachweise erforderlich ist.''',
          ),
          _LegalSection(
            title:
                '21. Missbrauchserkennung, Moderation und Durchsetzung der Regeln',
            body:
                r'''Zum Schutz der Nutzer, Dritter und der technischen Infrastruktur können wir Informationen verarbeiten, um Verstöße gegen Gesetze oder Nutzungsbedingungen zu erkennen und zu bearbeiten.

Hierzu können insbesondere zusammengeführt und ausgewertet werden:

* Nutzerkonto und Nutzer-ID,
* Kontaktanfragen,
* Meldungen und Beschwerden,
* Chat- oder Story-Inhalte, soweit konkret gemeldet oder für die Prüfung erforderlich,
* Kennzeichenbezüge,
* Zeitstempel,
* IP-Adressen und technische Kennungen,
* Geräte- und Sitzungsdaten,
* frühere Verwarnungen oder Sperren,
* Verifizierungsstatus,
* Beweismittel, Screenshots oder Supportkommunikation.

Mögliche Maßnahmen sind:

* Warnung,
* Einschränkung einzelner Funktionen,
* Begrenzung von Anfragen,
* Ausblendung oder Entfernung von Inhalten,
* vorübergehende oder dauerhafte Kontosperre,
* Sicherung relevanter Nachweisdaten,
* Information betroffener Nutzer,
* Weitergabe an zuständige Stellen, soweit eine Rechtsgrundlage besteht,
* Geltendmachung oder Verteidigung rechtlicher Ansprüche.

Eine Weitergabe an Behörden erfolgt nicht allein aufgrund einer beliebigen privaten Forderung. Sie setzt eine gesetzliche Grundlage, eine rechtmäßige Anordnung, eine erforderliche Rechtsverfolgung oder einen anderen zulässigen Übermittlungsgrund voraus.

Meldungen können direkt am Inhalt oder unter Einstellungen > Hilfe & Rechtliches > Support > Problem melden eingereicht werden. Abhängig von Art und Schwere kommen Ausblendung, Entfernung, Funktionseinschränkung oder Kontosperre in Betracht. Beschwerden gegen eine Maßnahme können an support@plaqa.de gerichtet werden; gesetzliche Begründungs- und Rechtsschutzpflichten bleiben unberührt.''',
          ),
          _LegalSection(
            title: '22. Nutzerverantwortung',
            body:
                r'''Nutzer bestätigen bei der Registrierung und während der Nutzung, dass:

* ihre Angaben richtig und aktuell sind,
* sie keine fremde Identität verwenden,
* sie nur eigene oder rechtmäßig nutzbare Inhalte hochladen,
* sie über erforderliche Einwilligungen und Nutzungsrechte verfügen,
* sie keine Persönlichkeits-, Datenschutz-, Urheber-, Marken- oder sonstigen Rechte Dritter verletzen,
* sie keine Personen belästigen, verfolgen, bedrohen, täuschen oder ausspähen,
* sie Kennzeichen-, Standort-, Bild-, Video-, Chat-, Story- und Hinweisfunktionen verantwortungsvoll nutzen,
* sie keine illegalen, beleidigenden, diskriminierenden, gefährlichen oder irreführenden Inhalte verbreiten,
* sie Schutzmechanismen, Sperren oder Sichtbarkeitseinstellungen nicht umgehen,
* sie keine automatisierten oder massenhaften Anfragen durchführen,
* sie keine Zugangsdaten an unberechtigte Dritte weitergeben.

Nutzer verstehen, dass ihre Inhalte je nach Funktion:

* anderen Nutzern angezeigt,
* an bestimmte Kontakte übermittelt,
* vom Empfänger gespeichert oder weitergegeben,
* bei einer Meldung durch berechtigte Personen geprüft,
* bei einem Verstoß gesperrt oder gelöscht,
* bei rechtlicher Erforderlichkeit gesichert und ausgewertet,
* bei Vorliegen einer Rechtsgrundlage an zuständige Stellen übermittelt werden können.

Diese Nutzerverantwortung entbindet plaqa nicht von eigenen gesetzlichen Pflichten.''',
          ),
          _LegalSection(
            title: '23. Firebase und Google-Dienste',
            body:
                r'''Für den Betrieb von plaqa werden Dienste der Google-Gruppe beziehungsweise Firebase eingesetzt.

Zum aktuellen technischen Umfang gehören:

* Firebase Authentication,
* Cloud Firestore,
* Cloud Storage for Firebase,
* Cloud Functions for Firebase,
* Firebase Hosting,
* Firebase App Check,
* Google Sign-In und für die optionale Fahrzeugbild-Erstellung Google Cloud Vertex AI/Gemini.

Die jeweils anwendbare Google-Vertragsgesellschaft und die Datenschutzbedingungen richten sich nach dem für das Firebase- beziehungsweise Google-Cloud-Projekt geführten Vertrag. Aktuelle Datenschutzinformationen stellt Google unter https://firebase.google.com/support/privacy und https://policies.google.com/privacy bereit.

Google verarbeitet die vom Betreiber bereitgestellten Endnutzerdaten bei vielen Firebase-Diensten grundsätzlich als Auftragsverarbeiter. Bei Google Sign-In, App-Store-Diensten und bestimmten Sicherheits- oder Vertragsdaten kann Google zusätzlich in eigener Verantwortlichkeit handeln.

Je nach Funktion können durch Google/Firebase insbesondere verarbeitet werden:

* Nutzer- und Authentifizierungskennungen,
* E-Mail-Adressen,
* Profildaten,
* Datenbankinhalte,
* hochgeladene Dateien,
* Push-Token,
* IP-Adressen,
* Geräte- und App-Informationen,
* technische Protokolle,
* Nutzungs- und Sicherheitsdaten.

Die Verarbeitung dient insbesondere der Authentifizierung, Speicherung, Datenbanksynchronisation, Dateibereitstellung, Sicherheit und technischen Bereitstellung. Cloud Functions sind in europe-west3 konfiguriert. Firebase Authentication wird nach Angaben von Google in US-Rechenzentren betrieben; andere Firebase-Dienste verwenden ihre jeweils konfigurierte oder globale Infrastruktur. Google stellt hierfür Datenschutz- und Auftragsverarbeitungsbedingungen sowie Informationen zu Unterauftragsverarbeitern bereit.''',
          ),
          _LegalSection(
            title: '24. Empfänger und Kategorien von Empfängern',
            body:
                r'''Personenbezogene Daten können im erforderlichen Umfang an folgende Empfänger oder Empfängerkategorien übermittelt werden:

* Hosting-, Cloud- und Infrastrukturanbieter,
* Google/Firebase,
* IT-Dienstleister und Entwickler,
* Support- und Wartungsdienstleister,
* Verifizierungsanbieter, falls eingesetzt,
* Zahlungs- und App-Store-Anbieter,
* Kommunikations- oder Push-Dienstleister,
* Rechtsanwälte, Steuerberater und sonstige Berufsgeheimnisträger,
* Versicherungen,
* Gerichte, Behörden oder Strafverfolgungsstellen bei Vorliegen einer Rechtsgrundlage,
* andere Nutzer, soweit dies durch die jeweilige App-Funktion vorgesehen ist,
* potenzielle Erwerber oder Rechtsnachfolger im Rahmen zulässiger Unternehmenstransaktionen.

Dienstleister erhalten nur solche Daten, die für ihre jeweilige Aufgabe erforderlich sind. Aktuell gehören dazu insbesondere Google/Firebase und Google Cloud für Authentifizierung, Datenbank, Dateien, Backend, App Check, Hosting und optionale Fahrzeugbilder sowie IONOS für die plaqa-E-Mail-Postfächer. Der jeweilige App Store verarbeitet Download- und Store-Daten in eigener Verantwortung. Soweit erforderlich, werden Verträge zur Auftragsverarbeitung geschlossen.''',
          ),
          _LegalSection(
            title: '25. App Stores und In-App-Käufe',
            body:
                r'''plaqa kann über den jeweiligen App Store bereitgestellt werden. Die iOS-Fassung befindet sich noch in der technischen Vorbereitung und ist noch nicht im Apple App Store veröffentlicht.

Beim Download, bei Updates oder In-App-Käufen verarbeiten die jeweiligen Store-Anbieter Daten in eigener Verantwortung. Dazu können gehören:

* Store-Konto,
* Geräteinformationen,
* Kauf- und Zahlungsdaten,
* Abonnementstatus,
* Beleg- oder Transaktionskennung,
* Land und Währung,
* technische Download- und Diagnosedaten.

plaqa erhält regelmäßig nicht alle vollständigen Zahlungsdaten. Die aktuelle App-Version bietet keine In-App-Käufe und keine Abonnements an und bindet kein Zahlungs-SDK ein. Vor einer späteren Aktivierung wird dieser Abschnitt um die konkret eingesetzten Store- und Zahlungsprozesse ergänzt.''',
          ),
          _LegalSection(
            title: '26. Optionale Analyse- und Crash-Dienste',
            body:
                r'''Firebase Analytics, Google Analytics for Firebase und Firebase Crashlytics sind in der aktuellen App-Version nicht eingebunden und nicht aktiv.

Vor einer Aktivierung müssen insbesondere geprüft werden:

* welche Daten tatsächlich erhoben werden,
* ob Geräte- oder Werbekennungen verarbeitet werden,
* ob eine Einwilligung erforderlich ist,
* wie die Einwilligung eingeholt und widerrufen wird,
* ob eine Nutzung ohne Einwilligung technisch verhindert wird,
* welche Aufbewahrungsfristen gelten,
* welche Drittlandtransfers stattfinden,
* ob die Datenschutzerklärung aktualisiert werden muss.

Vor einer späteren Einbindung werden Einwilligung, Widerruf, automatische Initialisierung, Datenarten, Aufbewahrung und Drittlandverarbeitung technisch und datenschutzrechtlich neu bewertet.''',
          ),
          _LegalSection(
            title: '27. Drittlandübermittlungen',
            body:
                r'''Google, Firebase oder andere Dienstleister können Daten in Staaten außerhalb Deutschlands, des Europäischen Wirtschaftsraums oder der Schweiz verarbeiten oder zugänglich machen.

Eine Übermittlung in ein Drittland erfolgt nur, soweit die datenschutzrechtlichen Voraussetzungen erfüllt sind. Als Grundlage kommen insbesondere in Betracht:

* ein Angemessenheitsbeschluss der Europäischen Kommission,
* eine gültige Zertifizierung nach dem EU-US Data Privacy Framework, soweit anwendbar,
* Standardvertragsklauseln der Europäischen Kommission,
* zusätzliche technische oder organisatorische Schutzmaßnahmen,
* eine gesetzliche Ausnahme nach Art. 49 DSGVO.

Trotz vertraglicher und technischer Schutzmaßnahmen kann bei bestimmten Drittländern nicht ausgeschlossen werden, dass Behörden nach lokalem Recht Zugriff auf Daten verlangen und europäische Betroffenenrechte nur eingeschränkt durchsetzbar sind.

Google verweist für internationale Übermittlungen unter anderem auf das EU-US Data Privacy Framework und, soweit erforderlich, Standardvertragsklauseln. Firebase Authentication wird ausschließlich aus US-Rechenzentren bereitgestellt; andere Dienste können abhängig von ihrer Konfiguration und Funktion global oder in ausgewählten Regionen verarbeitet werden.''',
          ),
          _LegalSection(
            title: '28. Speicherdauer',
            body:
                r'''Wir speichern personenbezogene Daten grundsätzlich nur so lange, wie dies für den jeweiligen Zweck erforderlich ist oder gesetzliche Aufbewahrungs- beziehungsweise Nachweispflichten bestehen.

Die Speicherdauer richtet sich insbesondere nach:

* Dauer des Benutzerkontos,
* Nutzung der jeweiligen Funktion,
* Status von Anfragen und Chats,
* Sichtbarkeitsdauer von Storys,
* gesetzlichen Aufbewahrungspflichten,
* laufenden Beschwerden oder Rechtsstreitigkeiten,
* Sicherheits- oder Missbrauchsvorfällen,
* Verjährungsfristen,
* Erforderlichkeit zur Durchsetzung von Sperren,
* technischen Sicherungs- und Wiederherstellungszyklen.

Der aktuelle technische und organisatorische Stand ist:

Datenkategorie	Vorgesehene Speicherdauer
Kontodaten	Bis zur Kontolöschung, sofern keine Aufbewahrungsgründe bestehen
Profildaten	Bis zur Löschung oder Änderung durch den Nutzer beziehungsweise Kontolöschung
Fahrzeug- und Kennzeichendaten	Bis zur Entfernung oder Kontolöschung, vorbehaltlich Sicherheits- und Nachweisfristen
Kontaktanfragen	Bis zur funktionsbezogenen Entfernung oder Kontolöschung; sicherheitsrelevante Vorgänge nur solange erforderlich
Chatnachrichten	Bis zur angebotenen Löschung oder Kontolöschung; bei anderen Teilnehmern gegebenenfalls pseudonymisiert weiter sichtbar
Story-Inhalte	Sichtbar grundsätzlich 24 Stunden; anschließend für die technische Bereinigung vorgesehen
Story-Aufrufdaten	Zusammen mit der Story beziehungsweise solange für Meldungen oder Sicherheit erforderlich
Standortdaten	Fahrzeugstandorte sind nach einer Stunde nicht mehr suchwirksam; aktiv geteilte Standorte folgen dem jeweiligen Inhalt
Lokale Verifizierungsaufnahmen	Nur während des lokalen Abgleichs; Löschung nach Abschluss, Abbruch, Abmeldung oder beim nächsten App-Start
Private Identitätsdaten und Verifizierungsstatus	Bis zur Änderung, zum Widerruf, Ablauf des Dokuments oder zur Kontolöschung, soweit kein vorrangiger Aufbewahrungsgrund besteht
Eigenerklärungs-PDF	Bis zum Widerruf, zur Entfernung des Fahrzeugs oder zur Kontolöschung, soweit kein vorrangiger Aufbewahrungsgrund besteht
Verifizierungsstatus	Bis zur Änderung, Kontolöschung oder solange ein erforderlicher Prüf- beziehungsweise Sicherheitsnachweis besteht
Push-Token	Derzeit nicht erhoben, da Push nicht aktiviert ist
Sicherheits- und Missbrauchslogs	Nur solange für Sicherheit, Nachweis, Beschwerden oder gesetzliche Pflichten erforderlich
Supportanfragen	Bis zum Abschluss und darüber hinaus nur solange ein berechtigter Nachweis- oder Rechtsgrund besteht
Kauf- und Abrechnungsdaten	Derzeit nicht durch plaqa erhoben, da keine In-App-Käufe angeboten werden
Einwilligungsnachweise	Für die Dauer der Verarbeitung und erforderliche Nachweiszeit
Backups	Nach den technischen Sicherungs- und Wiederherstellungszyklen des jeweiligen Dienstes; keine unbegrenzte Aufbewahrung

Eine Löschung kann vorübergehend eingeschränkt sein, wenn Daten:

* gesetzlichen Aufbewahrungspflichten unterliegen,
* zur Bearbeitung einer Meldung benötigt werden,
* zur Aufklärung eines Sicherheits- oder Missbrauchsfalls erforderlich sind,
* zur Geltendmachung, Ausübung oder Verteidigung von Rechtsansprüchen benötigt werden,
* aufgrund einer behördlichen oder gerichtlichen Anordnung gesichert werden müssen,
* Bestandteil zeitlich begrenzter technischer Sicherungskopien sind.

In diesen Fällen werden Daten nach Möglichkeit gesperrt oder in ihrer Verarbeitung beschränkt und nach Wegfall des Grundes gelöscht.

Eine pauschale unbegrenzte Vorratsspeicherung findet nicht statt. Gleichzeitig kann keine sofortige Löschung sämtlicher Daten aus allen produktiven Systemen, Protokollen und Sicherungskopien zugesichert werden.''',
          ),
          _LegalSection(
            title: '29. Kontolöschung',
            body:
                r'''Nutzer können die Löschung ihres Kontos in der App unter Einstellungen > Konto > Konto & Sicherheit > Gefahrenbereich > Konto löschen oder per E-Mail an privacy@plaqa.de beantragen.

Vor einer Löschung kann eine Identitäts- oder Kontobestätigung erforderlich sein, um unberechtigte Löschanträge zu verhindern.

Die Kontolöschung kann insbesondere folgende Folgen haben:

* Zugang zum Konto entfällt,
* Profil wird entfernt oder deaktiviert,
* aktive Sitzungen werden beendet,
* Fahrzeugzuordnungen werden aufgehoben,
* Kontaktanfragen werden gelöscht oder anonymisiert,
* Inhalte werden nach den jeweils geltenden Löschregeln entfernt oder einem gelöschten Konto zugeordnet,
* Push-Token werden entfernt, soweit technisch möglich,
* gesetzlich oder sicherheitsbedingt aufzubewahrende Daten bleiben gesperrt gespeichert.

Der serverseitige Löschworkflow entfernt das Auth-Konto sowie private Profil-, Fahrzeug-, Kennzeichen-, Story-, Verifizierungs- und Mediendaten. Gemeinsame Chats werden gesperrt und das gelöschte Konto pseudonymisiert; Textnachrichten können im Postfach anderer Teilnehmer als Inhalt eines gelöschten Kontos erhalten bleiben, während Medienverweise des gelöschten Kontos entfernt werden. Sicherheits- und Meldevorgänge können gelöscht oder pseudonymisiert werden. Eine feste Bearbeitungs- oder Backup-Nachlauffrist wird nicht zugesagt.''',
          ),
          _LegalSection(
            title: '30. Datenexport und Auskunft',
            body:
                r'''Nutzer können Auskunft über die zu ihrer Person verarbeiteten Daten verlangen. Soweit die Voraussetzungen vorliegen, kann außerdem ein Datenexport in einem strukturierten, gängigen und maschinenlesbaren Format verlangt werden.

Anfragen können in der App unter Einstellungen > Schutz & Daten > Datenschutz > Datenexport oder an privacy@plaqa.de gestellt werden.

Zur Verhinderung unberechtigter Datenzugriffe kann eine angemessene Identitätsprüfung erforderlich sein. Die App legt eine geschützte Exportanfrage an; die vollständige Zusammenstellung und Bereitstellung aller zuordenbaren Daten erfolgt derzeit nicht vollautomatisch.

Daten anderer Personen, Geschäftsgeheimnisse sowie Sicherheitsinformationen können bei einer Auskunft oder einem Export geschwärzt, eingeschränkt oder zurückgehalten werden, soweit dies gesetzlich zulässig oder erforderlich ist.''',
          ),
          _LegalSection(
            title: '31. Rechte betroffener Personen',
            body:
                r'''Betroffene Personen haben nach Maßgabe der gesetzlichen Voraussetzungen insbesondere folgende Rechte:

31.1 Auskunft

Recht auf Auskunft über die verarbeiteten personenbezogenen Daten und weitere Informationen nach Art. 15 DSGVO.

31.2 Berichtigung

Recht auf Berichtigung unrichtiger und Vervollständigung unvollständiger Daten nach Art. 16 DSGVO.

31.3 Löschung

Recht auf Löschung nach Art. 17 DSGVO, soweit keine gesetzlichen Gründe für eine weitere Verarbeitung bestehen.

31.4 Einschränkung

Recht auf Einschränkung der Verarbeitung nach Art. 18 DSGVO.

31.5 Datenübertragbarkeit

Recht auf Erhalt und Übertragung bestimmter Daten nach Art. 20 DSGVO.

31.6 Widerspruch

Recht, aus Gründen, die sich aus der besonderen Situation der betroffenen Person ergeben, gegen eine Verarbeitung auf Grundlage von Art. 6 Abs. 1 lit. e oder f DSGVO Widerspruch einzulegen.

Bei Direktwerbung besteht ein jederzeitiges Widerspruchsrecht ohne Angabe besonderer Gründe.

31.7 Widerruf einer Einwilligung

Eine erteilte Einwilligung kann jederzeit mit Wirkung für die Zukunft widerrufen werden.

31.8 Beschwerde bei einer Aufsichtsbehörde

Betroffene Personen können sich bei einer Datenschutzaufsichtsbehörde beschweren, insbesondere bei der Aufsichtsbehörde ihres Aufenthaltsorts, Arbeitsplatzes oder des Orts des vermuteten Verstoßes.

Für den Verantwortlichen in Hamburg ist grundsätzlich zuständig:

Der Hamburgische Beauftragte für Datenschutz und Informationsfreiheit
Ludwig-Erhard-Straße 22
20459 Hamburg
Deutschland

Die Beschwerde kann unabhängig von anderen verwaltungsrechtlichen oder gerichtlichen Rechtsbehelfen erfolgen.''',
          ),
          _LegalSection(
            title: '32. Minderjährige',
            body:
                r'''plaqa darf nur von Personen genutzt werden, die das festgelegte Mindestalter erreicht haben.

Mindestalter: 16 Jahre

Die App und ihre Community-Funktionen richten sich ausschließlich an Personen ab 16 Jahren.

Soweit die Verarbeitung auf einer Einwilligung in Bezug auf Dienste der Informationsgesellschaft beruht und der Nutzer das gesetzlich maßgebliche Alter noch nicht erreicht hat, kann die Zustimmung der Erziehungsberechtigten erforderlich sein.

plaqa richtet sich nicht gezielt an Kinder unter dem festgelegten Mindestalter. Das Geburtsdatum wird bei den persönlichen Daten gegen die dynamische Altersgrenze von 16 Jahren geprüft und nach der Bestätigung gesperrt. Werden konkrete Hinweise auf ein unzulässig minderjähriges oder falsch angegebenes Konto bekannt, kann das Konto geprüft, eingeschränkt oder gelöscht werden.''',
          ),
          _LegalSection(
            title: '33. Sicherheit der Verarbeitung',
            body:
                r'''Wir treffen angemessene technische und organisatorische Maßnahmen, um personenbezogene Daten gegen unbeabsichtigte oder unrechtmäßige Vernichtung, Verlust, Veränderung, unbefugte Offenlegung oder unbefugten Zugriff zu schützen.

Dazu können insbesondere gehören:

* Zugriffsbeschränkungen,
* rollenbasierte Berechtigungen,
* Authentifizierungs- und Autorisierungskonzepte,
* verschlüsselte Datenübertragung,
* Schutz von Administrationszugängen,
* Protokollierung sicherheitsrelevanter Zugriffe,
* Datensicherungen,
* Trennung von Entwicklungs-, Test- und Produktivsystemen,
* regelmäßige Sicherheitsupdates,
* Lösch- und Berechtigungskonzepte,
* Missbrauchserkennung,
* Schulung berechtigter Personen.

Technisch umgesetzt sind insbesondere TLS-verschlüsselte Übertragung, Firebase Authentication, optionaler Zwei-Faktor-Schutz, App Check, Firestore- und Storage-Zugriffsregeln, serverseitige Eingabe- und Teilnehmerprüfungen, erneute Anmeldung für sensible Kontoaktionen sowie begrenzte Function-Instanzen und Sicherheitsprotokolle. Interne organisatorische Maßnahmen werden getrennt von dieser öffentlichen Erklärung dokumentiert.

Keine elektronische Datenübertragung und kein Speichersystem kann absolute Sicherheit garantieren. Daher versprechen wir weder eine „100-prozentige Sicherheit“ noch einen vollständigen Ausschluss sämtlicher Sicherheitsrisiken.

Nutzer sind selbst verpflichtet, sichere Zugangsdaten zu verwenden, ihr Gerät zu schützen und Zugangsdaten nicht weiterzugeben.''',
          ),
          _LegalSection(
            title: '34. Datenschutzverletzungen',
            body:
                r'''Kommt es zu einer Verletzung des Schutzes personenbezogener Daten, prüfen wir den Vorfall nach den gesetzlichen Vorgaben.

Soweit erforderlich, wird der Vorfall innerhalb der gesetzlichen Fristen an die zuständige Datenschutzaufsichtsbehörde gemeldet. Besteht voraussichtlich ein hohes Risiko für Rechte und Freiheiten betroffener Personen, werden diese nach Maßgabe der gesetzlichen Anforderungen informiert.

Dies bedeutet nicht, dass jede technische Störung oder jeder Nutzerverstoß automatisch eine meldepflichtige Datenschutzverletzung darstellt.''',
          ),
          _LegalSection(
            title: '35. Automatisierte Entscheidungen und Profiling',
            body:
                r'''Derzeit sind keine ausschließlich automatisierten Entscheidungen vorgesehen, die gegenüber Nutzern rechtliche Wirkung entfalten oder sie in ähnlich erheblicher Weise beeinträchtigen.

Die aktuelle App verwendet technische Zugriffsregeln, Eingabeprüfungen und Rate-Limits, aber keine ausschließlich automatisierte endgültige Sperr-, Verifizierungs- oder Moderationsentscheidung mit rechtlicher oder ähnlich erheblicher Wirkung.

Technische Filter, Spam-Erkennung, Sicherheitsregeln oder automatisierte Hinweise können eingesetzt werden, soweit sie keine unzulässige ausschließlich automatisierte Entscheidung im Sinne von Art. 22 DSGVO darstellen.

Werden zukünftig Entscheidungen im Sinne des Art. 22 DSGVO eingesetzt, wird diese Datenschutzerklärung vorab ergänzt und es werden die gesetzlich erforderlichen Schutzmaßnahmen eingerichtet.''',
          ),
          _LegalSection(
            title: '36. Keine Notfall-, Behörden- oder Rechtsberatungsfunktion',
            body: r'''plaqa stellt eine Kommunikationsplattform bereit. plaqa:

* nimmt keine Notrufe entgegen,
* alarmiert nicht automatisch Polizei, Feuerwehr oder Rettungsdienste,
* veranlasst nicht automatisch Abschlepp- oder Pannenhilfe,
* prüft nicht zwingend die Richtigkeit von Nutzerhinweisen,
* ersetzt keine Anzeige bei Behörden,
* ersetzt keine rechtliche Beratung,
* garantiert keine rechtzeitige Kenntnisnahme durch den Empfänger,
* garantiert keine erfolgreiche Kontaktaufnahme,
* garantiert keine exakte Standortbestimmung.

Nutzer dürfen sich bei Gefahren, Unfällen, Straftaten oder dringenden Situationen nicht allein auf die App verlassen.''',
          ),
          _LegalSection(
            title: '37. Änderungen dieser Datenschutzerklärung',
            body: r'''Wir können diese Datenschutzerklärung ändern, wenn:

* neue Funktionen eingeführt werden,
* sich technische Abläufe ändern,
* neue Dienstleister eingesetzt werden,
* gesetzliche oder behördliche Anforderungen dies erfordern,
* Sicherheits- oder Verarbeitungsprozesse angepasst werden.

Die jeweils aktuelle Fassung wird innerhalb der App und auf der Website bereitgestellt.

Bei wesentlichen Änderungen werden Nutzer in angemessener Weise informiert. Soweit eine neue Einwilligung erforderlich ist, wird die betreffende Verarbeitung nicht allein aufgrund einer Änderung dieser Datenschutzerklärung begonnen.''',
          ),
          _LegalSection(
            title: '38. Verfügbarkeit der Datenschutzerklärung',
            body: r'''Diese Datenschutzerklärung soll dauerhaft abrufbar sein:

* in der App unter „Einstellungen > Datenschutz“,
* auf der Website unter https://plaqa.de/datenschutz/,
* gegebenenfalls über die Datenschutzangaben im jeweiligen App Store.''',
          ),
          _LegalSection(
            title: '39. Kontakt und aktuelle Fassung',
            body:
                r'''Die jeweils aktuelle Fassung ist unter https://plaqa.de/datenschutz/ und innerhalb der App verfügbar.

Datenschutzanfragen, Auskunfts-, Berichtigungs-, Lösch- oder Widerspruchsanliegen können an privacy@plaqa.de gerichtet werden. Wesentliche Änderungen an Datenarten, Zwecken oder Dienstleistern werden in dieser Erklärung nachvollziehbar aktualisiert.''',
          ),
        ],
      ),
      'Community-Richtlinien' => const _LegalContent(
        title: 'Community-Richtlinien',
        icon: Icons.shield_outlined,
        versionLabel: 'Aktuelle Version: ${LegalVersions.responsibleUse}',
        sections: [
          _LegalSection(
            title: 'Stand und Version',
            body: r'''Community-Richtlinien und Verhaltensregeln für plaqa

Stand: 22. August 2026
Version: 1.0.0''',
          ),
          _LegalSection(
            title: '1. Zweck der Community-Richtlinien',
            body:
                r'''plaqa ist eine mobile App zur geschützten Kontaktaufnahme rund um Fahrzeuge und Kennzeichen.

Diese Community-Richtlinien legen fest, wie Nutzer plaqa verwenden dürfen, welche Inhalte und Verhaltensweisen unzulässig sind und welche Maßnahmen bei Verstößen ergriffen werden können.

Unser Ziel ist eine sichere, respektvolle und verantwortungsvolle Nutzung der App. Die Richtlinien sollen insbesondere verhindern, dass plaqa für Belästigung, Stalking, Überwachung, Drohungen, Täuschung, Bloßstellung, falsche Anschuldigungen, Datenschutzverletzungen oder andere rechtswidrige Zwecke verwendet wird.

Die Community-Richtlinien gelten für sämtliche Funktionen und Inhalte von plaqa, insbesondere für:

* Benutzerkonten und Profile,
* Fahrzeug- und Kennzeichendaten,
* Kennzeichen-Suchen,
* Kontaktanfragen,
* Chats,
* Storys,
* fahrzeugbezogene Hinweise und Meldungen,
* Standortinformationen,
* Fotos, Videos und Tonaufnahmen,
* Dokumente und Verifizierungsnachweise,
* Blockier-, Melde- und Beschwerdefunktionen.

Ergänzend gelten die Allgemeinen Geschäftsbedingungen, die Datenschutzerklärung und das Impressum von plaqa.''',
          ),
          _LegalSection(
            title: '2. Grundprinzipien der Nutzung',
            body: r'''2.1 Respekt

Behandeln Sie andere Nutzer respektvoll. Meinungsverschiedenheiten rechtfertigen keine Beleidigungen, Drohungen, Einschüchterungen, Diskriminierungen oder persönlichen Angriffe.

2.2 Sicherheit

Verwenden Sie plaqa so, dass andere Personen weder gefährdet noch verängstigt oder unter Druck gesetzt werden.

Unterlassen Sie jedes Verhalten, das als Nachstellung, Überwachung, Bedrohung oder Vorbereitung einer rechtswidrigen Handlung verstanden werden kann.

2.3 Wahrheit und Sachlichkeit

Machen Sie nur Angaben, die Sie nach bestem Wissen für richtig halten.

Fahrzeugbezogene Hinweise und Meldungen müssen sachlich, nachvollziehbar und auf das erforderliche Maß beschränkt sein.

2.4 Datenschutz

Veröffentlichen oder übermitteln Sie keine personenbezogenen oder vertraulichen Informationen anderer Personen, wenn Sie hierzu nicht berechtigt sind.

Dies gilt insbesondere für:

* Namen,
* Telefonnummern,
* Adressen,
* E-Mail-Adressen,
* Standorte,
* Kennzeichen,
* Fahrzeugdaten,
* Fotos und Videos,
* Nachrichten und Screenshots,
* Dokumente,
* Gesundheitsdaten,
* Zahlungs- oder Kontodaten.

2.5 Keine Belästigung

Ein abgelehnter, blockierter oder erkennbar unerwünschter Kontaktversuch ist zu respektieren.

Versuchen Sie nicht, eine Ablehnung oder Blockierung über weitere Konten, andere Kennzeichen oder andere App-Funktionen zu umgehen.

2.6 Keine missbräuchliche Kennzeichennutzung

Kennzeichen dürfen nur im Rahmen der vorgesehenen Funktionen und für einen legitimen, sachlichen Zweck verwendet werden.

Kennzeichen dürfen nicht zur Überwachung, Verfolgung, Ausforschung, Veröffentlichung oder Erstellung eigener Datenbestände verwendet werden.''',
          ),
          _LegalSection(
            title: '3. Zulässige Nutzung',
            body:
                r'''plaqa darf insbesondere für folgende Zwecke verwendet werden:

3.1 Geschützte Kontaktaufnahme

Sie dürfen eine Kontaktanfrage senden, wenn ein nachvollziehbarer und verhältnismäßiger Anlass mit Bezug zu einem Fahrzeug oder einer konkreten Situation besteht.

3.2 Sachliche Fahrzeughinweise

Zulässig können beispielsweise Hinweise sein, dass:

* das Licht eines Fahrzeugs eingeschaltet ist,
* ein Fenster oder Schiebedach offensteht,
* ein sichtbarer Schaden am Fahrzeug vorhanden ist,
* ein Fahrzeug eine Einfahrt blockiert,
* ein Gegenstand auf oder neben dem Fahrzeug liegt,
* eine erkennbare Gefahr für das Fahrzeug besteht.

Die Nachricht muss sachlich bleiben und darf nur die Informationen enthalten, die für den Hinweis erforderlich sind.

3.3 Freiwillige Profil- und Story-Inhalte

Sie dürfen freiwillig Profil- und Story-Inhalte veröffentlichen, wenn:

* Sie die erforderlichen Rechte daran besitzen,
* die Inhalte rechtmäßig sind,
* keine Rechte anderer Personen verletzt werden,
* keine privaten oder sensiblen Informationen unberechtigt offengelegt werden.

3.4 Respektvolle Kommunikation

Sie dürfen über den Chat kommunizieren, wenn die Kontaktanfrage angenommen wurde.

Kommunikation muss respektvoll, freiwillig und frei von Druck, Täuschung oder Belästigung bleiben.

3.5 Berechtigte Meldungen

Sie dürfen Verstöße gegen diese Richtlinien melden, wenn Sie nach bestem Wissen davon ausgehen, dass ein tatsächlicher Verstoß vorliegt.

Meldungen müssen sachlich erfolgen und dürfen nicht als Mittel zur Rache, Einschüchterung oder Schädigung anderer Nutzer eingesetzt werden.''',
          ),
          _LegalSection(
            title: '4. Verbotene Nutzung',
            body:
                r'''Die folgenden Verhaltensweisen und Inhalte sind auf plaqa untersagt.

4.1 Stalking und Nachstellung

Verboten sind insbesondere:

* wiederholtes Aufsuchen oder Kontaktieren einer Person gegen ihren Willen,
* systematisches Beobachten einer Person oder eines Fahrzeugs,
* Nachverfolgen von Aufenthaltsorten,
* Verbinden mehrerer Standort- oder Kennzeicheninformationen zu einem Bewegungsprofil,
* Umgehen einer Blockierung oder Sperre,
* Kontaktaufnahme über weitere Konten nach einer Ablehnung.

4.2 Überwachung von Personen oder Fahrzeugen

plaqa darf nicht verwendet werden, um:

* Personen oder Fahrzeuge gezielt zu überwachen,
* regelmäßige Standorte festzustellen,
* private Gewohnheiten oder Bewegungsabläufe zu erfassen,
* Daten über Dritte zu sammeln,
* Kennzeichenlisten oder eigene Fahrzeugdatenbanken anzulegen.

4.3 Belästigung

Verboten sind insbesondere:

* wiederholte unerwünschte Nachrichten,
* aufdringliche Kontaktversuche,
* sexualisierte oder intime Ansprachen ohne Zustimmung,
* unerwünschte Werbung,
* Kontaktaufnahme trotz ausdrücklicher Ablehnung,
* Druck zur Herausgabe persönlicher Daten.

4.4 Drohungen und Gewalt

Nicht erlaubt sind:

* Gewaltandrohungen,
* Androhung von Sachbeschädigung,
* Androhung rechtlicher oder persönlicher Nachteile als Druckmittel,
* Verherrlichung oder Billigung konkreter Gewalt,
* Aufrufe zu Gewalt oder Selbstjustiz,
* Einschüchterung durch Bilder, Videos oder Tonaufnahmen.

4.5 Beleidigungen und Einschüchterung

Verboten sind:

* Beleidigungen,
* Erniedrigungen,
* Demütigungen,
* gezielte Provokationen,
* Einschüchterungen,
* aggressive oder menschenverachtende Äußerungen.

4.6 Erpressung und Nötigung

plaqa darf nicht verwendet werden, um eine Person durch Drohung, Druck oder Bloßstellung zu einer Handlung, Zahlung, Kontaktaufnahme oder Unterlassung zu zwingen.

4.7 Falsche Anschuldigungen

Untersagt sind:

* bewusst falsche Tatsachenbehauptungen,
* erfundene Vorfälle,
* falsche Unfall- oder Schadensmeldungen,
* unbelegte öffentliche Beschuldigungen,
* Meldungen mit dem Ziel, einer Person oder einem Unternehmen zu schaden.

4.8 Täuschung und Identitätsmissbrauch

Verboten sind insbesondere:

* Verwendung einer fremden Identität,
* Vortäuschung einer behördlichen oder geschäftlichen Funktion,
* Vortäuschung einer Verbindung zu plaqa,
* Verwendung fremder Profilbilder,
* Eintragung fremder Fahrzeuge oder Kennzeichen ohne Berechtigung,
* gefälschte oder manipulierte Verifizierungsnachweise.

4.9 Veröffentlichung fremder Daten

Ohne ausreichende Rechtsgrundlage oder Zustimmung dürfen insbesondere nicht veröffentlicht oder weitergegeben werden:

* private Telefonnummern,
* Wohnanschriften,
* E-Mail-Adressen,
* exakte Aufenthaltsorte,
* private Kennzeichen- oder Fahrzeugzuordnungen,
* Ausweisdaten oder Fahrzeugdokumente,
* Bank- oder Zahlungsdaten,
* vertrauliche Dokumente,
* private Chatverläufe.

4.10 Screenshots und Weitergabe privater Inhalte

Private Nachrichten, Storys, Fotos, Videos, Sprachnachrichten oder Profile dürfen nicht ohne ausreichende Berechtigung:

* veröffentlicht,
* an unbeteiligte Dritte weitergeleitet,
* in sozialen Netzwerken geteilt,
* zur Bloßstellung verwendet,
* für Werbung oder kommerzielle Zwecke genutzt werden.

Dies gilt auch für Screenshots und Bildschirmaufnahmen.

Eine Weitergabe kann zulässig sein, wenn sie zur Beweissicherung, Rechtsverfolgung oder Meldung eines Verstoßes erforderlich und rechtlich erlaubt ist.

4.11 Diskriminierung und Hassrede

Untersagt sind Inhalte oder Handlungen, die Personen oder Gruppen aufgrund geschützter oder persönlicher Merkmale herabwürdigen, bedrohen oder zu Hass gegen sie aufrufen.

Dazu gehören insbesondere rassistische, antisemitische, antimuslimische, sexistische, homophobe, transfeindliche oder behindertenfeindliche Inhalte.

4.12 Sexualisierte Inhalte ohne Einwilligung

Verboten sind insbesondere:

* unerwünschte sexuelle Nachrichten,
* intime Bilder ohne Einwilligung,
* Veröffentlichung oder Weitergabe intimer Inhalte,
* sexuelle Erpressung,
* sexualisierte Belästigung,
* heimliche Aufnahmen,
* manipulierte intime Darstellungen realer Personen.

4.13 Inhalte mit Minderjährigen

Strikt verboten sind:

* sexualisierte Darstellungen Minderjähriger,
* Anbahnung sexueller Kontakte zu Minderjährigen,
* Aufforderung Minderjähriger zur Übersendung intimer Inhalte,
* Veröffentlichung privater oder gefährdender Informationen über Minderjährige,
* Ausnutzung oder Gefährdung Minderjähriger.

Bilder oder Videos von Minderjährigen dürfen nur veröffentlicht werden, wenn dies rechtmäßig erfolgt und die erforderlichen Zustimmungen vorliegen.

plaqa ist ab 16 Jahren vorgesehen und richtet sich nicht an Kinder. Sexuelle Ausbeutung, Grooming, sexuelle Erpressung und jede Gefährdung Minderjähriger sind strikt untersagt. Der öffentliche Kinderschutzstandard ist unter https://plaqa.de/kinderschutz/ abrufbar.

4.14 Rechtswidrige oder gefährliche Inhalte

Nicht erlaubt sind insbesondere:

* strafbare Inhalte,
* Aufrufe zu Straftaten,
* Darstellung oder Anleitung konkreter Gewalttaten,
* volksverhetzende Inhalte,
* verbotene Symbole oder Propagandamittel,
* Inhalte zur gezielten Gefährdung anderer Personen,
* Schadsoftware oder schädliche Dateien.

4.15 Betrug

Verboten sind:

* betrügerische Angebote,
* Vortäuschung falscher Schäden,
* Zahlungsaufforderungen unter falschem Vorwand,
* Phishing,
* Abgreifen von Zugangsdaten,
* Täuschung über Identität, Fahrzeug oder Sachverhalt.

4.16 Spam und Werbung

Ohne ausdrückliche Freigabe von plaqa und erforderliche Zustimmung der Empfänger sind nicht erlaubt:

* Massenwerbung,
* wiederholte Werbenachrichten,
* Kettennachrichten,
* automatisierte Nachrichten,
* Affiliate- oder Empfehlungswerbung,
* kommerzielle Kontaktaufnahme über Kennzeichen.

4.17 Bots, Scraping und automatisierte Nutzung

Unzulässig sind:

* Bots,
* Scraper,
* Crawler,
* automatisierte Kennzeichenabfragen,
* automatisiertes Sammeln von Profilen oder Fahrzeugdaten,
* nicht genehmigte Schnittstellenzugriffe,
* Umgehung technischer Zugriffsbeschränkungen.

4.18 Massenabfragen

Nutzer dürfen nicht:

* eine große Zahl von Kennzeichen systematisch abfragen,
* Kennzeichenlisten hochladen,
* Suchergebnisse automatisiert speichern,
* eigene Datenbanken aus Suchergebnissen erstellen,
* Suchlimits umgehen.

4.19 Umgehung von Sperren

Verboten sind:

* neue Konten nach einer Sperrung,
* Verwendung anderer Geräte oder Identitäten zur Umgehung,
* Nutzung fremder Konten,
* Änderung von Kennzeichenangaben zur Umgehung von Beschränkungen,
* gezielte Umgehung von Blockierungen.

4.20 Manipulation von Standortdaten

Standortdaten dürfen nicht manipuliert werden, um:

* eine falsche Nähe vorzutäuschen,
* Suchbeschränkungen zu umgehen,
* andere Nutzer zu täuschen,
* einen unzutreffenden Vorfall zu konstruieren,
* Sicherheitsmechanismen zu umgehen.

4.21 Missbrauch der Meldefunktion

Verboten sind:

* wissentlich falsche Meldungen,
* massenhafte unbegründete Meldungen,
* Meldungen aus Rache,
* koordinierte Meldungen zur Schädigung eines Nutzers,
* Meldungen zur Einschüchterung oder Unterdrückung zulässiger Inhalte.

4.22 Nutzung als Notrufersatz

plaqa darf nicht anstelle offizieller Notfall- oder Behördendienste verwendet werden.

Bei akuter Gefahr müssen Nutzer unmittelbar die zuständigen offiziellen Stellen kontaktieren.''',
          ),
          _LegalSection(
            title: '5. Regeln für Kennzeichen-Suche und Kontaktanfragen',
            body: r'''5.1 Legitimer Anlass

Kennzeichen-Suchen und Kontaktanfragen dürfen nur bei einem legitimen, nachvollziehbaren und verhältnismäßigen Anlass erfolgen.

Die Eingabe eines Kennzeichens ist nicht allein deshalb zulässig, weil das Kennzeichen öffentlich sichtbar ist.

5.2 Keine wiederholten unerwünschten Anfragen

Wurde eine Anfrage abgelehnt, nicht angenommen oder blockiert, ist dies zu respektieren.

Weitere Anfragen über andere Konten, Kennzeichen oder Funktionen sind untersagt.

5.3 Keine Überwachung

Die Kennzeichen-Suche darf nicht verwendet werden, um:

* eine bestimmte Person regelmäßig zu suchen,
* Standorte zu überprüfen,
* tägliche Wege nachzuvollziehen,
* Fahrzeuge einer Person oder Familie zusammenzustellen,
* private Beziehungen oder Aufenthaltsmuster zu untersuchen.

5.4 Keine Datenbanken

Suchergebnisse dürfen nicht systematisch gesammelt, exportiert oder in einer eigenen Datenbank gespeichert werden.

5.5 Keine Veröffentlichung fremder Kennzeichen

Fremde Kennzeichen dürfen nicht ohne ausreichende Berechtigung öffentlich oder gegenüber unbeteiligten Personen veröffentlicht werden.

Bei einer zulässigen Veröffentlichung sollten Kennzeichen und andere identifizierende Merkmale unkenntlich gemacht werden, soweit sie für den Zweck nicht erforderlich sind.

5.6 Keine Erfolgsgarantie

Ein fehlendes oder nicht angezeigtes Suchergebnis bedeutet nicht, dass:

* das Fahrzeug nicht existiert,
* das Fahrzeug nicht registriert ist,
* sich das Fahrzeug nicht in der Nähe befindet,
* der Nutzer nicht aktiv ist.

Standort- und Aktivitätsinformationen können ungenau, verzögert oder technisch nicht verfügbar sein.''',
          ),
          _LegalSection(
            title: '6. Regeln für den Chat',
            body: r'''6.1 Respektvolle Kommunikation

Chatnachrichten müssen respektvoll und sachlich bleiben.

6.2 Keine Drohungen oder Belästigungen

Drohungen, Einschüchterungen, Beleidigungen und wiederholte unerwünschte Nachrichten sind verboten.

6.3 Keine unerlaubten Inhalte

Im Chat dürfen keine rechtswidrigen, betrügerischen, gefährlichen, diskriminierenden oder Rechte Dritter verletzenden Inhalte übermittelt werden.

6.4 Keine Veröffentlichung privater Nachrichten

Private Chatnachrichten dürfen nicht ohne Berechtigung veröffentlicht oder an unbeteiligte Dritte weitergegeben werden.

Die Weitergabe an plaqa, Rechtsberater, Behörden oder Gerichte kann zulässig sein, wenn sie zur Meldung, Beweissicherung oder Rechtsverfolgung erforderlich ist.

6.5 Blockierungen respektieren

Wird ein Nutzer blockiert, darf er nicht versuchen, über andere Konten oder Kommunikationswege innerhalb von plaqa erneut Kontakt aufzunehmen.

6.6 Vorsicht bei persönlichen Treffen

Treffen zwischen Nutzern erfolgen eigenverantwortlich.

Nutzer sollten:

* keine unnötigen persönlichen Daten teilen,
* erste Treffen an sicheren öffentlichen Orten durchführen,
* keine Zahlungen unter Druck leisten,
* bei auffälligem Verhalten den Kontakt beenden,
* gefährliche Situationen vermeiden.

plaqa organisiert, überwacht oder kontrolliert solche Treffen nicht.''',
          ),
          _LegalSection(
            title: '7. Regeln für Storys',
            body: r'''7.1 Eigene oder rechtmäßig nutzbare Inhalte

Veröffentlichen Sie nur Inhalte, die Sie selbst erstellt haben oder für die Sie ausreichende Nutzungsrechte besitzen.

7.2 Fremde Personen

Erkennbare Personen dürfen nur gezeigt werden, wenn:

* sie wirksam eingewilligt haben,
* oder eine andere ausreichende Rechtsgrundlage besteht.

Besondere Vorsicht gilt bei Kindern, privaten Situationen und sensiblen Orten.

7.3 Kennzeichen und private Daten

Kennzeichen, Gesichter, Adressen, Dokumente und andere identifizierende Informationen Dritter sind unkenntlich zu machen, soweit keine ausreichende Berechtigung zur Veröffentlichung besteht.

7.4 Verbotene Story-Inhalte

Nicht erlaubt sind insbesondere:

* rechtswidrige Inhalte,
* Drohungen,
* Gewaltaufrufe,
* gefährliche Handlungen,
* Diffamierungen,
* falsche Anschuldigungen,
* öffentliche Bloßstellungen,
* intime Inhalte ohne Einwilligung,
* private Nachrichten oder Dokumente,
* Inhalte, die andere Personen gefährden.

7.5 Zeitlich begrenzte Sichtbarkeit

Auch wenn eine Story nur vorübergehend sichtbar ist, kann sie von anderen Nutzern technisch gespeichert oder aufgenommen werden.

Veröffentlichen Sie daher keine Inhalte, deren Weitergabe erhebliche Risiken für Sie oder andere Personen verursachen könnte.''',
          ),
          _LegalSection(
            title: '8. Regeln für fahrzeugbezogene Hinweise und Meldungen',
            body: r'''8.1 Sachlichkeit

Hinweise müssen kurz, sachlich und auf den notwendigen Inhalt beschränkt sein.

8.2 Wahrheitsgemäße Angaben

Melden Sie nur Tatsachen, die Sie selbst wahrgenommen haben oder für die Sie eine nachvollziehbare Grundlage besitzen.

Vermutungen müssen als solche erkennbar sein.

8.3 Beispiele zulässiger Hinweise

Zulässig können beispielsweise sein:

* „Das Licht Ihres Fahrzeugs ist noch eingeschaltet.“
* „Das Fahrerfenster steht offen.“
* „An Ihrem Fahrzeug ist ein sichtbarer Schaden.“
* „Ihr Fahrzeug blockiert aktuell eine Einfahrt.“
* „Auf dem Fahrzeug liegt ein Gegenstand.“
* „Ein Reifen wirkt deutlich beschädigt.“

Auch zulässige Hinweise müssen respektvoll formuliert sein.

8.4 Beispiele unzulässiger Hinweise

Nicht erlaubt sind beispielsweise:

* „Du kannst nicht fahren, du Idiot.“
* „Ich weiß, wo du wohnst.“
* „Wenn du nicht sofort kommst, passiert etwas.“
* erfundene Schadensmeldungen,
* Meldungen aus Rache,
* öffentliche Beschuldigungen,
* wiederholte Meldungen zur Belästigung,
* Veröffentlichung von Fahrerbildern oder privaten Daten,
* Drohungen mit Polizei oder Behörden als Druckmittel.

8.5 Keine öffentlichen Anschuldigungen

plaqa darf nicht zur öffentlichen Anprangerung oder Bloßstellung verwendet werden.

Bei einem vermuteten Rechtsverstoß müssen Nutzer die zuständigen offiziellen Stellen kontaktieren, sofern dies erforderlich ist.

8.6 Keine Notfallfunktion

Fahrzeugbezogene Hinweise werden nicht zwingend sofort gelesen oder zugestellt.

Bei Gefahr, Unfall, Straftat oder akuter Verkehrsbehinderung müssen offizielle Stellen direkt kontaktiert werden.

8.7 Anonyme oder pseudonyme Darstellung

Ein Hinweis kann dem Empfänger ohne sichtbaren Absender angezeigt werden.

Dies bedeutet nicht, dass der Hinweis gegenüber plaqa technisch vollständig anonym ist. Zur Missbrauchsabwehr und Nachweisführung kann der Vorgang intern einem Benutzerkonto und technischen Informationen zugeordnet werden.''',
          ),
          _LegalSection(
            title: '9. Datenschutz und private Informationen',
            body: r'''9.1 Keine fremden privaten Daten

Veröffentlichen oder versenden Sie ohne ausreichende Berechtigung keine:

* Telefonnummern,
* Anschriften,
* E-Mail-Adressen,
* Ausweisdaten oder Fahrzeugdokumente,
* Fahrzeugdokumente,
* Zahlungsdaten,
* privaten Fotos oder Videos,
* Chatnachrichten,
* Standortdaten,
* Gesundheitsinformationen.

9.2 Keine unberechtigte Weitergabe

Informationen, die Sie über plaqa erhalten, dürfen nicht zweckwidrig weitergegeben, veröffentlicht oder verkauft werden.

9.3 Verantwortungsvolle Behandlung von Kennzeichen

Kennzeichen und Fahrzeugdaten dürfen nur für den konkreten zulässigen Anlass verwendet werden.

Sie dürfen nicht:

* dauerhaft gesammelt,
* mit fremden Datenbanken abgeglichen,
* veröffentlicht,
* verkauft,
* für Werbung genutzt,
* zur Nachverfolgung verwendet werden.

9.4 Eigene Datensparsamkeit

Teilen Sie nur Informationen, die für den jeweiligen Zweck erforderlich sind.

Vermeiden Sie insbesondere die Veröffentlichung von:

* Wohnanschriften,
* regelmäßigen Aufenthaltsorten,
* Arbeitsorten,
* Reiserouten,
* Zugangsdaten,
* vollständigen Dokumenten.''',
          ),
          _LegalSection(
            title: '10. Verifizierung und Dokumente',
            body: r'''10.1 Nur eigene und echte Dokumente

Verwenden Sie nur echte Dokumente, die Ihnen gehören oder die Sie rechtmäßig für die Verifizierung verwenden dürfen.

10.2 Keine Fälschungen

Verboten sind:

* gefälschte Dokumente,
* manipulierte Dokumente,
* veränderte Namen oder Daten,
* fremde Ausweise oder Fahrzeugdokumente,
* falsche Fahrzeugnachweise,
* Täuschung über die Fahrzeugberechtigung.

10.3 Sensible Angaben

Verwenden Sie nur die ausdrücklich angeforderte Vorder- oder Datenseite im vorgesehenen Kamera- oder Galerieablauf. Rückseiten, Führerschein, Selfie sowie beliebige Datei-Uploads gehören nicht zum aktuellen Verfahren.

10.4 Keine fremden Dokumente

Identitätsdokumente anderer Personen dürfen nicht verwendet werden. Beim Fahrzeugschein darf eine abweichende Halterperson nur im vorgesehenen Ablauf mit wahrheitsgemäßer Angabe der eigenen Nutzungsberechtigung und Eigenerklärung verarbeitet werden.

10.5 Bedeutung der Verifizierung

Eine Verifizierung bestätigt nur die im jeweiligen Verfahren geprüften Merkmale.

Der aktuelle Dokumentdatenabgleich ist keine amtliche Echtheitsprüfung und keine Registerabfrage.

Sie ist keine Garantie für:

* vollständige Identität,
* Vertrauenswürdigkeit,
* rechtmäßiges zukünftiges Verhalten,
* Eigentum am Fahrzeug,
* Richtigkeit sämtlicher Profilangaben.''',
          ),
          _LegalSection(
            title: '11. Meldung von Verstößen',
            body: r'''11.1 Meldewege

Verstöße können gemeldet werden:

* über die vorgesehene Meldefunktion innerhalb der App,
* per E-Mail an support@plaqa.de.

In-App-Meldeweg:
Direkt am betroffenen Inhalt oder unter Einstellungen > Hilfe & Rechtliches > Support > Problem melden.

11.2 Hilfreiche Angaben

Eine Meldung sollte möglichst enthalten:

* den betroffenen Nutzer oder Inhalt,
* den Grund der Meldung,
* eine kurze sachliche Beschreibung,
* Zeitpunkt des Vorfalls,
* betroffene App-Funktion,
* gegebenenfalls geeignete Screenshots oder Nachweise.

Übermitteln Sie nur solche Nachweise, die zur Prüfung erforderlich sind.

11.3 Dringende Gefahren

Bei unmittelbarer Gefahr wenden Sie sich nicht nur an plaqa, sondern direkt an Polizei, Feuerwehr, Rettungsdienst oder andere zuständige Stellen.

11.4 Keine missbräuchlichen Meldungen

Wissentlich falsche, beleidigende, wiederholte unbegründete oder koordinierte Meldungen sind verboten.

Der Missbrauch der Meldefunktion kann selbst zu Maßnahmen gegen das meldende Konto führen.''',
          ),
          _LegalSection(
            title: '12. Moderation und mögliche Maßnahmen',
            body: r'''12.1 Prüfung von Verstößen

plaqa kann Inhalte, Konten oder Vorgänge prüfen, wenn:

* eine Meldung eingeht,
* konkrete Hinweise auf einen Verstoß vorliegen,
* technische Sicherheitsmechanismen auffälliges Verhalten erkennen,
* eine gesetzliche Verpflichtung besteht.

Je nach technischer Ausgestaltung können Prüfungen durch berechtigte Personen, technische Filter oder eine Kombination aus beiden erfolgen.

Aktuell unterstützen Firestore- und Storage-Regeln, Eingabeprüfungen, Rate-Limits und Sicherheitsprotokolle die Missbrauchserkennung. Gemeldete Vorgänge werden durch berechtigte Prüfer bewertet; eine ausschließlich automatisierte endgültige Moderationsentscheidung ist nicht vorgesehen.

12.2 Mögliche Maßnahmen

Abhängig von Art, Schwere, Häufigkeit und Auswirkungen des Verstoßes können insbesondere folgende Maßnahmen ergriffen werden:

* Hinweis oder Warnung,
* Aufforderung zur Änderung oder Entfernung eines Inhalts,
* Entfernung oder Ausblendung von Inhalten,
* Einschränkung der Sichtbarkeit,
* Einschränkung einzelner App-Funktionen,
* Begrenzung oder Sperrung von Kontaktanfragen,
* Sperrung der Chatfunktion,
* Sperrung der Story-Funktion,
* Sperrung der Hinweis- oder Meldefunktion,
* erneute Verifizierung,
* vorübergehende Kontosperre,
* dauerhafte Kontosperre,
* Kündigung des Nutzungsvertrags,
* Löschung oder Deaktivierung eines Kontos,
* Sicherung relevanter Nachweise,
* rechtliche Schritte,
* Weitergabe an Behörden oder andere zuständige Stellen, soweit gesetzlich zulässig oder erforderlich.

12.3 Verhältnismäßigkeit

Bei der Auswahl einer Maßnahme werden insbesondere berücksichtigt:

* Schwere des Verstoßes,
* mögliche oder eingetretene Schäden,
* Wiederholungsgefahr,
* frühere Verstöße,
* Vorsatz oder erkennbare Fahrlässigkeit,
* Schutz gefährdeter Personen,
* Gefahr weiterer Rechtsverletzungen,
* Bereitschaft zur Abhilfe.

Bei geringfügigen oder erstmaligen Verstößen kann zunächst eine Warnung oder Einschränkung erfolgen.

Bei schweren Verstößen kann eine sofortige Sperrung ohne vorherige Warnung erforderlich sein.

12.4 Keine allgemeine Vorabkontrolle

plaqa kontrolliert nicht zwingend sämtliche Inhalte vor der Veröffentlichung oder Übermittlung.

Die Möglichkeit einer Moderation entbindet Nutzer nicht von ihrer eigenen Verantwortung.

12.5 Informationen an Behörden

Eine Weitergabe von Daten an Behörden erfolgt nur, wenn hierfür eine gesetzliche Grundlage besteht, eine rechtmäßige Anordnung vorliegt oder die Übermittlung anderweitig gesetzlich zulässig oder erforderlich ist.

plaqa entscheidet nicht selbst über Schuld oder Strafbarkeit einer Person.''',
          ),
          _LegalSection(
            title: '13. Beschwerde gegen Maßnahmen',
            body: r'''13.1 Beschwerdemöglichkeit

Nutzer können gegen eine Warnung, Inhaltsentfernung, Funktionsbeschränkung oder Kontosperre Beschwerde einlegen.

Kontakt:

E-Mail: support@plaqa.de

In der App: Einstellungen > Hilfe & Rechtliches > Support > Problem melden.

13.2 Inhalt der Beschwerde

Die Beschwerde sollte enthalten:

* das betroffene Konto,
* die betroffene Maßnahme,
* das Datum der Maßnahme,
* eine sachliche Begründung,
* gegebenenfalls geeignete Nachweise.

13.3 Erneute Prüfung

plaqa prüft Beschwerden sachlich anhand der verfügbaren Informationen.

Soweit erforderlich, kann plaqa weitere Angaben oder Nachweise anfordern.

13.4 Ergebnis

Nach Abschluss der Prüfung kann die Maßnahme:

* bestätigt,
* aufgehoben,
* angepasst,
* verkürzt,
* verlängert oder
* durch eine andere angemessene Maßnahme ersetzt werden.

Ein Anspruch auf ein bestimmtes Ergebnis besteht nicht. Beschwerden werden ohne zugesagte feste Bearbeitungsfrist so zeitnah wie möglich geprüft. Soweit gesetzlich erforderlich, werden wesentliche Entscheidungsgründe und verfügbare Rechtsbehelfe mitgeteilt. Gesetzliche Rechte bleiben unberührt.''',
          ),
          _LegalSection(
            title: '14. Wiederholte oder schwere Verstöße',
            body: r'''14.1 Wiederholte Verstöße

Wiederholt ein Nutzer Verstöße oder ignoriert vorherige Warnungen, können strengere Maßnahmen ergriffen werden.

14.2 Schwere Verstöße

Eine sofortige erhebliche Einschränkung oder dauerhafte Sperrung kann insbesondere erfolgen bei:

* Stalking oder Nachstellung,
* konkreten Drohungen,
* Gewaltaufrufen,
* Erpressung,
* Veröffentlichung intimer Inhalte ohne Einwilligung,
* Identitätsmissbrauch,
* gefälschten Verifizierungsunterlagen,
* schwerwiegenden Datenschutzverletzungen,
* Betrug,
* Ausspähen von Konten,
* systematischen Massenabfragen,
* Umgehung vorheriger Sperren,
* Inhalten, die Minderjährige gefährden,
* Angriffen auf die technische Infrastruktur.

14.3 Schutz der Community

Bei der Entscheidung über Maßnahmen haben der Schutz betroffener Nutzer, Dritter und der Plattform vor weiteren Schäden besonderes Gewicht.

Rechte des betroffenen Nutzers auf eine sachliche und verhältnismäßige Prüfung bleiben unberührt.''',
          ),
          _LegalSection(
            title: '15. Keine Notfall- oder Behördenfunktion',
            body:
                r'''plaqa ist keine Notruf-, Polizei-, Feuerwehr-, Rettungsdienst-, Pannenhilfe-, Abschlepp- oder Rechtsberatungs-App.

plaqa garantiert insbesondere nicht:

* die sofortige Zustellung einer Nachricht,
* die rechtzeitige Kenntnisnahme durch einen Empfänger,
* die Verfügbarkeit eines Empfängers,
* die Richtigkeit eines Standortes,
* die Richtigkeit eines Nutzerhinweises,
* die Einleitung behördlicher Maßnahmen.

Bei:

* Gefahr für Personen,
* Unfall,
* Brand,
* medizinischem Notfall,
* Straftat,
* akuter Verkehrsgefährdung,
* dringender Panne,
* erforderlichem Abschleppen

müssen Nutzer unmittelbar die zuständigen offiziellen Stellen kontaktieren.''',
          ),
          _LegalSection(
            title: '16. Änderungen der Community-Richtlinien',
            body:
                r'''plaqa kann diese Community-Richtlinien ändern, insbesondere wenn:

* neue Funktionen eingeführt werden,
* neue Missbrauchsformen auftreten,
* technische Schutzmaßnahmen geändert werden,
* gesetzliche oder behördliche Anforderungen dies erfordern,
* Sicherheits- oder Moderationsprozesse angepasst werden.

Wesentliche Änderungen werden den Nutzern in angemessener Weise mitgeteilt.

Die jeweils aktuelle Fassung wird innerhalb der App und auf der Website bereitgestellt.

Soweit eine Änderung eine ausdrückliche Zustimmung zu geänderten Vertragsbedingungen erfordert, wird diese gesondert eingeholt.''',
          ),
          _LegalSection(
            title: '17. Kontakt und Verantwortlicher',
            body: r'''Anbieter und Betreiber:

Sehmus Yildirim
Auftreten unter der Bezeichnung plaqa
Bremer Straße 254e
21077 Hamburg
Deutschland

E-Mail: info@plaqa.de
Website: plaqa.de''',
          ),
          _LegalSection(
            title: '18. Sicherheit, Beschwerden und aktuelle Fassung',
            body:
                r'''Sicherheits- und Kinderschutzmeldungen können direkt am betroffenen Inhalt, unter Einstellungen > Hilfe & Rechtliches > Support > Problem melden oder per E-Mail an support@plaqa.de eingereicht werden.

Die jeweils aktuelle Fassung dieser Richtlinien ist in der App und unter https://plaqa.de/community-richtlinien/ verfügbar. Der ergänzende Kinderschutzstandard steht unter https://plaqa.de/kinderschutz/.''',
          ),
        ],
      ),
      'Impressum' => const _LegalContent(
        title: 'Impressum',
        icon: Icons.business_rounded,
        sections: [
          _LegalSection(
            title: '1. Angaben gemäß § 5 DDG',
            body: '''
Sehmus Yildirim
Auftreten unter der Bezeichnung plaqa
Bremer Straße 254e
21077 Hamburg
Deutschland
''',
          ),
          _LegalSection(
            title: '2. Kontakt',
            body: '''
E-Mail: info@plaqa.de
Website: https://plaqa.de/
Support: support@plaqa.de
Datenschutz: privacy@plaqa.de
Kontaktseite: https://plaqa.de/support/''',
          ),
          _LegalSection(
            title: '3. Verantwortlich für den Inhalt',
            body: '''
Verantwortlich für die eigenen Inhalte dieses Angebots:

Sehmus Yildirim
Bremer Straße 254e
21077 Hamburg
Deutschland

plaqa bietet derzeit keine eigenen journalistisch-redaktionellen Inhalte an. Eine gesonderte Benennung eines Verantwortlichen nach dem Medienstaatsvertrag erfolgt daher derzeit nicht. Sollte plaqa zukünftig eigene redaktionelle Inhalte anbieten, wird dieser Abschnitt entsprechend aktualisiert.''',
          ),
          _LegalSection(
            title: '4. Verbraucherstreitbeilegung',
            body: '''
Anliegen und Beschwerden können zunächst an info@plaqa.de oder support@plaqa.de gerichtet werden. Angaben zu einer Teilnahme an Verbraucherstreitbeilegungsverfahren werden ergänzt, soweit dies gesetzlich erforderlich oder verbindlich vereinbart ist.''',
          ),
          _LegalSection(
            title: '5. Haftung für eigene Inhalte',
            body:
                'Als Diensteanbieter sind wir für die eigenen Inhalte dieses Angebots nach den allgemeinen Gesetzen verantwortlich.',
          ),
          _LegalSection(
            title: '6. Inhalte von Nutzern',
            body: '''
plaqa ermöglicht Nutzern unter anderem, eigene Inhalte in Profilen, Storys, Chats und anonymen fahrzeugbezogenen Hinweisen zu veröffentlichen oder zu übermitteln.

Für rechtswidrige Inhalte von Nutzern besteht keine allgemeine Pflicht zur anlasslosen Überwachung.

Sobald uns konkrete Anhaltspunkte für eine mögliche Rechtsverletzung bekannt werden, prüfen wir den betreffenden Inhalt und entfernen oder sperren ihn im Rahmen der gesetzlichen Vorgaben, sofern dies erforderlich ist.

Nutzer sind selbst dafür verantwortlich, dass ihre veröffentlichten oder übermittelten Inhalte keine gesetzlichen Vorschriften oder Rechte Dritter verletzen.''',
          ),
          _LegalSection(
            title: '7. Externe Links',
            body: '''
Soweit dieses Angebot Links zu externen Websites Dritter enthält, haben wir keinen dauerhaften Einfluss auf deren Inhalte.

Für die Inhalte der verlinkten Seiten ist grundsätzlich der jeweilige Anbieter oder Betreiber verantwortlich.

Werden uns konkrete Rechtsverletzungen bekannt, werden rechtswidrige Links nach Prüfung entfernt.''',
          ),
        ],
      ),
      'Über plaqa' => _LegalContent(
        title: 'Über plaqa',
        icon: Icons.info_outline_rounded,
        sections: [
          const _LegalSection(
            title: 'Unsere Idee',
            body:
                'plaqa verbindet Menschen über ihre Fahrzeuge, ohne private Kontaktdaten öffentlich preiszugeben. Kennzeichensuche, Kontaktanfragen, Chats, Storys und sachliche Fahrzeughinweise werden in einer geschützten Community zusammengeführt.',
          ),
          const _LegalSection(
            title: 'Sicherheit und Verantwortung',
            body:
                'Datensparsamkeit, kontrollierte Kontaktaufnahme und ein respektvoller Umgang stehen im Mittelpunkt. Private Kontodaten, Dokumente und Verifizierungsunterlagen werden nicht in öffentliche Profile übernommen.',
          ),
          const _LegalSection(
            title: 'Community',
            body:
                'plaqa richtet sich an Fahrzeugbegeisterte, die sich austauschen, Fahrzeuge entdecken und sicher miteinander in Kontakt treten möchten. Missbrauch, Belästigung und die Veröffentlichung fremder Daten werden nicht toleriert.',
          ),
          _LegalSection(
            title: 'Version',
            body: 'plaqa ${CaRismaAppConfig.appVersion}',
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
        sections: [
          _LegalSection(
            title: 'Flutter & Dart',
            body:
                'plaqa wird mit Flutter und Dart entwickelt. Die Lizenzinformationen werden über die App-Lizenzübersicht bereitgestellt.',
          ),
          _LegalSection(
            title: 'Pakete',
            body:
                'Die verwendeten Open-Source-Pakete und ihre Lizenztexte sind in der App-Lizenzübersicht dokumentiert.',
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
        sections: const [
          _LegalSection(
            title: 'Rechtliche Informationen',
            body:
                'Die aktuellen rechtlichen Informationen sind unter Datenschutz, Nutzungsbedingungen, Community-Richtlinien und Impressum verfügbar.',
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
  });

  final IconData icon;
  final String title;
  final String description;
}

class _SettingsDetailTile extends StatelessWidget {
  const _SettingsDetailTile({required this.item, required this.onTap});

  final _SettingsDetailItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              CaRismaBlueIconBox(icon: item.icon, size: 44, iconSize: 22),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CaRismaDesignTokens.textPrimary.withValues(
                          alpha: 0.66,
                        ),
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
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.66),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
