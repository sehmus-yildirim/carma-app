import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_blue_icon_box.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../profile/data/profile_vehicle.dart';
import '../../profile/data/profile_vehicle_repository.dart';
import '../../profile/presentation/profile_verification_screen.dart';
import '../../profile/presentation/widgets/profile_vehicle_editor_sheet.dart';

enum ProfileSettingsArea { personalData, documents, vehicles }

class ProfileVerificationSettingsScreen extends StatefulWidget {
  const ProfileVerificationSettingsScreen({
    super.key,
    required this.userState,
    required this.area,
    this.vehicleRepository,
  });

  final AppUserState userState;
  final ProfileSettingsArea area;
  final ProfileVehicleRepository? vehicleRepository;

  @override
  State<ProfileVerificationSettingsScreen> createState() =>
      _ProfileVerificationSettingsScreenState();
}

class _ProfileVerificationSettingsScreenState
    extends State<ProfileVerificationSettingsScreen> {
  late final ProfileVehicleRepository _vehicleRepository =
      widget.vehicleRepository ?? ProfileVehicleRepository();

  Future<void> _openVehicleEditor({ProfileVehicle? vehicle}) async {
    final saved = await showProfileVehicleEditorSheet(
      context,
      userId: widget.userState.userId,
      vehicleId:
          vehicle?.id ??
          _vehicleRepository.createVehicleId(widget.userState.userId),
      vehicle: vehicle,
      onSave: _vehicleRepository.saveVehicle,
      onOpenVerification: _openVerification,
    );
    if (!mounted || !saved) return;
    _showMessage(
      vehicle == null ? 'Fahrzeug hinzugefügt.' : 'Fahrzeug gespeichert.',
    );
  }

  Future<void> _openVerification() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProfileVerificationScreen(userId: widget.userState.userId),
      ),
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
          '${vehicle.displayName} wird deaktiviert und nicht mehr öffentlich angezeigt oder in neuen Storys und Anfragen angeboten. Bestehende Chats bleiben erhalten.',
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
                icon: Icons.directions_car_rounded,
                title: 'Fahrzeuge & Kennzeichen',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              _buildVehicles(),
            ],
          ),
        ),
      ),
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
                        _VehicleThumbnail(vehicle: vehicle),
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
                                '${_verificationStatusLabel(vehicle.verificationStatus)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CaRismaDesignTokens.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                vehicle.isPubliclyVisible
                                    ? 'Öffentlich sichtbar'
                                    : 'Nicht öffentlich sichtbar',
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

  static String _verificationStatusLabel(
    ProfileVehicleVerificationStatus status,
  ) {
    return switch (status) {
      ProfileVehicleVerificationStatus.unverified => 'Entwurf',
      ProfileVehicleVerificationStatus.evidenceMissing => 'Nachweis fehlt',
      ProfileVehicleVerificationStatus.inReview => 'In Prüfung',
      ProfileVehicleVerificationStatus.verified => 'Verifiziert',
      ProfileVehicleVerificationStatus.rejected => 'Abgelehnt',
    };
  }
}

class _VehicleThumbnail extends StatelessWidget {
  const _VehicleThumbnail({required this.vehicle});

  final ProfileVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final imageUrl = vehicle.heroImageUrl?.trim() ?? '';
    if (imageUrl.isEmpty) {
      return const CaRismaBlueIconBox(
        icon: Icons.directions_car_rounded,
        size: 50,
        iconSize: 25,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const CaRismaBlueIconBox(
          icon: Icons.directions_car_rounded,
          size: 50,
          iconSize: 25,
        ),
      ),
    );
  }
}
