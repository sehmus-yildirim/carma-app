part of '../chats_screen.dart';

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onOpenGallery,
    required this.onOpenCamera,
    required this.onShareLocation,
    required this.onShareContact,
    required this.onPickDocument,
    required this.onSend,
    required this.onVoiceMemoStart,
    required this.onVoiceMemoStop,
    required this.onVoiceMemoCancel,
    required this.onVoiceMemoLock,
    required this.isVoiceMemoLocked,
    required this.isAttachmentPanelVisible,
    required this.onToggleAttachmentPanel,
    required this.isSending,
    required this.isEnabled,
    this.disabledMessage,
    required this.isRecordingVoiceMemo,
    required this.voiceMemoRecordingSeconds,
    required this.onTextInputFocus,
    this.attachmentUploadProgress,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onOpenGallery;
  final VoidCallback onOpenCamera;
  final VoidCallback onShareLocation;
  final VoidCallback onShareContact;
  final VoidCallback onPickDocument;
  final VoidCallback onSend;
  final VoidCallback onVoiceMemoStart;
  final VoidCallback onVoiceMemoStop;
  final VoidCallback onVoiceMemoCancel;
  final VoidCallback onVoiceMemoLock;
  final bool isVoiceMemoLocked;
  final bool isAttachmentPanelVisible;
  final VoidCallback onToggleAttachmentPanel;
  final bool isSending;
  final bool isEnabled;
  final String? disabledMessage;
  final bool isRecordingVoiceMemo;
  final int voiceMemoRecordingSeconds;
  final VoidCallback onTextInputFocus;
  final double? attachmentUploadProgress;

  String _formatRecordingDuration() {
    final minutes = (voiceMemoRecordingSeconds ~/ 60).toString();
    final seconds = (voiceMemoRecordingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _runAttachmentAction(_ChatAttachmentAction action) {
    switch (action) {
      case _ChatAttachmentAction.media:
        onOpenGallery();
        return;
      case _ChatAttachmentAction.contact:
        onShareContact();
        return;
      case _ChatAttachmentAction.location:
        onShareLocation();
        return;
      case _ChatAttachmentAction.document:
        onPickDocument();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final canUseComposer = isEnabled && !isSending;
    final hintText = !isEnabled
        ? disabledMessage ?? 'Chat nicht verfügbar'
        : isRecordingVoiceMemo
        ? 'Aufnahme ${_formatRecordingDuration()}'
        : 'Nachricht schreiben';

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(14, 0, 14, isLandscape ? 2 : 10),
      child: GlassCard(
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: isLandscape ? 3 : 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachmentUploadProgress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: attachmentUploadProgress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    CaRismaDesignTokens.bluePrimary,
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AttachmentMenuAnchor(
                  isVisible: isAttachmentPanelVisible,
                  isEnabled: canUseComposer,
                  onToggle: onToggleAttachmentPanel,
                  onAction: _runAttachmentAction,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IgnorePointer(
                        ignoring: isRecordingVoiceMemo,
                        child: Opacity(
                          opacity: isRecordingVoiceMemo ? 0 : 1,
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            readOnly: !isEnabled,
                            onTap: isEnabled ? onTextInputFocus : null,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            scrollPadding: const EdgeInsets.only(bottom: 18),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isEnabled
                                      ? CaRismaDesignTokens.textPrimary
                                      : CaRismaDesignTokens.textMuted,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: hintText,
                              hintMaxLines: 1,
                              hintStyle: const TextStyle(
                                color: CaRismaDesignTokens.textMuted,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                              filled: true,
                              fillColor: isEnabled
                                  ? CaRismaDesignTokens.surface2.withValues(
                                      alpha: 0.82,
                                    )
                                  : CaRismaDesignTokens.surface1.withValues(
                                      alpha: 0.72,
                                    ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isRecordingVoiceMemo)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _VoiceMemoRecordingBar(
                              durationLabel: _formatRecordingDuration(),
                              isLocked: isVoiceMemoLocked,
                              onCancel: onVoiceMemoCancel,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isRecordingVoiceMemo) ...[
                  _ComposerIconButton(
                    icon: Icons.photo_camera_rounded,
                    tooltip: 'Kamera öffnen',
                    onTap: canUseComposer ? onOpenCamera : null,
                  ),
                  const SizedBox(width: 8),
                ],
                if (hasText)
                  _SendButton(
                    isEnabled: canUseComposer,
                    icon: Icons.send_rounded,
                    isBusy: isSending,
                    onTap: onSend,
                  )
                else if (isRecordingVoiceMemo && isVoiceMemoLocked)
                  _SendButton(
                    isEnabled: canUseComposer,
                    icon: Icons.send_rounded,
                    isBusy: isSending,
                    onTap: onVoiceMemoStop,
                  )
                else
                  _VoiceMemoGestureButton(
                    isEnabled: canUseComposer,
                    isRecording: isRecordingVoiceMemo,
                    onStart: onVoiceMemoStart,
                    onStop: onVoiceMemoStop,
                    onCancel: onVoiceMemoCancel,
                    onLock: onVoiceMemoLock,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatAttachmentAction { media, contact, location, document }

class _AttachmentMenuAnchor extends StatefulWidget {
  const _AttachmentMenuAnchor({
    required this.isVisible,
    required this.isEnabled,
    required this.onToggle,
    required this.onAction,
  });

  final bool isVisible;
  final bool isEnabled;
  final VoidCallback onToggle;
  final ValueChanged<_ChatAttachmentAction> onAction;

  @override
  State<_AttachmentMenuAnchor> createState() => _AttachmentMenuAnchorState();
}

class _AttachmentMenuAnchorState extends State<_AttachmentMenuAnchor> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(covariant _AttachmentMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible == oldWidget.isVisible) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (widget.isVisible) {
        _showMenu();
      } else {
        _hideMenu();
      }
    });
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _showMenu() {
    if (!mounted || !widget.isVisible) return;
    if (_overlayEntry != null) {
      return;
    }

    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _hideMenu() {
    final overlayEntry = _overlayEntry;
    _overlayEntry = null;
    if (overlayEntry?.mounted ?? false) {
      overlayEntry!.remove();
    }
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      width: 66,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -10),
        child: Material(
          type: MaterialType.transparency,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0.82, end: 1),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AttachmentFloatingAction(
                  icon: Icons.photo_library_rounded,
                  iconColor: CaRismaDesignTokens.blueBright,
                  label: 'Medien',
                  onTap: () => widget.onAction(_ChatAttachmentAction.media),
                ),
                _AttachmentFloatingAction(
                  icon: Icons.person_rounded,
                  iconColor: Colors.white,
                  label: 'Kontakt',
                  onTap: () => widget.onAction(_ChatAttachmentAction.contact),
                ),
                _AttachmentFloatingAction(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFF22C55E),
                  label: 'Standort',
                  onTap: () => widget.onAction(_ChatAttachmentAction.location),
                ),
                _AttachmentFloatingAction(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFFEF4444),
                  label: 'Dokument',
                  onTap: () => widget.onAction(_ChatAttachmentAction.document),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: _ComposerIconButton(
        icon: Icons.add_rounded,
        tooltip: widget.isVisible ? 'Anhänge schließen' : 'Anhänge öffnen',
        onTap: widget.isEnabled ? widget.onToggle : null,
      ),
    );
  }
}

class _AttachmentFloatingAction extends StatelessWidget {
  const _AttachmentFloatingAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _CaRismaActionCircle(
            size: 56,
            icon: icon,
            iconColor: iconColor,
            iconSize: 28,
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _CaRismaActionCircle(
          size: 46,
          icon: icon,
          iconColor: onTap == null
              ? Colors.white.withValues(alpha: 0.38)
              : CaRismaDesignTokens.textPrimary,
          iconSize: 25,
          isEnabled: onTap != null,
        ),
      ),
    );
  }
}

class _CaRismaActionCircle extends StatelessWidget {
  const _CaRismaActionCircle({
    required this.icon,
    this.size = 56,
    this.iconSize = 28,
    this.iconColor = Colors.white,
    this.isActive = false,
    this.isEnabled = true,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color iconColor;
  final bool isActive;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: isEnabled ? 1 : 0.42,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CaRismaDesignTokens.controlSurface,
          border: Border.all(
            color: isActive
                ? CaRismaDesignTokens.bluePrimary
                : Colors.white.withValues(alpha: 0.11),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            if (isActive)
              BoxShadow(
                color: CaRismaDesignTokens.bluePrimary.withValues(alpha: 0.3),
                blurRadius: 18,
              ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}

class _VoiceMemoRecordingBar extends StatelessWidget {
  const _VoiceMemoRecordingBar({
    required this.durationLabel,
    required this.isLocked,
    required this.onCancel,
  });

  final String durationLabel;
  final bool isLocked;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: CaRismaDesignTokens.surface2.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (isLocked) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.circle, color: Color(0xFFEF4444), size: 10),
          const SizedBox(width: 8),
          Text(
            durationLabel,
            style: const TextStyle(
              color: CaRismaDesignTokens.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          if (isLocked)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: CaRismaDesignTokens.textSecondary,
                  size: 18,
                ),
                SizedBox(width: 5),
                Text(
                  'Gesperrt',
                  style: TextStyle(
                    color: CaRismaDesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            const Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 19,
                  ),
                  SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      'Nach links',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CaRismaDesignTokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_left_rounded,
                    color: CaRismaDesignTokens.textSecondary,
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Icon(
                    Icons.lock_outline_rounded,
                    color: CaRismaDesignTokens.textSecondary,
                    size: 18,
                  ),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: CaRismaDesignTokens.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceMemoGestureButton extends StatefulWidget {
  const _VoiceMemoGestureButton({
    required this.isEnabled,
    required this.isRecording,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onLock,
  });

  final bool isEnabled;
  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback onLock;

  @override
  State<_VoiceMemoGestureButton> createState() =>
      _VoiceMemoGestureButtonState();
}

class _VoiceMemoGestureButtonState extends State<_VoiceMemoGestureButton> {
  static const double _cancelThreshold = -72;
  static const double _lockThreshold = -68;

  bool _isPressing = false;
  bool _isCancelled = false;
  bool _isLocked = false;

  void _handleTap() {
    if (!widget.isEnabled) {
      return;
    }

    HapticFeedback.mediumImpact();
    widget.onStart();
    widget.onLock();
  }

  void _handleLongPressStart(LongPressStartDetails _) {
    if (!widget.isEnabled) {
      return;
    }

    setState(() {
      _isPressing = true;
      _isCancelled = false;
      _isLocked = false;
    });
    HapticFeedback.mediumImpact();
    widget.onStart();
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_isPressing || _isCancelled || _isLocked) {
      return;
    }

    final offset = details.localOffsetFromOrigin;
    if (offset.dx <= _cancelThreshold) {
      setState(() {
        _isCancelled = true;
        _isPressing = false;
      });
      HapticFeedback.lightImpact();
      widget.onCancel();
      return;
    }

    if (offset.dy <= _lockThreshold) {
      setState(() {
        _isLocked = true;
        _isPressing = false;
      });
      HapticFeedback.mediumImpact();
      widget.onLock();
    }
  }

  void _handleLongPressEnd(LongPressEndDetails _) {
    if (_isCancelled || _isLocked || !_isPressing) {
      return;
    }

    setState(() {
      _isPressing = false;
    });
    widget.onStop();
  }

  void _handleLongPressCancel() {
    if (!_isPressing || _isLocked || _isCancelled) {
      return;
    }

    setState(() {
      _isPressing = false;
      _isCancelled = true;
    });
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isRecording || _isPressing;

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: 'Sprachmemo aufnehmen',
      hint:
          'Antippen für freie Aufnahme oder gedrückt halten, nach links abbrechen und nach oben sperren',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMove,
        onLongPressEnd: _handleLongPressEnd,
        onLongPressCancel: _handleLongPressCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isEnabled
                ? isActive
                      ? const Color(0xFFEF4444)
                      : CaRismaDesignTokens.bluePrimary
                : CaRismaDesignTokens.surface2.withValues(alpha: 0.72),
            boxShadow: widget.isEnabled
                ? [
                    BoxShadow(
                      color:
                          (isActive
                                  ? const Color(0xFFEF4444)
                                  : CaRismaDesignTokens.bluePrimary)
                              .withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Icon(
            Icons.mic_rounded,
            color: widget.isEnabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.42),
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.icon,
    this.isBusy = false,
    required this.onTap,
  });

  final bool isEnabled;
  final IconData icon;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isEnabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CaRismaDesignTokens.bluePrimary,
                      CaRismaDesignTokens.blueBright,
                    ],
                  )
                : null,
            color: isEnabled
                ? null
                : CaRismaDesignTokens.surface2.withValues(alpha: 0.72),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.0 : 0.14),
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: _carismaBlue.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: isBusy
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.42),
                  size: 22,
                ),
        ),
      ),
    );
  }
}
