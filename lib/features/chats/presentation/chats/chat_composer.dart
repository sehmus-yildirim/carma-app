part of '../chats_screen.dart';

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onPickPhoto,
    required this.onTakePhoto,
    required this.onShareLocation,
    required this.onShareContact,
    required this.onPickDocument,
    required this.onSend,
    required this.onVoiceMemo,
    required this.isSending,
    required this.isEnabled,
    this.disabledMessage,
    required this.isRecordingVoiceMemo,
    required this.voiceMemoRecordingSeconds,
    required this.onTextInputFocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onPickPhoto;
  final VoidCallback onTakePhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onShareContact;
  final VoidCallback onPickDocument;
  final VoidCallback onSend;
  final VoidCallback onVoiceMemo;
  final bool isSending;
  final bool isEnabled;
  final String? disabledMessage;
  final bool isRecordingVoiceMemo;
  final int voiceMemoRecordingSeconds;
  final VoidCallback onTextInputFocus;

  String _formatRecordingDuration() {
    final minutes = (voiceMemoRecordingSeconds ~/ 60).toString();
    final seconds = (voiceMemoRecordingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _openAttachmentSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CaRismaDesignTokens.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Anhang senden',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AttachmentSheetAction(
                      icon: Icons.photo_library_rounded,
                      label: 'Foto',
                      onTap: () {
                        Navigator.of(context).pop();
                        onPickPhoto();
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.person_rounded,
                      label: 'Kontakt',
                      onTap: () {
                        Navigator.of(context).pop();
                        onShareContact();
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.location_on_rounded,
                      label: 'Standort',
                      onTap: () {
                        Navigator.of(context).pop();
                        onShareLocation();
                      },
                    ),
                    _AttachmentSheetAction(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Dokument',
                      onTap: () {
                        Navigator.of(context).pop();
                        onPickDocument();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUseComposer = isEnabled && !isSending;
    final hintText = !isEnabled
        ? disabledMessage ?? 'Chat nicht verfügbar'
        : isRecordingVoiceMemo
        ? 'Aufnahme ${_formatRecordingDuration()}'
        : 'Nachricht schreiben';
    final sendIcon = hasText
        ? Icons.send_rounded
        : isRecordingVoiceMemo
        ? Icons.stop_rounded
        : Icons.mic_rounded;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ComposerIconButton(
              icon: Icons.add_rounded,
              onTap: canUseComposer
                  ? () => _openAttachmentSheet(context)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: !canUseComposer,
                onTap: isEnabled ? onTextInputFocus : null,
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.newline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isEnabled
                      ? CaRismaDesignTokens.textPrimary
                      : CaRismaDesignTokens.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintMaxLines: 1,
                  hintStyle: TextStyle(
                    color: !isEnabled
                        ? CaRismaDesignTokens.textMuted
                        : isRecordingVoiceMemo
                        ? const Color(0xFFFF8A9A)
                        : CaRismaDesignTokens.textMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                  filled: true,
                  fillColor: isEnabled
                      ? CaRismaDesignTokens.surface2.withValues(alpha: 0.82)
                      : CaRismaDesignTokens.surface1.withValues(alpha: 0.72),
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
            const SizedBox(width: 8),
            _ComposerIconButton(
              icon: Icons.photo_camera_rounded,
              onTap: canUseComposer ? onTakePhoto : null,
            ),
            const SizedBox(width: 8),
            _SendButton(
              isEnabled: canUseComposer,
              icon: sendIcon,
              isBusy: isSending,
              isRecording: isRecordingVoiceMemo && !hasText,
              onTap: hasText ? onSend : onVoiceMemo,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSheetAction extends StatelessWidget {
  const _AttachmentSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: CaRismaDesignTokens.surface2.withValues(alpha: 0.86),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Icon(icon, color: Colors.white, size: 25),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CaRismaDesignTokens.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CaRismaDesignTokens.controlSurface,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(
            icon,
            color: onTap == null
                ? Colors.white.withValues(alpha: 0.38)
                : CaRismaDesignTokens.textPrimary,
            size: 22,
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
    this.isRecording = false,
    required this.onTap,
  });

  final bool isEnabled;
  final IconData icon;
  final bool isBusy;
  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isRecording
                        ? const [
                            Color(0xFFE84B5F),
                            Color(0xFFD71F3C),
                            Color(0xFF9F1430),
                          ]
                        : const [
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
