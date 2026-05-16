part of '../chats_screen.dart';

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.hasText,
    required this.onPickPhoto,
    required this.onTakePhoto,
    required this.onShareLocation,
    required this.onShareContact,
    required this.onPickDocument,
    required this.onSend,
    required this.onVoiceMemo,
    required this.isRecordingVoiceMemo,
    required this.onTextInputFocus,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onPickPhoto;
  final VoidCallback onTakePhoto;
  final VoidCallback onShareLocation;
  final VoidCallback onShareContact;
  final VoidCallback onPickDocument;
  final VoidCallback onSend;
  final VoidCallback onVoiceMemo;
  final bool isRecordingVoiceMemo;
  final VoidCallback onTextInputFocus;

  Future<void> _openAttachmentSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101827),
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
                    color: Colors.white.withValues(alpha: 0.24),
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
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
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
                      icon: Icons.photo_camera_rounded,
                      label: 'Kamera',
                      onTap: () {
                        Navigator.of(context).pop();
                        onTakePhoto();
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
                      icon: Icons.person_rounded,
                      label: 'Kontakt',
                      onTap: () {
                        Navigator.of(context).pop();
                        onShareContact();
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
    final sendIcon = hasText
        ? Icons.send_rounded
        : isRecordingVoiceMemo
        ? Icons.stop_rounded
        : Icons.mic_rounded;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _ComposerIconButton(
              icon: Icons.add_rounded,
              onTap: () => _openAttachmentSheet(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onTap: onTextInputFocus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Nachricht schreiben',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(
              isEnabled: true,
              icon: sendIcon,
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
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(icon, color: Colors.white, size: 27),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.icon,
    this.isRecording = false,
    required this.onTap,
  });

  final bool isEnabled;
  final IconData icon;
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
          width: 46,
          height: 46,
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
                            _myMessageBlueDark,
                            _myMessageBlue,
                            _myMessageBlueLight,
                          ],
                  )
                : null,
            color: isEnabled ? null : Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.0 : 0.14),
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: _carmaBlue.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Icon(
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
