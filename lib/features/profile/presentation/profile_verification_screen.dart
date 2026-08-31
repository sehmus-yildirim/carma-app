import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/theme/carisma_design_tokens.dart';
import '../../../shared/widgets/carisma_background.dart';
import '../../../shared/widgets/carisma_message_card.dart';
import '../../../shared/widgets/carisma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/profile_repository.dart';
import '../data/profile_vehicle.dart';
import '../data/profile_vehicle_repository.dart';
import '../data/user_profile.dart';
import '../verification_v1/data/document_services.dart';
import '../verification_v1/data/local_image_quality_service.dart';
import '../verification_v1/data/verification_document_processor.dart';
import '../verification_v1/data/verification_v1_repository.dart';
import '../verification_v1/domain/document_profiles.dart';
import '../verification_v1/domain/verification_models.dart';
import '../verification_v1/domain/verification_parsers.dart';
import '../verification_v1/domain/verification_state_machine.dart';
import '../verification_v1/presentation/document_camera_screen.dart';
import '../verification_v1/presentation/verification_v1_strings.dart';

ButtonStyle _verificationActionButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: CaRismaDesignTokens.textPrimary,
    backgroundColor: CaRismaDesignTokens.controlSurface,
    disabledForegroundColor: CaRismaDesignTokens.textMuted,
    side: BorderSide(
      color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.88),
      width: 1.4,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

class ProfileVerificationScreen extends StatefulWidget {
  const ProfileVerificationScreen({
    super.key,
    required this.userId,
    this.profileRepository,
    this.vehicleRepository,
    this.verificationV1Repository,
    this.captureService,
    this.ocrService,
    this.imageQualityService,
    this.temporaryFileService,
    Object? verificationRepository,
    Object? mediaStorage,
  });

  final String userId;
  final ProfileRepository? profileRepository;
  final ProfileVehicleRepository? vehicleRepository;
  final VerificationV1Repository? verificationV1Repository;
  final DocumentCaptureService? captureService;
  final DocumentOcrService? ocrService;
  final ImageQualityService? imageQualityService;
  final VerificationTemporaryFileService? temporaryFileService;

  @override
  State<ProfileVerificationScreen> createState() =>
      _ProfileVerificationScreenState();
}

class _ProfileVerificationScreenState extends State<ProfileVerificationScreen> {
  late final ProfileRepository _profileRepository;
  late final ProfileVehicleRepository _vehicleRepository;
  late final VerificationV1Repository _verificationRepository;
  late final DocumentOcrService _ocrService;
  late final ImageQualityService _qualityService;
  late final VerificationTemporaryFileService _temporaryFiles;
  late final VerificationDocumentProcessor _documentProcessor;
  late final bool _ownsOcrService;
  late final Stream<UserProfile?> _profileStream;
  late final Stream<List<ProfileVehicle>> _vehicleStream;

  VerificationIdentityDocumentType _documentType =
      VerificationIdentityDocumentType.idCard;
  String _identityIssuingCountryCode = 'DE';
  VerificationVehicleRelation _relation =
      VerificationVehicleRelation.registeredHolder;
  VerificationStateMachine _flowState = VerificationStateMachine();
  String? _selectedVehicleId;
  IdentityDocumentData? _identity;
  VehicleRegistrationData? _registration;
  VerificationSession? _session;
  VerificationSubmissionResult? _result;
  List<ProfileVehicle> _vehicles = const [];
  int _step = 0;
  bool _busy = false;
  bool _privacyOpened = false;
  bool _privacyAccepted = false;
  bool _declarationAccepted = false;
  String? _error;
  String? _success;
  final List<List<Offset>> _signature = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _profileRepository = widget.profileRepository ?? ProfileRepository();
    _vehicleRepository = widget.vehicleRepository ?? ProfileVehicleRepository();
    _verificationRepository =
        widget.verificationV1Repository ?? VerificationV1Repository();
    _ownsOcrService = widget.ocrService == null;
    _ocrService = widget.ocrService ?? MlKitDocumentOcrService();
    _qualityService =
        widget.imageQualityService ?? const LocalImageQualityService();
    _temporaryFiles =
        widget.temporaryFileService ?? LocalVerificationTemporaryFileService();
    _documentProcessor = VerificationDocumentProcessor(
      ocrService: _ocrService,
      qualityService: _qualityService,
      temporaryFiles: _temporaryFiles,
    );
    _profileStream = _profileRepository.watchProfile(widget.userId);
    _vehicleStream = _vehicleRepository.watchOwnerVehicles(widget.userId);
    unawaited(_temporaryFiles.cleanupOrphans());
  }

  @override
  void dispose() {
    if (_ownsOcrService) unawaited(_ocrService.close());
    unawaited(_temporaryFiles.cleanupOrphans());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        return StreamBuilder<List<ProfileVehicle>>(
          stream: _vehicleStream,
          builder: (context, vehicleSnapshot) {
            _vehicles = (vehicleSnapshot.data ?? const <ProfileVehicle>[])
                .where((vehicle) => !vehicle.isArchived)
                .toList(growable: false);
            if (_selectedVehicleId == null && _vehicles.isNotEmpty) {
              _selectedVehicleId = _vehicles.first.id;
            }
            final loading =
                profileSnapshot.connectionState == ConnectionState.waiting ||
                vehicleSnapshot.connectionState == ConnectionState.waiting;
            return Scaffold(
              body: CaRismaBackground(
                child: SafeArea(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: CaRismaSubPageHeader(
              icon: Icons.verified_user_rounded,
              title: 'Identität & Fahrzeug',
              onBack: _busy ? () {} : () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(
            children: [
              _FlowStepper(currentStep: _step),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Text(
                  VerificationV1Strings.intro,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CaRismaDesignTokens.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                CaRismaMessageCard(
                  icon: Icons.error_outline_rounded,
                  message: _error!,
                ),
              ],
              if (_success != null) ...[
                const SizedBox(height: 14),
                CaRismaMessageCard(
                  icon: Icons.check_circle_outline_rounded,
                  message: _success!,
                ),
              ],
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _buildIdentityStep(context),
                    1 => _buildVehicleStep(context),
                    2 => _buildDeclarationStep(context),
                    _ => _buildCompletionStep(context),
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityStep(BuildContext context) {
    return _StepCard(
      title: 'Identität bestätigen',
      subtitle:
          'Nur die Vorderseite beziehungsweise Datenseite wird lokal gelesen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _identityIssuingCountryCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ausstellungsland des Dokuments',
              prefixIcon: Icon(Icons.public_rounded),
            ),
            items: [
              for (final country in DocumentProfileRegistry.countries)
                DropdownMenuItem(
                  value: country.code,
                  child: Text(country.label),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null || value == _identityIssuingCountryCode) {
                      return;
                    }
                    final types = DocumentProfileRegistry.identityTypesFor(
                      value,
                    );
                    setState(() {
                      _identityIssuingCountryCode = value;
                      _documentType = types.contains(_documentType)
                          ? _documentType
                          : types.first;
                      _identity = null;
                      _session = null;
                      _flowState = VerificationStateMachine();
                      _clearMessages();
                    });
                  },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<VerificationIdentityDocumentType>(
            initialValue: _documentType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Dokumenttyp',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              for (final type in DocumentProfileRegistry.identityTypesFor(
                _identityIssuingCountryCode,
              ))
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null || value == _documentType) return;
                    setState(() {
                      _documentType = value;
                      _identity = null;
                      _session = null;
                      _flowState = VerificationStateMachine();
                      _clearMessages();
                    });
                  },
          ),
          const SizedBox(height: 14),
          if (_identity == null)
            _CameraAction(
              label: _documentType.captureLabel,
              busy: _busy,
              onPressed: _scanIdentity,
            )
          else
            _IdentitySummary(
              data: _identity!,
              busy: _busy,
              onRetake: _scanIdentity,
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: !_busy && _identity != null
                ? () => setState(() {
                    _step = 1;
                    _clearMessages();
                  })
                : null,
            style: _verificationActionButtonStyle(),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Weiter zum Fahrzeug'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStep(BuildContext context) {
    final selectedVehicle = _selectedVehicle;
    final vehicleProfile = selectedVehicle == null
        ? null
        : DocumentProfileRegistry.vehicleRegistrationProfile(
            selectedVehicle.countryCode,
          );
    return _StepCard(
      title: 'Fahrzeugbezug bestätigen',
      subtitle:
          'Fotografiere die im Dokumentprofil festgelegte Seite des Zulassungsdokuments.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_vehicles.isEmpty)
            const CaRismaMessageCard(
              icon: Icons.info_outline_rounded,
              message: 'Lege zuerst ein Fahrzeug in deinem Profil an.',
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Fahrzeug',
                prefixIcon: Icon(Icons.directions_car_rounded),
              ),
              items: [
                for (final vehicle in _vehicles)
                  DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(
                      '${vehicle.displayName} · ${vehicle.displayPlate}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _selectedVehicleId = value;
                      _registration = null;
                      _session = null;
                      _flowState = VerificationStateMachine(
                        initialState: VerificationFlowState.identityDataChecked,
                      );
                      _clearMessages();
                    }),
            ),
          const SizedBox(height: 18),
          Text(
            'Fahrzeugzuordnung',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final relation in VerificationVehicleRelation.values)
            _RelationOption(
              relation: relation,
              selected: relation == _relation,
              enabled: !_busy,
              onTap: () => setState(() {
                _relation = relation;
                _session = null;
                _declarationAccepted = false;
                _signature.clear();
                _clearMessages();
              }),
            ),
          const SizedBox(height: 12),
          if (selectedVehicle != null && vehicleProfile == null) ...[
            CaRismaMessageCard(
              icon: Icons.info_outline_rounded,
              message:
                  'Das Zulassungsdokument für ${selectedVehicle.countryCode.toUpperCase()} ist noch nicht zuverlässig unterstützt. Wir raten bei Dokumentdaten nicht.',
            ),
            const SizedBox(height: 12),
          ],
          if (_registration == null)
            _CameraAction(
              label: 'Fahrzeugschein fotografieren',
              busy: _busy,
              onPressed: _selectedVehicleId == null || vehicleProfile == null
                  ? null
                  : _scanVehicle,
            )
          else
            _VehicleSummary(
              data: _registration!,
              busy: _busy,
              onRetake: _scanVehicle,
            ),
          const SizedBox(height: 14),
          _PrivacyConfirmation(
            opened: _privacyOpened,
            accepted: _privacyAccepted,
            enabled: !_busy,
            onOpen: _openPrivacy,
            onChanged: (value) => setState(() => _privacyAccepted = value),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _step = 0;
                          _clearMessages();
                        }),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Zurück'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canSubmitDocuments ? _submitDocuments : null,
                  style: _verificationActionButtonStyle(),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(
                    _relation.requiresDeclaration
                        ? 'Zum Abgleich'
                        : 'Abgleichen',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeclarationStep(BuildContext context) {
    final identity = _identity;
    final registration = _registration;
    if (identity == null || registration == null) {
      return _StepCard(
        title: 'Abgleich unvollständig',
        subtitle: 'Bitte starte den Dokumentabgleich erneut.',
        child: OutlinedButton(
          onPressed: _restart,
          style: _verificationActionButtonStyle(),
          child: const Text('Neu starten'),
        ),
      );
    }
    final text = VerificationV1Strings.declaration(
      fullName: '${identity.firstNames} ${identity.lastName}',
      plate: registration.plate,
      relation: _relation.label,
    );
    return _StepCard(
      title: 'Eigenerklärung',
      subtitle:
          'Deine Unterschrift dokumentiert deine Erklärung. Sie ist keine amtliche Prüfung der Berechtigung.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CaRismaDesignTokens.controlSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CaRismaDesignTokens.border),
            ),
            child: SelectableText(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _declarationAccepted,
            enabled: !_busy,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(VerificationV1Strings.declarationConfirmation),
            onChanged: (value) =>
                setState(() => _declarationAccepted = value == true),
          ),
          const SizedBox(height: 8),
          _SignaturePad(
            strokes: _signature,
            enabled: !_busy,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _canFinalize ? _finalizeDeclaration : null,
            style: _verificationActionButtonStyle(),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.draw_rounded),
            label: const Text('Verbindlich bestätigen'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStep(BuildContext context) {
    final verified = _result?.status == VerificationV1Status.verified;
    return _StepCard(
      title: verified ? 'Fahrzeug verifiziert' : 'Abgleich abgeschlossen',
      subtitle:
          'Plaqa hat Dokumentdaten, Gültigkeit und Fahrzeugzuordnung abgeglichen. Dies ist keine amtliche Echtheitsprüfung.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.task_alt_rounded,
            size: 64,
            color: CaRismaDesignTokens.success,
          ),
          const SizedBox(height: 16),
          if (_result?.declarationId != null)
            Text(
              'Deine Eigenerklärung wurde privat gespeichert.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            style: _verificationActionButtonStyle(),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  bool get _canSubmitDocuments =>
      _step == 1 &&
      !_busy &&
      _identity != null &&
      _registration != null &&
      _selectedVehicleId != null &&
      _privacyOpened &&
      _privacyAccepted;

  ProfileVehicle? get _selectedVehicle {
    final id = _selectedVehicleId;
    if (id == null) return null;
    for (final vehicle in _vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  bool get _canFinalize =>
      _step == 2 &&
      !_busy &&
      _session != null &&
      _declarationAccepted &&
      _signatureIsMeaningful;

  bool get _signatureIsMeaningful {
    final points = _signature.expand((stroke) => stroke).toList();
    if (points.length < 8) return false;
    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);
    return (xs.reduce((a, b) => a > b ? a : b) -
                xs.reduce((a, b) => a < b ? a : b)) *
            (ys.reduce((a, b) => a > b ? a : b) -
                ys.reduce((a, b) => a < b ? a : b)) >=
        0.004;
  }

  Future<void> _scanIdentity() async {
    final kind = switch (_documentType) {
      VerificationIdentityDocumentType.idCard =>
        VerificationDocumentKind.identityCard,
      VerificationIdentityDocumentType.passport =>
        VerificationDocumentKind.passport,
      VerificationIdentityDocumentType.residencePermit =>
        VerificationDocumentKind.residencePermit,
    };
    final profile = DocumentProfileRegistry.identityProfile(
      countryCode: _identityIssuingCountryCode,
      documentType: _documentType,
    );
    if (profile == null) {
      setState(() {
        _error = 'Dieser Dokumenttyp ist noch nicht zuverlässig unterstützt.';
      });
      return;
    }
    final result = await _captureAndParse<IdentityDocumentData>(
      kind: kind,
      parser: ProfileDrivenIdentityDocumentParser(profile: profile).parse,
      capturingState: VerificationFlowState.capturingIdentity,
      processingState: VerificationFlowState.processingIdentity,
      successState: VerificationFlowState.identityDataChecked,
      retryState: VerificationFlowState.identityRetryRequired,
    );
    if (result != null && mounted) {
      setState(() {
        _identity = result;
        _session = null;
        _success = 'Identitätsdaten wurden lokal erkannt.';
      });
    }
  }

  Future<void> _scanVehicle() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return;
    final profile = DocumentProfileRegistry.vehicleRegistrationProfile(
      vehicle.countryCode,
    );
    if (profile == null) {
      setState(() {
        _error =
            'Dieses Fahrzeugdokument ist noch nicht zuverlässig unterstützt.';
      });
      return;
    }
    if (_flowState.state == VerificationFlowState.processingVehicle) {
      _flowState.transitionTo(VerificationFlowState.vehicleRetryRequired);
    }
    final result = await _captureAndParse<VehicleRegistrationData>(
      kind: VerificationDocumentKind.vehicleRegistration,
      parser: ProfileDrivenVehicleRegistrationParser(profile: profile).parse,
      capturingState: VerificationFlowState.capturingVehicle,
      processingState: VerificationFlowState.processingVehicle,
      successState: VerificationFlowState.processingVehicle,
      retryState: VerificationFlowState.vehicleRetryRequired,
    );
    if (result != null && mounted) {
      setState(() {
        _registration = result;
        _session = null;
        _success = 'Das Kennzeichen wurde lokal erkannt.';
      });
    }
  }

  Future<T?> _captureAndParse<T>({
    required VerificationDocumentKind kind,
    required VerificationParseResult<T> Function(List<OcrBlock>) parser,
    required VerificationFlowState capturingState,
    required VerificationFlowState processingState,
    required VerificationFlowState successState,
    required VerificationFlowState retryState,
  }) async {
    if (_busy) return null;
    setState(() {
      _clearMessages();
    });
    try {
      _flowState.transitionTo(capturingState);
      final captureService = widget.captureService;
      final capture = captureService == null
          ? await _captureDocument(kind)
          : await captureService.capture(kind);
      if (capture == null) {
        _resetFlowAfterCancelledCapture(kind);
        return null;
      }
      if (mounted) setState(() => _busy = true);
      _flowState.transitionTo(processingState);
      final processed = await _documentProcessor.process<T>(
        capture: capture,
        parser: parser,
      );
      if (successState != processingState) {
        _flowState.transitionTo(successState);
      }
      return processed.data;
    } on VerificationV1Exception catch (error) {
      if (_flowState.canTransitionTo(retryState)) {
        _flowState.transitionTo(retryState);
      }
      if (mounted) setState(() => _error = error.message);
      return null;
    } on VerificationDocumentProcessingException catch (error) {
      if (_flowState.canTransitionTo(retryState)) {
        _flowState.transitionTo(retryState);
      }
      if (mounted) setState(() => _error = error.message);
      return null;
    } catch (_) {
      if (_flowState.canTransitionTo(retryState)) {
        _flowState.transitionTo(retryState);
      }
      if (mounted) {
        setState(() {
          _error =
              'Das Dokument konnte nicht sicher gelesen werden. Bitte fotografiere es erneut.';
        });
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<CapturedVerificationDocument?> _captureDocument(
    VerificationDocumentKind kind,
  ) => CameraDocumentCaptureService(
    Navigator.of(context),
    temporaryFiles: _temporaryFiles,
  ).capture(kind);

  void _resetFlowAfterCancelledCapture(VerificationDocumentKind kind) {
    final target = kind == VerificationDocumentKind.vehicleRegistration
        ? VerificationFlowState.identityDataChecked
        : VerificationFlowState.notStarted;
    if (_flowState.canTransitionTo(target)) _flowState.transitionTo(target);
  }

  Future<void> _submitDocuments() async {
    if (!_canSubmitDocuments) return;
    setState(() {
      _busy = true;
      _clearMessages();
    });
    try {
      final session =
          _session ??
          await _verificationRepository.createSession(
            vehicleId: _selectedVehicleId!,
            relation: _relation,
          );
      _session = session;
      final result = await _verificationRepository.submitData(
        session: session,
        identity: _identity!,
        vehicleRegistration: _registration!,
      );
      final nextFlowState =
          result.status == VerificationV1Status.requiresDeclaration
          ? VerificationFlowState.awaitingDeclaration
          : VerificationFlowState.verified;
      if (_flowState.canTransitionTo(nextFlowState)) {
        _flowState.transitionTo(nextFlowState);
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = result.status == VerificationV1Status.requiresDeclaration
            ? 2
            : 3;
        _success = result.status == VerificationV1Status.requiresDeclaration
            ? 'Der Dokumentabgleich war erfolgreich. Bitte bestätige jetzt deine Nutzungsberechtigung.'
            : 'Der Dokumentabgleich wurde erfolgreich abgeschlossen.';
      });
    } on VerificationV1Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        if (error.reason == 'session-expired') _session = null;
      });
      _revealStatusMessage();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalizeDeclaration() async {
    if (!_canFinalize) return;
    setState(() {
      _busy = true;
      _clearMessages();
    });
    try {
      if (_flowState.canTransitionTo(
        VerificationFlowState.declarationSigning,
      )) {
        _flowState.transitionTo(VerificationFlowState.declarationSigning);
      }
      final result = await _verificationRepository.finalizeDeclaration(
        session: _session!,
        signatureStrokes: [
          for (final stroke in _signature)
            [
              for (final point in stroke) {'x': point.dx, 'y': point.dy},
            ],
        ],
      );
      if (_flowState.canTransitionTo(VerificationFlowState.verified)) {
        _flowState.transitionTo(VerificationFlowState.verified);
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _signature.clear();
        _step = 3;
        _success = 'Die Eigenerklärung wurde sicher erstellt.';
      });
    } on VerificationV1Exception catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        _revealStatusMessage();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _revealStatusMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openPrivacy() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  VerificationV1Strings.privacyTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                for (final item in VerificationV1Strings.privacyItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: _verificationActionButtonStyle(),
                  child: const Text('Information verstanden'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _privacyOpened = true);
  }

  void _restart() {
    setState(() {
      _step = 0;
      _identity = null;
      _registration = null;
      _session = null;
      _result = null;
      _flowState = VerificationStateMachine();
      _declarationAccepted = false;
      _signature.clear();
      _clearMessages();
    });
  }

  void _clearMessages() {
    _error = null;
    _success = null;
  }
}

class _FlowStepper extends StatelessWidget {
  const _FlowStepper({required this.currentStep});

  final int currentStep;

  static const labels = ['Identität', 'Fahrzeug', 'Erklärung', 'Abschluss'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Schritt ${currentStep + 1} von 4: ${labels[currentStep]}',
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= currentStep
                          ? CaRismaDesignTokens.blueBright
                          : CaRismaDesignTokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: index == currentStep
                          ? CaRismaDesignTokens.textPrimary
                          : CaRismaDesignTokens.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (index < labels.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt_rounded),
        label: Text(label),
      ),
    );
  }
}

class _IdentitySummary extends StatelessWidget {
  const _IdentitySummary({
    required this.data,
    required this.busy,
    required this.onRetake,
  });

  final IdentityDocumentData data;
  final bool busy;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) => _ReadOnlySummary(
    title: 'Lokal erkannt',
    rows: [
      ('Vorname(n)', data.firstNames),
      ('Nachname', data.lastName),
      ('Geburtsdatum', _formatDate(data.dateOfBirth)),
      ('Gültig bis', _formatDate(data.expiresAt)),
    ],
    busy: busy,
    onRetake: onRetake,
  );
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({
    required this.data,
    required this.busy,
    required this.onRetake,
  });

  final VehicleRegistrationData data;
  final bool busy;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) => _ReadOnlySummary(
    title: 'Lokal erkannt',
    rows: [('Kennzeichen', data.plate)],
    busy: busy,
    onRetake: onRetake,
  );
}

class _ReadOnlySummary extends StatelessWidget {
  const _ReadOnlySummary({
    required this.title,
    required this.rows,
    required this.busy,
    required this.onRetake,
  });

  final String title;
  final List<(String, String)> rows;
  final bool busy;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.controlSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CaRismaDesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: CaRismaDesignTokens.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CaRismaDesignTokens.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: busy ? null : onRetake,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Neu fotografieren'),
          ),
        ],
      ),
    );
  }
}

class _RelationOption extends StatelessWidget {
  const _RelationOption({
    required this.relation,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final VerificationVehicleRelation relation;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: relation.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected
              ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: ValueKey('verification-relation-${relation.value}'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? CaRismaDesignTokens.blueBright
                        : CaRismaDesignTokens.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      relation.label,
                      style: TextStyle(
                        color: enabled
                            ? CaRismaDesignTokens.textPrimary
                            : CaRismaDesignTokens.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyConfirmation extends StatelessWidget {
  const _PrivacyConfirmation({
    required this.opened,
    required this.accepted,
    required this.enabled,
    required this.onOpen,
    required this.onChanged,
  });

  final bool opened;
  final bool accepted;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? onOpen : null,
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('Datenschutz & Berechtigung ansehen'),
        ),
        CheckboxListTile(
          value: accepted,
          enabled: enabled && opened,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Ich habe die aktuelle Information gelesen.'),
          onChanged: (value) => onChanged(value == true),
        ),
      ],
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({
    required this.strokes,
    required this.enabled,
    required this.onChanged,
  });

  final List<List<Offset>> strokes;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mit dem Finger unterschreiben',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Unterschrift zurücksetzen',
              onPressed: !enabled || strokes.isEmpty
                  ? null
                  : () {
                      strokes.clear();
                      onChanged();
                    },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          key: const ValueKey('verification-signature-pad'),
          label: 'Unterschriftsfeld',
          hint: 'Mit dem Finger innerhalb des Feldes unterschreiben',
          child: SizedBox(
            height: 190,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: !enabled
                    ? null
                    : (details) {
                        strokes.add([
                          _normalized(
                            details.localPosition,
                            constraints.biggest,
                          ),
                        ]);
                        onChanged();
                      },
                onPanUpdate: !enabled
                    ? null
                    : (details) {
                        if (strokes.isEmpty) strokes.add([]);
                        strokes.last.add(
                          _normalized(
                            details.localPosition,
                            constraints.biggest,
                          ),
                        );
                        onChanged();
                      },
                child: CustomPaint(
                  painter: _SignaturePainter(strokes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CaRismaDesignTokens.border),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Offset _normalized(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF09264D)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

String _formatDate(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}
