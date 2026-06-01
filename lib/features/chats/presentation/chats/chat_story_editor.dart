part of '../chats_screen.dart';

const int _storyTextMaxLength = 280;
const int _storyLinkMaxLength = 300;
const int _storyHashtagMaxLength = 79;

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

  final List<CameraDescription> _cameras = <CameraDescription>[];
  CameraController? _cameraController;
  Timer? _recordingTimer;

  bool _isInitializingCamera = true;
  bool _isCapturing = false;
  bool _isRecordingVideo = false;
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
    if (_isCapturing || _isRecordingVideo) {
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF101827).withValues(alpha: 0.94),
                        const Color(0xFF071120).withValues(alpha: 0.88),
                      ],
                    ),
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
    if (_cameras.length < 2 || _isCapturing || _isInitializingCamera) {
      return;
    }

    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera(cameraIndex: nextIndex);
  }

  Future<void> _handleLongPressStart() async {
    final controller = _cameraController;

    if (_isCapturing ||
        _isRecordingVideo ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo) {
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      await controller.startVideoRecording();

      if (!mounted) {
        return;
      }

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
          _handleLongPressEnd();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video konnte nicht gestartet werden: $error')),
      );
    }
  }

  Future<void> _handleLongPressEnd() async {
    final controller = _cameraController;

    if (!_isRecordingVideo ||
        controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isRecordingVideo) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });
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
    final isCameraReady =
        controller != null &&
        controller.value.isInitialized &&
        !_isInitializingCamera;
    final recordingProgress =
        (_recordingDuration.inMilliseconds /
                _maxStoryVideoDuration.inMilliseconds)
            .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: isCameraReady
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
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
                      Colors.black.withValues(alpha: 0.42),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.50),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: viewPadding.top + 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF101827).withValues(alpha: 0.70),
                        Colors.black.withValues(alpha: 0.34),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      _StoryEditorHeaderButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Abbrechen',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Story aufnehmen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.photo_camera_rounded),
                        color: Colors.white,
                        tooltip: 'Foto aufnehmen',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            left: 14,
            right: 14,
            bottom: viewPadding.bottom + 22,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF101827).withValues(alpha: 0.72),
                        Colors.black.withValues(alpha: 0.40),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StoryCaptureSideAction(
                        icon: Icons.photo_library_rounded,
                        label: 'Aufnahmen',
                        onTap: _pickFromGallery,
                      ),
                      Listener(
                        onPointerUp: (_) {
                          if (_isRecordingVideo) {
                            _handleLongPressEnd();
                          }
                        },
                        onPointerCancel: (_) {
                          if (_isRecordingVideo) {
                            _handleLongPressEnd();
                          }
                        },
                        child: GestureDetector(
                          onTap: _takePhoto,
                          onLongPressStart: (_) => _handleLongPressStart(),
                          onLongPressEnd: (_) => _handleLongPressEnd(),
                          onLongPressCancel: _handleLongPressEnd,
                          child: _StoryCaptureButton(
                            isBusy: _isCapturing,
                            isRecording: _isRecordingVideo,
                            recordingProgress: recordingProgress,
                          ),
                        ),
                      ),
                      _StoryCaptureSideAction(
                        icon: Icons.flip_camera_android_rounded,
                        label: 'Kamera',
                        onTap: _switchCamera,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060810), Color(0xFF101827), Color(0xFF02040A)],
        ),
      ),
      child: Center(
        child: isLoading
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
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
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.black.withValues(alpha: 0.34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
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
                          color: Colors.white.withValues(alpha: 0.78),
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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _carmaBlue.withValues(alpha: 0.82),
                  boxShadow: [
                    BoxShadow(
                      color: _carmaBlue.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
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
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.46),
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
            color: Colors.black.withValues(alpha: 0.42),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF315A),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                durationLabel,
                style: const TextStyle(
                  color: Colors.white,
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
                Colors.black.withValues(alpha: 0.46),
                _carmaBlueDark.withValues(alpha: 0.28),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
              color: Colors.white,
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
              color: const Color(0xFFFF315A).withValues(alpha: 0.18),
              border: Border.all(
                color: const Color(0xFFFF7A90).withValues(alpha: 0.42),
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
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 4,
              ),
              color: isBusy || isRecording
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: _carmaBlue.withValues(alpha: 0.32),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
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
                gradient: isBusy || isRecording
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _carmaBlue.withValues(alpha: 0.92),
                          _myMessageBlueDark.withValues(alpha: 0.88),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.82),
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
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      isRecording
                          ? Icons.stop_rounded
                          : Icons.photo_camera_rounded,
                      color: isRecording
                          ? Colors.white
                          : _myMessageBlueDark.withValues(alpha: 0.72),
                      size: isRecording ? 34 : 28,
                    ),
            ),
          ),
          if (isRecording)
            SizedBox(
              width: 92,
              height: 92,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF315A),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.07),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
  Alignment _textAlignment = const Alignment(0, 0.16);
  String _filterType = 'normal';
  _StoryStickerDraft _sticker = const _StoryStickerDraft.empty();
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _isVideoTooLong = false;

  static const Duration _maxDraftVideoDuration = Duration(seconds: 30);

  static const List<Color> _storyTextColors = [
    Colors.white,
    Color(0xFFFFD54F),
    Color(0xFFFF7A3D),
    Color(0xFFFF3B30),
    Color(0xFFFF5C8A),
    Color(0xFFFF8AD8),
    Color(0xFFC084FC),
    Color(0xFF007AFF),
    Color(0xFF63D5FF),
    Color(0xFF2DD4BF),
    Color(0xFF64F29B),
    Color(0xFFB6FF3B),
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
    });
  }

  void _activateTextEditing() {
    setState(() {
      _isTextEditingEnabled = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocusNode.requestFocus();
      }
    });
  }

  void _finishTextEditing() {
    FocusScope.of(context).unfocus();
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

  Future<void> _addLinkSticker() async {
    final sticker = await _showStickerTextDialog(
      context: context,
      title: 'Link hinzuf\u00FCgen',
      hintText: 'https://...',
      type: 'link',
      iconPrefix: '',
      maxLength: _storyLinkMaxLength,
    );

    if (sticker == null || !mounted) {
      return;
    }

    setState(() {
      _sticker = sticker;
    });
  }

  Future<void> _addHashtagSticker() async {
    final sticker = await _showStickerTextDialog(
      context: context,
      title: 'Hashtag hinzuf\u00FCgen',
      hintText: 'carma',
      type: 'hashtag',
      iconPrefix: '#',
      maxLength: _storyHashtagMaxLength,
    );

    if (sticker == null || !mounted) {
      return;
    }

    setState(() {
      _sticker = sticker;
    });
  }

  void _addVehicleSticker() {
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

    final vehicleLabel = vehicleStickerData.vehicleLabel.trim().isEmpty
        ? 'Fahrzeug'
        : vehicleStickerData.vehicleLabel.trim();

    setState(() {
      _sticker = _StoryStickerDraft(
        type: 'vehicle',
        label: vehicleLabel,
        payload: vehicleStickerData.plateLabel.trim(),
        alignment: const Alignment(0, 0.52),
      );
    });
  }

  Future<void> _addStatusSticker() async {
    final status = await _showStatusStickerPicker(context);

    if (status == null || !mounted) {
      return;
    }

    setState(() {
      _sticker = _StoryStickerDraft(
        type: 'status',
        label: status,
        payload: status,
        alignment: const Alignment(0, 0.52),
      );
    });
  }

  Future<void> _addPollSticker() async {
    final sticker = await _showPollStickerDialog(context);

    if (sticker == null || !mounted) {
      return;
    }

    setState(() {
      _sticker = sticker;
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
      final fallbackLabel = 'Aktueller Standort';
      final places = await ChatNativeBridge()
          .reverseGeocodeLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          )
          .catchError((_) => const <ResolvedLocationPlace>[]);
      final selectedPlace = context.mounted
          ? await _showLocationPlacePicker(
              context: context,
              places: places,
              fallbackLabel: fallbackLabel,
            )
          : null;
      final label = selectedPlace?.label.trim().isNotEmpty == true
          ? selectedPlace!.label.trim()
          : fallbackLabel;

      return _StoryStickerDraft(
        type: 'location',
        label: label,
        payload: '${position.latitude},${position.longitude}',
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
    required String fallbackLabel,
  }) async {
    final options = _buildLocationPickerOptions(
      places: places,
      fallbackLabel: fallbackLabel,
    );

    if (options.length == 1) {
      return options.first;
    }

    return showModalBottomSheet<ResolvedLocationPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.62;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF101827).withValues(alpha: 0.94),
                          const Color(0xFF071120).withValues(alpha: 0.88),
                        ],
                      ),
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
                          'Standort auswählen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final place = options[index];

                              return _StoryLocationPlaceTile(
                                place: place,
                                onTap: () => Navigator.of(context).pop(place),
                              );
                            },
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
  }

  List<ResolvedLocationPlace> _buildLocationPickerOptions({
    required List<ResolvedLocationPlace> places,
    required String fallbackLabel,
  }) {
    final options = <ResolvedLocationPlace>[];
    final seenLabels = <String>{};

    bool isUsefulLabel(String label) {
      final trimmedLabel = label.trim();

      if (trimmedLabel.length < 3) {
        return false;
      }

      if (RegExp(r'^\d+[a-zA-Z]?\b').hasMatch(trimmedLabel)) {
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

      final key = trimmedLabel.toLowerCase();
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

    for (final place in places.take(6)) {
      addOption(
        label: place.city,
        city: place.city,
        region: place.region,
        country: place.country,
      );

      addOption(
        label: place.region,
        city: place.city,
        region: place.region,
        country: place.country,
      );

      addOption(
        label: [
          place.city,
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

    addOption(label: fallbackLabel, city: '', region: '', country: '');

    return options.take(6).toList(growable: false);
  }

  Future<_StoryStickerDraft?> _showStickerTextDialog({
    required BuildContext context,
    required String title,
    required String hintText,
    required String type,
    required String iconPrefix,
    required int maxLength,
  }) async {
    final controller = TextEditingController();

    try {
      final value = await showDialog<String>(
        context: context,
        builder: (context) {
          return _StoryTextInputDialog(
            backgroundColor: const Color(0xFF101827),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.of(context).pop(value),
              buildCounter: _hideStoryInputCounter,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                prefixText: iconPrefix.isEmpty ? null : iconPrefix,
                prefixStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                style: FilledButton.styleFrom(
                  backgroundColor: _carmaBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Hinzufügen'),
              ),
            ],
          );
        },
      );

      final trimmedValue = value?.trim() ?? '';

      if (trimmedValue.isEmpty) {
        return null;
      }

      final normalizedValue = type == 'link'
          ? _normalizeStoryLink(trimmedValue)
          : trimmedValue
                .replaceFirst(RegExp(r'^#+'), '')
                .replaceAll(RegExp(r'\s+'), '');

      if (normalizedValue.isEmpty) {
        return null;
      }

      final label = type == 'link'
          ? normalizedValue
          : '$iconPrefix$normalizedValue';

      return _StoryStickerDraft(
        type: type,
        label: label,
        payload: normalizedValue,
        alignment: const Alignment(0, 0.52),
      );
    } finally {
      controller.dispose();
    }
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF101827).withValues(alpha: 0.94),
                        const Color(0xFF071120).withValues(alpha: 0.88),
                      ],
                    ),
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
                          for (final status in statusOptions)
                            _StoryStatusChoiceChip(
                              label: status,
                              onTap: () => Navigator.of(context).pop(status),
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

  Future<_StoryStickerDraft?> _showPollStickerDialog(
    BuildContext context,
  ) async {
    final questionController = TextEditingController();
    final firstOptionController = TextEditingController(text: 'Ja');
    final secondOptionController = TextEditingController(text: 'Nein');

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return _StoryTextInputDialog(
            backgroundColor: const Color(0xFF101827),
            title: const Text(
              'Umfrage hinzufügen',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  autofocus: true,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  buildCounter: _hideStoryInputCounter,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Frage, z. B. Treffen heute?',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: firstOptionController,
                  maxLength: 28,
                  textInputAction: TextInputAction.next,
                  buildCounter: _hideStoryInputCounter,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Antwort 1'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: secondOptionController,
                  maxLength: 28,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.of(context).pop(true),
                  buildCounter: _hideStoryInputCounter,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Antwort 2'),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _carmaBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Hinzufügen'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return null;
      }

      final question = questionController.text.trim();
      final firstOption = firstOptionController.text.trim();
      final secondOption = secondOptionController.text.trim();

      if (question.isEmpty || firstOption.isEmpty || secondOption.isEmpty) {
        return null;
      }

      return _StoryStickerDraft(
        type: 'poll',
        label: question,
        payload: '$firstOption\n$secondOption',
        alignment: const Alignment(0, 0.52),
      );
    } finally {
      questionController.dispose();
      firstOptionController.dispose();
      secondOptionController.dispose();
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
        await ChatNativeBridge().saveImageToGallery(
          url: widget.mediaPath,
          fileName: 'carma_story_${DateTime.now().millisecondsSinceEpoch}.mp4',
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
        'carma_story_',
      );
      final fileName =
          'carma_story_${DateTime.now().millisecondsSinceEpoch}.png';
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

                          return Align(
                            alignment: _textAlignment,
                            child: GestureDetector(
                              onTap: hasText && !_isTextEditingEnabled
                                  ? _activateTextEditing
                                  : null,
                              onPanUpdate: (details) =>
                                  _moveText(details, size),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.82,
                                ),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _textFocusNode,
                                  textAlign: TextAlign.center,
                                  maxLength: _storyTextMaxLength,
                                  maxLines: 4,
                                  minLines: 1,
                                  cursorColor: _textColor,
                                  readOnly: !_isTextEditingEnabled,
                                  enableInteractiveSelection:
                                      _isTextEditingEnabled,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _finishTextEditing(),
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
                                    focusedErrorBorder: InputBorder.none,
                                    filled: false,
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
                                onPanUpdate: (details) =>
                                    _moveSticker(details, size),
                                child: _StoryStickerChip(
                                  type: _sticker.type,
                                  label: _sticker.label,
                                  payload: _sticker.payload,
                                  onRemove: _isSaving || _isPublishing
                                      ? null
                                      : () {
                                          setState(() {
                                            _sticker =
                                                const _StoryStickerDraft.empty();
                                          });
                                        },
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
          if (!_isSaving)
            Positioned(
              left: 12,
              right: 12,
              top: viewPadding.top + 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF101827).withValues(alpha: 0.70),
                          Colors.black.withValues(alpha: 0.34),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!_isPublishing)
                          _StoryEditorHeaderButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Abbrechen',
                            onPressed: _closeEditor,
                          )
                        else
                          const SizedBox(width: 44, height: 44),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Story bearbeiten',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: canPublish ? _publish : null,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _carmaBlue,
                            disabledBackgroundColor: _carmaBlue.withValues(
                              alpha: _isVideoTooLong ? 0.24 : 0.54,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: _isPublishing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Teilen',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_isSaving && !_isPublishing)
            Positioned(
              right: 14,
              top: viewPadding.top + 86,
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
                onAddLink: _addLinkSticker,
                onAddHashtag: _addHashtagSticker,
                onAddPoll: _addPollSticker,
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
                textColor: _textColor,
                colors: _storyTextColors,
                onDone: _finishTextEditing,
                onToggleBold: () => setState(() => _isBold = !_isBold),
                onToggleItalic: () => setState(() => _isItalic = !_isItalic),
                onToggleUnderline: () =>
                    setState(() => _isUnderline = !_isUnderline),
                onFontChanged: (value) {
                  setState(() {
                    _fontFamily = value;
                  });
                },
                onColorChanged: (value) {
                  setState(() {
                    _textColor = value;
                  });
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
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: Colors.white,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF101827).withValues(alpha: 0.94),
                  const Color(0xFF071120).withValues(alpha: 0.90),
                ],
              ),
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
                        color: _carmaBlue.withValues(alpha: 0.18),
                        border: Border.all(
                          color: _carmaBlueLight.withValues(alpha: 0.24),
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
                          backgroundColor: _carmaBlue,
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
    Color? backgroundColor,
    this.title,
    this.content,
    this.actions,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF101827).withValues(alpha: 0.94),
                  const Color(0xFF071120).withValues(alpha: 0.90),
                ],
              ),
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
                        color: _carmaBlue.withValues(alpha: 0.18),
                        border: Border.all(
                          color: _carmaBlueLight.withValues(alpha: 0.24),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
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
                        fillColor: Colors.white.withValues(alpha: 0.08),
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
    required this.onAddLink,
    required this.onAddHashtag,
    required this.onAddPoll,
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
  final VoidCallback onAddLink;
  final VoidCallback onAddHashtag;
  final VoidCallback onAddPoll;
  final VoidCallback onToggleVideoMuted;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final selectedStickerType = stickerType.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).top -
                128,
          ),
          child: Container(
            width: 78,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF101827).withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.38),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
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
                    icon: Icons.bolt_rounded,
                    label: 'Status',
                    isSelected: selectedStickerType == 'status',
                    onTap: onAddStatus,
                  ),
                  const SizedBox(height: 8),
                  _StoryRailButton(
                    icon: Icons.link_rounded,
                    label: 'Link',
                    isSelected: selectedStickerType == 'link',
                    onTap: onAddLink,
                  ),
                  const SizedBox(height: 8),
                  _StoryRailButton(
                    icon: Icons.tag_rounded,
                    label: 'Hashtag',
                    isSelected: selectedStickerType == 'hashtag',
                    onTap: onAddHashtag,
                  ),
                  const SizedBox(height: 8),
                  _StoryRailButton(
                    icon: Icons.poll_rounded,
                    label: 'Umfrage',
                    isSelected: selectedStickerType == 'poll',
                    onTap: onAddPoll,
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
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_myMessageBlueDark, _carmaBlue],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: isSelected
                    ? _carmaBlueLight
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: isBusy
                ? const Center(
                    child: SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryTextStyleBar extends StatelessWidget {
  const _StoryTextStyleBar({
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.fontFamily,
    required this.textColor,
    required this.colors,
    required this.onDone,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onFontChanged,
    required this.onColorChanged,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String fontFamily;
  final Color textColor;
  final List<Color> colors;
  final VoidCallback onDone;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF101827).withValues(alpha: 0.82),
                Colors.black.withValues(alpha: 0.54),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _StoryToolButton(
                    icon: Icons.format_bold_rounded,
                    isSelected: isBold,
                    onTap: onToggleBold,
                  ),
                  const SizedBox(width: 6),
                  _StoryToolButton(
                    icon: Icons.format_italic_rounded,
                    isSelected: isItalic,
                    onTap: onToggleItalic,
                  ),
                  const SizedBox(width: 6),
                  _StoryToolButton(
                    icon: Icons.format_underlined_rounded,
                    isSelected: isUnderline,
                    onTap: onToggleUnderline,
                  ),
                  const SizedBox(width: 6),
                  _StoryToolButton(
                    icon: Icons.check_rounded,
                    isSelected: true,
                    onTap: onDone,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StoryFontSelector(
                      selectedValue: fontFamily,
                      onChanged: onFontChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 29,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: colors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final color = colors[index];
                    final isSelected = color.toARGB32() == textColor.toARGB32();

                    return GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 29,
                        height: 29,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.20)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.12),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.42),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.18),
                            ),
                          ),
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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _carmaBlue.withValues(alpha: 0.82),
                  boxShadow: [
                    BoxShadow(
                      color: _carmaBlue.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
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
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
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
    this.onRemove,
  });

  final String type;
  final String label;
  final String payload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'vehicle' => Icons.directions_car_filled_rounded,
      'location' => Icons.location_on_rounded,
      'status' => Icons.bolt_rounded,
      'link' => Icons.link_rounded,
      'hashtag' => Icons.tag_rounded,
      'poll' => Icons.poll_rounded,
      _ => Icons.add_reaction_rounded,
    };
    final subtitle = switch (type) {
      'vehicle' => payload.trim(),
      'poll' =>
        payload
            .split('\n')
            .where((option) => option.trim().isNotEmpty)
            .take(2)
            .join('  ·  '),
      _ => '',
    };
    final isExpandedSticker = subtitle.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(isExpandedSticker ? 22 : 999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(maxWidth: isExpandedSticker ? 310 : 270),
          padding: EdgeInsets.fromLTRB(
            12,
            isExpandedSticker ? 11 : 9,
            9,
            isExpandedSticker ? 11 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isExpandedSticker ? 22 : 999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF101827).withValues(alpha: 0.84),
                _carmaBlueDark.withValues(alpha: 0.74),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                  color: _carmaBlue.withValues(alpha: 0.92),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: isExpandedSticker ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 7),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
              ],
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

    return _StoryFilteredContent(
      filterType: filterType,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: videoController.value.size.width,
          height: videoController.value.size.height,
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
  });

  final ImageProvider image;
  final String filterType;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return _StoryFilteredContent(
      filterType: filterType,
      child: Image(image: image, fit: fit, errorBuilder: errorBuilder),
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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: const Color(0xFF101827),
          isExpanded: true,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
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
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        color: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? _carmaBlue
              : Colors.white.withValues(alpha: 0.12),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
