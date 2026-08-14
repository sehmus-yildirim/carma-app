import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../settings/data/support_request_repository.dart';
import '../../settings/presentation/support_settings_screens.dart';
import '../data/profile_media_storage.dart';
import '../data/profile_repository.dart';
import '../data/profile_vehicle.dart';
import '../data/profile_vehicle_repository.dart';
import '../data/profile_verification_repository.dart';
import '../data/profile_verification_request.dart';
import '../data/user_profile.dart';
import 'widgets/profile_verification_document_editor_screen.dart';

class ProfileVerificationScreen extends StatefulWidget {
  const ProfileVerificationScreen({
    super.key,
    required this.userId,
    this.profileRepository,
    this.vehicleRepository,
    this.verificationRepository,
    this.mediaStorage,
    this.imagePicker,
  });

  final String userId;
  final ProfileRepository? profileRepository;
  final ProfileVehicleRepository? vehicleRepository;
  final ProfileVerificationRepository? verificationRepository;
  final ProfileMediaStorage? mediaStorage;
  final ImagePicker? imagePicker;

  @override
  State<ProfileVerificationScreen> createState() =>
      _ProfileVerificationScreenState();
}

class _ProfileVerificationScreenState extends State<ProfileVerificationScreen> {
  late final ProfileRepository _profileRepository;
  late final ProfileVehicleRepository _vehicleRepository;
  late final ProfileVerificationRepository _verificationRepository;
  late final ProfileMediaStorage _mediaStorage;
  late final ImagePicker _imagePicker;

  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<List<ProfileVehicle>>? _vehicleSubscription;
  StreamSubscription<ProfileVerificationRequest?>? _requestSubscription;
  StreamSubscription<List<ProfileVerificationHistoryEntry>>?
  _historySubscription;
  StreamSubscription<List<ProfileVerificationNotification>>?
  _notificationSubscription;

  UserProfile? _profile;
  List<ProfileVehicle> _vehicles = const [];
  ProfileVerificationRequest? _request;
  List<ProfileVerificationHistoryEntry> _history = const [];
  List<ProfileVerificationNotification> _notifications = const [];
  String? _selectedVehicleId;
  ProfileVehicleRelationship _relationship = ProfileVehicleRelationship.owner;
  bool _consentAccepted = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final Map<String, double> _uploadProgress = {};
  final Set<String> _busyDocuments = {};
  final Set<String> _dirtyExpirationKeys = {};
  final Map<String, TextEditingController> _expirationControllers = {
    for (final key in ProfileVerificationDocumentKeys.requiredExpirationKeys)
      key: TextEditingController(),
  };
  bool _profileLoaded = false;
  bool _vehiclesLoaded = false;
  bool _requestLoaded = false;

  bool get _isLoading =>
      (!_profileLoaded || !_vehiclesLoaded || !_requestLoaded) &&
      _errorMessage == null;

  @override
  void initState() {
    super.initState();
    _profileRepository = widget.profileRepository ?? ProfileRepository();
    _vehicleRepository = widget.vehicleRepository ?? ProfileVehicleRepository();
    _verificationRepository =
        widget.verificationRepository ?? ProfileVerificationRepository();
    _mediaStorage = widget.mediaStorage ?? ProfileMediaStorage();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _bindStreams();
  }

  void _bindStreams() {
    final userId = widget.userId.trim();
    _profileSubscription = _profileRepository.watchProfile(userId).listen(
      (profile) {
        if (mounted) {
          setState(() {
            _profile = profile;
            _profileLoaded = true;
          });
        }
      },
      onError: (_) => _setLoadError(
        'Deine persönlichen Daten konnten nicht geladen werden.',
      ),
    );
    _vehicleSubscription = _vehicleRepository.watchOwnerVehicles(userId).listen(
      (vehicles) {
        if (!mounted) return;
        final active = vehicles
            .where((vehicle) => !vehicle.isArchived)
            .toList(growable: false);
        setState(() {
          _vehicles = active;
          _vehiclesLoaded = true;
          if (_selectedVehicleId == null ||
              !active.any((vehicle) => vehicle.id == _selectedVehicleId)) {
            _selectedVehicleId = active
                .where((vehicle) => vehicle.isPrimary)
                .firstOrNull
                ?.id;
            _selectedVehicleId ??= active.firstOrNull?.id;
          }
          if (_request == null) {
            _relationship = _relationshipForVehicle(_selectedVehicle);
          }
        });
      },
      onError: (_) =>
          _setLoadError('Deine Fahrzeuge konnten nicht geladen werden.'),
    );
    _requestSubscription = _verificationRepository
        .watchCurrentRequest(userId)
        .listen(
          (request) {
            if (!mounted) return;
            setState(() {
              _request = request;
              _requestLoaded = true;
              if (request != null) {
                _relationship = request.vehicleRelationship;
                if (request.vehicleId?.trim().isNotEmpty == true) {
                  _selectedVehicleId = request.vehicleId;
                }
                _consentAccepted = request.authorizationConfirmed;
                for (final key
                    in ProfileVerificationDocumentKeys.requiredExpirationKeys) {
                  if (_dirtyExpirationKeys.contains(key)) continue;
                  final expiration = request.expirationFor(key);
                  _expirationControllers[key]?.text = expiration == null
                      ? ''
                      : _formatDate(expiration);
                }
              }
            });
          },
          onError: (_) => _setLoadError(
            'Der Verifizierungsstatus konnte nicht geladen werden.',
          ),
        );
    _notificationSubscription = _verificationRepository
        .watchNotifications(userId)
        .listen(
          (notifications) {
            if (mounted) {
              setState(() => _notifications = notifications);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _notifications = const []);
          },
        );
    _historySubscription = _verificationRepository
        .watchHistory(userId)
        .listen(
          (history) {
            if (mounted) setState(() => _history = history);
          },
          onError: (_) {
            if (mounted) setState(() => _history = const []);
          },
        );
  }

  void _setLoadError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _vehicleSubscription?.cancel();
    _requestSubscription?.cancel();
    _historySubscription?.cancel();
    _notificationSubscription?.cancel();
    for (final controller in _expirationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ProfileVehicle? get _selectedVehicle {
    final selectedId = _selectedVehicleId;
    if (selectedId == null) return null;
    for (final vehicle in _vehicles) {
      if (vehicle.id == selectedId) return vehicle;
    }
    return null;
  }

  bool get _hasCompleteName {
    final profile = _profile;
    return profile != null &&
        profile.firstName.trim().isNotEmpty &&
        profile.lastName.trim().isNotEmpty &&
        profile.birthDate != null &&
        profile.personalDataLocked;
  }

  bool get _hasProfilePhoto => _profile?.photoUrl?.trim().isNotEmpty == true;
  bool get _hasVehicle => _selectedVehicle?.hasRequiredData == true;
  bool get _hasPlate =>
      _selectedVehicle?.displayPlate.trim().isNotEmpty == true;
  bool get _isLocked => _request?.isLocked == true;
  bool get _allDocumentsReady => _request?.hasAllRequiredDocuments == true;
  bool get _allExpirationsReady =>
      ProfileVerificationDocumentKeys.requiredExpirationKeys.every(
        (key) => _parseExpiration(_expirationControllers[key]?.text) != null,
      );
  bool get _canSubmit =>
      !_isLocked &&
      !_isSubmitting &&
      _busyDocuments.isEmpty &&
      _hasCompleteName &&
      _hasVehicle &&
      _hasPlate &&
      _allDocumentsReady &&
      _allExpirationsReady &&
      _consentAccepted;

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
  }

  DateTime? _parseExpiration(String? value) {
    final parts = value?.trim().split('.') ?? const <String>[];
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null || year < 2000) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.day != day || parsed.month != month || parsed.year != year) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return parsed.isAfter(today) ? parsed : null;
  }

  Future<bool> _persistExpiration(String key) async {
    final expiration = _parseExpiration(_expirationControllers[key]?.text);
    if (expiration == null) {
      _showError('Bitte gib ein gültiges zukünftiges Ablaufdatum ein.');
      return false;
    }
    try {
      await _verificationRepository.saveDraftExpiration(
        userId: widget.userId,
        expirationKey: key,
        expiresAt: expiration,
      );
      _dirtyExpirationKeys.remove(key);
      return true;
    } catch (error) {
      _showError(_errorText(error));
      return false;
    }
  }

  Future<bool> _persistAllExpirations() async {
    for (final key in ProfileVerificationDocumentKeys.requiredExpirationKeys) {
      if (!await _persistExpiration(key)) return false;
    }
    return true;
  }

  Future<void> _selectVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _selectedVehicleId || _isLocked) {
      return;
    }
    setState(() {
      _selectedVehicleId = vehicleId;
      _relationship = _relationshipForVehicle(_selectedVehicle);
      _consentAccepted = false;
      _clearMessages();
    });
    await _persistRelationship();
  }

  Future<void> _selectRelationship(
    ProfileVehicleRelationship? relationship,
  ) async {
    if (relationship == null || relationship == _relationship || _isLocked) {
      return;
    }
    setState(() {
      _relationship = relationship;
      _consentAccepted = false;
      _clearMessages();
    });
    await _persistRelationship();
  }

  Future<void> _persistRelationship() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    try {
      await _verificationRepository.saveDraftRelationship(
        userId: widget.userId,
        vehicleId: vehicleId,
        relationship: _relationship,
      );
    } catch (error) {
      _showError(_errorText(error));
    }
  }

  Future<void> _chooseDocumentSource(String documentKey) async {
    if (_isLocked || _busyDocuments.contains(documentKey)) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: CaRismaDesignTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: _SourceAction(
                  icon: Icons.camera_alt_outlined,
                  label: 'Kamera',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Galerie',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3200,
      );
      if (picked == null || !mounted) return;
      final prepared = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) =>
              ProfileVerificationDocumentEditorScreen(sourceFile: picked),
        ),
      );
      if (prepared == null || !mounted) return;
      await _uploadDocument(documentKey, prepared);
    } catch (_) {
      _showError(
        'Der Nachweis konnte nicht geöffnet werden. Bitte prüfe die Kamera- oder Fotoberechtigung.',
      );
    }
  }

  Future<void> _uploadDocument(String documentKey, XFile prepared) async {
    if (_busyDocuments.contains(documentKey)) return;
    setState(() {
      _busyDocuments.add(documentKey);
      _uploadProgress[documentKey] = 0;
      _clearMessages();
    });
    ProfileMediaUploadResult? upload;
    try {
      upload = await _mediaStorage.uploadVerificationDocument(
        userId: widget.userId,
        documentType: documentKey,
        file: File(prepared.path),
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress[documentKey] = progress);
        },
      );
      await _verificationRepository.saveDraftDocument(
        userId: widget.userId,
        documentKey: documentKey,
        storagePath: upload.path,
      );
      if (!mounted) return;
      setState(() {
        _successMessage =
            '${ProfileVerificationDocumentKeys.labelFor(documentKey)} '
            '(${ProfileVerificationDocumentKeys.sideLabelFor(documentKey)}) '
            'wurde sicher hochgeladen.';
      });
    } catch (error) {
      if (upload != null) {
        await _mediaStorage.deleteVerificationDocument(
          userId: widget.userId,
          documentType: documentKey,
        );
      }
      _showError(_errorText(error));
    } finally {
      try {
        if (prepared.path.startsWith(Directory.systemTemp.path)) {
          await File(prepared.path).delete();
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _busyDocuments.remove(documentKey);
          _uploadProgress.remove(documentKey);
        });
      }
    }
  }

  Future<void> _removeDocument(String documentKey) async {
    if (_isLocked || _busyDocuments.contains(documentKey)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        title: const Text(
          'Nachweis entfernen?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Der ausgewählte Nachweis wird aus dem privaten Speicher entfernt.',
          style: TextStyle(color: CaRismaDesignTokens.textSecondary),
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
    setState(() => _busyDocuments.add(documentKey));
    try {
      await _mediaStorage.deleteVerificationDocument(
        userId: widget.userId,
        documentType: documentKey,
      );
      await _verificationRepository.removeDraftDocument(
        userId: widget.userId,
        documentKey: documentKey,
      );
    } catch (error) {
      _showError(_errorText(error));
    } finally {
      if (mounted) setState(() => _busyDocuments.remove(documentKey));
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      _showError(_submissionBlockReason());
      return;
    }
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    if (!await _persistAllExpirations()) return;
    setState(() {
      _isSubmitting = true;
      _clearMessages();
    });
    try {
      await _verificationRepository.submitVerification(
        userId: widget.userId,
        vehicleId: vehicleId,
        relationship: _relationship,
        authorizationConfirmed: _consentAccepted,
      );
      if (!mounted) return;
      setState(() {
        _successMessage = 'Deine Nachweise wurden zur Prüfung eingereicht.';
      });
    } catch (error) {
      _showError(_errorText(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _submissionBlockReason() {
    if (!_hasCompleteName) {
      return 'Bitte speichere zuerst Vorname, Nachname und Geburtsdatum.';
    }
    if (!_hasVehicle || !_hasPlate) {
      return 'Bitte hinterlege zuerst ein vollständiges Fahrzeug mit Kennzeichen.';
    }
    if (!_allDocumentsReady) {
      return 'Bitte lade für alle Nachweise Vorder- und Rückseite vollständig hoch.';
    }
    if (!_allExpirationsReady) {
      return 'Bitte gib für Ausweis und Führerschein ein gültiges Ablaufdatum ein.';
    }
    if (!_consentAccepted) {
      return 'Bitte bestätige deine Berechtigung und die Datenschutzhinweise.';
    }
    return 'Die Verifizierung kann gerade nicht eingereicht werden.';
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  String _errorText(Object error) {
    if (error is ProfileVerificationException ||
        error is ProfileMediaStorageException) {
      return error.toString();
    }
    return 'Die Verifizierung konnte gerade nicht aktualisiert werden. Bitte versuche es erneut.';
  }

  void _showConsentDetails() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CaRismaDesignTokens.card,
        title: const Text(
          'Datenschutz & Berechtigung',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Deine Dokumente werden ausschließlich zur Identitäts- und Fahrzeugverifizierung verwendet. Sie erscheinen niemals öffentlich und sind nur für dich und autorisierte Prüfer zugänglich. Nach Abschluss der Prüfung werden sie innerhalb der angegebenen Speicherfrist gelöscht. Mit deiner Bestätigung erklärst du, dass du Halter bist oder das Fahrzeug nachweislich berechtigt nutzt. Falsche oder manipulierte Nachweise können zur Ablehnung, Kontoeinschränkung und rechtlichen Prüfung führen.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  void _openSupport() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            const SupportRequestScreen(type: SupportRequestType.verification),
      ),
    );
  }

  Future<void> _markNotificationRead(
    ProfileVerificationNotification notification,
  ) async {
    if (notification.isRead) return;
    try {
      await _verificationRepository.markNotificationRead(
        userId: widget.userId,
        notificationId: notification.id,
      );
    } catch (_) {
      _showError(
        'Die Benachrichtigung konnte gerade nicht aktualisiert werden.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? _buildLoading()
              : ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    CaRismaSubPageHeader(
                      icon: Icons.verified_user_outlined,
                      title: 'Dokumente hochladen',
                      titleFontSize: 19,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    const _VerificationInfoBox(
                      icon: Icons.privacy_tip_outlined,
                      text:
                          'Deine Dokumente werden ausschließlich zur Verifizierung verwendet und niemals öffentlich angezeigt.',
                    ),
                    const SizedBox(height: 12),
                    _buildOverview(),
                    if (_notifications.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildNotifications(),
                    ],
                    const SizedBox(height: 12),
                    _buildPrerequisites(),
                    const SizedBox(height: 12),
                    for (final group
                        in ProfileVerificationDocumentKeys.groups) ...[
                      _VerificationDocumentCard(
                        group: group,
                        frontStatus: _effectiveDocumentStatus(group.frontKey),
                        backStatus: _effectiveDocumentStatus(group.backKey),
                        frontRejectionReason:
                            _request?.documentRejectionReasons[group.frontKey],
                        backRejectionReason:
                            _request?.documentRejectionReasons[group.backKey],
                        frontProgress: _uploadProgress[group.frontKey],
                        backProgress: _uploadProgress[group.backKey],
                        frontBusy: _busyDocuments.contains(group.frontKey),
                        backBusy: _busyDocuments.contains(group.backKey),
                        isLocked: _isLocked,
                        onSelectFront: () =>
                            _chooseDocumentSource(group.frontKey),
                        onSelectBack: () =>
                            _chooseDocumentSource(group.backKey),
                        onRemoveFront: () => _removeDocument(group.frontKey),
                        onRemoveBack: () => _removeDocument(group.backKey),
                        vehicleAssignment: group.includesVehicleAssignment
                            ? _buildVehicleAssignmentFields()
                            : null,
                        expirationField: group.expirationKey == null
                            ? null
                            : _buildExpirationField(group.expirationKey!),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildConsent(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      CaRismaMessageCard(
                        icon: Icons.error_outline_rounded,
                        message: _errorMessage!,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 12),
                      CaRismaMessageCard(
                        icon: Icons.check_circle_outline_rounded,
                        message: _successMessage!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _SubmitVerificationAction(
                      enabled: _canSubmit,
                      isLoading: _isSubmitting,
                      isLocked: _isLocked,
                      onTap: _submit,
                    ),
                    const SizedBox(height: 12),
                    _buildRetentionAndRecheck(),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildHistory(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        children: [
          CaRismaSubPageHeader(
            icon: Icons.verified_user_outlined,
            title: 'Dokumente hochladen',
            titleFontSize: 19,
            onBack: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: CaRismaDesignTokens.bluePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final request = _request;
    final completed = request?.completedDocumentCount ?? 0;
    final total = ProfileVerificationDocumentKeys.required.length;
    final status = request?.status ?? ProfileVerificationStatus.draft;
    final statusLabel = switch (status) {
      ProfileVerificationStatus.pending => 'In Prüfung',
      ProfileVerificationStatus.verified => 'Verifiziert',
      ProfileVerificationStatus.rejected => 'Abgelehnt',
      ProfileVerificationStatus.expired => 'Abgelaufen',
      ProfileVerificationStatus.draft =>
        completed == 0 ? 'Nicht begonnen' : 'Unvollständig',
    };
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: CaRismaDesignTokens.bluePrimary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Verifizierungsübersicht',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$completed von $total Nachweisen vollständig',
                    maxLines: 1,
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: statusLabel, status: status),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 7,
              backgroundColor: CaRismaDesignTokens.controlSurface,
              valueColor: const AlwaysStoppedAnimation(
                CaRismaDesignTokens.bluePrimary,
              ),
            ),
          ),
          if (request?.rejectionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 11),
            Text(
              request!.rejectionReason!.trim(),
              style: const TextStyle(
                color: CaRismaDesignTokens.danger,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            TextButton.icon(
              onPressed: _openSupport,
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Verifizierungsproblem melden'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrerequisites() {
    final vehicle = _selectedVehicle;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfilePhoto(photoUrl: _profile?.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _profile?.displayName.trim().isNotEmpty == true
                      ? _profile!.displayName.trim()
                      : 'Persönliche Daten',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PrerequisiteRow(
            icon: Icons.person_outline_rounded,
            label: 'Name & Geburtsdatum',
            complete: _hasCompleteName,
          ),
          _PrerequisiteRow(
            icon: Icons.photo_camera_front_outlined,
            label: 'Profilbild',
            complete: _hasProfilePhoto,
            optional: true,
          ),
          _PrerequisiteRow(
            icon: Icons.directions_car_outlined,
            label: vehicle?.displayName ?? 'Fahrzeug',
            complete: _hasVehicle,
          ),
          _PrerequisiteRow(
            icon: Icons.pin_outlined,
            label: vehicle?.displayPlate ?? 'Kennzeichen',
            complete: _hasPlate,
            isLast: true,
          ),
          const SizedBox(height: 12),
          const _VerificationInfoBox(
            icon: Icons.rule_folder_outlined,
            text:
                'Name, Kennzeichen und Fahrzeug müssen für eine erfolgreiche Verifizierung exakt zu den Nachweisen passen.',
            centerIcon: true,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleAssignmentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Color(0x1FFFFFFF), height: 26),
        const Text(
          'Fahrzeugzuordnung',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _DarkDropdown<String>(
          value: _selectedVehicleId,
          hint: 'Fahrzeug auswählen',
          enabled: !_isLocked && _vehicles.isNotEmpty,
          items: _vehicles
              .map(
                (vehicle) => DropdownMenuItem(
                  value: vehicle.id,
                  child: Text(
                    '${vehicle.displayName} · ${vehicle.displayPlate}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: _selectVehicle,
        ),
        const SizedBox(height: 10),
        _DarkDropdown<ProfileVehicleRelationship>(
          value: _relationship,
          hint: 'Berechtigung auswählen',
          enabled: !_isLocked,
          items: ProfileVehicleRelationship.values
              .map(
                (relationship) => DropdownMenuItem(
                  value: relationship,
                  child: Text(_relationshipLabel(relationship)),
                ),
              )
              .toList(growable: false),
          onChanged: _selectRelationship,
        ),
      ],
    );
  }

  Widget _buildExpirationField(String expirationKey) {
    final label =
        expirationKey == ProfileVerificationDocumentKeys.identityExpiration
        ? 'Ablaufdatum des Ausweises'
        : 'Ablaufdatum des Führerscheins';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: _expirationControllers[expirationKey],
        enabled: !_isLocked,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        maxLength: 10,
        inputFormatters: const [_GermanDateInputFormatter()],
        onChanged: (_) {
          _dirtyExpirationKeys.add(expirationKey);
          setState(_clearMessages);
        },
        onSubmitted: (_) {
          _persistExpiration(expirationKey);
        },
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          labelText: label,
          hintText: 'TT.MM.JJJJ',
          prefixIcon: const Icon(Icons.event_outlined),
          helperText: 'Manuell eintragen · muss aktuell gültig sein',
          filled: true,
          fillColor: CaRismaDesignTokens.controlSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildConsent() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: CaRismaDesignTokens.danger,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'UNBEDINGT LESEN!',
                style: TextStyle(
                  color: CaRismaDesignTokens.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isLocked
                ? null
                : () => setState(() {
                    _consentAccepted = !_consentAccepted;
                    _clearMessages();
                  }),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    _consentAccepted
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: _consentAccepted
                        ? CaRismaDesignTokens.bluePrimary
                        : CaRismaDesignTokens.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ich bestätige, dass ich Halter bin oder dieses Fahrzeug berechtigt nutze und der Verarbeitung meiner Nachweise zur Verifizierung zustimme.',
                    style: TextStyle(
                      color: CaRismaDesignTokens.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.38,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showConsentDetails,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Datenschutz & Berechtigung ansehen'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionAndRecheck() {
    return const _VerificationInfoBox(
      icon: Icons.schedule_outlined,
      text:
          'Nach Abschluss werden Nachweise spätestens nach 30 Tagen gelöscht. Eine erneute Prüfung ist bei geändertem Kennzeichen, neuem Hauptfahrzeug oder abgelaufenen Nachweisen erforderlich.',
    );
  }

  Widget _buildHistory() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verifizierungsverlauf',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < _history.length; index++)
            _HistoryRow(
              entry: _history[index],
              isLast: index == _history.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildNotifications() {
    final visible = _notifications.take(5).toList(growable: false);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktuelle Hinweise',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < visible.length; index++)
            _VerificationNotificationRow(
              notification: visible[index],
              isLast: index == visible.length - 1,
              onMarkRead: () => _markNotificationRead(visible[index]),
            ),
        ],
      ),
    );
  }

  ProfileVerificationDocumentStatus _effectiveDocumentStatus(String key) {
    if (_busyDocuments.contains(key)) {
      return ProfileVerificationDocumentStatus.uploading;
    }
    return _request?.documentStatusFor(key) ??
        ProfileVerificationDocumentStatus.missing;
  }
}

class _VerificationDocumentCard extends StatelessWidget {
  const _VerificationDocumentCard({
    required this.group,
    required this.frontStatus,
    required this.backStatus,
    required this.frontRejectionReason,
    required this.backRejectionReason,
    required this.frontProgress,
    required this.backProgress,
    required this.frontBusy,
    required this.backBusy,
    required this.isLocked,
    required this.onSelectFront,
    required this.onSelectBack,
    required this.onRemoveFront,
    required this.onRemoveBack,
    this.vehicleAssignment,
    this.expirationField,
  });

  final ProfileVerificationDocumentGroup group;
  final ProfileVerificationDocumentStatus frontStatus;
  final ProfileVerificationDocumentStatus backStatus;
  final String? frontRejectionReason;
  final String? backRejectionReason;
  final double? frontProgress;
  final double? backProgress;
  final bool frontBusy;
  final bool backBusy;
  final bool isLocked;
  final VoidCallback onSelectFront;
  final VoidCallback onSelectBack;
  final VoidCallback onRemoveFront;
  final VoidCallback onRemoveBack;
  final Widget? vehicleAssignment;
  final Widget? expirationField;

  @override
  Widget build(BuildContext context) {
    final icon = switch (group.iconName) {
      'identity' => Icons.badge_outlined,
      'driverLicense' => Icons.credit_card_rounded,
      _ => Icons.description_outlined,
    };
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: CaRismaDesignTokens.controlSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      group.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textMuted,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ?vehicleAssignment,
          ?expirationField,
          const SizedBox(height: 12),
          _DocumentSideSection(
            label: 'Vorderseite',
            status: frontStatus,
            rejectionReason: frontRejectionReason,
            progress: frontProgress,
            isBusy: frontBusy,
            isLocked: isLocked,
            onSelect: onSelectFront,
            onRemove: onRemoveFront,
          ),
          const Divider(color: Color(0x1FFFFFFF), height: 24),
          _DocumentSideSection(
            label: 'Rückseite',
            status: backStatus,
            rejectionReason: backRejectionReason,
            progress: backProgress,
            isBusy: backBusy,
            isLocked: isLocked,
            onSelect: onSelectBack,
            onRemove: onRemoveBack,
          ),
        ],
      ),
    );
  }
}

class _DocumentSideSection extends StatelessWidget {
  const _DocumentSideSection({
    required this.label,
    required this.status,
    required this.rejectionReason,
    required this.progress,
    required this.isBusy,
    required this.isLocked,
    required this.onSelect,
    required this.onRemove,
  });

  final String label;
  final ProfileVerificationDocumentStatus status;
  final String? rejectionReason;
  final double? progress;
  final bool isBusy;
  final bool isLocked;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  bool get _hasDocument => !const {
    ProfileVerificationDocumentStatus.missing,
    ProfileVerificationDocumentStatus.uploading,
    ProfileVerificationDocumentStatus.expired,
  }.contains(status);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (status != ProfileVerificationDocumentStatus.missing)
              _DocumentStatusLine(status: status),
          ],
        ),
        if (isBusy) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: CaRismaDesignTokens.controlSurface,
            color: CaRismaDesignTokens.bluePrimary,
          ),
        ],
        if (rejectionReason?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 9),
          Text(
            rejectionReason!.trim(),
            style: const TextStyle(
              color: CaRismaDesignTokens.danger,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
        if (!isLocked) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OutlineAction(
                  label: _hasDocument ? 'Ersetzen' : 'Auswählen',
                  icon: _hasDocument
                      ? Icons.sync_rounded
                      : Icons.add_photo_alternate_outlined,
                  onTap: isBusy ? null : onSelect,
                ),
              ),
              if (_hasDocument) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _OutlineAction(
                    label: status == ProfileVerificationDocumentStatus.rejected
                        ? 'Neu einreichen'
                        : 'Entfernen',
                    icon: status == ProfileVerificationDocumentStatus.rejected
                        ? Icons.refresh_rounded
                        : Icons.delete_outline_rounded,
                    isDanger:
                        status != ProfileVerificationDocumentStatus.rejected,
                    onTap: isBusy
                        ? null
                        : status == ProfileVerificationDocumentStatus.rejected
                        ? onSelect
                        : onRemove,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _DocumentStatusLine extends StatelessWidget {
  const _DocumentStatusLine({required this.status});

  final ProfileVerificationDocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      ProfileVerificationDocumentStatus.missing => (
        'Fehlt',
        Icons.error_outline_rounded,
        CaRismaDesignTokens.textMuted,
      ),
      ProfileVerificationDocumentStatus.uploading => (
        'Wird hochgeladen',
        Icons.cloud_upload_outlined,
        CaRismaDesignTokens.bluePrimary,
      ),
      ProfileVerificationDocumentStatus.uploaded => (
        'Hochgeladen',
        Icons.cloud_done_outlined,
        CaRismaDesignTokens.bluePrimary,
      ),
      ProfileVerificationDocumentStatus.inReview => (
        'In Prüfung',
        Icons.manage_search_rounded,
        CaRismaDesignTokens.bluePrimary,
      ),
      ProfileVerificationDocumentStatus.verified => (
        'Verifiziert',
        Icons.verified_outlined,
        CaRismaDesignTokens.success,
      ),
      ProfileVerificationDocumentStatus.rejected => (
        'Abgelehnt',
        Icons.cancel_outlined,
        CaRismaDesignTokens.danger,
      ),
      ProfileVerificationDocumentStatus.expired => (
        'Abgelaufen',
        Icons.schedule_outlined,
        CaRismaDesignTokens.danger,
      ),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _VerificationInfoBox extends StatelessWidget {
  const _VerificationInfoBox({
    required this.icon,
    required this.text,
    this.centerIcon = false,
  });

  final IconData icon;
  final String text;
  final bool centerIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: centerIcon
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: CaRismaDesignTokens.textSecondary,
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

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return Container(
      width: 54,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: url.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
    );
  }
}

class _PrerequisiteRow extends StatelessWidget {
  const _PrerequisiteRow({
    required this.icon,
    required this.label,
    required this.complete,
    this.optional = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final bool complete;
  final bool optional;
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
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (complete || optional)
            Text(
              complete ? 'Vorhanden' : 'Optional',
              style: TextStyle(
                color: complete
                    ? CaRismaDesignTokens.success
                    : CaRismaDesignTokens.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});

  final String label;
  final ProfileVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProfileVerificationStatus.verified => CaRismaDesignTokens.success,
      ProfileVerificationStatus.rejected ||
      ProfileVerificationStatus.expired => CaRismaDesignTokens.danger,
      _ => CaRismaDesignTokens.bluePrimary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GermanDateInputFormatter extends TextInputFormatter {
  const _GermanDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length > 8 ? 8 : digits.length);
    final buffer = StringBuffer();
    for (var index = 0; index < limited.length; index++) {
      if (index == 2 || index == 4) buffer.write('.');
      buffer.write(limited[index]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final bool enabled;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: CaRismaDesignTokens.card,
      iconEnabledColor: Colors.white,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        filled: true,
        fillColor: CaRismaDesignTokens.controlSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      hint: Text(
        hint,
        style: const TextStyle(color: CaRismaDesignTokens.textMuted),
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: CaRismaDesignTokens.controlSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 27),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.bluePrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _SubmitVerificationAction extends StatelessWidget {
  const _SubmitVerificationAction({
    required this.enabled,
    required this.isLoading,
    required this.isLocked,
    required this.onTap,
  });

  final bool enabled;
  final bool isLoading;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isLocked ? 'Prüfung läuft' : 'Zur Prüfung einreichen';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || isLocked ? 1 : 0.46,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLocked
                  ? Colors.white.withValues(alpha: 0.14)
                  : CaRismaDesignTokens.bluePrimary,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isLocked ? Icons.lock_outline_rounded : Icons.send_rounded,
                    color: Colors.white,
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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

class _VerificationNotificationRow extends StatelessWidget {
  const _VerificationNotificationRow({
    required this.notification,
    required this.isLast,
    required this.onMarkRead,
  });

  final ProfileVerificationNotification notification;
  final bool isLast;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final isPositive =
        notification.status == ProfileVerificationStatus.verified;
    final color = isPositive
        ? CaRismaDesignTokens.success
        : notification.status == ProfileVerificationStatus.rejected
        ? CaRismaDesignTokens.danger
        : CaRismaDesignTokens.bluePrimary;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPositive
                ? Icons.verified_outlined
                : notification.status == ProfileVerificationStatus.rejected
                ? Icons.assignment_late_outlined
                : Icons.notifications_none_rounded,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: TextStyle(
                    color: notification.isRead
                        ? CaRismaDesignTokens.textSecondary
                        : Colors.white,
                    fontWeight: notification.isRead
                        ? FontWeight.w700
                        : FontWeight.w900,
                    height: 1.35,
                  ),
                ),
                if (notification.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.createdAt!),
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!notification.isRead) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMarkRead,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.done_rounded,
                  color: CaRismaDesignTokens.bluePrimary,
                  size: 21,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.isLast});

  final ProfileVerificationHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final label = switch (entry.status) {
      ProfileVerificationStatus.pending => 'Zur Prüfung eingereicht',
      ProfileVerificationStatus.verified => 'Verifiziert',
      ProfileVerificationStatus.rejected => 'Nachreichung erforderlich',
      ProfileVerificationStatus.expired => 'Nachweise gelöscht',
      ProfileVerificationStatus.draft => 'Entwurf aktualisiert',
    };
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (entry.reason?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.reason!.trim(),
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.createdAt != null)
            Text(
              _formatDate(entry.createdAt!),
              style: const TextStyle(
                color: CaRismaDesignTokens.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

String _relationshipLabel(ProfileVehicleRelationship relationship) {
  return switch (relationship) {
    ProfileVehicleRelationship.owner => 'Ich bin Halter',
    ProfileVehicleRelationship.leasingCompany => 'Leasing- oder Firmenfahrzeug',
    ProfileVehicleRelationship.authorizedUser =>
      'Ich nutze das Fahrzeug mit Erlaubnis',
  };
}

ProfileVehicleRelationship _relationshipForVehicle(ProfileVehicle? vehicle) {
  return switch (vehicle?.useRelationship) {
    ProfileVehicleUseRelationship.leasingCompany =>
      ProfileVehicleRelationship.leasingCompany,
    ProfileVehicleUseRelationship.authorizedUser =>
      ProfileVehicleRelationship.authorizedUser,
    _ => ProfileVehicleRelationship.owner,
  };
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
