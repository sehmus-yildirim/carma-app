import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/theme/carisma_design_tokens.dart';
import '../../../../shared/widgets/carisma_background.dart';
import '../../../../shared/widgets/carisma_sub_page_header.dart';

class ProfilePhotoCropScreen extends StatefulWidget {
  const ProfilePhotoCropScreen({super.key, required this.sourceFile});

  final XFile sourceFile;

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();

  double? _imageAspectRatio;
  String? _loadError;
  bool _isSaving = false;

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
      if (!mounted) return;
      setState(() => _imageAspectRatio = ratio);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Das ausgewählte Bild konnte nicht geöffnet werden.';
      });
    }
  }

  void _resetCrop() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _confirmCrop() async {
    if (_isSaving) return;
    final renderObject = _cropBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      _showError('Der Bildausschnitt konnte nicht erstellt werden.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final logicalWidth = renderObject.size.width;
      final pixelRatio = logicalWidth <= 0
          ? 3.0
          : (1080 / logicalWidth).clamp(1.0, 4.0).toDouble();
      final croppedImage = await renderObject.toImage(pixelRatio: pixelRatio);
      final pngData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      croppedImage.dispose();
      if (pngData == null) {
        throw StateError('Bilddaten fehlen.');
      }

      final outputFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'plaqa_profile_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(
        pngData.buffer.asUint8List(
          pngData.offsetInBytes,
          pngData.lengthInBytes,
        ),
        flush: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(XFile(outputFile.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(
        'Der Bildausschnitt konnte nicht gespeichert werden. Bitte versuche es erneut.',
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
              final cropSize = math.min(
                constraints.maxWidth - 32,
                constraints.maxHeight * 0.58,
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  children: [
                    CaRismaSubPageHeader(
                      icon: Icons.crop_rounded,
                      title: 'Profilbild anpassen',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 20),
                    Expanded(child: Center(child: _buildCropArea(cropSize))),
                    const SizedBox(height: 16),
                    Text(
                      'Mit zwei Fingern zoomen und das Bild verschieben.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CaRismaDesignTokens.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CropActionButton(
                            label: 'Zurücksetzen',
                            icon: Icons.restart_alt_rounded,
                            onTap: _imageAspectRatio == null || _isSaving
                                ? null
                                : _resetCrop,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CropActionButton(
                            label: 'Übernehmen',
                            icon: Icons.check_rounded,
                            isPrimary: true,
                            isLoading: _isSaving,
                            onTap: _imageAspectRatio == null || _isSaving
                                ? null
                                : _confirmCrop,
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

  Widget _buildCropArea(double cropSize) {
    final error = _loadError;
    final ratio = _imageAspectRatio;
    if (error != null) {
      return SizedBox(
        width: cropSize,
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CaRismaDesignTokens.danger,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    if (ratio == null) {
      return const SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }

    final imageWidth = ratio >= 1 ? cropSize * ratio : cropSize;
    final imageHeight = ratio >= 1 ? cropSize : cropSize / ratio;

    return SizedBox.square(
      dimension: cropSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _cropBoundaryKey,
            child: ClipRect(
              child: ColoredBox(
                color: Colors.black,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  minScale: 1,
                  maxScale: 5,
                  alignment: Alignment.center,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: SizedBox(
                    width: imageWidth,
                    height: imageHeight,
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
          IgnorePointer(
            child: CustomPaint(painter: const _CircularCropGuidePainter()),
          ),
        ],
      ),
    );
  }
}

class _CircularCropGuidePainter extends CustomPainter {
  const _CircularCropGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CropActionButton extends StatelessWidget {
  const _CropActionButton({
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
        opacity: enabled ? 1 : 0.46,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: CaRismaDesignTokens.controlSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? CaRismaDesignTokens.bluePrimary
                  : Colors.white.withValues(alpha: 0.12),
              width: isPrimary ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: Colors.white, size: 21),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
