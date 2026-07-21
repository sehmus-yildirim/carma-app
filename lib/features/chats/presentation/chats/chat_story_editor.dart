part of '../chats_screen.dart';

const int _storyTextMaxLength = 280;
const int _storyCustomStatusMaxLength = 32;
const String _storyCustomStatusOption = '__custom_status__';

Widget? _hideStoryInputCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  return null;
}

class _StoryDraft {
  const _StoryDraft({
    required this.mediaPath,
    required this.isVideo,
    required this.videoIsMuted,
    required this.text,
    required this.textColor,
    required this.textFontFamily,
    required this.textIsBold,
    required this.textIsItalic,
    required this.textIsUnderline,
    required this.textAlign,
    required this.textAlignment,
    required this.filterType,
    required this.sticker,
  });

  final String mediaPath;
  final bool isVideo;
  final bool videoIsMuted;
  final String text;
  final Color textColor;
  final String textFontFamily;
  final bool textIsBold;
  final bool textIsItalic;
  final bool textIsUnderline;
  final String textAlign;
  final Alignment textAlignment;
  final String filterType;
  final _StoryStickerDraft sticker;
}

class _StoryCaptureResult {
  const _StoryCaptureResult({required this.path, required this.isVideo});

  final String path;
  final bool isVideo;
}

class _StoryStickerDraft {
  const _StoryStickerDraft({
    required this.type,
    required this.label,
    required this.payload,
    required this.alignment,
  });

  const _StoryStickerDraft.empty()
    : type = '',
      label = '',
      payload = '',
      alignment = const Alignment(0, 0.52);

  final String type;
  final String label;
  final String payload;
  final Alignment alignment;

  bool get isEmpty {
    return type.trim().isEmpty || label.trim().isEmpty;
  }
}

class _StoryVehicleStickerData {
  const _StoryVehicleStickerData({
    required this.vehicleLabel,
    required this.plateLabel,
  });

  final String vehicleLabel;
  final String plateLabel;

  bool get isComplete {
    return vehicleLabel.trim().isNotEmpty || plateLabel.trim().isNotEmpty;
  }
}

class _StoryVehicleStickerOption {
  const _StoryVehicleStickerOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sticker,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _StoryStickerDraft sticker;
}

String _vehicleStickerPayload({
  required String style,
  required String plateLabel,
}) {
  final safeStyle = style.trim().isEmpty ? 'card' : style.trim();
  final safePlate = plateLabel.trim();

  return '$safeStyle|$safePlate';
}

String _vehicleStickerStyleFromPayload(String payload) {
  final trimmedPayload = payload.trim();
  final separatorIndex = trimmedPayload.indexOf('|');

  if (separatorIndex < 0) {
    return 'card';
  }

  final style = trimmedPayload.substring(0, separatorIndex).trim();

  return style.isEmpty ? 'card' : style;
}

String _vehicleStickerDetailFromPayload(String payload) {
  final trimmedPayload = payload.trim();
  final separatorIndex = trimmedPayload.indexOf('|');

  if (separatorIndex < 0) {
    return trimmedPayload;
  }

  return trimmedPayload.substring(separatorIndex + 1).trim();
}

IconData _storyStatusStickerIcon(String label) {
  return switch (label.trim()) {
    'Unterwegs' => Icons.route_rounded,
    'Parke hier' => Icons.local_parking_rounded,
    'Kurze Frage' => Icons.help_rounded,
    'Treffen offen' => Icons.event_available_rounded,
    'Nicht stören' => Icons.do_disturb_on_rounded,
    'Auto gesehen' => Icons.visibility_rounded,
    'Bin am Auto' => Icons.car_repair_rounded,
    _ => Icons.bolt_rounded,
  };
}

class _StoryFilterOption {
  const _StoryFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _StoryCaptureScreen extends StatefulWidget {
  const _StoryCaptureScreen({required this.imagePicker});

  final ImagePicker imagePicker;

  @override
  State<_StoryCaptureScreen> createState() => _StoryCaptureScreenState();
}

class _StoryCaptureScreenState extends State<_StoryCaptureScreen> {
  static const Duration _maxStoryVideoDuration = Duration(seconds: 30);
  static const Duration _videoRecordHoldDelay = Duration(milliseconds: 280);

  final List<CameraDescription> _cameras = <CameraDescription>[];
  CameraController? _cameraController;
  Timer? _recordingTimer;
  Timer? _captureHoldTimer;

  bool _isInitializingCamera = true;
  bool _isCapturing = false;
  bool _isStartingVideoRecording = false;
  bool _isRecordingVideo = false;
  bool _isStoppingVideoRecording = false;
  bool _shouldStopRecordingWhenReady = false;
  bool _isCapturePointerDown = false;
  bool _hasCaptureHoldStartedVideo = false;
  String? _cameraError;
  Duration _recordingDuration = Duration.zero;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _captureHoldTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      if (_cameras.isEmpty) {
        _cameras.addAll(await availableCameras());
      }

      if (_cameras.isEmpty) {
        throw StateError('Keine Kamera gefunden.');
      }

      final preferredIndex = cameraIndex ?? _preferredBackCameraIndex();
      _cameraIndex = preferredIndex.clamp(0, _cameras.length - 1);
      final oldController = _cameraController;
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await oldController?.dispose();
      await controller.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingCamera = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializingCamera = false;
        _cameraError = 'Kamera konnte nicht gestartet werden.';
      });
    }
  }

  int _preferredBackCameraIndex() {
    final backIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    return backIndex < 0 ? 0 : backIndex;
  }

  Future<void> _pickFromGallery() async {
    if (_isCapturing ||
        _isRecordingVideo ||
        _isStartingVideoRecording ||
        _isStoppingVideoRecording) {
      return;
    }

    final pickVideo = await _showGalleryMediaPicker();

    if (!mounted || pickVideo == null) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final media = pickVideo
          ? await widget.imagePicker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 30),
            )
          : await widget.imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 86,
            );

      if (!mounted || media == null) {
        return;
      }

      Navigator.of(
        context,
      ).pop(_StoryCaptureResult(path: media.path, isVideo: pickVideo));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story-Medium konnte nicht geladen werden: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<bool?> _showGalleryMediaPicker() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: CaRismaDesignTokens.card,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Aufnahmen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StoryMediaPickerTile(
                        icon: Icons.photo_library_rounded,
                        title: 'Foto auswählen',
                        subtitle: 'Bild aus deiner Galerie verwenden',
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(height: 10),
                      _StoryMediaPickerTile(
                        icon: Icons.video_library_rounded,
                        title: 'Video auswählen',
                        subtitle: 'Video bis 30 Sekunden verwenden',
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    final controller = _cameraController;

    if (_isCapturing ||
        _isRecordingVideo ||
        _isStartingVideoRecording ||
        _isStoppingVideoRecording ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await controller.takePicture();

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(_StoryCaptureResult(path: image.path, isVideo: false));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto konnte nicht aufgenommen werden: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _isCapturing ||
        _isInitializingCamera ||
        _isRecordingVideo ||
        _isStartingVideoRecording ||
        _isStoppingVideoRecording) {
      return;
    }

    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera(cameraIndex: nextIndex);
  }

  void _handleCapturePointerDown() {
    if (_isCapturing ||
        _isRecordingVideo ||
        _isStartingVideoRecording ||
        _isStoppingVideoRecording) {
      return;
    }

    _captureHoldTimer?.cancel();
    _isCapturePointerDown = true;
    _hasCaptureHoldStartedVideo = false;
    _captureHoldTimer = Timer(_videoRecordHoldDelay, () {
      if (!_isCapturePointerDown || _hasCaptureHoldStartedVideo || !mounted) {
        return;
      }

      _hasCaptureHoldStartedVideo = true;
      unawaited(_handleLongPressStart());
    });
  }

  void _handleCapturePointerUp({required bool takePhotoOnShortPress}) {
    if (!_isCapturePointerDown && !_hasCaptureHoldStartedVideo) {
      return;
    }

    _isCapturePointerDown = false;
    _captureHoldTimer?.cancel();
    _captureHoldTimer = null;

    if (_hasCaptureHoldStartedVideo ||
        _isStartingVideoRecording ||
        _isRecordingVideo) {
      _requestStopVideoRecording();
      return;
    }

    if (takePhotoOnShortPress) {
      unawaited(_takePhoto());
    }
  }

  Future<void> _handleLongPressStart() async {
    final controller = _cameraController;

    if (_isCapturing ||
        _isStartingVideoRecording ||
        _isRecordingVideo ||
        _isStoppingVideoRecording ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo) {
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      _isStartingVideoRecording = true;
      _shouldStopRecordingWhenReady = false;
      await controller.startVideoRecording();

      if (!mounted) {
        _isStartingVideoRecording = false;
        return;
      }

      _isStartingVideoRecording = false;
      setState(() {
        _isRecordingVideo = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecordingVideo) {
          return;
        }

        final nextDuration = _recordingDuration + const Duration(seconds: 1);
        setState(() {
          _recordingDuration = nextDuration;
        });

        if (nextDuration >= _maxStoryVideoDuration) {
          _requestStopVideoRecording();
        }
      });

      if (_shouldStopRecordingWhenReady) {
        _requestStopVideoRecording();
      }
    } catch (error) {
      _isStartingVideoRecording = false;
      _shouldStopRecordingWhenReady = false;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video konnte nicht gestartet werden: $error')),
      );
    }
  }

  void _requestStopVideoRecording() {
    if (_isStoppingVideoRecording) {
      return;
    }

    if (_isStartingVideoRecording) {
      _shouldStopRecordingWhenReady = true;
      return;
    }

    if (_isRecordingVideo) {
      _handleLongPressEnd();
    }
  }

  Future<void> _handleLongPressEnd() async {
    final controller = _cameraController;

    if (_isStartingVideoRecording) {
      _shouldStopRecordingWhenReady = true;
      return;
    }

    if (_isStoppingVideoRecording ||
        !_isRecordingVideo ||
        controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isRecordingVideo) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _isRecordingVideo = false;
      _isStoppingVideoRecording = true;
    });
    _shouldStopRecordingWhenReady = false;
    _recordingTimer?.cancel();

    try {
      final video = await controller.stopVideoRecording();

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(_StoryCaptureResult(path: video.path, isVideo: true));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video konnte nicht gespeichert werden: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isRecordingVideo = false;
          _isStoppingVideoRecording = false;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  String _formatRecordingDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);
    final controller = _cameraController;
    final previewSize = controller?.value.previewSize;
    final isCameraReady =
        controller != null &&
        previewSize != null &&
        controller.value.isInitialized &&
        !_isInitializingCamera;
    final isCaptureBusy =
        _isCapturing ||
        _isStartingVideoRecording ||
        _isRecordingVideo ||
        _isStoppingVideoRecording;
    final canPickMedia = !isCaptureBusy;
    final canSwitchCamera =
        isCameraReady && _cameras.length > 1 && !isCaptureBusy;
    final recordingProgress =
        (_recordingDuration.inMilliseconds /
                _maxStoryVideoDuration.inMilliseconds)
            .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: CaRismaDesignTokens.background,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => _requestStopVideoRecording(),
        onPointerCancel: (_) => _requestStopVideoRecording(),
        child: Stack(
          children: [
            Positioned.fill(
              child: isCameraReady
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewSize.height,
                        height: previewSize.width,
                        child: CameraPreview(controller),
                      ),
                    )
                  : _StoryCameraPlaceholder(
                      isLoading: _isInitializingCamera,
                      message: _cameraError,
                      onRetry: () => _initializeCamera(),
                    ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CaRismaDesignTokens.backgroundTop.withValues(
                          alpha: 0.56,
                        ),
                        Colors.transparent,
                        CaRismaDesignTokens.background.withValues(alpha: 0.68),
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: viewPadding.top + 10,
              child: _StoryEditorHeaderButton(
                icon: Icons.close_rounded,
                tooltip: 'Abbrechen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (_isRecordingVideo)
              Positioned(
                left: 0,
                right: 0,
                top: viewPadding.top + 86,
                child: Center(
                  child: _StoryRecordingIndicator(
                    durationLabel: _formatRecordingDuration(_recordingDuration),
                  ),
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: viewPadding.bottom + 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _StoryCaptureSideAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Aufnahmen',
                    enabled: canPickMedia,
                    onTap: _pickFromGallery,
                  ),
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _handleCapturePointerDown(),
                    onPointerUp: (_) =>
                        _handleCapturePointerUp(takePhotoOnShortPress: true),
                    onPointerCancel: (_) =>
                        _handleCapturePointerUp(takePhotoOnShortPress: false),
                    child: _StoryCaptureButton(
                      isBusy: _isCapturing,
                      isRecording: _isRecordingVideo,
                      recordingProgress: recordingProgress,
                    ),
                  ),
                  _StoryCaptureSideAction(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Kamera wechseln',
                    enabled: canSwitchCamera,
                    onTap: _switchCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCameraPlaceholder extends StatelessWidget {
  const _StoryCameraPlaceholder({
    required this.isLoading,
    required this.message,
    required this.onRetry,
  });

  final bool isLoading;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: CaRismaDesignTokens.screenGradient,
      ),
      child: Center(
        child: isLoading
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.surface2.withValues(alpha: 0.78),
                  border: Border.all(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.10,
                    ),
                  ),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    CaRismaDesignTokens.radiusCard,
                  ),
                  color: CaRismaDesignTokens.surface1.withValues(alpha: 0.88),
                  border: Border.all(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      color: Colors.white,
                      tooltip: message ?? 'Kamera erneut starten',
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message ?? 'Kamera konnte nicht gestartet werden.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CaRismaDesignTokens.textSecondary,
                          fontWeight: FontWeight.w800,
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

class _StoryMediaPickerTile extends StatelessWidget {
  const _StoryMediaPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.controlSurface,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CaRismaDesignTokens.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CaRismaDesignTokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: CaRismaDesignTokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryRecordingIndicator extends StatelessWidget {
  const _StoryRecordingIndicator({required this.durationLabel});

  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: CaRismaDesignTokens.surface1.withValues(alpha: 0.86),
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.danger,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                durationLabel,
                style: const TextStyle(
                  color: CaRismaDesignTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryFilterNamePill extends StatelessWidget {
  const _StoryFilterNamePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CaRismaDesignTokens.surface1.withValues(alpha: 0.88),
                CaRismaDesignTokens.blueDark.withValues(alpha: 0.54),
              ],
            ),
            border: Border.all(
              color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryVideoLengthWarning extends StatelessWidget {
  const _StoryVideoLengthWarning();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: CaRismaDesignTokens.danger.withValues(alpha: 0.18),
              border: Border.all(
                color: CaRismaDesignTokens.danger.withValues(alpha: 0.46),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.content_cut_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Video ist länger als 30 Sekunden',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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

class _StoryCaptureButton extends StatelessWidget {
  const _StoryCaptureButton({
    required this.isBusy,
    required this.isRecording,
    required this.recordingProgress,
  });

  final bool isBusy;
  final bool isRecording;
  final double recordingProgress;

  @override
  Widget build(BuildContext context) {
    final progress = recordingProgress.clamp(0.0, 1.0);

    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CaRismaDesignTokens.textPrimary.withValues(alpha: 0.92),
                width: 3.5,
              ),
              color: isBusy || isRecording
                  ? CaRismaDesignTokens.textPrimary.withValues(alpha: 0.18)
                  : Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color:
                      (isRecording ? CaRismaDesignTokens.danger : Colors.white)
                          .withValues(alpha: 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isRecording
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          CaRismaDesignTokens.danger,
                          CaRismaDesignTokens.danger.withValues(alpha: 0.78),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          CaRismaDesignTokens.controlSurface,
                          CaRismaDesignTokens.controlSurface,
                        ],
                      ),
              ),
              child: isBusy
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: CaRismaDesignTokens.textPrimary,
                        ),
                      ),
                    )
                  : Icon(
                      isRecording
                          ? Icons.stop_rounded
                          : Icons.camera_alt_rounded,
                      color: CaRismaDesignTokens.textPrimary,
                      size: isRecording ? 34 : 28,
                    ),
            ),
          ),
          if (isRecording)
            SizedBox(
              width: 86,
              height: 86,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: CaRismaDesignTokens.textPrimary.withValues(
                  alpha: 0.16,
                ),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  CaRismaDesignTokens.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryCaptureSideAction extends StatelessWidget {
  const _StoryCaptureSideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.42;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Icon(
                icon,
                color:
                    (enabled
                            ? CaRismaDesignTokens.textPrimary
                            : CaRismaDesignTokens.textMuted)
                        .withValues(alpha: opacity),
                size: 30,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.78),
                    blurRadius: 12,
                  ),
                  if (enabled)
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.22),
                      blurRadius: 16,
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

class _StoryDeleteDropTarget extends StatelessWidget {
  const _StoryDeleteDropTarget({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: isActive ? 1.08 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(18, 11, 20, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: (isActive ? const Color(0xFFFF315A) : Colors.black)
                  .withValues(alpha: isActive ? 0.72 : 0.44),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFFFA0B0).withValues(alpha: 0.74)
                    : Colors.white.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? const Color(0xFFFF315A) : Colors.black)
                      .withValues(alpha: isActive ? 0.34 : 0.24),
                  blurRadius: isActive ? 26 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? Icons.delete_forever_rounded
                      : Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Loslassen zum Löschen' : 'Zum Löschen hierher',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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

class _StoryDraftEditorScreen extends StatefulWidget {
  const _StoryDraftEditorScreen({
    required this.mediaPath,
    required this.isVideo,
    this.vehicleStickerData,
  });

  final String mediaPath;
  final bool isVideo;
  final _StoryVehicleStickerData? vehicleStickerData;

  @override
  State<_StoryDraftEditorScreen> createState() =>
      _StoryDraftEditorScreenState();
}

class _StoryDraftEditorScreenState extends State<_StoryDraftEditorScreen> {
  final GlobalKey _storyPreviewKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  VideoPlayerController? _draftVideoController;

  Color _textColor = Colors.white;
  bool _isBold = true;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isTextEditingEnabled = false;
  bool _isVideoMuted = false;
  String _fontFamily = 'standard';
  TextAlign _textAlign = TextAlign.center;
  Alignment _textAlignment = const Alignment(0, -0.20);
  String _filterType = 'normal';
  _StoryStickerDraft _sticker = const _StoryStickerDraft.empty();
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _isVideoTooLong = false;
  bool _isDraggingText = false;
  bool _isDraggingSticker = false;
  bool _isDeleteTargetActive = false;

  static const Duration _maxDraftVideoDuration = Duration(seconds: 30);

  static const List<Color> _storyTextColors = [
    Colors.white,
    Color(0xFFFFF8B5),
    Color(0xFFFFD54F),
    Color(0xFFFF9A3D),
    Color(0xFFFF5C5C),
    Color(0xFFFF4F9A),
    Color(0xFFE879F9),
    Color(0xFFC084FC),
    Color(0xFF7C3AED),
    Color(0xFF3B82F6),
    Color(0xFF38BDF8),
    Color(0xFF22D3EE),
    Color(0xFF2DD4BF),
    Color(0xFF4ADE80),
    Color(0xFFA3E635),
    Color(0xFFE5E7EB),
    Color(0xFF111827),
    Colors.black,
  ];

  static const List<_StoryFilterOption> _storyFilterOptions = [
    _StoryFilterOption(value: 'normal', label: 'Original'),
    _StoryFilterOption(value: 'warm', label: 'Warm'),
    _StoryFilterOption(value: 'cool', label: 'Kühl'),
    _StoryFilterOption(value: 'mono', label: 'Mono'),
    _StoryFilterOption(value: 'soft', label: 'Soft'),
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
    if (widget.isVideo) {
      _initializeDraftVideo();
    }
  }

  @override
  void dispose() {
    _draftVideoController?.dispose();
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeDraftVideo() async {
    final controller = VideoPlayerController.file(File(widget.mediaPath));
    _draftVideoController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isVideoMuted ? 0 : 1);
      await controller.play();

      if (mounted) {
        setState(() {
          _isVideoTooLong = controller.value.duration > _maxDraftVideoDuration;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  String? get _effectiveFontFamily {
    return switch (_fontFamily) {
      'serif' => 'serif',
      'mono' => 'monospace',
      'rounded' => 'sans-serif-medium',
      'condensed' => 'sans-serif-condensed',
      'light' => 'sans-serif-light',
      'medium' => 'sans-serif-medium',
      'black' => 'sans-serif-black',
      'casual' => 'casual',
      'cursive' => 'cursive',
      _ => null,
    };
  }

  bool get _hasDraftChanges {
    return _textController.text.trim().isNotEmpty ||
        !_sticker.isEmpty ||
        _filterType != 'normal';
  }

  Future<bool> _confirmDiscardDraft() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _StoryDiscardDialog(
          backgroundColor: const Color(0xFF101827),
          title: const Text(
            'Story verwerfen?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Deine Bearbeitung wird nicht gespeichert.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Weiter bearbeiten'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Verwerfen'),
            ),
          ],
        );
      },
    );

    return shouldDiscard == true;
  }

  Future<void> _closeEditor() async {
    FocusScope.of(context).unfocus();

    if (_isSaving || _isPublishing) {
      return;
    }

    if (_hasDraftChanges && !await _confirmDiscardDraft()) {
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _moveText(DragUpdateDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final nextX = (_textAlignment.x + (details.delta.dx / size.width) * 2)
        .clamp(-0.88, 0.88);
    final nextY = (_textAlignment.y + (details.delta.dy / size.height) * 2)
        .clamp(-0.72, 0.72);

    setState(() {
      _textAlignment = Alignment(nextX.toDouble(), nextY.toDouble());
      _isDeleteTargetActive = nextY > 0.60;
    });
  }

  void _startTextDrag() {
    if (_textController.text.trim().isEmpty || _isTextEditingEnabled) {
      return;
    }

    setState(() {
      _isDraggingText = true;
      _isDeleteTargetActive = false;
    });
  }

  void _finishTextDrag() {
    if (!_isDraggingText) {
      return;
    }

    setState(() {
      if (_isDeleteTargetActive) {
        _textController.clear();
        _isTextEditingEnabled = false;
      }

      _isDraggingText = false;
      _isDeleteTargetActive = false;
    });
  }

  void _moveSticker(DragUpdateDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0 || _sticker.isEmpty) {
      return;
    }

    final nextX = (_sticker.alignment.x + (details.delta.dx / size.width) * 2)
        .clamp(-0.86, 0.86);
    final nextY = (_sticker.alignment.y + (details.delta.dy / size.height) * 2)
        .clamp(-0.72, 0.82);

    setState(() {
      _sticker = _StoryStickerDraft(
        type: _sticker.type,
        label: _sticker.label,
        payload: _sticker.payload,
        alignment: Alignment(nextX.toDouble(), nextY.toDouble()),
      );
      _isDeleteTargetActive = nextY > 0.60;
    });
  }

  void _startStickerDrag() {
    if (_sticker.isEmpty) {
      return;
    }

    setState(() {
      _isDraggingSticker = true;
      _isDeleteTargetActive = false;
    });
  }

  void _finishStickerDrag() {
    if (!_isDraggingSticker) {
      return;
    }

    setState(() {
      if (_isDeleteTargetActive) {
        _sticker = const _StoryStickerDraft.empty();
      }

      _isDraggingSticker = false;
      _isDeleteTargetActive = false;
    });
  }

  void _keepTextInputFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isTextEditingEnabled) {
        _textFocusNode.requestFocus();
      }
    });
  }

  Alignment _visibleTextAlignmentForEditing(BuildContext context) {
    if (!_isTextEditingEnabled) {
      return _textAlignment;
    }

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    if (screenHeight <= 0) {
      return _textAlignment;
    }

    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final safeTop = mediaQuery.padding.top + 104;
    final styleBarHeight = keyboardHeight > 0 ? 120.0 : 108.0;
    final safeBottom =
        (keyboardHeight > 0 ? keyboardHeight : mediaQuery.padding.bottom) +
        styleBarHeight;

    final minY = ((safeTop / screenHeight) * 2 - 1).clamp(-0.82, 0.40);
    final maxY = (((screenHeight - safeBottom) / screenHeight) * 2 - 1).clamp(
      minY + 0.08,
      0.72,
    );

    return Alignment(
      _textAlignment.x.clamp(-0.88, 0.88).toDouble(),
      _textAlignment.y.clamp(minY, maxY).toDouble(),
    );
  }

  void _activateTextEditing() {
    final isNewText = _textController.text.trim().isEmpty;

    setState(() {
      _isTextEditingEnabled = true;
      if (isNewText) {
        _textAlignment = const Alignment(0, -0.20);
      }
    });
    _keepTextInputFocused();
  }

  void _finishTextEditing() {
    _textFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final trimmedText = _textController.text.trim();
    if (trimmedText.isEmpty) {
      _textController.clear();
    } else if (_textController.text != trimmedText) {
      _textController.text = trimmedText;
      _textController.selection = TextSelection.collapsed(
        offset: trimmedText.length,
      );
    }

    setState(() {
      _isTextEditingEnabled = false;
    });
  }

  Future<void> _toggleVideoMuted() async {
    if (!widget.isVideo) {
      return;
    }

    final nextValue = !_isVideoMuted;
    setState(() {
      _isVideoMuted = nextValue;
    });

    await _draftVideoController?.setVolume(nextValue ? 0 : 1);
  }

  Future<void> _addLocationSticker() async {
    final sticker = await _buildLocationSticker(context);

    if (sticker == null || !mounted) {
      return;
    }

    setState(() {
      _sticker = sticker;
    });
  }

  Future<void> _addVehicleSticker() async {
    final vehicleStickerData = widget.vehicleStickerData;

    if (vehicleStickerData == null || !vehicleStickerData.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fahrzeugdaten fehlen noch. Ergänze sie zuerst im Profil.',
          ),
        ),
      );
      return;
    }

    final sticker = await _showVehicleStickerPicker(
      context: context,
      vehicleStickerData: vehicleStickerData,
    );

    if (sticker == null || !mounted) {
      return;
    }

    setState(() {
      _sticker = sticker;
    });
  }

  Future<void> _addStatusSticker() async {
    var status = await _showStatusStickerPicker(context);

    if (status == null || !mounted) {
      return;
    }

    if (status == _storyCustomStatusOption) {
      await Future<void>.delayed(const Duration(milliseconds: 120));

      if (!mounted) {
        return;
      }

      status = await _showCustomStatusInput(context);

      if (status == null || !mounted) {
        return;
      }
    }

    final effectiveStatus = status;

    setState(() {
      _sticker = _StoryStickerDraft(
        type: 'status',
        label: effectiveStatus,
        payload: effectiveStatus,
        alignment: const Alignment(0, 0.52),
      );
    });
  }

  void _changeFilterBySwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 260) {
      return;
    }

    final currentIndex = _storyFilterOptions.indexWhere(
      (filter) => filter.value == _filterType,
    );
    final safeCurrentIndex = currentIndex < 0 ? 0 : currentIndex;
    final direction = velocity < 0 ? 1 : -1;
    final nextIndex =
        (safeCurrentIndex + direction) % _storyFilterOptions.length;
    final normalizedIndex = nextIndex < 0
        ? _storyFilterOptions.length - 1
        : nextIndex;

    setState(() {
      _filterType = _storyFilterOptions[normalizedIndex].value;
    });
  }

  String get _selectedFilterLabel {
    return _storyFilterOptions
        .firstWhere(
          (filter) => filter.value == _filterType,
          orElse: () => _storyFilterOptions.first,
        )
        .label;
  }

  Future<_StoryStickerDraft?> _buildLocationSticker(
    BuildContext context,
  ) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Standortzugriff wurde abgelehnt.')),
          );
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      final places = await ChatNativeBridge()
          .reverseGeocodeLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          )
          .catchError((_) => const <ResolvedLocationPlace>[]);
      final selectedPlace = context.mounted
          ? await _showLocationPlacePicker(context: context, places: places)
          : null;

      if (selectedPlace == null) {
        return null;
      }

      final label = selectedPlace.label.trim();

      if (label.isEmpty) {
        return null;
      }

      return _StoryStickerDraft(
        type: 'location',
        label: label,
        payload:
            '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}',
        alignment: const Alignment(0, 0.52),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Standort konnte nicht geladen werden: $error'),
          ),
        );
      }
      return null;
    }
  }

  Future<ResolvedLocationPlace?> _showLocationPlacePicker({
    required BuildContext context,
    required List<ResolvedLocationPlace> places,
  }) async {
    final options = _buildLocationPickerOptions(places: places);

    if (options.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kein passender Standort gefunden.')),
        );
      }

      return null;
    }

    if (options.length == 1) {
      return options.first;
    }

    final initialChildSize = (0.50 + (options.length * 0.055))
        .clamp(0.58, 0.88)
        .toDouble();
    final minChildSize = (initialChildSize - 0.18).clamp(0.42, 0.72).toDouble();

    return showModalBottomSheet<ResolvedLocationPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: CaRismaDesignTokens.card,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Scrollbar(
                        controller: scrollController,
                        thumbVisibility: options.length > 4,
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 6),
                          children: [
                            Center(
                              child: Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Standort auswählen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wähle, wie dein Ort in der Story erscheinen soll.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (var index = 0; index < options.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == options.length - 1 ? 0 : 8,
                                ),
                                child: _StoryLocationPlaceTile(
                                  place: options[index],
                                  onTap: () =>
                                      Navigator.of(context).pop(options[index]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<ResolvedLocationPlace> _buildLocationPickerOptions({
    required List<ResolvedLocationPlace> places,
  }) {
    final options = <ResolvedLocationPlace>[];
    final seenLabels = <String>{};

    String normalizeKey(String label) {
      return label.trim().toLowerCase().replaceAll(RegExp(r'[\s,.-]+'), ' ');
    }

    bool isUsefulLabel(String label) {
      final trimmedLabel = label.trim();

      if (trimmedLabel.length < 3) {
        return false;
      }

      if (RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(trimmedLabel)) {
        return false;
      }

      if (RegExp(r'^\d+[a-zA-Z]?\b').hasMatch(trimmedLabel)) {
        return false;
      }

      if (RegExp(
        r'\b(stra(?:ß|ss)e|str\.?|weg|allee|platz|ring|damm|ufer|chaussee|stieg|kamp|hof|barg|berg)\b',
        caseSensitive: false,
      ).hasMatch(trimmedLabel)) {
        return false;
      }

      if (trimmedLabel.split(',').length > 2) {
        return false;
      }

      return true;
    }

    void addOption({
      required String label,
      required String city,
      required String region,
      required String country,
    }) {
      final trimmedLabel = label.trim();
      if (!isUsefulLabel(trimmedLabel)) {
        return;
      }

      final key = normalizeKey(trimmedLabel);
      if (!seenLabels.add(key)) {
        return;
      }

      options.add(
        ResolvedLocationPlace(
          label: trimmedLabel,
          city: city.trim(),
          region: region.trim(),
          country: country.trim(),
        ),
      );
    }

    for (final place in places.take(8)) {
      addOption(
        label: place.city,
        city: place.city,
        region: place.region,
        country: place.country,
      );

      addOption(
        label: [
          place.city,
          if (place.region.trim().toLowerCase() !=
              place.city.trim().toLowerCase())
            place.region,
        ].where((value) => value.trim().isNotEmpty).join(', '),
        city: place.city,
        region: place.region,
        country: place.country,
      );

      addOption(
        label: [
          place.city,
          if (place.country.trim().toLowerCase() !=
              place.city.trim().toLowerCase())
            place.country,
        ].where((value) => value.trim().isNotEmpty).join(', '),
        city: place.city,
        region: place.region,
        country: place.country,
      );

      addOption(
        label: place.label,
        city: place.city,
        region: place.region,
        country: place.country,
      );
    }

    if (options.length <= 8) {
      return options;
    }

    return options.take(8).toList();
  }

  Future<_StoryStickerDraft?> _showVehicleStickerPicker({
    required BuildContext context,
    required _StoryVehicleStickerData vehicleStickerData,
  }) async {
    final vehicleLabel = vehicleStickerData.vehicleLabel.trim().isEmpty
        ? 'Fahrzeug'
        : vehicleStickerData.vehicleLabel.trim();
    final plateLabel = vehicleStickerData.plateLabel.trim();
    final visiblePlateLabel = plateLabel.isEmpty ? 'Kennzeichen' : plateLabel;
    final options = <_StoryVehicleStickerOption>[
      _StoryVehicleStickerOption(
        title: 'Fahrzeugkarte',
        subtitle: '$vehicleLabel - $visiblePlateLabel',
        icon: Icons.directions_car_filled_rounded,
        sticker: _StoryStickerDraft(
          type: 'vehicle',
          label: vehicleLabel,
          payload: _vehicleStickerPayload(
            style: 'card',
            plateLabel: plateLabel,
          ),
          alignment: const Alignment(0, 0.52),
        ),
      ),
      _StoryVehicleStickerOption(
        title: 'Kennzeichen',
        subtitle: visiblePlateLabel,
        icon: Icons.pin_rounded,
        sticker: _StoryStickerDraft(
          type: 'vehicle',
          label: visiblePlateLabel,
          payload: _vehicleStickerPayload(
            style: 'plate',
            plateLabel: plateLabel,
          ),
          alignment: const Alignment(0, 0.52),
        ),
      ),
      _StoryVehicleStickerOption(
        title: 'Kompakt',
        subtitle: '$vehicleLabel - $visiblePlateLabel',
        icon: Icons.local_offer_rounded,
        sticker: _StoryStickerDraft(
          type: 'vehicle',
          label: vehicleLabel,
          payload: _vehicleStickerPayload(
            style: 'compact',
            plateLabel: plateLabel,
          ),
          alignment: const Alignment(0, 0.52),
        ),
      ),
      _StoryVehicleStickerOption(
        title: 'CaRisma Badge',
        subtitle: '$vehicleLabel - $visiblePlateLabel',
        icon: Icons.verified_rounded,
        sticker: _StoryStickerDraft(
          type: 'vehicle',
          label: vehicleLabel,
          payload: _vehicleStickerPayload(
            style: 'badge',
            plateLabel: plateLabel,
          ),
          alignment: const Alignment(0, 0.52),
        ),
      ),
    ];

    return showModalBottomSheet<_StoryStickerDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: CaRismaDesignTokens.card,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Fahrzeug-Sticker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Wähle eine Darstellung für deine Story.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var index = 0; index < options.length; index++) ...[
                        if (index > 0) const SizedBox(height: 10),
                        _StoryVehicleStickerChoice(
                          option: options[index],
                          onTap: () =>
                              Navigator.of(context).pop(options[index].sticker),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showStatusStickerPicker(BuildContext context) async {
    const statusOptions = <String>[
      'Unterwegs',
      'Parke hier',
      'Kurze Frage',
      'Treffen offen',
      'Nicht stören',
      'Auto gesehen',
    ];
    final visibleStatusOptions = <String>[
      for (final status in statusOptions)
        if (status != 'Kurze Frage' && !status.startsWith('Nicht ')) status,
      'Bin am Auto',
    ];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: CaRismaDesignTokens.card,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Status auswählen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final status in visibleStatusOptions)
                            _StoryStatusChoiceChip(
                              label: status,
                              onTap: () => Navigator.of(context).pop(status),
                            ),
                          _StoryStatusChoiceChip(
                            label: 'Eigener Status',
                            onTap: () => Navigator.of(
                              context,
                            ).pop(_storyCustomStatusOption),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showCustomStatusInput(BuildContext context) async {
    final controller = TextEditingController();

    try {
      final value = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.58),
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18),
            child: _StoryTextInputDialog(
              icon: Icons.bolt_rounded,
              title: const Text(
                'Eigener Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: _storyCustomStatusMaxLength,
                textInputAction: TextInputAction.done,
                buildCounter: _hideStoryInputCounter,
                onSubmitted: (text) {
                  final trimmed = text.trim();

                  if (trimmed.isNotEmpty) {
                    Navigator.of(dialogContext).pop(trimmed);
                  }
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  hintText: 'z. B. Gleich wieder da',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Abbrechen',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();

                    if (trimmed.isNotEmpty) {
                      Navigator.of(dialogContext).pop(trimmed);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _carismaBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Hinzufügen',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        },
      );

      final trimmedValue = value?.trim() ?? '';
      return trimmedValue.isEmpty ? null : trimmedValue;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _saveDraftImage() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isVideo) {
        await ChatNativeBridge().saveVideoToGallery(
          url: widget.mediaPath,
          fileName:
              'carisma_story_${DateTime.now().millisecondsSinceEpoch}.mp4',
          contentType: 'video/mp4',
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story-Video wurde gespeichert.')),
        );
        return;
      }

      final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.0);

      FocusScope.of(context).unfocus();
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _storyPreviewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw StateError('Story-Vorschau konnte nicht gerendert werden.');
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null || bytes.isEmpty) {
        throw StateError('Story-Bild konnte nicht erstellt werden.');
      }

      final tempDirectory = await Directory.systemTemp.createTemp(
        'carisma_story_',
      );
      final fileName =
          'carisma_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final renderedFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}$fileName',
      );
      await renderedFile.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      await ChatNativeBridge().saveImageToGallery(
        url: renderedFile.path,
        fileName: fileName,
        contentType: 'image/png',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story-Bild wurde gespeichert.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _publish() {
    if (_isSaving || _isPublishing) {
      return;
    }

    if (widget.isVideo && _isVideoTooLong) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story-Videos dürfen maximal 30 Sekunden lang sein.'),
        ),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      _StoryDraft(
        mediaPath: widget.mediaPath,
        isVideo: widget.isVideo,
        videoIsMuted: _isVideoMuted,
        text: _textController.text.trim(),
        textColor: _textColor,
        textFontFamily: _fontFamily,
        textIsBold: _isBold,
        textIsItalic: _isItalic,
        textIsUnderline: _isUnderline,
        textAlign: _storyTextAlignName(_textAlign),
        textAlignment: _textAlignment,
        filterType: _filterType,
        sticker: _sticker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final canPublish = !_isPublishing && !_isVideoTooLong;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: _changeFilterBySwipe,
              child: RepaintBoundary(
                key: _storyPreviewKey,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: widget.isVideo
                          ? _StoryDraftVideoPreview(
                              controller: _draftVideoController,
                              filterType: _filterType,
                            )
                          : _StoryFilteredImage(
                              image: FileImage(File(widget.mediaPath)),
                              filterType: _filterType,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
                                );
                              },
                            ),
                    ),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          final hasText = _textController.text
                              .trim()
                              .isNotEmpty;

                          if ((!_isTextEditingEnabled && !hasText) ||
                              ((_isSaving || _isPublishing) && !hasText)) {
                            return const SizedBox.shrink();
                          }

                          final textAlignment = _visibleTextAlignmentForEditing(
                            context,
                          );

                          return Align(
                            alignment: textAlignment,
                            child: GestureDetector(
                              onTap: hasText && !_isTextEditingEnabled
                                  ? _activateTextEditing
                                  : null,
                              onPanStart: (_) => _startTextDrag(),
                              onPanUpdate: (details) =>
                                  _moveText(details, size),
                              onPanEnd: (_) => _finishTextDrag(),
                              onPanCancel: _finishTextDrag,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.82,
                                ),
                                child: AbsorbPointer(
                                  absorbing: !_isTextEditingEnabled,
                                  child: _isTextEditingEnabled
                                      ? TextField(
                                          controller: _textController,
                                          focusNode: _textFocusNode,
                                          textAlign: _textAlign,
                                          maxLength: _storyTextMaxLength,
                                          maxLines: 4,
                                          minLines: 1,
                                          cursorColor: _textColor,
                                          readOnly: !_isTextEditingEnabled,
                                          enableInteractiveSelection:
                                              _isTextEditingEnabled,
                                          textInputAction: TextInputAction.done,
                                          onTapOutside: (_) =>
                                              _keepTextInputFocused(),
                                          onEditingComplete: _finishTextEditing,
                                          onSubmitted: (_) =>
                                              _finishTextEditing(),
                                          onChanged: (_) => setState(() {}),
                                          buildCounter: _hideStoryInputCounter,
                                          style: TextStyle(
                                            color: _textColor,
                                            fontSize: 30,
                                            height: 1.08,
                                            fontWeight: _isBold
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            fontStyle: _isItalic
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            fontFamily: _effectiveFontFamily,
                                            decoration: _isUnderline
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                            decorationColor: _textColor,
                                            decorationThickness: 2,
                                            shadows: const [
                                              Shadow(
                                                blurRadius: 12,
                                                color: Colors.black87,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          decoration: InputDecoration(
                                            isCollapsed: true,
                                            contentPadding: EdgeInsets.zero,
                                            hintText: 'Text hinzufügen',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.62,
                                              ),
                                              fontWeight: FontWeight.w800,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            focusedErrorBorder:
                                                InputBorder.none,
                                            filled: false,
                                          ),
                                        )
                                      : Text(
                                          _textController.text.trim(),
                                          textAlign: _textAlign,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _textColor,
                                            fontSize: 30,
                                            height: 1.08,
                                            fontWeight: _isBold
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            fontStyle: _isItalic
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            fontFamily: _effectiveFontFamily,
                                            decoration: _isUnderline
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                            decorationColor: _textColor,
                                            decorationThickness: 2,
                                            shadows: const [
                                              Shadow(
                                                blurRadius: 12,
                                                color: Colors.black87,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!_sticker.isEmpty)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );

                            return Align(
                              alignment: _sticker.alignment,
                              child: GestureDetector(
                                onPanStart: (_) => _startStickerDrag(),
                                onPanUpdate: (details) =>
                                    _moveSticker(details, size),
                                onPanEnd: (_) => _finishStickerDrag(),
                                onPanCancel: _finishStickerDrag,
                                child: _StoryStickerChip(
                                  type: _sticker.type,
                                  label: _sticker.label,
                                  payload: _sticker.payload,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_filterType != 'normal' && !_isSaving && !_isPublishing)
            Positioned(
              left: 0,
              right: 0,
              bottom: viewPadding.bottom + 152,
              child: Center(
                child: _StoryFilterNamePill(label: _selectedFilterLabel),
              ),
            ),
          if (_isVideoTooLong && !_isSaving && !_isPublishing)
            Positioned(
              left: 16,
              right: 16,
              bottom: viewPadding.bottom + 124,
              child: const _StoryVideoLengthWarning(),
            ),
          if ((_isDraggingText || _isDraggingSticker) &&
              !_isSaving &&
              !_isPublishing)
            Positioned(
              left: 0,
              right: 0,
              bottom: viewPadding.bottom + 28,
              child: Center(
                child: _StoryDeleteDropTarget(isActive: _isDeleteTargetActive),
              ),
            ),
          if (!_isSaving)
            Positioned(
              left: 14,
              right: 14,
              top: viewPadding.top + 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isPublishing)
                    _StoryEditorHeaderButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Abbrechen',
                      onPressed: _closeEditor,
                    )
                  else
                    const SizedBox(width: 60, height: 60),
                  const Spacer(),
                  _StoryEditorPublishButton(
                    isEnabled: canPublish,
                    isBusy: _isPublishing,
                    onPressed: _publish,
                  ),
                ],
              ),
            ),
          if (!_isSaving && !_isPublishing && !_isTextEditingEnabled)
            Positioned(
              right: 14,
              top: viewPadding.top + 96,
              child: _StoryEditorActionRail(
                isSaving: _isSaving,
                isVideo: widget.isVideo,
                videoIsMuted: _isVideoMuted,
                hasTextTool:
                    _isTextEditingEnabled ||
                    _textController.text.trim().isNotEmpty,
                stickerType: _sticker.type,
                onAddText: _activateTextEditing,
                onAddVehicle: _addVehicleSticker,
                onAddLocation: _addLocationSticker,
                onAddStatus: _addStatusSticker,
                onToggleVideoMuted: _toggleVideoMuted,
                onSave: _saveDraftImage,
              ),
            ),
          if (!_isSaving && !_isPublishing && _isTextEditingEnabled)
            Positioned(
              left: 14,
              right: 14,
              bottom:
                  (viewInsets.bottom > 0
                      ? viewInsets.bottom
                      : viewPadding.bottom) +
                  14,
              child: _StoryTextStyleBar(
                isBold: _isBold,
                isItalic: _isItalic,
                isUnderline: _isUnderline,
                fontFamily: _fontFamily,
                textAlign: _textAlign,
                textColor: _textColor,
                colors: _storyTextColors,
                onDone: _finishTextEditing,
                onToggleBold: () {
                  setState(() => _isBold = !_isBold);
                  _keepTextInputFocused();
                },
                onToggleItalic: () {
                  setState(() => _isItalic = !_isItalic);
                  _keepTextInputFocused();
                },
                onToggleUnderline: () {
                  setState(() => _isUnderline = !_isUnderline);
                  _keepTextInputFocused();
                },
                onTextAlignChanged: (value) {
                  setState(() {
                    _textAlign = value;
                  });
                  _keepTextInputFocused();
                },
                onFontChanged: (value) {
                  setState(() {
                    _fontFamily = value;
                  });
                  _keepTextInputFocused();
                },
                onColorChanged: (value) {
                  setState(() {
                    _textColor = value;
                  });
                  _keepTextInputFocused();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryEditorHeaderButton extends StatelessWidget {
  const _StoryEditorHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: _StoryGlassActionCircle(
                size: 52,
                child: Icon(
                  icon,
                  color: CaRismaDesignTokens.textPrimary,
                  size: 29,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryEditorPublishButton extends StatelessWidget {
  const _StoryEditorPublishButton({
    required this.isEnabled,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Story teilen',
      child: Semantics(
        button: true,
        enabled: isEnabled && !isBusy,
        label: 'Story teilen',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled && !isBusy ? onPressed : null,
          child: SizedBox(
            width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StoryGlassActionCircle(
                  size: 54,
                  isActive: isEnabled,
                  child: isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: isEnabled
                              ? CaRismaDesignTokens.textPrimary
                              : CaRismaDesignTokens.textMuted,
                          size: 26,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Teilen',
                  maxLines: 1,
                  style: TextStyle(
                    color: isEnabled
                        ? CaRismaDesignTokens.textPrimary
                        : CaRismaDesignTokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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

class _StoryGlassActionCircle extends StatelessWidget {
  const _StoryGlassActionCircle({
    required this.size,
    required this.child,
    this.isActive = false,
  });

  final double size;
  final Widget child;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(
          color: Colors.white.withValues(alpha: isActive ? 0.82 : 0.42),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          if (isActive)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.18),
              blurRadius: 18,
            ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _StoryDiscardDialog extends StatelessWidget {
  const _StoryDiscardDialog({
    Color? backgroundColor,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: CaRismaDesignTokens.card,
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _carismaBlue.withValues(alpha: 0.18),
                        border: Border.all(
                          color: _carismaBlueLight.withValues(alpha: 0.24),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Story verwerfen?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Deine Bearbeitung wird nicht gespeichert.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Weiter bearbeiten',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _carismaBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Verwerfen',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryTextInputDialog extends StatelessWidget {
  const _StoryTextInputDialog({
    this.icon = Icons.edit_rounded,
    this.title,
    this.content,
    this.actions,
  });

  final IconData icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(14, 0, 14, keyboardInset + 14),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: CaRismaDesignTokens.card,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.13),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.36),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CaRismaDesignTokens.controlSurface,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: title ?? const SizedBox.shrink()),
                      ],
                    ),
                    if (content != null) ...[
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: CaRismaDesignTokens.controlSurface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.46),
                              fontWeight: FontWeight.w700,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        child: content!,
                      ),
                    ],
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!
                            .map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: action,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryEditorActionRail extends StatelessWidget {
  const _StoryEditorActionRail({
    required this.isSaving,
    required this.isVideo,
    required this.videoIsMuted,
    required this.hasTextTool,
    required this.stickerType,
    required this.onAddText,
    required this.onAddVehicle,
    required this.onAddLocation,
    required this.onAddStatus,
    required this.onToggleVideoMuted,
    required this.onSave,
  });

  final bool isSaving;
  final bool isVideo;
  final bool videoIsMuted;
  final bool hasTextTool;
  final String stickerType;
  final VoidCallback onAddText;
  final VoidCallback onAddVehicle;
  final VoidCallback onAddLocation;
  final VoidCallback onAddStatus;
  final VoidCallback onToggleVideoMuted;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final selectedStickerType = stickerType.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).top -
            128,
      ),
      child: SizedBox(
        width: 72,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StoryRailButton(
                icon: Icons.text_fields_rounded,
                label: 'Text',
                isSelected: hasTextTool,
                onTap: onAddText,
              ),
              const SizedBox(height: 8),
              _StoryRailButton(
                icon: Icons.directions_car_filled_rounded,
                label: 'Fahrzeug',
                isSelected: selectedStickerType == 'vehicle',
                onTap: onAddVehicle,
              ),
              const SizedBox(height: 8),
              _StoryRailButton(
                icon: Icons.location_on_rounded,
                label: 'Standort',
                isSelected: selectedStickerType == 'location',
                onTap: onAddLocation,
              ),
              const SizedBox(height: 8),
              _StoryRailButton(
                icon: Icons.auto_awesome_rounded,
                label: 'Status',
                isSelected: selectedStickerType == 'status',
                onTap: onAddStatus,
              ),
              if (isVideo) ...[
                const SizedBox(height: 8),
                _StoryRailButton(
                  icon: videoIsMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: videoIsMuted ? 'Stumm' : 'Audio',
                  isSelected: videoIsMuted,
                  onTap: onToggleVideoMuted,
                ),
              ],
              const SizedBox(height: 8),
              _StoryRailButton(
                icon: Icons.download_rounded,
                label: 'Sichern',
                isBusy: isSaving,
                onTap: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryRailButton extends StatelessWidget {
  const _StoryRailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.isBusy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: !isBusy,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isBusy ? null : onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StoryGlassActionCircle(
                size: 52,
                isActive: isSelected,
                child: Center(
                  child: isBusy
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CaRismaDesignTokens.textPrimary.withValues(
                      alpha: isSelected ? 1 : 0.94,
                    ),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
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

TextAlign _nextStoryTextAlign(TextAlign value) {
  return switch (value) {
    TextAlign.left => TextAlign.center,
    TextAlign.center => TextAlign.right,
    _ => TextAlign.left,
  };
}

String _storyTextAlignName(TextAlign value) {
  return switch (value) {
    TextAlign.left => 'left',
    TextAlign.right => 'right',
    _ => 'center',
  };
}

IconData _storyTextAlignIcon(TextAlign value) {
  return switch (value) {
    TextAlign.left => Icons.format_align_left_rounded,
    TextAlign.right => Icons.format_align_right_rounded,
    _ => Icons.format_align_center_rounded,
  };
}

class _StoryTextStyleBar extends StatelessWidget {
  const _StoryTextStyleBar({
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.fontFamily,
    required this.textAlign,
    required this.textColor,
    required this.colors,
    required this.onDone,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onTextAlignChanged,
    required this.onFontChanged,
    required this.onColorChanged,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String fontFamily;
  final TextAlign textAlign;
  final Color textColor;
  final List<Color> colors;
  final VoidCallback onDone;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final ValueChanged<TextAlign> onTextAlignChanged;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: CaRismaDesignTokens.card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              final swatchSize = isCompact ? 28.0 : 30.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StoryToolButton(
                                icon: Icons.format_bold_rounded,
                                isSelected: isBold,
                                onTap: onToggleBold,
                              ),
                              const SizedBox(width: 4),
                              _StoryToolButton(
                                icon: Icons.format_italic_rounded,
                                isSelected: isItalic,
                                onTap: onToggleItalic,
                              ),
                              const SizedBox(width: 4),
                              _StoryToolButton(
                                icon: Icons.format_underlined_rounded,
                                isSelected: isUnderline,
                                onTap: onToggleUnderline,
                              ),
                              const SizedBox(width: 4),
                              _StoryToolButton(
                                icon: _storyTextAlignIcon(textAlign),
                                isSelected: textAlign != TextAlign.center,
                                onTap: () => onTextAlignChanged(
                                  _nextStoryTextAlign(textAlign),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StoryDoneToolButton(onTap: onDone),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: isCompact ? 126 : 148,
                        child: _StoryFontSelector(
                          selectedValue: fontFamily,
                          onChanged: onFontChanged,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: swatchSize,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: colors.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(width: isCompact ? 4 : 5),
                            itemBuilder: (context, index) {
                              final color = colors[index];
                              final isSelected =
                                  color.toARGB32() == textColor.toARGB32();

                              return GestureDetector(
                                onTap: () => onColorChanged(color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: swatchSize,
                                  height: swatchSize,
                                  padding: EdgeInsets.all(isSelected ? 3 : 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : Colors.white.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: isSelected
                                          ? _carismaBlueLight
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: _carismaBlueLight
                                                  .withValues(alpha: 0.24),
                                              blurRadius: 16,
                                              offset: const Offset(0, 7),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color,
                                      border: Border.all(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoryLocationPlaceTile extends StatelessWidget {
  const _StoryLocationPlaceTile({required this.place, required this.onTap});

  final ResolvedLocationPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      place.city,
      place.region,
      place.country,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.controlSurface,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: CaRismaDesignTokens.bluePrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.46),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryStatusChoiceChip extends StatelessWidget {
  const _StoryStatusChoiceChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.controlSurface,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  _storyStatusStickerIcon(label),
                  color: CaRismaDesignTokens.bluePrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
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
      ),
    );
  }
}

class _StoryVehicleStickerChoice extends StatelessWidget {
  const _StoryVehicleStickerChoice({required this.option, required this.onTap});

  final _StoryVehicleStickerOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.controlSurface,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  option.icon,
                  color: CaRismaDesignTokens.bluePrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.48),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryStickerChip extends StatelessWidget {
  const _StoryStickerChip({
    required this.type,
    required this.label,
    this.payload = '',
  });

  final String type;
  final String label;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final vehicleStyle = type == 'vehicle'
        ? _vehicleStickerStyleFromPayload(payload)
        : '';
    final vehicleDetail = type == 'vehicle'
        ? _vehicleStickerDetailFromPayload(payload)
        : '';
    final isPlateSticker = type == 'vehicle' && vehicleStyle == 'plate';
    final isCompactSticker = type == 'vehicle' && vehicleStyle == 'compact';
    final isBadgeSticker = type == 'vehicle' && vehicleStyle == 'badge';
    final isLocationSticker = type == 'location';
    final isStatusSticker = type == 'status';
    final icon = switch (type) {
      'vehicle' => Icons.directions_car_filled_rounded,
      'location' => Icons.location_on_rounded,
      'status' => _storyStatusStickerIcon(label),
      _ => Icons.add_reaction_rounded,
    };
    final subtitle = switch (type) {
      'vehicle' =>
        isPlateSticker || isCompactSticker || isBadgeSticker
            ? ''
            : vehicleDetail,
      'status' => '',
      _ => '',
    };
    final isExpandedSticker = subtitle.isNotEmpty;
    final effectiveLabel = isPlateSticker && vehicleDetail.isNotEmpty
        ? vehicleDetail
        : label;
    final borderRadius = isPlateSticker
        ? 14.0
        : isStatusSticker
        ? 24.0
        : isExpandedSticker
        ? 22.0
        : 999.0;
    final maxWidth = isStatusSticker
        ? 286.0
        : isExpandedSticker
        ? 310.0
        : 270.0;
    final foregroundColor = isPlateSticker
        ? const Color(0xFF08111F)
        : Colors.white;
    final secondaryColor = isPlateSticker
        ? const Color(0xFF20304A).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.72);
    final iconColor = isPlateSticker ? Colors.white : Colors.white;
    final iconBackground = isPlateSticker
        ? const Color(0xFF08111F)
        : isBadgeSticker
        ? const Color(0xFF2A7DFF)
        : isStatusSticker
        ? const Color(0xFF00A3FF)
        : _carismaBlue.withValues(alpha: 0.92);
    final gradientColors = isPlateSticker
        ? <Color>[
            Colors.white.withValues(alpha: 0.96),
            const Color(0xFFDDEBFF).withValues(alpha: 0.92),
          ]
        : isBadgeSticker
        ? <Color>[
            const Color(0xFF064F8F).withValues(alpha: 0.9),
            const Color(0xFF0B1A2D).withValues(alpha: 0.86),
          ]
        : isStatusSticker
        ? <Color>[
            const Color(0xFF073A63).withValues(alpha: 0.92),
            const Color(0xFF0A1628).withValues(alpha: 0.88),
          ]
        : <Color>[
            const Color(0xFF101827).withValues(alpha: 0.84),
            _carismaBlueDark.withValues(alpha: 0.74),
          ];

    if (isCompactSticker) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFF08111F).withValues(alpha: 0.72),
              border: Border.all(
                color: _carismaBlueLight.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  color: Colors.black.withValues(alpha: 0.26),
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_car_filled_rounded,
                  color: _carismaBlueLight,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    [
                      label,
                      if (vehicleDetail.isNotEmpty) vehicleDetail,
                    ].join('  |  '),
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

    if (isBadgeSticker) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [CaRismaDesignTokens.bluePrimary, Color(0xFF061628)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  color: _carismaBlue.withValues(alpha: 0.24),
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CaRisma',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        vehicleDetail.isEmpty
                            ? label
                            : '$label - $vehicleDetail',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isLocationSticker) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 286),
            padding: const EdgeInsets.fromLTRB(13, 10, 14, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B1B2F).withValues(alpha: 0.88),
                  const Color(0xFF0F766E).withValues(alpha: 0.78),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF5EEAD4).withValues(alpha: 0.24),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.18),
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isStatusSticker) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 270),
            padding: const EdgeInsets.fromLTRB(12, 8, 15, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.94),
                  const Color(0xFF061628).withValues(alpha: 0.86),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  color: _carismaBlue.withValues(alpha: 0.24),
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    _storyStatusStickerIcon(label),
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: EdgeInsets.fromLTRB(
            isPlateSticker ? 14 : 12,
            isExpandedSticker || isPlateSticker ? 11 : 9,
            isPlateSticker || isStatusSticker ? 12 : 9,
            isExpandedSticker || isPlateSticker ? 11 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(
              color: isPlateSticker
                  ? const Color(0xFF08111F).withValues(alpha: 0.42)
                  : isStatusSticker
                  ? _carismaBlueLight.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.18),
              width: isPlateSticker ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                color: Colors.black.withValues(alpha: 0.32),
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStatusSticker ? null : iconBackground,
                  gradient: isStatusSticker
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _carismaBlueLight.withValues(alpha: 0.96),
                            _carismaBlue.withValues(alpha: 0.9),
                          ],
                        )
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveLabel,
                      maxLines: isExpandedSticker && !isCompactSticker ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: isPlateSticker ? 0.4 : 0,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryDraftVideoPreview extends StatelessWidget {
  const _StoryDraftVideoPreview({
    required this.controller,
    required this.filterType,
  });

  final VideoPlayerController? controller;
  final String filterType;

  @override
  Widget build(BuildContext context) {
    final videoController = controller;

    if (videoController == null || !videoController.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    final videoSize = videoController.value.size;
    if (videoSize.width <= 0 || videoSize.height <= 0) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return _StoryFilteredContent(
      filterType: filterType,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: VideoPlayer(videoController),
        ),
      ),
    );
  }
}

class _StoryFilteredContent extends StatelessWidget {
  const _StoryFilteredContent({required this.filterType, required this.child});

  final String filterType;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_storyFilterMatrix(filterType)),
      child: child,
    );
  }
}

class _StoryFilteredImage extends StatelessWidget {
  const _StoryFilteredImage({
    required this.image,
    required this.filterType,
    required this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final ImageProvider image;
  final String filterType;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    return _StoryFilteredContent(
      filterType: filterType,
      child: Image(
        image: image,
        fit: fit,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      ),
    );
  }
}

List<double> _storyFilterMatrix(String filterType) {
  return switch (filterType.trim()) {
    'warm' => const [
      1.12,
      0.03,
      0.0,
      0,
      10,
      0.02,
      1.03,
      0.0,
      0,
      4,
      0.0,
      0.02,
      0.92,
      0,
      -4,
      0,
      0,
      0,
      1,
      0,
    ],
    'cool' => const [
      0.92,
      0.0,
      0.06,
      0,
      -2,
      0.0,
      1.0,
      0.03,
      0,
      2,
      0.04,
      0.0,
      1.15,
      0,
      8,
      0,
      0,
      0,
      1,
      0,
    ],
    'mono' => const [
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ],
    'soft' => const [
      1.05,
      0.02,
      0.02,
      0,
      8,
      0.02,
      1.05,
      0.02,
      0,
      8,
      0.02,
      0.02,
      1.05,
      0,
      8,
      0,
      0,
      0,
      1,
      0,
    ],
    _ => const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
  };
}

String _normalizeStoryLink(String value) {
  final trimmedValue = value.trim();

  if (trimmedValue.startsWith('http://') ||
      trimmedValue.startsWith('https://')) {
    return trimmedValue;
  }

  return 'https://$trimmedValue';
}

class _StoryFontSelector extends StatelessWidget {
  const _StoryFontSelector({
    required this.selectedValue,
    required this.onChanged,
  });

  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: CaRismaDesignTokens.card,
          isExpanded: true,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          items: const [
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
            DropdownMenuItem(value: 'rounded', child: Text('Rund')),
            DropdownMenuItem(value: 'serif', child: Text('Serif')),
            DropdownMenuItem(value: 'mono', child: Text('Mono')),
            DropdownMenuItem(value: 'condensed', child: Text('Schmal')),
            DropdownMenuItem(value: 'light', child: Text('Leicht')),
            DropdownMenuItem(value: 'medium', child: Text('Modern')),
            DropdownMenuItem(value: 'black', child: Text('Fett')),
            DropdownMenuItem(value: 'casual', child: Text('Casual')),
            DropdownMenuItem(value: 'cursive', child: Text('Script')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _StoryToolButton extends StatelessWidget {
  const _StoryToolButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onTap,
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        icon: Icon(icon),
        color: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? _carismaBlue
              : Colors.white.withValues(alpha: 0.12),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

class _StoryDoneToolButton extends StatelessWidget {
  const _StoryDoneToolButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Fertig'),
        style: TextButton.styleFrom(
          backgroundColor: _carismaBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}
