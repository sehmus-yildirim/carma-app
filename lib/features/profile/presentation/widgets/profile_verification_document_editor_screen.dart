import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/carisma_background.dart';
import '../../../../shared/widgets/carisma_sub_page_header.dart';
import '../../verification_v1/data/document_services.dart';
import '../../verification_v1/domain/verification_models.dart';

class ProfileVerificationDocumentEditorScreen extends StatefulWidget {
  const ProfileVerificationDocumentEditorScreen({
    super.key,
    required this.sourceFile,
    required this.kind,
  });

  final XFile sourceFile;
  final VerificationDocumentKind kind;

  @override
  State<ProfileVerificationDocumentEditorScreen> createState() =>
      _ProfileVerificationDocumentEditorScreenState();
}

class _ProfileVerificationDocumentEditorScreenState
    extends State<ProfileVerificationDocumentEditorScreen> {
  final GlobalKey _previewBoundaryKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();

  double? _sourceAspectRatio;
  int _quarterTurns = 0;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeEditor());
  }

  Future<void> _initializeEditor() async {
    if (widget.kind == VerificationDocumentKind.vehicleRegistration) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (mounted) await _loadImageSize();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    if (widget.kind == VerificationDocumentKind.vehicleRegistration) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final source = File(widget.sourceFile.path);
      final byteLength = await source.length();
      if (byteLength > verificationDocumentMaxSourceBytes) {
        throw const FormatException(
          'Das ausgewählte Bild ist zu groß. Bitte wähle ein kleineres Foto.',
        );
      }
      final bytes = await source.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      late final double ratio;
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          validateVerificationSourceImage(
            byteLength: byteLength,
            width: descriptor.width,
            height: descriptor.height,
          );
          ratio = descriptor.width / descriptor.height;
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
      if (mounted) setState(() => _sourceAspectRatio = ratio);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Das ausgewählte Bild konnte nicht geöffnet werden.';
      });
    }
  }

  void _reset() {
    _transformationController.value = Matrix4.identity();
    setState(() => _quarterTurns = 0);
  }

  void _rotate() {
    _transformationController.value = Matrix4.identity();
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  Future<void> _confirm() async {
    if (_isSaving) return;
    final renderObject = _previewBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      _showError('Der Bildausschnitt konnte nicht erstellt werden.');
      return;
    }

    setState(() => _isSaving = true);
    File? pendingOutput;
    try {
      final logicalWidth = renderObject.size.width;
      final pixelRatio = logicalWidth <= 0
          ? 3.0
          : (2400 / logicalWidth).clamp(1.0, 10.0).toDouble();
      final rendered = await renderObject.toImage(pixelRatio: pixelRatio);
      final pngData = await rendered.toByteData(format: ui.ImageByteFormat.png);
      rendered.dispose();
      if (pngData == null) throw StateError('Bilddaten fehlen.');

      final outputRoot = defaultVerificationTemporaryDirectory();
      await outputRoot.create(recursive: true);
      final output = File(
        '${outputRoot.path}${Platform.pathSeparator}'
        'plaqa_verification_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      pendingOutput = output;
      await output.writeAsBytes(
        pngData.buffer.asUint8List(
          pngData.offsetInBytes,
          pngData.lengthInBytes,
        ),
        flush: true,
      );
      if (!mounted) {
        await output.delete();
        return;
      }
      Navigator.of(context).pop(XFile(output.path));
      pendingOutput = null;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(
        'Der Nachweis konnte nicht vorbereitet werden. Bitte versuche es erneut.',
      );
    } finally {
      if (pendingOutput != null) {
        await LocalVerificationTemporaryFileService.discardCaptureSource(
          pendingOutput.path,
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return CaRismaBackground(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vehicleLandscape =
                  widget.kind == VerificationDocumentKind.vehicleRegistration &&
                  constraints.maxWidth > constraints.maxHeight;
              return vehicleLandscape
                  ? _buildLandscapeLayout(constraints)
                  : _buildPortraitLayout(constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    final ratio = _documentRatio;
    final maxWidth = math.max(1.0, constraints.maxWidth - 32);
    final maxHeight = math.max(1.0, constraints.maxHeight * 0.58);
    final width = math.min(maxWidth, maxHeight * ratio);
    final height = width / ratio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          CaRismaSubPageHeader(
            icon: Icons.document_scanner_outlined,
            title: 'Dokument ausrichten',
            onBack: _isSaving ? () {} : () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 18),
          Expanded(child: Center(child: _buildPreview(width, height))),
          const SizedBox(height: 14),
          Text(
            _instructionText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          CaRismaSubPageHeader(
            icon: Icons.document_scanner_outlined,
            title: 'Fahrzeugschein ausrichten',
            onBack: _isSaving ? () {} : () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, frameConstraints) {
                final width = math.min(
                  frameConstraints.maxWidth,
                  frameConstraints.maxHeight * _documentRatio,
                );
                final height = width / _documentRatio;
                return Center(child: _buildPreview(width, height));
              },
            ),
          ),
          const SizedBox(height: 10),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final enabled = _sourceAspectRatio != null && !_isSaving;
    return Row(
      children: [
        Expanded(
          child: _DocumentEditorAction(
            label: 'Zurücksetzen',
            icon: Icons.restart_alt_rounded,
            onTap: enabled ? _reset : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DocumentEditorAction(
            label: 'Drehen',
            icon: Icons.rotate_right_rounded,
            onTap: enabled ? _rotate : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DocumentEditorAction(
            label: 'Übernehmen',
            icon: Icons.check_rounded,
            isPrimary: true,
            isLoading: _isSaving,
            onTap: enabled ? _confirm : null,
          ),
        ),
      ],
    );
  }

  double get _documentRatio => switch (widget.kind) {
    VerificationDocumentKind.passport => 1.42,
    VerificationDocumentKind.vehicleRegistration => 210 / 106,
    VerificationDocumentKind.identityCard ||
    VerificationDocumentKind.residencePermit => 1.586,
  };

  String get _instructionText =>
      widget.kind == VerificationDocumentKind.vehicleRegistration
      ? 'Verschiebe, zoome oder drehe das Bild. Der Fahrzeugschein wird im Querformat übernommen.'
      : 'Verschiebe, zoome oder drehe das Bild, bis alle Angaben vollständig im Rahmen liegen.';

  Widget _buildPreview(double width, double height) {
    final error = _loadError;
    final sourceRatio = _sourceAspectRatio;
    if (error != null) {
      return Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CaRismaDesignTokens.danger,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    if (sourceRatio == null) {
      return const SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }

    final rotated = _quarterTurns.isOdd;
    final visibleRatio = rotated ? 1 / sourceRatio : sourceRatio;
    final frameRatio = width / height;
    final imageWidth = visibleRatio >= frameRatio
        ? width
        : height * visibleRatio;
    final imageHeight = imageWidth / visibleRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: RepaintBoundary(
        key: _previewBoundaryKey,
        child: SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: CaRismaDesignTokens.controlSurface,
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              minScale: 0.5,
              maxScale: 5,
              boundaryMargin: EdgeInsets.all(math.max(width, height)),
              panEnabled: true,
              scaleEnabled: true,
              trackpadScrollCausesScale: true,
              scaleFactor: 120,
              alignment: Alignment.center,
              child: SizedBox(
                width: width,
                height: height,
                child: Center(
                  child: SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: SizedBox(
                        width: rotated ? imageHeight : imageWidth,
                        height: rotated ? imageWidth : imageHeight,
                        child: Image.file(
                          File(widget.sourceFile.path),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentEditorAction extends StatelessWidget {
  const _DocumentEditorAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: CaRismaDesignTokens.controlSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary
                    ? CaRismaDesignTokens.bluePrimary
                    : CaRismaDesignTokens.textPrimary.withValues(alpha: 0.12),
                width: isPrimary ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: CaRismaDesignTokens.textPrimary, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CaRismaDesignTokens.textPrimary,
                    fontWeight: FontWeight.w800,
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
