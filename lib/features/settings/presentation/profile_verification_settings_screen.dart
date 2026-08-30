import 'package:flutter/material.dart';

import '../../../shared/models/carisma_models.dart';
import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_primary_button.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../profile/data/profile_vehicle.dart';
import '../../profile/data/profile_vehicle_repository.dart';
import '../../profile/presentation/widgets/profile_vehicle_editor_sheet.dart';
import '../../profile/presentation/widgets/profile_vehicle_manage_card.dart';

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
                title: 'Fahrzeuge',
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
            const _VerificationLevelOverview(),
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
                  child: ProfileVehicleManageCard(
                    vehicle: vehicle,
                    trailing: PopupMenuButton<String>(
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
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VerificationLevelOverview extends StatelessWidget {
  const _VerificationLevelOverview();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verifizierungsstufen',
            style: TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Du entscheidest selbst, welche Stufe du nutzen möchtest.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14),
          _VerificationLevelRow(
            icon: Icons.person_outline_rounded,
            color: CaRismaDesignTokens.textMuted,
            title: 'Basis-Konto',
            description:
                'Fahrzeug und Kennzeichen eintragen, Kennzeichen suchen und Fahrzeuge melden. Kontaktanfragen sind noch nicht möglich.',
          ),
          _VerificationLevelRow(
            icon: Icons.directions_car_outlined,
            color: CaRismaDesignTokens.bluePrimary,
            title: 'Dokumentdaten abgeglichen',
            description:
                'Vorderseiten direkt fotografieren und die ausgelesenen Identitäts-, Gültigkeits- und Fahrzeugdaten abgleichen. Das ist keine amtliche Echtheitsprüfung.',
          ),
          _VerificationLevelRow(
            icon: Icons.badge_outlined,
            color: Color(0xFF38BDF8),
            title: 'Private Identitätsdaten',
            description:
                'Name, Geburtsdatum, Dokumentart und Ablaufdatum bleiben privat. Dokumentbilder und Roh-OCR werden nicht dauerhaft gespeichert.',
          ),
          _VerificationLevelRow(
            icon: Icons.verified_user_outlined,
            color: CaRismaDesignTokens.success,
            title: 'Berechtigung dokumentiert',
            description:
                'Bei Leasing-, Firmen- und berechtigt genutzten Fahrzeugen hält eine private Eigenerklärung die ausgewählte Zuordnung fest.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _VerificationLevelRow extends StatelessWidget {
  const _VerificationLevelRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.9)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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
