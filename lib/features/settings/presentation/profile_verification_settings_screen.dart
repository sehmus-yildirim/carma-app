import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/profile_vehicle.dart';
import '../../profile/data/profile_vehicle_repository.dart';
import '../../profile/data/user_profile.dart' as profile_data;
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/widgets/profile_vehicle_editor_sheet.dart';

enum ProfileSettingsArea { personalData, documents, vehicles }

class ProfileVerificationSettingsScreen extends StatefulWidget {
  const ProfileVerificationSettingsScreen({
    super.key,
    required this.userState,
    required this.area,
  });

  final AppUserState userState;
  final ProfileSettingsArea area;

  @override
  State<ProfileVerificationSettingsScreen> createState() =>
      _ProfileVerificationSettingsScreenState();
}

class _ProfileVerificationSettingsScreenState
    extends State<ProfileVerificationSettingsScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final ProfileVehicleRepository _vehicleRepository =
      ProfileVehicleRepository();
  profile_data.UserProfile? _profile;
  bool _loading = true;
  String? _error;

  String get _title => switch (widget.area) {
    ProfileSettingsArea.personalData => 'Persönliche Daten',
    ProfileSettingsArea.documents => 'Dokumente hochladen',
    ProfileSettingsArea.vehicles => 'Fahrzeuge & Kennzeichen',
  };

  IconData get _icon => switch (widget.area) {
    ProfileSettingsArea.personalData => Icons.badge_outlined,
    ProfileSettingsArea.documents => Icons.upload_file_rounded,
    ProfileSettingsArea.vehicles => Icons.directions_car_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _profileRepository.getProfile(
        widget.userState.userId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Deine Profildaten konnten gerade nicht geladen werden.';
      });
    }
  }

  Future<void> _openEditor({bool documents = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          userState: widget.userState,
          initialEntry: documents
              ? ProfileEditorEntry.documents
              : ProfileEditorEntry.overview,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openVehicleEditor({ProfileVehicle? vehicle}) async {
    final saved = await showProfileVehicleEditorSheet(
      context,
      userId: widget.userState.userId,
      vehicleId:
          vehicle?.id ??
          _vehicleRepository.createVehicleId(widget.userState.userId),
      vehicle: vehicle,
      onSave: _vehicleRepository.saveVehicle,
    );
    if (!mounted || !saved) return;
    _showMessage(
      vehicle == null ? 'Fahrzeug hinzugefügt.' : 'Fahrzeug gespeichert.',
    );
  }

  Future<void> _setPrimaryVehicle(ProfileVehicle vehicle) async {
    try {
      await _vehicleRepository.setPrimaryVehicle(
        userId: widget.userState.userId,
        vehicleId: vehicle.id,
      );
      if (mounted) _showMessage('Hauptfahrzeug aktualisiert.');
    } catch (_) {
      if (mounted) {
        _showMessage('Das Hauptfahrzeug konnte nicht geändert werden.');
      }
    }
  }

  Future<void> _archiveVehicle(ProfileVehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        title: const Text(
          'Fahrzeug entfernen?',
          style: TextStyle(color: CaRismaDesignTokens.textPrimary),
        ),
        content: Text(
          '${vehicle.displayName} wird archiviert und nicht mehr öffentlich angezeigt.',
          style: const TextStyle(color: CaRismaDesignTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Entfernen',
              style: TextStyle(color: CaRismaDesignTokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _vehicleRepository.archiveVehicle(
        userId: widget.userState.userId,
        vehicleId: vehicle.id,
      );
      if (mounted) _showMessage('Fahrzeug wurde entfernt.');
    } catch (_) {
      if (mounted) {
        _showMessage(
          vehicle.isPrimary
              ? 'Wähle zuerst ein anderes Hauptfahrzeug aus.'
              : 'Das Fahrzeug konnte nicht entfernt werden.',
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
                icon: _icon,
                title: _title,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: CaRismaDesignTokens.bluePrimary,
                    ),
                  ),
                )
              else if (_error != null)
                CaRismaMessageCard(
                  icon: Icons.error_outline_rounded,
                  message: _error!,
                )
              else
                switch (widget.area) {
                  ProfileSettingsArea.personalData => _buildPersonalData(),
                  ProfileSettingsArea.documents => _buildDocuments(),
                  ProfileSettingsArea.vehicles => _buildVehicles(),
                },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalData() {
    final profile = _profile;
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName.trim()
        : 'Name noch nicht vollständig';
    final birthDate = profile?.birthDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _ProfilePhoto(photoUrl: profile?.photoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: CaRismaDesignTokens.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _verificationLabel(profile?.verificationStatus),
                          style: const TextStyle(
                            color: CaRismaDesignTokens.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DataLine(
                icon: Icons.phone_outlined,
                label: 'Telefonnummer',
                value: _available(profile?.phoneNumber),
              ),
              _DataLine(
                icon: Icons.cake_outlined,
                label: 'Geburtsdatum',
                value: birthDate == null ? 'Nicht angegeben' : _date(birthDate),
              ),
              _DataLine(
                icon: Icons.location_city_outlined,
                label: 'Öffentliche Region',
                value: _available(profile?.publicRegion),
              ),
              _DataLine(
                icon: Icons.notes_rounded,
                label: 'Öffentliche Bio',
                value: _available(profile?.publicBio),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const CaRismaMessageCard(
          icon: Icons.lock_outline_rounded,
          message:
              'Telefonnummer und Geburtsdatum bleiben privat. Nur ausdrücklich freigegebene Profildaten erscheinen öffentlich.',
        ),
        const SizedBox(height: 16),
        CaRismaPrimaryButton(
          label: 'Persönliche Daten bearbeiten',
          icon: Icons.edit_outlined,
          onPressed: _openEditor,
        ),
      ],
    );
  }

  Widget _buildDocuments() {
    final profile = _profile;
    const names = <String>[
      'Ausweis Vorderseite',
      'Ausweis Rückseite',
      'Führerschein Vorderseite',
      'Führerschein Rückseite',
      'Fahrzeugschein Vorderseite',
      'Fahrzeugschein Rückseite',
    ];
    final uploadedTitles =
        profile?.documentRemoteUrls.entries
            .where((entry) => entry.value?.trim().isNotEmpty == true)
            .map((entry) => _documentTitle(entry.key))
            .toSet() ??
        <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _VerificationHeader(
                status: profile?.verificationStatus ?? 'unverified',
                uploaded: uploadedTitles.length,
                total: names.length,
              ),
              const SizedBox(height: 14),
              ...List.generate(names.length, (index) {
                final title = names[index];
                final uploaded = uploadedTitles.contains(title);
                return _DocumentLine(
                  title: title,
                  uploaded: uploaded,
                  isLast: index == names.length - 1,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const CaRismaMessageCard(
          icon: Icons.privacy_tip_outlined,
          message:
              'Dokumente sind privat, werden verschlüsselt übertragen und niemals in dein öffentliches Profil kopiert.',
        ),
        const SizedBox(height: 16),
        CaRismaPrimaryButton(
          label: 'Dokumente sicher verwalten',
          icon: Icons.upload_file_rounded,
          onPressed: () => _openEditor(documents: true),
        ),
      ],
    );
  }

  Widget _buildVehicles() {
    return StreamBuilder<List<ProfileVehicle>>(
      stream: _vehicleRepository.watchOwnerVehicles(widget.userState.userId),
      builder: (context, snapshot) {
        final vehicles = (snapshot.data ?? const <ProfileVehicle>[])
            .where((vehicle) => !vehicle.isArchived)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CaRismaPrimaryButton(
              label: 'Fahrzeug hinzufügen',
              icon: Icons.add_rounded,
              surfaceOutlined: true,
              showShadow: false,
              onPressed: () => _openVehicleEditor(),
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              const CaRismaMessageCard(
                icon: Icons.error_outline_rounded,
                message: 'Fahrzeuge konnten gerade nicht geladen werden.',
              )
            else if (vehicles.isEmpty)
              const CaRismaMessageCard(
                icon: Icons.directions_car_outlined,
                message:
                    'Noch kein Fahrzeug hinterlegt. Ergänze Fahrzeugdaten und ein vollständiges Kennzeichen.',
              )
            else
              ...vehicles.map(
                (vehicle) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CaRismaBlueIconBox(
                          icon: Icons.directions_car_rounded,
                          size: 50,
                          iconSize: 25,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle.displayName,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vehicle.displayPlate,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_vehicleStatusLabel(vehicle.status)} · '
                                '${vehicle.visibility == ProfileVehicleVisibility.contacts ? 'Für Kontakte sichtbar' : 'Nur für mich'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (vehicle.isPrimary) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Hauptfahrzeug',
                                  style: TextStyle(
                                    color: CaRismaDesignTokens.bluePrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: CaRismaDesignTokens.card,
                          tooltip: 'Fahrzeug verwalten',
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: CaRismaDesignTokens.textSecondary,
                          ),
                          onSelected: (action) {
                            switch (action) {
                              case 'edit':
                                _openVehicleEditor(vehicle: vehicle);
                              case 'primary':
                                _setPrimaryVehicle(vehicle);
                              case 'archive':
                                _archiveVehicle(vehicle);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Fahrzeug bearbeiten'),
                            ),
                            if (!vehicle.isPrimary)
                              const PopupMenuItem(
                                value: 'primary',
                                child: Text('Als Hauptfahrzeug festlegen'),
                              ),
                            if (!vehicle.isPrimary)
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Fahrzeug entfernen'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const CaRismaMessageCard(
              icon: Icons.info_outline_rounded,
              message:
                  'Ein Hauptfahrzeug bestimmt die Kennzeichensuche und freigegebene Fahrzeugdaten. Änderungen können eine erneute Dokumentprüfung auslösen.',
            ),
          ],
        );
      },
    );
  }

  static String _available(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Nicht angegeben'
        : normalized;
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  static String _verificationLabel(String? status) {
    return switch (status) {
      'verified' => 'Verifiziert',
      'pending' => 'Prüfung läuft',
      'rejected' => 'Prüfung abgelehnt',
      _ => 'Noch nicht verifiziert',
    };
  }

  static String _vehicleStatusLabel(ProfileVehicleStatus status) {
    return switch (status) {
      ProfileVehicleStatus.active => 'Kennzeichen aktiv',
      ProfileVehicleStatus.modification => 'Fahrzeug im Umbau',
      ProfileVehicleStatus.repair => 'Fahrzeug in Reparatur',
      ProfileVehicleStatus.seasonal => 'Saisonfahrzeug',
      ProfileVehicleStatus.deregistered => 'Kennzeichen inaktiv',
      ProfileVehicleStatus.sold => 'Fahrzeug verkauft',
      ProfileVehicleStatus.noLongerOwned => 'Nicht mehr im Besitz',
      ProfileVehicleStatus.archived => 'Archiviert',
    };
  }

  static String _documentTitle(String key) {
    return switch (key) {
      'idFront' => 'Ausweis Vorderseite',
      'idBack' => 'Ausweis Rückseite',
      'driverLicenseFront' => 'Führerschein Vorderseite',
      'driverLicenseBack' => 'Führerschein Rückseite',
      'vehicleRegistrationFront' => 'Fahrzeugschein Vorderseite',
      'vehicleRegistrationBack' => 'Fahrzeugschein Rückseite',
      _ => key,
    };
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return Container(
      width: 68,
      height: 68,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: url.isEmpty
          ? const Icon(
              Icons.person_rounded,
              color: CaRismaDesignTokens.bluePrimary,
              size: 34,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: CaRismaDesignTokens.bluePrimary,
                size: 34,
              ),
            ),
    );
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
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

class _VerificationHeader extends StatelessWidget {
  const _VerificationHeader({
    required this.status,
    required this.uploaded,
    required this.total,
  });

  final String status;
  final int uploaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CaRismaBlueIconBox(
          icon: Icons.verified_user_outlined,
          size: 50,
          iconSize: 25,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ProfileVerificationSettingsScreenState._verificationLabel(
                  status,
                ),
                style: const TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$uploaded von $total Dokumenten hinterlegt',
                style: const TextStyle(
                  color: CaRismaDesignTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentLine extends StatelessWidget {
  const _DocumentLine({
    required this.title,
    required this.uploaded,
    required this.isLast,
  });

  final String title;
  final bool uploaded;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
      ),
      child: Row(
        children: [
          Icon(
            uploaded ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: uploaded
                ? CaRismaDesignTokens.success
                : CaRismaDesignTokens.textMuted,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: CaRismaDesignTokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            uploaded ? 'Hinterlegt' : 'Fehlt',
            style: TextStyle(
              color: uploaded
                  ? CaRismaDesignTokens.success
                  : CaRismaDesignTokens.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
