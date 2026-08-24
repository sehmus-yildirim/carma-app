import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/carisma_background.dart';
import '../../../../shared/widgets/carisma_sub_page_header.dart';

class ProfileVerificationDocumentEditorScreen extends StatefulWidget {
  const ProfileVerificationDocumentEditorScreen({
    super.key,
    required this.sourceFile,
  });

  final XFile sourceFile;

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
    _loadImageSize();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.sourceFile.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final ratio = image.width / image.height;
      image.dispose();
      codec.dispose();
      if (mounted) setState(() => _sourceAspectRatio = ratio);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Der Nachweis konnte nicht geöffnet werden.';
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
    try {
      final logicalWidth = renderObject.size.width;
      final pixelRatio = logicalWidth <= 0
          ? 3.0
          : (1600 / logicalWidth).clamp(1.0, 4.0).toDouble();
      final rendered = await renderObject.toImage(pixelRatio: pixelRatio);
      final pngData = await rendered.toByteData(format: ui.ImageByteFormat.png);
      rendered.dispose();
      if (pngData == null) throw StateError('Bilddaten fehlen.');

      final output = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'plaqa_verification_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await output.writeAsBytes(
        pngData.buffer.asUint8List(
          pngData.offsetInBytes,
          pngData.lengthInBytes,
        ),
        flush: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(XFile(output.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(
        'Der Nachweis konnte nicht vorbereitet werden. Bitte versuche es erneut.',
      );
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
              final width = math.max(240.0, constraints.maxWidth - 32);
              final height = math.min(
                width * 0.72,
                constraints.maxHeight * 0.58,
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  children: [
                    CaRismaSubPageHeader(
                      icon: Icons.document_scanner_outlined,
                      title: 'Nachweis prüfen',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Center(child: _buildPreview(width, height)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Verschiebe und zoome den Nachweis. Alle Angaben müssen vollständig lesbar sein.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DocumentEditorAction(
                            label: 'Zurücksetzen',
                            icon: Icons.restart_alt_rounded,
                            onTap: _sourceAspectRatio == null || _isSaving
                                ? null
                                : _reset,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DocumentEditorAction(
                            label: 'Drehen',
                            icon: Icons.rotate_right_rounded,
                            onTap: _sourceAspectRatio == null || _isSaving
                                ? null
                                : _rotate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DocumentEditorAction(
                            label: 'Übernehmen',
                            icon: Icons.check_rounded,
                            isPrimary: true,
                            isLoading: _isSaving,
                            onTap: _sourceAspectRatio == null || _isSaving
                                ? null
                                : _confirm,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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
    final ratio = rotated ? 1 / sourceRatio : sourceRatio;
    final frameRatio = width / height;
    final imageWidth = ratio >= frameRatio ? height * ratio : width;
    final imageHeight = ratio >= frameRatio ? height : width / ratio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: RepaintBoundary(
        key: _previewBoundaryKey,
        child: SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: Colors.black,
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              alignment: Alignment.center,
              child: SizedBox(
                width: imageWidth,
                height: imageHeight,
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.file(
                    File(widget.sourceFile.path),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
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
    return GestureDetector(
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
    );
  }
}
