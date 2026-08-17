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
  ProfileVerificationIdentityDocumentType _identityDocumentType =
      ProfileVerificationIdentityDocumentType.identityCard;
  bool _consentAccepted = false;
  bool _vehicleAssignmentConfirmed = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final Map<String, double> _uploadProgress = {};
  final Set<String> _busyDocuments = {};
  final Set<String> _dirtyExpirationKeys = {};
  final Map<String, DateTime> _pendingExpirations = {};
  final Map<String, XFile> _localDocumentPreviews = {};
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _expirationControllers = {
    for (final key in ProfileVerificationDocumentKeys.requiredExpirationKeys)
      key: TextEditingController(),
  };
  final Map<String, FocusNode> _expirationFocusNodes = {
    for (final key in ProfileVerificationDocumentKeys.requiredExpirationKeys)
      key: FocusNode(debugLabel: 'verification-expiration-$key'),
  };
  bool _profileLoaded = false;
  bool _vehiclesLoaded = false;
  bool _requestLoaded = false;
  bool _requestStreamFailed = false;
  bool _identityDocumentTypeInitialized = false;
  ProfileVerificationIdentityDocumentType? _pendingIdentityDocumentType;
  bool _confirmationsInitialized = false;

  bool get _isLoading => !_profileLoaded || !_vehiclesLoaded || !_requestLoaded;

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
          final scrollOffset = _captureScrollOffset();
          setState(() {
            _profile = profile;
            _profileLoaded = true;
          });
          _restoreScrollOffset(scrollOffset);
        }
      },
      onError: (_) => _setLoadError(
        'Deine persönlichen Daten konnten nicht geladen werden.',
        profileLoaded: true,
      ),
    );
    _vehicleSubscription = _vehicleRepository.watchOwnerVehicles(userId).listen(
      (vehicles) {
        if (!mounted) return;
        final active = vehicles
            .where((vehicle) => !vehicle.isArchived)
            .toList(growable: false);
        final scrollOffset = _captureScrollOffset();
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
        _restoreScrollOffset(scrollOffset);
      },
      onError: (_) => _setLoadError(
        'Deine Fahrzeuge konnten nicht geladen werden.',
        vehiclesLoaded: true,
      ),
    );
    _bindRequestStream(userId);
    _notificationSubscription = _verificationRepository
        .watchNotifications(userId)
        .listen(
          (notifications) {
            if (mounted) {
              final scrollOffset = _captureScrollOffset();
              setState(() => _notifications = notifications);
              _restoreScrollOffset(scrollOffset);
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
            if (mounted) {
              final scrollOffset = _captureScrollOffset();
              setState(() => _history = history);
              _restoreScrollOffset(scrollOffset);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _history = const []);
          },
        );
  }

  void _bindRequestStream(String userId) {
    _requestSubscription = _verificationRepository
        .watchCurrentRequest(userId)
        .listen(
          (request) {
            if (!mounted) return;
            _requestStreamFailed = false;
            final scrollOffset = _captureScrollOffset();
            setState(() {
              _request = request;
              _requestLoaded = true;
              if (!_identityDocumentTypeInitialized) {
                _identityDocumentType =
                    request?.identityDocumentType ?? _identityDocumentType;
                _identityDocumentTypeInitialized = true;
              } else if (request != null) {
                final pendingType = _pendingIdentityDocumentType;
                if (pendingType == null) {
                  _identityDocumentType = request.identityDocumentType;
                } else if (request.identityDocumentType == pendingType) {
                  _identityDocumentType = pendingType;
                  _pendingIdentityDocumentType = null;
                }
              }
              if (request != null) {
                _relationship = request.vehicleRelationship;
                if (request.vehicleId?.trim().isNotEmpty == true) {
                  _selectedVehicleId = request.vehicleId;
                }
                if (!_confirmationsInitialized) {
                  _consentAccepted = request.authorizationConfirmed;
                  _vehicleAssignmentConfirmed =
                      request.vehicleAssignmentConfirmed;
                  _confirmationsInitialized = true;
                }
              } else if (!_confirmationsInitialized) {
                _confirmationsInitialized = true;
              }
            });
            _synchronizeExpirationFields(request);
            _restoreScrollOffset(scrollOffset);
          },
          onError: (_) {
            _requestStreamFailed = true;
            _setLoadError(
              'Der Verifizierungsstatus konnte nicht geladen werden.',
              requestLoaded: true,
            );
          },
        );
  }

  Future<void> _recoverRequestStreamIfNeeded() async {
    if (!_requestStreamFailed) return;
    await _requestSubscription?.cancel();
    if (!mounted) return;
    _requestStreamFailed = false;
    _bindRequestStream(widget.userId.trim());
  }

  void _setLoadError(
    String message, {
    bool profileLoaded = false,
    bool vehiclesLoaded = false,
    bool requestLoaded = false,
  }) {
    if (!mounted) return;
    setState(() {
      _profileLoaded = _profileLoaded || profileLoaded;
      _vehiclesLoaded = _vehiclesLoaded || vehiclesLoaded;
      _requestLoaded = _requestLoaded || requestLoaded;
      _errorMessage = message;
    });
  }

  double? _captureScrollOffset() {
    return _scrollController.hasClients ? _scrollController.offset : null;
  }

  void _restoreScrollOffset(double? offset) {
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target = offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    });
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
    for (final focusNode in _expirationFocusNodes.values) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    for (final preview in _localDocumentPreviews.values) {
      _deleteTemporaryPreview(preview);
    }
    super.dispose();
  }

  void _synchronizeExpirationFields(ProfileVerificationRequest? request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key
          in ProfileVerificationDocumentKeys.requiredExpirationKeys) {
        final pendingExpiration = _pendingExpirations[key];
        if (pendingExpiration != null) {
          final remoteExpiration = request?.expirationFor(key);
          if (_isSameDay(remoteExpiration, pendingExpiration)) {
            _pendingExpirations.remove(key);
            _dirtyExpirationKeys.remove(key);
          } else {
            continue;
          }
        }
        if (_dirtyExpirationKeys.contains(key) ||
            _expirationFocusNodes[key]?.hasFocus == true) {
          continue;
        }
        final expiration = request?.expirationFor(key);
        final nextText = expiration == null ? '' : _formatDate(expiration);
        final controller = _expirationControllers[key];
        if (controller != null && controller.text != nextText) {
          controller.value = TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          );
        }
      }
    });
  }

  static bool _isSameDay(DateTime? first, DateTime? second) {
    if (first == null || second == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static void _deleteTemporaryPreview(XFile file) {
    if (!file.path.startsWith(Directory.systemTemp.path)) return;
    unawaited(_deleteFileIfPresent(File(file.path)));
  }

  static Future<void> _deleteFileIfPresent(File file) async {
    try {
      await file.delete();
    } catch (_) {}
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
      _consentAccepted &&
      _vehicleAssignmentConfirmed;

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
  }

  DateTime? _parseGermanDate(String? value) {
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
    return parsed;
  }

  DateTime? _parseExpiration(String? value) {
    final parsed = _parseGermanDate(value);
    if (parsed == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return parsed.isAfter(today) ? parsed : null;
  }

  String? _expirationValidationMessage(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 10) return null;
    final parsed = _parseGermanDate(trimmed);
    if (parsed == null) {
      return 'Bitte gib ein gültiges Datum im Format TT.MM.JJJJ ein.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (parsed.isBefore(today)) {
      return 'Dieses Dokument ist abgelaufen.';
    }
    if (!parsed.isAfter(today)) {
      return 'Das Ablaufdatum muss nach dem heutigen Tag liegen.';
    }
    return null;
  }

  Future<bool> _persistExpiration(String key) async {
    final value = _expirationControllers[key]?.text ?? '';
    final expiration = _parseExpiration(value);
    if (expiration == null) {
      _showError(
        _expirationValidationMessage(value) ??
            'Bitte gib ein gültiges, nicht abgelaufenes Datum ein.',
      );
      return false;
    }
    _pendingExpirations[key] = expiration;
    try {
      await _verificationRepository.saveDraftExpiration(
        userId: widget.userId,
        expirationKey: key,
        expiresAt: expiration,
      );
      await _recoverRequestStreamIfNeeded();
      return true;
    } catch (error) {
      _pendingExpirations.remove(key);
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

  Future<void> _selectIdentityDocumentType(
    ProfileVerificationIdentityDocumentType? type,
  ) async {
    if (type == null || type == _identityDocumentType || _isLocked) return;
    final scrollOffset = _captureScrollOffset();
    setState(() {
      _identityDocumentType = type;
      _pendingIdentityDocumentType = type;
      _consentAccepted = false;
      _dirtyExpirationKeys.remove(
        ProfileVerificationDocumentKeys.identityExpiration,
      );
      _clearMessages();
    });
    _restoreScrollOffset(scrollOffset);
    try {
      await _verificationRepository.saveDraftIdentityDocumentType(
        userId: widget.userId,
        identityDocumentType: type,
      );
      await _recoverRequestStreamIfNeeded();
    } catch (error) {
      _showError(_errorText(error));
      return;
    }

    var cleanupFailed = false;
    for (final key in const [
      ProfileVerificationDocumentKeys.identityFront,
      ProfileVerificationDocumentKeys.identityBack,
    ]) {
      final localPreview = _localDocumentPreviews.remove(key);
      if (localPreview != null) _deleteTemporaryPreview(localPreview);
      try {
        await _mediaStorage.deleteVerificationDocument(
          userId: widget.userId,
          documentType: key,
        );
      } catch (_) {
        cleanupFailed = true;
      }
    }
    if (!mounted) return;
    setState(() {
      if (cleanupFailed) {
        _errorMessage =
            'Der Dokumenttyp wurde gespeichert. Alte lokale Nachweise konnten noch nicht vollständig entfernt werden.';
      }
    });
  }

  Future<bool> _ensureIdentityDocumentTypeSaved() async {
    if (_pendingIdentityDocumentType == null) return true;
    try {
      await _verificationRepository.saveDraftIdentityDocumentType(
        userId: widget.userId,
        identityDocumentType: _identityDocumentType,
      );
      await _recoverRequestStreamIfNeeded();
      return true;
    } catch (error) {
      _showError(_errorText(error));
      return false;
    }
  }

  Future<void> _persistConfirmations() async {
    try {
      await _verificationRepository.saveDraftConfirmations(
        userId: widget.userId,
        authorizationConfirmed: _consentAccepted,
        vehicleAssignmentConfirmed: _vehicleAssignmentConfirmed,
      );
      await _recoverRequestStreamIfNeeded();
    } catch (error) {
      _showError(_errorText(error));
    }
  }

  void _toggleConsent(bool value) {
    if (_isLocked || !mounted) return;
    final scrollOffset = _captureScrollOffset();
    setState(() {
      _consentAccepted = value;
      _clearMessages();
    });
    _restoreScrollOffset(scrollOffset);
    unawaited(_persistConfirmations());
  }

  void _toggleVehicleAssignment(bool value) {
    if (_isLocked || !mounted) return;
    setState(() {
      _vehicleAssignmentConfirmed = value;
      _clearMessages();
    });
    unawaited(_persistConfirmations());
  }

  Future<void> _selectVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _selectedVehicleId || _isLocked) {
      return;
    }
    setState(() {
      _selectedVehicleId = vehicleId;
      _relationship = _relationshipForVehicle(_selectedVehicle);
      _consentAccepted = false;
      _vehicleAssignmentConfirmed = false;
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
      _vehicleAssignmentConfirmed = false;
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
      await _recoverRequestStreamIfNeeded();
    } catch (error) {
      _showError(_errorText(error));
    }
  }

  Future<void> _chooseDocumentSource(String documentKey) async {
    if (_isLocked || _busyDocuments.contains(documentKey)) return;
    final scrollOffset = _captureScrollOffset();
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
    _restoreScrollOffset(scrollOffset);
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
      _restoreScrollOffset(scrollOffset);
      if (prepared == null || !mounted) return;
      if ((documentKey == ProfileVerificationDocumentKeys.identityFront ||
              documentKey == ProfileVerificationDocumentKeys.identityBack) &&
          !await _ensureIdentityDocumentTypeSaved()) {
        return;
      }
      if (!mounted) return;
      final previousPreview = _localDocumentPreviews[documentKey];
      setState(() {
        _localDocumentPreviews[documentKey] = prepared;
        _clearMessages();
      });
      _restoreScrollOffset(scrollOffset);
      if (previousPreview != null && previousPreview.path != prepared.path) {
        _deleteTemporaryPreview(previousPreview);
      }
      await _uploadDocument(documentKey, prepared);
      _restoreScrollOffset(scrollOffset);
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
      await _recoverRequestStreamIfNeeded();
      if (!mounted) return;
      setState(() {
        _successMessage =
            '${ProfileVerificationDocumentKeys.labelFor(documentKey)} '
            '(${ProfileVerificationDocumentKeys.sideLabelFor(documentKey)}) '
            'wurde sicher hochgeladen.';
      });
    } catch (error) {
      if (upload != null) {
        try {
          await _mediaStorage.deleteVerificationDocument(
            userId: widget.userId,
            documentType: documentKey,
          );
        } catch (_) {}
      }
      _showError(_errorText(error));
    } finally {
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
    final localPreview = _localDocumentPreviews.remove(documentKey);
    if (localPreview != null) _deleteTemporaryPreview(localPreview);
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
      await _recoverRequestStreamIfNeeded();
    } catch (error) {
      _showError(_errorText(error));
    } finally {
      if (mounted) setState(() => _busyDocuments.remove(documentKey));
    }
  }

  Future<void> _previewDocument(String documentKey) async {
    final localPreview = _localDocumentPreviews[documentKey];
    if (localPreview != null) {
      try {
        final bytes = await localPreview.readAsBytes();
        if (!mounted) return;
        await _showDocumentPreview(documentKey, bytes);
      } catch (_) {
        _showError('Die ausgewählte Vorschau konnte nicht geöffnet werden.');
      }
      return;
    }
    final storagePath = _request?.documentStoragePaths[documentKey]?.trim();
    if (storagePath == null || storagePath.isEmpty) {
      _showError(
        'Für diesen Nachweis ist nach der sicheren Löschung keine Vorschau mehr verfügbar.',
      );
      return;
    }
    try {
      final bytes = await _mediaStorage.loadVerificationDocumentPreview(
        userId: widget.userId,
        documentType: documentKey,
        storagePath: storagePath,
      );
      if (!mounted) return;
      await _showDocumentPreview(documentKey, bytes);
    } catch (error) {
      _showError(_errorText(error));
    }
  }

  Future<void> _showDocumentPreview(String documentKey, List<int> bytes) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: CaRismaDesignTokens.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CaRismaSubPageHeader(
                  icon: Icons.visibility_outlined,
                  title:
                      '${ProfileVerificationDocumentKeys.labelFor(documentKey)} · ${ProfileVerificationDocumentKeys.sideLabelFor(documentKey)}',
                  titleFontSize: 16,
                  onBack: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      Uint8List.fromList(bytes),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
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

  Future<void> _submit() async {
    if (!_canSubmit) {
      _showError(_submissionBlockReason());
      return;
    }
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    if (!await _ensureIdentityDocumentTypeSaved()) return;
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
        vehicleAssignmentConfirmed: _vehicleAssignmentConfirmed,
        identityDocumentType: _identityDocumentType,
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
    if (!_vehicleAssignmentConfirmed) {
      return 'Bitte bestätige, welches Fahrzeug geprüft werden soll.';
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
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: CaRismaDesignTokens.textSecondary,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text:
                      'Deine Dokumente werden ausschließlich zur Identitäts- und Fahrzeugverifizierung verwendet. Sie erscheinen niemals öffentlich und sind nur für dich und autorisierte Prüfer zugänglich. Nach Abschluss der Prüfung werden sie innerhalb der angegebenen Speicherfrist gelöscht. Mit deiner Bestätigung erklärst du, dass du Halter bist oder das Fahrzeug nachweislich berechtigt nutzt. Falsche oder manipulierte Nachweise können zur Ablehnung, Kontoeinschränkung und ',
                ),
                TextSpan(
                  text: 'rechtlichen Prüfung',
                  style: TextStyle(
                    color: CaRismaDesignTokens.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(text: ' führen.'),
              ],
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

  void _openSupport([String? documentGroup]) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SupportRequestScreen(
          type: SupportRequestType.verification,
          technicalReference: documentGroup == null
              ? null
              : SupportTechnicalReference(
                  referenceId: widget.userId,
                  referenceGroup: documentGroup,
                ),
        ),
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
                  key: PageStorageKey<String>(
                    'profile-verification-${widget.userId}',
                  ),
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    CaRismaSubPageHeader(
                      icon: Icons.verified_user_outlined,
                      title: 'Dokumente hochladen',
                      titleFontSize: 19,
                      onBack: () => Navigator.of(context).pop(),
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
                        backRequired:
                            group.groupKey !=
                                ProfileVerificationDocumentKeys.identityGroup ||
                            _identityDocumentType.requiresBackSide,
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
                        frontLocked: _isDocumentLocked(group.frontKey),
                        backLocked: _isDocumentLocked(group.backKey),
                        onSelectFront: () =>
                            _chooseDocumentSource(group.frontKey),
                        onSelectBack: () =>
                            _chooseDocumentSource(group.backKey),
                        onRemoveFront: () => _removeDocument(group.frontKey),
                        onRemoveBack: () => _removeDocument(group.backKey),
                        onPreviewFront: () => _previewDocument(group.frontKey),
                        onPreviewBack: () => _previewDocument(group.backKey),
                        frontLocalPreviewPath:
                            _localDocumentPreviews[group.frontKey]?.path,
                        backLocalPreviewPath:
                            _localDocumentPreviews[group.backKey]?.path,
                        frontPreviewAvailable:
                            _localDocumentPreviews.containsKey(
                              group.frontKey,
                            ) ||
                            _request?.documentStoragePaths[group.frontKey]
                                    ?.trim()
                                    .isNotEmpty ==
                                true,
                        backPreviewAvailable:
                            _localDocumentPreviews.containsKey(group.backKey) ||
                            _request?.documentStoragePaths[group.backKey]
                                    ?.trim()
                                    .isNotEmpty ==
                                true,
                        onReportProblem: () => _openSupport(group.groupKey),
                        documentTypeField:
                            group.groupKey ==
                                ProfileVerificationDocumentKeys.identityGroup
                            ? _buildIdentityDocumentTypeField()
                            : null,
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
    final total = ProfileVerificationDocumentKeys.requiredFor(
      request?.identityDocumentType ?? _identityDocumentType,
    ).length;
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
          enabled:
              !_isLocked &&
              !_isGroupProtected(
                ProfileVerificationDocumentKeys.vehicleGroup,
              ) &&
              _vehicles.isNotEmpty,
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
          enabled:
              !_isLocked &&
              !_isGroupProtected(ProfileVerificationDocumentKeys.vehicleGroup),
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
        const SizedBox(height: 10),
        if (_selectedVehicle == null)
          const _VerificationInfoBox(
            icon: Icons.info_outline_rounded,
            text: 'Bitte wähle zuerst ein Fahrzeug aus.',
            centerIcon: true,
          )
        else
          _InlineConfirmationRow(
            value: _vehicleAssignmentConfirmed,
            enabled: !_isLocked,
            text:
                'Dieses Fahrzeug prüfen: ${_selectedVehicle!.displayName} · ${_selectedVehicle!.displayPlate}',
            onChanged: _toggleVehicleAssignment,
          ),
      ],
    );
  }

  Widget _buildIdentityDocumentTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Color(0x1FFFFFFF), height: 26),
        const Text(
          'Dokumenttyp',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _DarkDropdown<ProfileVerificationIdentityDocumentType>(
          value: _identityDocumentType,
          hint: 'Dokumenttyp auswählen',
          enabled:
              !_isLocked &&
              !_isGroupProtected(ProfileVerificationDocumentKeys.identityGroup),
          items: ProfileVerificationIdentityDocumentType.values
              .map(
                (type) =>
                    DropdownMenuItem(value: type, child: Text(type.label)),
              )
              .toList(growable: false),
          onChanged: _selectIdentityDocumentType,
        ),
      ],
    );
  }

  Widget _buildExpirationField(String expirationKey) {
    final label =
        expirationKey == ProfileVerificationDocumentKeys.identityExpiration
        ? 'Ablaufdatum des Ausweises'
        : 'Ablaufdatum des Führerscheins';
    final controller = _expirationControllers[expirationKey]!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final validationMessage = _expirationValidationMessage(value.text);
          final errorBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: CaRismaDesignTokens.danger,
              width: 1.5,
            ),
          );
          return TextField(
            key: ValueKey('verification-expiration-$expirationKey'),
            controller: controller,
            focusNode: _expirationFocusNodes[expirationKey],
            enabled: !_isExpirationLocked(expirationKey),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: const [_GermanDateInputFormatter()],
            maxLength: 10,
            onChanged: (_) {
              _dirtyExpirationKeys.add(expirationKey);
              if (_errorMessage != null || _successMessage != null) {
                setState(_clearMessages);
              }
            },
            onEditingComplete: () {
              _expirationFocusNodes[expirationKey]?.unfocus();
              unawaited(_persistExpiration(expirationKey));
            },
            onTapOutside: (_) {
              _expirationFocusNodes[expirationKey]?.unfocus();
              if (_dirtyExpirationKeys.contains(expirationKey)) {
                unawaited(_persistExpiration(expirationKey));
              }
            },
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: 'TT.MM.JJJJ',
              prefixIcon: const Icon(Icons.event_outlined),
              helperText: validationMessage == null
                  ? 'Muss aktuell gültig sein'
                  : null,
              errorText: validationMessage,
              errorMaxLines: 2,
              counterText: '',
              filled: true,
              fillColor: CaRismaDesignTokens.controlSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder,
            ),
          );
        },
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
          const SizedBox(height: 8),
          const Text(
            'Bitte öffne und lies zuerst die Informationen zu Datenschutz und Berechtigung vollständig durch.',
            style: TextStyle(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _OutlineAction(
            label: 'Datenschutz & Berechtigung ansehen',
            icon: Icons.policy_outlined,
            onTap: _showConsentDetails,
          ),
          const SizedBox(height: 12),
          _InlineConfirmationRow(
            key: const ValueKey('verification-consent-checkbox'),
            value: _consentAccepted,
            enabled: !_isLocked,
            text:
                'Ich bestätige, dass ich Halter bin oder dieses Fahrzeug berechtigt nutze und der Verarbeitung meiner Nachweise zur Verifizierung zustimme.',
            onChanged: _toggleConsent,
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionAndRecheck() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datenschutzübersicht',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const _PrivacyOverviewRow(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Prüfung',
            text:
                'Nur ausdrücklich berechtigte Prüfer dürfen deine Nachweise für die Verifizierung einsehen.',
          ),
          const _PrivacyOverviewRow(
            icon: Icons.lock_outline_rounded,
            title: 'Speicherung',
            text:
                'Dokumente werden geschützt und ausschließlich für die Identitäts-, Führerschein- und Fahrzeugprüfung gespeichert.',
          ),
          const _PrivacyOverviewRow(
            icon: Icons.visibility_off_outlined,
            title: 'Öffentliche Daten',
            text:
                'Dokumentbilder und persönliche Dokumentangaben bleiben privat. Öffentlich erscheint nur der freigegebene Verifizierungsstatus.',
          ),
          const _PrivacyOverviewRow(
            icon: Icons.find_replace_outlined,
            title: 'Nachreichung und Löschung',
            text:
                'Abgelehnte oder abgelaufene Nachweise können gezielt ersetzt werden. Nicht mehr benötigte Dateien werden nach den festgelegten Regeln entfernt.',
            isLast: true,
          ),
        ],
      ),
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

  bool _isDocumentLocked(String key) {
    final request = _request;
    if (request == null) return false;
    return !request.canEditDocument(key);
  }

  bool _isExpirationLocked(String expirationKey) {
    if (_isLocked) return true;
    final request = _request;
    if (request == null) return false;
    final groupKey =
        expirationKey == ProfileVerificationDocumentKeys.identityExpiration
        ? ProfileVerificationDocumentKeys.identityGroup
        : ProfileVerificationDocumentKeys.driverLicenseGroup;
    return request.isGroupVerified(groupKey);
  }

  bool _isGroupProtected(String groupKey) {
    return _request?.isGroupProtected(groupKey) ?? false;
  }
}

class _InlineConfirmationRow extends StatelessWidget {
  const _InlineConfirmationRow({
    super.key,
    required this.value,
    required this.enabled,
    required this.text,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final String text;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 32,
          child: Checkbox(
            value: value,
            onChanged: enabled
                ? (nextValue) => onChanged(nextValue ?? false)
                : null,
            activeColor: CaRismaDesignTokens.bluePrimary,
            checkColor: Colors.white,
            side: const BorderSide(color: CaRismaDesignTokens.textMuted),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(!value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                text,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.38,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationDocumentCard extends StatelessWidget {
  const _VerificationDocumentCard({
    required this.group,
    required this.backRequired,
    required this.frontStatus,
    required this.backStatus,
    required this.frontRejectionReason,
    required this.backRejectionReason,
    required this.frontProgress,
    required this.backProgress,
    required this.frontBusy,
    required this.backBusy,
    required this.frontLocked,
    required this.backLocked,
    required this.onSelectFront,
    required this.onSelectBack,
    required this.onRemoveFront,
    required this.onRemoveBack,
    required this.onPreviewFront,
    required this.onPreviewBack,
    required this.frontLocalPreviewPath,
    required this.backLocalPreviewPath,
    required this.frontPreviewAvailable,
    required this.backPreviewAvailable,
    required this.onReportProblem,
    this.vehicleAssignment,
    this.expirationField,
    this.documentTypeField,
  });

  final ProfileVerificationDocumentGroup group;
  final bool backRequired;
  final ProfileVerificationDocumentStatus frontStatus;
  final ProfileVerificationDocumentStatus backStatus;
  final String? frontRejectionReason;
  final String? backRejectionReason;
  final double? frontProgress;
  final double? backProgress;
  final bool frontBusy;
  final bool backBusy;
  final bool frontLocked;
  final bool backLocked;
  final VoidCallback onSelectFront;
  final VoidCallback onSelectBack;
  final VoidCallback onRemoveFront;
  final VoidCallback onRemoveBack;
  final VoidCallback onPreviewFront;
  final VoidCallback onPreviewBack;
  final String? frontLocalPreviewPath;
  final String? backLocalPreviewPath;
  final bool frontPreviewAvailable;
  final bool backPreviewAvailable;
  final VoidCallback onReportProblem;
  final Widget? vehicleAssignment;
  final Widget? expirationField;
  final Widget? documentTypeField;

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
          ?documentTypeField,
          ?vehicleAssignment,
          ?expirationField,
          const SizedBox(height: 12),
          _DocumentSideSection(
            label: 'Vorderseite',
            status: frontStatus,
            rejectionReason: frontRejectionReason,
            progress: frontProgress,
            isBusy: frontBusy,
            isLocked: frontLocked,
            onSelect: onSelectFront,
            onRemove: onRemoveFront,
            onPreview: onPreviewFront,
            localPreviewPath: frontLocalPreviewPath,
            previewAvailable: frontPreviewAvailable,
            onReportProblem: onReportProblem,
          ),
          if (backRequired) ...[
            const Divider(color: Color(0x1FFFFFFF), height: 24),
            _DocumentSideSection(
              label: 'Rückseite',
              status: backStatus,
              rejectionReason: backRejectionReason,
              progress: backProgress,
              isBusy: backBusy,
              isLocked: backLocked,
              onSelect: onSelectBack,
              onRemove: onRemoveBack,
              onPreview: onPreviewBack,
              localPreviewPath: backLocalPreviewPath,
              previewAvailable: backPreviewAvailable,
              onReportProblem: onReportProblem,
            ),
          ] else ...[
            const SizedBox(height: 12),
            const _VerificationInfoBox(
              icon: Icons.info_outline_rounded,
              text: 'Beim Reisepass ist nur die Datenseite erforderlich.',
              centerIcon: true,
            ),
          ],
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
    required this.onPreview,
    required this.localPreviewPath,
    required this.previewAvailable,
    required this.onReportProblem,
  });

  final String label;
  final ProfileVerificationDocumentStatus status;
  final String? rejectionReason;
  final double? progress;
  final bool isBusy;
  final bool isLocked;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final VoidCallback onPreview;
  final String? localPreviewPath;
  final bool previewAvailable;
  final VoidCallback onReportProblem;

  bool get _hasDocument =>
      localPreviewPath?.trim().isNotEmpty == true ||
      !const {
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
          TextButton.icon(
            onPressed: onReportProblem,
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: const Text('Problem melden'),
          ),
        ],
        if (localPreviewPath?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPreview,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: 128,
                child: Image.file(
                  File(localPreviewPath!),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: CaRismaDesignTokens.controlSurface,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: CaRismaDesignTokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (previewAvailable) ...[
          const SizedBox(height: 8),
          _OutlineAction(
            label: 'Sicher ansehen',
            icon: Icons.visibility_outlined,
            onTap: onPreview,
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
    return InputDecorator(
      key: ValueKey('dark-dropdown-$T-$value'),
      isEmpty: value == null,
      decoration: InputDecoration(
        enabled: enabled,
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: CaRismaDesignTokens.card,
          iconEnabledColor: Colors.white,
          iconDisabledColor: Colors.white.withValues(alpha: 0.45),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          hint: Text(
            hint,
            style: const TextStyle(color: CaRismaDesignTokens.textMuted),
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
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
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index == 2 || index == 4) buffer.write('.');
      buffer.write(digits[index]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
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
    final label = switch (entry.eventType) {
      'submitted' => 'Zur Prüfung eingereicht',
      'reviewed' => 'Prüfung abgeschlossen',
      'resubmissionRequested' => 'Erneute Prüfung angefordert',
      _ => switch (entry.status) {
        ProfileVerificationStatus.pending => 'Zur Prüfung eingereicht',
        ProfileVerificationStatus.verified => 'Verifiziert',
        ProfileVerificationStatus.rejected => 'Nachreichung erforderlich',
        ProfileVerificationStatus.expired => 'Nachweis abgelaufen',
        ProfileVerificationStatus.draft => 'Entwurf aktualisiert',
      },
    };
    final dateLabel = switch (entry.eventType) {
      'submitted' => 'Eingereicht am',
      'reviewed' => 'Geprüft am',
      'resubmissionRequested' => 'Angefordert am',
      _ => 'Aktualisiert am',
    };
    final groupLabel = entry.documentGroups
        .map(ProfileVerificationDocumentKeys.groupLabel)
        .join(', ');
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
                if (groupLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Nachweise: $groupLabel',
                    style: const TextStyle(
                      color: CaRismaDesignTokens.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (entry.validUntil != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Gültig bis ${_formatDate(entry.validUntil!)}',
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
          if (entry.createdAt != null)
            Flexible(
              child: Text(
                '$dateLabel\n${_formatDate(entry.createdAt!)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrivacyOverviewRow extends StatelessWidget {
  const _PrivacyOverviewRow({
    required this.icon,
    required this.title,
    required this.text,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String text;
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: CaRismaDesignTokens.textSecondary,
                    height: 1.35,
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
