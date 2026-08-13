part of '../chats_screen.dart';

class _ChatImageEditorResult {
  const _ChatImageEditorResult({
    required this.file,
    required this.caption,
    required this.isViewOnce,
  });

  final File file;
  final String caption;
  final bool isViewOnce;
}

class _ChatVideoPreviewResult {
  const _ChatVideoPreviewResult({
    required this.durationMs,
    required this.caption,
    required this.isViewOnce,
  });

  final int durationMs;
  final String caption;
  final bool isViewOnce;
}

class _ChatImageEditorScreen extends StatefulWidget {
  const _ChatImageEditorScreen({
    required this.file,
    required this.nativeBridge,
    required this.initialViewOnce,
  });

  final File file;
  final ChatNativeBridge nativeBridge;
  final bool initialViewOnce;

  @override
  State<_ChatImageEditorScreen> createState() => _ChatImageEditorScreenState();
}

class _ChatImageEditorScreenState extends State<_ChatImageEditorScreen> {
  static const _editorColors = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFF1A5CBA),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFFFFC107),
    Color(0xFFEC4899),
  ];

  final GlobalKey _renderKey = GlobalKey();
  final GlobalKey _textDeleteTargetKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _overlayTextController = TextEditingController();
  final FocusNode _overlayTextFocusNode = FocusNode();
  final List<_ChatDrawingStroke> _strokes = <_ChatDrawingStroke>[];
  final List<_ChatImageTextOverlay> _textOverlays = <_ChatImageTextOverlay>[];

  File? _workingFile;
  _ChatDrawingStroke? _activeStroke;
  Color _drawingColor = Colors.white;
  double _drawingWidth = 5;
  double _sourceAspectRatio = 4 / 5;
  double _originalAspectRatio = 4 / 5;
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
  int _quarterTurns = 0;
  bool _isDrawing = false;
  bool _showCropControls = false;
  bool _isTextEditing = false;
  Color _textColor = Colors.white;
  bool _isTextBold = true;
  bool _isTextItalic = false;
  bool _isTextUnderline = false;
  TextAlign _textAlign = TextAlign.center;
  String _textFontFamily = 'standard';
  bool _isViewOnce = false;
  bool _isBusy = false;
  bool _isToolMenuExpanded = false;
  String? _draggingTextOverlayId;
  bool _isTextOverDeleteTarget = false;

  double get _previewAspectRatio =>
      _quarterTurns.isOdd ? 1 / _sourceAspectRatio : _sourceAspectRatio;

  String? get _effectiveTextFontFamily {
    return switch (_textFontFamily) {
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

  @override
  void initState() {
    super.initState();
    _isViewOnce = widget.initialViewOnce;
    unawaited(_loadSourceAspectRatio());
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _captionController.dispose();
    _overlayTextController.dispose();
    _overlayTextFocusNode.dispose();
    super.dispose();
  }

  File get _sourceFile => _workingFile ?? widget.file;

  Future<double?> _readSourceAspectRatio(File file) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final bytes = await file.readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      return image.height <= 0 ? null : image.width / image.height;
    } catch (_) {
      // The editor keeps a safe portrait fallback when metadata is unavailable.
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<void> _loadSourceAspectRatio() async {
    final aspectRatio = await _readSourceAspectRatio(widget.file);
    if (!mounted || aspectRatio == null) {
      return;
    }
    setState(() {
      _originalAspectRatio = aspectRatio;
      if (_workingFile == null) {
        _sourceAspectRatio = aspectRatio;
      }
    });
  }

  void _close() {
    if (_isBusy) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
      _transformationController.value = Matrix4.identity();
    });
  }

  void _resetCrop() {
    setState(() {
      // A confirmed crop uses a temporary working file. Returning to the
      // original here keeps Reset useful even after the crop was accepted.
      if (_workingFile != null) {
        _workingFile = null;
        _sourceAspectRatio = _originalAspectRatio;
        _quarterTurns = 0;
        _transformationController.value = Matrix4.identity();
      }
      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
    });
  }

  Future<void> _finishCropping() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final croppedFile = await _renderEditedFile();
      final aspectRatio = await _readSourceAspectRatio(croppedFile);
      if (!mounted) {
        return;
      }
      setState(() {
        _workingFile = croppedFile;
        if (aspectRatio != null) {
          _sourceAspectRatio = aspectRatio;
        }
        _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
        _quarterTurns = 0;
        _showCropControls = false;
        _isDrawing = false;
        _activeStroke = null;
        _strokes.clear();
        _textOverlays.clear();
        _transformationController.value = Matrix4.identity();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyChatUiError(
                error,
                fallback: 'Der Ausschnitt konnte nicht übernommen werden.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _resetDrawing() {
    setState(() {
      _activeStroke = null;
      _strokes.clear();
    });
  }

  void _finishDrawing() {
    setState(() {
      _activeStroke = null;
      _isDrawing = false;
    });
  }

  void _addTextOverlay() {
    setState(() {
      _isTextEditing = true;
      _isDrawing = false;
      _showCropControls = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _overlayTextFocusNode.requestFocus();
      }
    });
  }

  void _finishTextEditing() {
    final value = _overlayTextController.text.trim();
    _overlayTextFocusNode.unfocus();
    if (value.isNotEmpty) {
      _textOverlays.add(
        _ChatImageTextOverlay(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: value,
          color: _textColor,
          position: const Offset(0.5, 0.42),
          isBold: _isTextBold,
          isItalic: _isTextItalic,
          isUnderline: _isTextUnderline,
          textAlign: _textAlign,
          fontFamily: _textFontFamily,
        ),
      );
    }
    _overlayTextController.clear();
    setState(() {
      _isTextEditing = false;
    });
  }

  void _keepTextInputFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isTextEditing) {
        _overlayTextFocusNode.requestFocus();
      }
    });
  }

  void _updateTextOverlayPosition(
    _ChatImageTextOverlay overlay,
    Offset delta,
    Size previewSize,
  ) {
    if (previewSize.width <= 0 || previewSize.height <= 0) {
      return;
    }

    final index = _textOverlays.indexWhere((item) => item.id == overlay.id);
    if (index < 0) {
      return;
    }

    final current = _textOverlays[index];

    final next = Offset(
      (current.position.dx + delta.dx / previewSize.width).clamp(0.06, 0.94),
      (current.position.dy + delta.dy / previewSize.height).clamp(0.06, 0.94),
    );
    setState(() {
      _textOverlays[index] = current.copyWith(position: next);
    });
  }

  void _startTextOverlayDrag(_ChatImageTextOverlay overlay) {
    setState(() {
      _draggingTextOverlayId = overlay.id;
      _isTextOverDeleteTarget = false;
    });
  }

  void _moveTextOverlayDrag(
    _ChatImageTextOverlay overlay,
    Offset globalPosition,
    Offset delta,
    Size previewSize,
  ) {
    _updateTextOverlayPosition(overlay, delta, previewSize);

    final targetBox = _textDeleteTargetKey.currentContext?.findRenderObject();
    final isOverDeleteTarget = targetBox is RenderBox && targetBox.hasSize
        ? (targetBox.localToGlobal(Offset.zero) & targetBox.size)
              .inflate(24)
              .contains(globalPosition)
        : false;
    setState(() {
      _isTextOverDeleteTarget = isOverDeleteTarget;
    });
  }

  void _finishTextOverlayDrag(_ChatImageTextOverlay overlay) {
    setState(() {
      if (_isTextOverDeleteTarget) {
        _textOverlays.removeWhere((item) => item.id == overlay.id);
      }
      _draggingTextOverlayId = null;
      _isTextOverDeleteTarget = false;
    });
  }

  Future<File> _renderEditedFile() async {
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.5, 3.0).toDouble();
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Das bearbeitete Foto konnte nicht erstellt werden.');
    }

    final renderedImage = await boundary.toImage(pixelRatio: pixelRatio);
    final normalizedCrop = _cropRect.intersect(const Rect.fromLTWH(0, 0, 1, 1));
    final cropLeft = (normalizedCrop.left * renderedImage.width)
        .round()
        .clamp(0, renderedImage.width - 1)
        .toInt();
    final cropTop = (normalizedCrop.top * renderedImage.height)
        .round()
        .clamp(0, renderedImage.height - 1)
        .toInt();
    final cropWidth = (normalizedCrop.width * renderedImage.width)
        .round()
        .clamp(1, renderedImage.width - cropLeft)
        .toInt();
    final cropHeight = (normalizedCrop.height * renderedImage.height)
        .round()
        .clamp(1, renderedImage.height - cropTop)
        .toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      renderedImage,
      Rect.fromLTWH(
        cropLeft.toDouble(),
        cropTop.toDouble(),
        cropWidth.toDouble(),
        cropHeight.toDouble(),
      ),
      Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(cropWidth, cropHeight);
    picture.dispose();
    renderedImage.dispose();
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    croppedImage.dispose();
    if (byteData == null) {
      throw StateError('Das bearbeitete Foto konnte nicht gespeichert werden.');
    }

    final directory = await Directory.systemTemp.createTemp(
      'plaqa_chat_image_',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}chat_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _saveToGallery() async {
    if (_isBusy) {
      return;
    }
    if (_isTextEditing) {
      _finishTextEditing();
      await WidgetsBinding.instance.endOfFrame;
    }
    setState(() => _isBusy = true);
    try {
      final file = await _renderEditedFile();
      await widget.nativeBridge.saveImageToGallery(
        url: file.path,
        fileName: 'CaRisma_${DateTime.now().millisecondsSinceEpoch}.png',
        contentType: 'image/png',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto wurde in der Galerie gespeichert.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyChatUiError(
                error,
                fallback: 'Foto konnte nicht gespeichert werden.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _finish() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final file = await _renderEditedFile();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        _ChatImageEditorResult(
          file: file,
          caption: _captionController.text.trim(),
          isViewOnce: _isViewOnce,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyChatUiError(
                error,
                fallback: 'Foto konnte nicht vorbereitet werden.',
              ),
            ),
          ),
        );
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: CaRismaDesignTokens.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ChatEditorIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Abbrechen',
                      onTap: _close,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      var previewWidth = constraints.maxWidth;
                      var previewHeight = previewWidth / _previewAspectRatio;
                      if (previewHeight > constraints.maxHeight) {
                        previewHeight = constraints.maxHeight;
                        previewWidth = previewHeight * _previewAspectRatio;
                      }
                      final previewSize = Size(previewWidth, previewHeight);

                      return Center(
                        child: SizedBox(
                          width: previewWidth,
                          height: previewHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                key: _renderKey,
                                child: ClipRect(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ColoredBox(
                                        color: Colors.black,
                                        child: IgnorePointer(
                                          ignoring:
                                              _isDrawing ||
                                              _showCropControls ||
                                              _isTextEditing,
                                          child: InteractiveViewer(
                                            transformationController:
                                                _transformationController,
                                            minScale: 1,
                                            maxScale: 5,
                                            panEnabled:
                                                !_isDrawing &&
                                                !_showCropControls &&
                                                !_isTextEditing,
                                            scaleEnabled:
                                                !_isDrawing &&
                                                !_showCropControls &&
                                                !_isTextEditing,
                                            child: SizedBox.expand(
                                              child: RotatedBox(
                                                quarterTurns: _quarterTurns,
                                                child: Image.file(
                                                  _sourceFile,
                                                  fit: BoxFit.cover,
                                                  filterQuality:
                                                      FilterQuality.high,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onPanStart: !_isDrawing
                                            ? null
                                            : (details) {
                                                final stroke =
                                                    _ChatDrawingStroke(
                                                      points: <Offset>[
                                                        details.localPosition,
                                                      ],
                                                      color: _drawingColor,
                                                      width: _drawingWidth,
                                                    );
                                                setState(() {
                                                  _activeStroke = stroke;
                                                  _strokes.add(stroke);
                                                });
                                              },
                                        onPanUpdate: !_isDrawing
                                            ? null
                                            : (details) {
                                                final stroke = _activeStroke;
                                                if (stroke == null) {
                                                  return;
                                                }
                                                setState(() {
                                                  stroke.points.add(
                                                    details.localPosition,
                                                  );
                                                });
                                              },
                                        onPanEnd: !_isDrawing
                                            ? null
                                            : (_) {
                                                _activeStroke = null;
                                              },
                                        child: CustomPaint(
                                          painter: _ChatDrawingPainter(
                                            strokes: _strokes,
                                          ),
                                          size: previewSize,
                                        ),
                                      ),
                                      for (final overlay in _textOverlays)
                                        Positioned(
                                          left:
                                              overlay.position.dx *
                                                  previewSize.width -
                                              140,
                                          top:
                                              overlay.position.dy *
                                                  previewSize.height -
                                              62,
                                          width: 280,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (_) =>
                                                _startTextOverlayDrag(overlay),
                                            onPanUpdate: (details) =>
                                                _moveTextOverlayDrag(
                                                  overlay,
                                                  details.globalPosition,
                                                  details.delta,
                                                  previewSize,
                                                ),
                                            onPanEnd: (_) =>
                                                _finishTextOverlayDrag(overlay),
                                            onPanCancel: () =>
                                                _finishTextOverlayDrag(overlay),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 22,
                                                  ),
                                              child: Text(
                                                overlay.text,
                                                textAlign: overlay.textAlign,
                                                style: TextStyle(
                                                  color: overlay.color,
                                                  fontSize: 28,
                                                  height: 1.08,
                                                  fontWeight: overlay.isBold
                                                      ? FontWeight.w900
                                                      : FontWeight.w600,
                                                  fontStyle: overlay.isItalic
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                  fontFamily: overlay
                                                      .effectiveFontFamily,
                                                  decoration:
                                                      overlay.isUnderline
                                                      ? TextDecoration.underline
                                                      : TextDecoration.none,
                                                  decorationColor:
                                                      overlay.color,
                                                  decorationThickness: 2,
                                                  shadows: const [
                                                    Shadow(
                                                      color: Colors.black87,
                                                      blurRadius: 10,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_isTextEditing)
                                        Align(
                                          alignment: keyboardInset > 0
                                              ? const Alignment(0, -0.38)
                                              : Alignment.center,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  previewSize.width * 0.84,
                                            ),
                                            child: TextField(
                                              controller:
                                                  _overlayTextController,
                                              focusNode: _overlayTextFocusNode,
                                              autofocus: true,
                                              textAlign: _textAlign,
                                              maxLength: 120,
                                              minLines: 1,
                                              maxLines: 4,
                                              cursorColor: _textColor,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) =>
                                                  _finishTextEditing(),
                                              style: TextStyle(
                                                color: _textColor,
                                                fontSize: 30,
                                                height: 1.08,
                                                fontWeight: _isTextBold
                                                    ? FontWeight.w900
                                                    : FontWeight.w600,
                                                fontStyle: _isTextItalic
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                                fontFamily:
                                                    _effectiveTextFontFamily,
                                                decoration: _isTextUnderline
                                                    ? TextDecoration.underline
                                                    : TextDecoration.none,
                                                decorationColor: _textColor,
                                                decorationThickness: 2,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black87,
                                                    blurRadius: 12,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              decoration: InputDecoration(
                                                counterText: '',
                                                isCollapsed: true,
                                                contentPadding: EdgeInsets.zero,
                                                hintText: 'Text hinzufügen',
                                                hintStyle: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.62),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                filled: false,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showCropControls)
                                _ChatFreeCropOverlay(
                                  cropRect: _cropRect,
                                  onChanged: (value) {
                                    setState(() => _cropRect = value);
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _isDrawing
                      ? _ChatDrawingControls(
                          colors: _editorColors,
                          selectedColor: _drawingColor,
                          width: _drawingWidth,
                          canUndo: _strokes.isNotEmpty,
                          onSelectColor: (color) {
                            setState(() => _drawingColor = color);
                          },
                          onWidthChanged: (value) {
                            setState(() => _drawingWidth = value);
                          },
                          onUndo: () {
                            if (_strokes.isEmpty) {
                              return;
                            }
                            setState(() => _strokes.removeLast());
                          },
                          onReset: _resetDrawing,
                          onDone: _finishDrawing,
                        )
                      : const SizedBox.shrink(),
                ),
                if (!_isTextEditing)
                  _ChatMediaSendBar(
                    controller: _captionController,
                    isViewOnce: _isViewOnce,
                    isBusy: _isBusy,
                    onToggleViewOnce: () {
                      setState(() => _isViewOnce = !_isViewOnce);
                    },
                    onSend: _finish,
                  ),
              ],
            ),
            if (_showCropControls && !_isTextEditing)
              Positioned(
                right: 12,
                bottom: 84,
                child: _ChatCropControls(
                  onReset: _resetCrop,
                  onRotate: _rotate,
                  onDone: () => unawaited(_finishCropping()),
                ),
              ),
            if (!_isTextEditing)
              Positioned(
                top: 8,
                right: 12,
                child: _ChatEditorToolMenu(
                  isExpanded: _isToolMenuExpanded,
                  isCropSelected: _showCropControls,
                  isDrawingSelected: _isDrawing,
                  onToggle: () {
                    setState(() {
                      _isToolMenuExpanded = !_isToolMenuExpanded;
                    });
                  },
                  onSave: () {
                    setState(() => _isToolMenuExpanded = false);
                    _saveToGallery();
                  },
                  onCrop: () {
                    setState(() {
                      _isToolMenuExpanded = false;
                      _showCropControls = !_showCropControls;
                      _isDrawing = false;
                    });
                  },
                  onText: () {
                    setState(() => _isToolMenuExpanded = false);
                    _addTextOverlay();
                  },
                  onDraw: () {
                    setState(() {
                      _isToolMenuExpanded = false;
                      _isDrawing = !_isDrawing;
                      _showCropControls = false;
                    });
                  },
                ),
              ),
            if (_isTextEditing)
              Positioned(
                left: 12,
                right: 12,
                bottom: keyboardInset + 8,
                child: _StoryTextStyleBar(
                  isBold: _isTextBold,
                  isItalic: _isTextItalic,
                  isUnderline: _isTextUnderline,
                  fontFamily: _textFontFamily,
                  textAlign: _textAlign,
                  textColor: _textColor,
                  colors: _editorColors,
                  onDone: _finishTextEditing,
                  onToggleBold: () {
                    setState(() => _isTextBold = !_isTextBold);
                    _keepTextInputFocused();
                  },
                  onToggleItalic: () {
                    setState(() => _isTextItalic = !_isTextItalic);
                    _keepTextInputFocused();
                  },
                  onToggleUnderline: () {
                    setState(() => _isTextUnderline = !_isTextUnderline);
                    _keepTextInputFocused();
                  },
                  onTextAlignChanged: (value) {
                    setState(() => _textAlign = value);
                    _keepTextInputFocused();
                  },
                  onFontChanged: (value) {
                    setState(() => _textFontFamily = value);
                    _keepTextInputFocused();
                  },
                  onColorChanged: (value) {
                    setState(() => _textColor = value);
                    _keepTextInputFocused();
                  },
                ),
              ),
            if (_draggingTextOverlayId != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 86,
                child: Center(
                  child: _ChatTextDeleteTarget(
                    key: _textDeleteTargetKey,
                    isActive: _isTextOverDeleteTarget,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatEditorToolMenu extends StatelessWidget {
  const _ChatEditorToolMenu({
    required this.isExpanded,
    required this.isCropSelected,
    required this.isDrawingSelected,
    required this.onToggle,
    required this.onSave,
    required this.onCrop,
    required this.onText,
    required this.onDraw,
  });

  final bool isExpanded;
  final bool isCropSelected;
  final bool isDrawingSelected;
  final VoidCallback onToggle;
  final VoidCallback onSave;
  final VoidCallback onCrop;
  final VoidCallback onText;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatEditorIconButton(
          icon: Icons.add_rounded,
          tooltip: isExpanded ? 'Werkzeuge schließen' : 'Werkzeuge öffnen',
          isSelected: isExpanded,
          onTap: onToggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !isExpanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ChatEditorIconButton(
                        icon: Icons.download_rounded,
                        iconColor: Colors.white,
                        tooltip: 'In Galerie speichern',
                        onTap: onSave,
                      ),
                      const SizedBox(height: 8),
                      _ChatEditorIconButton(
                        icon: Icons.crop_rotate_rounded,
                        iconColor: Colors.white,
                        tooltip: 'Zuschneiden',
                        isSelected: isCropSelected,
                        onTap: onCrop,
                      ),
                      const SizedBox(height: 8),
                      _ChatEditorIconButton(
                        icon: Icons.text_fields_rounded,
                        iconColor: Colors.white,
                        tooltip: 'Text hinzufügen',
                        onTap: onText,
                      ),
                      const SizedBox(height: 8),
                      _ChatEditorIconButton(
                        icon: Icons.draw_rounded,
                        iconColor: Colors.white,
                        tooltip: 'Zeichnen',
                        isSelected: isDrawingSelected,
                        onTap: onDraw,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChatMediaSendBar extends StatelessWidget {
  const _ChatMediaSendBar({
    required this.controller,
    required this.isViewOnce,
    required this.isBusy,
    required this.onToggleViewOnce,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isViewOnce;
  final bool isBusy;
  final VoidCallback onToggleViewOnce;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleViewOnce,
            child: Tooltip(
              message: isViewOnce
                  ? 'Einmal ansehen aktiviert'
                  : 'Einmal ansehen',
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaRismaDesignTokens.controlSurface,
                  border: Border.all(
                    color: isViewOnce
                        ? CaRismaDesignTokens.bluePrimary
                        : Colors.white.withValues(alpha: 0.11),
                    width: isViewOnce ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.36),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                    if (isViewOnce)
                      BoxShadow(
                        color: CaRismaDesignTokens.bluePrimary.withValues(
                          alpha: 0.30,
                        ),
                        blurRadius: 18,
                      ),
                  ],
                ),
                child: _ChatViewOnceGlyph(
                  color: Colors.white,
                  isActive: isViewOnce,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Bildunterschrift hinzufügen',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                ),
                filled: true,
                fillColor: CaRismaDesignTokens.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: CaRismaDesignTokens.bluePrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isBusy ? null : onSend,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CaRismaDesignTokens.bluePrimary,
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatViewOnceGlyph extends StatelessWidget {
  const _ChatViewOnceGlyph({required this.color, required this.isActive});

  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: CustomPaint(
        painter: _ChatViewOnceGlyphPainter(color: color, isActive: isActive),
        child: Center(
          child: Text(
            '1',
            style: TextStyle(
              color: color,
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatViewOnceGlyphPainter extends CustomPainter {
  const _ChatViewOnceGlyphPainter({
    required this.color,
    required this.isActive,
  });

  final Color color;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isActive ? 2.5 : 2.1;
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawArc(rect, -1.15, 5.45, false, stroke);
  }

  @override
  bool shouldRepaint(covariant _ChatViewOnceGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isActive != isActive;
  }
}

class _ChatViewOnceMediaScreen extends StatefulWidget {
  const _ChatViewOnceMediaScreen({required this.message});

  final _LocalChatMessage message;

  @override
  State<_ChatViewOnceMediaScreen> createState() =>
      _ChatViewOnceMediaScreenState();
}

class _ChatViewOnceMediaScreenState extends State<_ChatViewOnceMediaScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.message.isVideo) {
      unawaited(_initializeVideo());
    }
  }

  Future<void> _initializeVideo() async {
    final source = widget.message.fileUrl?.trim() ?? '';
    if (source.isEmpty) {
      setState(() => _videoError = 'Video konnte nicht geladen werden.');
      return;
    }

    setState(() => _isVideoLoading = true);
    try {
      final controller =
          source.startsWith('http://') || source.startsWith('https://')
          ? VideoPlayerController.networkUrl(Uri.parse(source))
          : VideoPlayerController.file(File(source));
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _isVideoLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVideoLoading = false;
        _videoError = 'Video konnte nicht geladen werden.';
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildImage() {
    final source = widget.message.imageUrl?.trim() ?? '';
    if (source.isEmpty) {
      return const Center(
        child: Text(
          'Foto konnte nicht geladen werden.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final image = source.startsWith('http://') || source.startsWith('https://')
        ? Image.network(
            source,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                'Foto konnte nicht geladen werden.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        : Image.file(
            File(source),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                'Foto konnte nicht geladen werden.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(child: image),
    );
  }

  Widget _buildVideo() {
    if (_isVideoLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: CaRismaDesignTokens.bluePrimary,
        ),
      );
    }
    if (_videoError != null) {
      return Center(
        child: Text(
          _videoError!,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            if (!controller.value.isPlaying)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.58),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.message.text.trim();
    final hasCaption =
        caption.isNotEmpty && caption != 'Foto' && caption != 'Video';

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.message.isVideo ? _buildVideo() : _buildImage(),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CaRismaDesignTokens.card.withValues(alpha: 0.88),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
              if (hasCaption)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
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
}

class _ChatEditorIconButton extends StatelessWidget {
  const _ChatEditorIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isSelected = false,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isSelected;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: _CaRismaActionCircle(
          icon: icon,
          size: 56,
          iconSize: 28,
          iconColor: iconColor,
          isActive: isSelected,
        ),
      ),
    );
  }
}

class _ChatCropControls extends StatelessWidget {
  const _ChatCropControls({
    required this.onReset,
    required this.onRotate,
    required this.onDone,
  });

  final VoidCallback onReset;
  final VoidCallback onRotate;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('crop-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatEditorIconButton(
          icon: Icons.check_rounded,
          tooltip: 'Ausschnitt übernehmen',
          onTap: onDone,
          iconColor: CaRismaDesignTokens.success,
        ),
        const SizedBox(width: 8),
        _ChatEditorIconButton(
          icon: Icons.restart_alt_rounded,
          tooltip: 'Ausschnitt zurücksetzen',
          onTap: onReset,
          iconColor: CaRismaDesignTokens.danger,
        ),
        const SizedBox(width: 8),
        _ChatEditorIconButton(
          icon: Icons.rotate_90_degrees_cw_rounded,
          tooltip: 'Drehen',
          onTap: onRotate,
        ),
      ],
    );
  }
}

class _ChatTextDeleteTarget extends StatelessWidget {
  const _ChatTextDeleteTarget({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: isActive ? 62 : 54,
      height: isActive ? 62 : 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(
          CaRismaDesignTokens.controlSurface,
          CaRismaDesignTokens.danger,
          isActive ? 0.18 : 0,
        ),
        border: Border.all(
          color: isActive
              ? CaRismaDesignTokens.danger.withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: CaRismaDesignTokens.danger,
        size: 28,
      ),
    );
  }
}

enum _ChatCropDragMode {
  move,
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _ChatFreeCropOverlay extends StatefulWidget {
  const _ChatFreeCropOverlay({required this.cropRect, required this.onChanged});

  final Rect cropRect;
  final ValueChanged<Rect> onChanged;

  @override
  State<_ChatFreeCropOverlay> createState() => _ChatFreeCropOverlayState();
}

class _ChatFreeCropOverlayState extends State<_ChatFreeCropOverlay> {
  static const double _edgeTolerance = 72;
  static const double _minimumNormalizedSize = 0.16;

  _ChatCropDragMode _dragMode = _ChatCropDragMode.move;
  late Rect _workingRect;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _workingRect = widget.cropRect;
  }

  @override
  void didUpdateWidget(covariant _ChatFreeCropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.cropRect != widget.cropRect) {
      _workingRect = widget.cropRect;
    }
  }

  Rect _pixelRect(Size size, Rect normalizedRect) {
    return Rect.fromLTRB(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.right * size.width,
      normalizedRect.bottom * size.height,
    );
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    _isDragging = true;
    _workingRect = widget.cropRect;
    final rect = _pixelRect(size, _workingRect);
    final point = details.localPosition;
    final leftDistance = (point.dx - rect.left).abs();
    final rightDistance = (point.dx - rect.right).abs();
    final topDistance = (point.dy - rect.top).abs();
    final bottomDistance = (point.dy - rect.bottom).abs();
    var nearLeft = leftDistance <= _edgeTolerance;
    var nearRight = rightDistance <= _edgeTolerance;
    var nearTop = topDistance <= _edgeTolerance;
    var nearBottom = bottomDistance <= _edgeTolerance;

    if (nearLeft && nearRight) {
      nearLeft = leftDistance <= rightDistance;
      nearRight = !nearLeft;
    }
    if (nearTop && nearBottom) {
      nearTop = topDistance <= bottomDistance;
      nearBottom = !nearTop;
    }

    _dragMode = switch ((nearLeft, nearRight, nearTop, nearBottom)) {
      (true, _, true, _) => _ChatCropDragMode.topLeft,
      (_, true, true, _) => _ChatCropDragMode.topRight,
      (true, _, _, true) => _ChatCropDragMode.bottomLeft,
      (_, true, _, true) => _ChatCropDragMode.bottomRight,
      (true, _, _, _) => _ChatCropDragMode.left,
      (_, true, _, _) => _ChatCropDragMode.right,
      (_, _, true, _) => _ChatCropDragMode.top,
      (_, _, _, true) => _ChatCropDragMode.bottom,
      _ => _ChatCropDragMode.move,
    };
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;
    final current = _workingRect;

    if (_dragMode == _ChatCropDragMode.move) {
      final left = (current.left + dx)
          .clamp(0.0, 1.0 - current.width)
          .toDouble();
      final top = (current.top + dy)
          .clamp(0.0, 1.0 - current.height)
          .toDouble();
      final next = Rect.fromLTWH(left, top, current.width, current.height);
      _workingRect = next;
      widget.onChanged(next);
      return;
    }

    var left = current.left;
    var top = current.top;
    var right = current.right;
    var bottom = current.bottom;

    final movesLeft = switch (_dragMode) {
      _ChatCropDragMode.left ||
      _ChatCropDragMode.topLeft ||
      _ChatCropDragMode.bottomLeft => true,
      _ => false,
    };
    final movesRight = switch (_dragMode) {
      _ChatCropDragMode.right ||
      _ChatCropDragMode.topRight ||
      _ChatCropDragMode.bottomRight => true,
      _ => false,
    };
    final movesTop = switch (_dragMode) {
      _ChatCropDragMode.top ||
      _ChatCropDragMode.topLeft ||
      _ChatCropDragMode.topRight => true,
      _ => false,
    };
    final movesBottom = switch (_dragMode) {
      _ChatCropDragMode.bottom ||
      _ChatCropDragMode.bottomLeft ||
      _ChatCropDragMode.bottomRight => true,
      _ => false,
    };

    if (movesLeft) {
      left = (left + dx).clamp(0.0, right - _minimumNormalizedSize).toDouble();
    }
    if (movesRight) {
      right = (right + dx).clamp(left + _minimumNormalizedSize, 1.0).toDouble();
    }
    if (movesTop) {
      top = (top + dy).clamp(0.0, bottom - _minimumNormalizedSize).toDouble();
    }
    if (movesBottom) {
      bottom = (bottom + dy)
          .clamp(top + _minimumNormalizedSize, 1.0)
          .toDouble();
    }

    final next = Rect.fromLTRB(left, top, right, bottom);
    _workingRect = next;
    widget.onChanged(next);
  }

  void _handlePanEnd() {
    _isDragging = false;
    _workingRect = widget.cropRect;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _handlePanStart(details, size),
          onPanUpdate: (details) => _handlePanUpdate(details, size),
          onPanEnd: (_) => _handlePanEnd(),
          onPanCancel: _handlePanEnd,
          child: CustomPaint(
            painter: _ChatCropOverlayPainter(cropRect: widget.cropRect),
          ),
        );
      },
    );
  }
}

class _ChatCropOverlayPainter extends CustomPainter {
  const _ChatCropOverlayPainter({required this.cropRect});

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(crop),
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.60),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(crop, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.48)
      ..strokeWidth = 1;
    for (var index = 1; index < 3; index++) {
      final fraction = index / 3;
      final x = crop.left + crop.width * fraction;
      final y = crop.top + crop.height * fraction;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), gridPaint);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), gridPaint);
    }

    final handlePaint = Paint()
      ..color = CaRismaDesignTokens.blueBright
      ..style = PaintingStyle.fill;
    for (final point in <Offset>[
      crop.topLeft,
      crop.topRight,
      crop.bottomLeft,
      crop.bottomRight,
    ]) {
      canvas.drawCircle(point, 11, handlePaint);
      canvas.drawCircle(point, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatCropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

class _ChatDrawingControls extends StatelessWidget {
  const _ChatDrawingControls({
    required this.colors,
    required this.selectedColor,
    required this.width,
    required this.canUndo,
    required this.onSelectColor,
    required this.onWidthChanged,
    required this.onUndo,
    required this.onReset,
    required this.onDone,
  });

  final List<Color> colors;
  final Color selectedColor;
  final double width;
  final bool canUndo;
  final ValueChanged<Color> onSelectColor;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('drawing-controls'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final color in colors) ...[
                _ChatEditorColorButton(
                  color: color,
                  isSelected: color == selectedColor,
                  onTap: () => onSelectColor(color),
                ),
                const SizedBox(width: 7),
              ],
              const Spacer(),
              IconButton(
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
                color: Colors.white,
                tooltip: 'Letzten Strich entfernen',
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.line_weight_rounded, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: width,
                  min: 2,
                  max: 18,
                  activeColor: CaRismaDesignTokens.bluePrimary,
                  onChanged: onWidthChanged,
                ),
              ),
              IconButton(
                onPressed: canUndo ? onReset : null,
                icon: const Icon(Icons.restart_alt_rounded),
                color: CaRismaDesignTokens.danger,
                disabledColor: CaRismaDesignTokens.danger.withValues(
                  alpha: 0.34,
                ),
                tooltip: 'Zeichnung zurücksetzen',
              ),
              IconButton(
                onPressed: onDone,
                icon: const Icon(Icons.check_rounded),
                color: CaRismaDesignTokens.success,
                tooltip: 'Zeichnung übernehmen',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatEditorColorButton extends StatelessWidget {
  const _ChatEditorColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 2,
            color: isSelected
                ? CaRismaDesignTokens.blueBright
                : Colors.transparent,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
        ),
      ),
    );
  }
}

class _ChatDrawingPainter extends CustomPainter {
  const _ChatDrawingPainter({required this.strokes});

  final List<_ChatDrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatDrawingPainter oldDelegate) => true;
}

class _ChatDrawingStroke {
  _ChatDrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;
}

class _ChatImageTextOverlay {
  const _ChatImageTextOverlay({
    required this.id,
    required this.text,
    required this.color,
    required this.position,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.textAlign,
    required this.fontFamily,
  });

  final String id;
  final String text;
  final Color color;
  final Offset position;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign textAlign;
  final String fontFamily;

  String? get effectiveFontFamily {
    return switch (fontFamily) {
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

  _ChatImageTextOverlay copyWith({Offset? position}) {
    return _ChatImageTextOverlay(
      id: id,
      text: text,
      color: color,
      position: position ?? this.position,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      textAlign: textAlign,
      fontFamily: fontFamily,
    );
  }
}
