import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/data_rights_request_repository.dart';

class DataExportRequestScreen extends StatefulWidget {
  const DataExportRequestScreen({super.key});

  @override
  State<DataExportRequestScreen> createState() =>
      _DataExportRequestScreenState();
}

class _DataExportRequestScreenState extends State<DataExportRequestScreen> {
  final TextEditingController _noteController = TextEditingController();
  final DataRightsRequestRepository _repository = DataRightsRequestRepository();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _error = 'Melde dich erneut an, um den Export anzufordern.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.requestExport(
        userId: user.uid,
        accountEmail: user.email,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deine Datenexport-Anfrage wurde sicher übermittelt.'),
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
              'Die Exportanfrage konnte gerade nicht gesendet werden. Bitte versuche es erneut.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + keyboardInset),
            children: [
              CaRismaSubPageHeader(
                icon: Icons.file_download_outlined,
                title: 'Datenexport',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              const CaRismaMessageCard(
                icon: Icons.privacy_tip_outlined,
                message:
                    'Du kannst eine Kopie deiner bei plaqa gespeicherten personenbezogenen Daten anfordern. Die Anfrage wird geprüft und sicher bereitgestellt.',
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ExportContentLine(
                      icon: Icons.person_outline_rounded,
                      title: 'Konto & Profil',
                      body: 'Kontodaten, Profil und Freigaben',
                    ),
                    const _ExportContentLine(
                      icon: Icons.directions_car_outlined,
                      title: 'Fahrzeuge & Kennzeichen',
                      body: 'Gespeicherte Fahrzeuge und zugehörige Angaben',
                    ),
                    const _ExportContentLine(
                      icon: Icons.forum_outlined,
                      title: 'Aktivitäten',
                      body:
                          'Anfragen, Chats, Storys und Meldungen im rechtlich zulässigen Umfang',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      maxLength: 500,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Optionaler Hinweis',
                        hintText: 'Welche Daten möchtest du besonders prüfen?',
                        alignLabelWithHint: true,
                      ),
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
                label: 'Export sicher anfordern',
                loadingLabel: 'Anfrage wird gesendet...',
                icon: Icons.lock_outline_rounded,
                isLoading: _submitting,
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

class StoredDataOverviewScreen extends StatelessWidget {
  const StoredDataOverviewScreen({super.key, required this.userState});

  final AppUserState userState;

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              CaRismaSubPageHeader(
                icon: Icons.manage_accounts_outlined,
                title: 'Gespeicherte Daten',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ExportContentLine(
                      icon: Icons.alternate_email_rounded,
                      title: 'Konto',
                      body: email?.isNotEmpty == true
                          ? email!
                          : 'Keine E-Mail Adresse verfügbar',
                    ),
                    const _ExportContentLine(
                      icon: Icons.account_circle_outlined,
                      title: 'Profil',
                      body: 'Persönliche und öffentliche Profilangaben',
                    ),
                    const _ExportContentLine(
                      icon: Icons.directions_car_outlined,
                      title: 'Fahrzeuge',
                      body: 'Fahrzeug-, Kennzeichen- und Verifizierungsdaten',
                    ),
                    _ExportContentLine(
                      icon: Icons.search_rounded,
                      title: 'Suchkontingent',
                      body:
                          '${userState.searchCredit.remaining} von ${userState.searchCredit.limit} Anfragen verfügbar',
                    ),
                    const _ExportContentLine(
                      icon: Icons.security_rounded,
                      title: 'Sicherheit & Einwilligungen',
                      body:
                          'Einstellungen, Einwilligungen und Sicherheitsstatus',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const CaRismaMessageCard(
                icon: Icons.lock_outline_rounded,
                message:
                    'Sensible Inhalte und Dokumente werden in dieser Übersicht nicht im Klartext angezeigt.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportContentLine extends StatelessWidget {
  const _ExportContentLine({
    required this.icon,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: CaRismaDesignTokens.textPrimary.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CaRismaBlueIconBox(icon: icon, size: 42, iconSize: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
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
    );
  }
}
