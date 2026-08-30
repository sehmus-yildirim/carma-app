import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../data/document_services.dart';
import '../domain/verification_models.dart';

class CameraDocumentCaptureService implements DocumentCaptureService {
  CameraDocumentCaptureService(
    this.navigator, {
    VerificationTemporaryFileService? temporaryFiles,
  }) : _temporaryFiles =
           temporaryFiles ?? LocalVerificationTemporaryFileService();

  final NavigatorState navigator;
  final VerificationTemporaryFileService _temporaryFiles;

  @override
  Future<CapturedVerificationDocument?> capture(
    VerificationDocumentKind kind,
  ) async {
    final path = await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) =>
            DocumentCameraScreen(kind: kind, temporaryFiles: _temporaryFiles),
        fullscreenDialog: true,
      ),
    );
    return path == null
        ? null
        : CapturedVerificationDocument(
            path: path,
            kind: kind,
            deleteSourceAfterAdoption: false,
            isManagedTemporaryFile: true,
          );
  }
}

class DocumentCameraScreen extends StatefulWidget {
  const DocumentCameraScreen({
    super.key,
    required this.kind,
    this.temporaryFiles,
  });

  final VerificationDocumentKind kind;
  final VerificationTemporaryFileService? temporaryFiles;

  @override
  State<DocumentCameraScreen> createState() => _DocumentCameraScreenState();
}

class _DocumentCameraScreenState extends State<DocumentCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  late final VerificationTemporaryFileService _temporaryFiles;
  String? _capturedPath;
  String? _error;
  bool _initializing = true;
  bool _capturing = false;
  bool _accepted = false;
  bool _flashEnabled = false;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _temporaryFiles =
        widget.temporaryFiles ?? LocalVerificationTemporaryFileService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeScreen());
  }

  Future<void> _initializeScreen() async {
    if (widget.kind == VerificationDocumentKind.vehicleRegistration) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (mounted) await _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeController());
    } else if (state == AppLifecycleState.resumed &&
        _capturedPath == null &&
        _controller == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'CameraNotAvailable',
          'Auf diesem Gerät ist keine Kamera verfügbar.',
        );
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = switch (error.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            'Der Kamerazugriff wurde verweigert. Erlaube ihn bitte in den Systemeinstellungen.',
          'CameraAccessRestricted' =>
            'Der Kamerazugriff ist auf diesem Gerät eingeschränkt.',
          _ =>
            'Die Kamera ist gerade nicht verfügbar. Bitte versuche es erneut.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error =
            'Die Kamera ist gerade nicht verfügbar. Bitte versuche es erneut.';
      });
    }
  }

  Future<void> _setFocus(Offset local, Size size) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
      if (mounted) setState(() => _focusPoint = local);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) setState(() => _focusPoint = null);
    } on CameraException {
      // Some fixed-focus cameras do not expose focus/exposure points.
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_flashEnabled;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashEnabled = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Der Blitz ist nicht verfügbar.')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _capturing) {
      return;
    }
    setState(() => _capturing = true);
    String? newCapturePath;
    try {
      final file = await controller.takePicture();
      newCapturePath = file.path;
      final managedPath = await _temporaryFiles.adopt(newCapturePath);
      newCapturePath = null;
      _capturedPath = managedPath;
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        // The completed capture remains usable when only flash reset fails.
      }
      if (!mounted) {
        _capturedPath = null;
        await _temporaryFiles.delete(managedPath);
        return;
      }
      setState(() {
        _flashEnabled = false;
        _capturing = false;
      });
      await _disposeController();
    } catch (_) {
      final path = newCapturePath ?? _capturedPath;
      _capturedPath = null;
      if (path != null) {
        await _temporaryFiles.delete(path);
        await _deleteFile(path);
      }
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error =
            'Das Foto konnte nicht aufgenommen werden. Bitte versuche es erneut.';
      });
    }
  }

  Future<void> _retake() async {
    final path = _capturedPath;
    setState(() {
      _capturedPath = null;
      _error = null;
    });
    if (path != null) await _temporaryFiles.delete(path);
    await _initializeCamera();
  }

  void _usePhoto() {
    final path = _capturedPath;
    if (path == null) return;
    _accepted = true;
    Navigator.of(context).pop(path);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeController());
    if (widget.kind == VerificationDocumentKind.vehicleRegistration) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    if (!_accepted && _capturedPath != null) {
      unawaited(_temporaryFiles.delete(_capturedPath!));
    }
    super.dispose();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = _capturedPath;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _CameraHeader(
              title: _title,
              flashEnabled: _flashEnabled,
              showFlash: previewPath == null && _controller != null,
              onClose: () => Navigator.of(context).maybePop(),
              onFlash: _toggleFlash,
            ),
            Expanded(
              child: previewPath != null
                  ? _buildCapturedPreview(previewPath)
                  : _buildLivePreview(),
            ),
            if (previewPath != null)
              _PreviewActions(onRetake: _retake, onUse: _usePhoto)
            else
              _CaptureFooter(
                busy: _capturing,
                enabled: _controller?.value.isInitialized == true,
                onCapture: _takePicture,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CameraError(message: _error!, onRetry: _initializeCamera);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _CameraError(
        message: 'Die Kamera ist nicht verfügbar.',
        onRetry: _initializeCamera,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _setFocus(details.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? size.width,
                    height: controller.value.previewSize?.width ?? size.height,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
              _DocumentOverlay(kind: widget.kind),
              if (_focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 22,
                  top: _focusPoint!.dy - 22,
                  child: const _FocusIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCapturedPreview(String path) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true),
        IgnorePointer(
          child: _DocumentOverlay(kind: widget.kind, preview: true),
        ),
      ],
    );
  }

  String get _title => switch (widget.kind) {
    VerificationDocumentKind.passport => 'Reisepass · Datenseite',
    VerificationDocumentKind.vehicleRegistration =>
      'Zulassungsbescheinigung Teil I',
    VerificationDocumentKind.identityCard => 'Personalausweis · Vorderseite',
    VerificationDocumentKind.residencePermit =>
      'Aufenthaltstitel · Vorderseite',
  };

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Startup cleanup performs another best-effort pass.
    }
  }
}

class _CameraHeader extends StatelessWidget {
  const _CameraHeader({
    required this.title,
    required this.flashEnabled,
    required this.showFlash,
    required this.onClose,
    required this.onFlash,
  });

  final String title;
  final bool flashEnabled;
  final bool showFlash;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kamera schließen',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showFlash)
            IconButton(
              tooltip: flashEnabled ? 'Blitz ausschalten' : 'Blitz einschalten',
              onPressed: onFlash,
              icon: Icon(
                flashEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _DocumentOverlay extends StatelessWidget {
  const _DocumentOverlay({required this.kind, this.preview = false});

  final VerificationDocumentKind kind;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final ratio = kind == VerificationDocumentKind.passport ? 1.42 : 1.58;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(
          math.max(1.0, constraints.maxWidth - 32),
          kind == VerificationDocumentKind.vehicleRegistration ? 760.0 : 640.0,
        );
        final maxHeight = math.max(1.0, constraints.maxHeight - 28);
        final width = math.min(maxWidth, maxHeight * ratio);
        final height = width / ratio;
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: preview ? 0.18 : 0.48),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                  Center(
                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            if (!preview)
              const Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Text(
                  'Dokument vollständig innerhalb des Rahmens platzieren',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white, width: 1.5),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

class _CaptureFooter extends StatelessWidget {
  const _CaptureFooter({
    required this.busy,
    required this.enabled,
    required this.onCapture,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Center(
        child: Semantics(
          button: true,
          label: 'Foto aufnehmen',
          child: IconButton.filled(
            tooltip: 'Foto aufnehmen',
            onPressed: enabled && !busy ? onCapture : null,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(76),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white38,
            ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Icon(Icons.camera_alt_rounded, size: 32),
          ),
        ),
      ),
    );
  }
}

class _PreviewActions extends StatelessWidget {
  const _PreviewActions({required this.onRetake, required this.onUse});

  final VoidCallback onRetake;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: _PreviewActionButton(
              onPressed: onRetake,
              icon: const Icon(Icons.refresh_rounded),
              label: 'Neu aufnehmen',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PreviewActionButton(
              onPressed: onUse,
              icon: const Icon(Icons.check_rounded),
              label: 'Foto verwenden',
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: isPrimary
            ? CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        side: BorderSide(
          color: isPrimary
              ? CaRismaDesignTokens.bluePrimary
              : Colors.white.withValues(alpha: 0.24),
          width: isPrimary ? 1.6 : 1,
        ),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme.merge(data: const IconThemeData(size: 20), child: icon),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Erneut versuchen'),
            ),
            TextButton(
              onPressed: Geolocator.openAppSettings,
              child: const Text('Systemeinstellungen öffnen'),
            ),
          ],
        ),
      ),
    );
  }
}
