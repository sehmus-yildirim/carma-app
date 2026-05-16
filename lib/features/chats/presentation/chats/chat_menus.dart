part of '../chats_screen.dart';

class _ChatOverflowMenu extends StatelessWidget {
  static final FirestoreChatRepository _chatRepository =
      FirestoreChatRepository();

  const _ChatOverflowMenu({
    this.chatId,
    this.title,
    this.subtitle,
    this.isFavorite = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isUnread = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.popAfterStatusAction = true,
  });

  final String? chatId;
  final String? title;
  final String? subtitle;
  final bool isFavorite;
  final bool isPinned;
  final bool isMuted;
  final bool isUnread;
  final bool isArchived;
  final bool isBlocked;
  final bool popAfterStatusAction;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showVehicleDetails(BuildContext context) async {
    final safeTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Carma Nutzer';

    final safeSubtitle = subtitle?.trim().isNotEmpty == true
        ? subtitle!.trim()
        : 'Fahrzeugdetails sind aktuell nicht verf\u00FCgbar.';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _myMessageBlueDark,
                  _myMessageBlue,
                  _myMessageBlueLight,
                ],
              ),
              border: Border.all(color: _myMessageBorder),
              boxShadow: [
                BoxShadow(
                  color: _carmaBlue.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _UserAvatarPlaceholder(size: 42, imageUrl: null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fahrzeugdetails',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                      tooltip: 'Schlie\u00DFen',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  safeTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Text(
                    safeSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required String resultMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      _showSnackBar(context, resultMessage);
    }
  }

  Future<void> _runReportAction(BuildContext context) async {
    final id = chatId?.trim();

    if (id == null || id.isEmpty) {
      _showSnackBar(
        context,
        'Diese Aktion ist f\u00FCr lokale Beispielchats noch nicht verf\u00FCgbar.',
      );
      return;
    }

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          title: const Text(
            'Nutzer melden?',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Grund optional eingeben',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Melden'),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (confirmed != true) {
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      await _chatRepository.reportChat(
        chatId: id,
        reporterUserId: currentUserId,
        reason: reason.isEmpty ? 'Chat gemeldet' : reason,
      );

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Meldung wurde gesendet.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Meldung konnte nicht gesendet werden: $error');
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    _ChatMenuAction action,
  ) async {
    switch (action) {
      case _ChatMenuAction.pin:
        final nextIsPinned = !isPinned;
        await _runChatPreferenceAction(
          context: context,
          successMessage: nextIsPinned
              ? 'Chat wurde angepinnt.'
              : 'Chat wurde gel\u00F6st.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatPinned(
              chatId: chatId,
              userId: userId,
              isPinned: nextIsPinned,
            );
          },
        );
      case _ChatMenuAction.favorite:
        final nextIsFavorite = !isFavorite;
        await _runChatPreferenceAction(
          context: context,
          successMessage: nextIsFavorite
              ? 'Chat wurde zu Favoriten hinzugefuegt.'
              : 'Chat wurde aus Favoriten entfernt.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatFavorite(
              chatId: chatId,
              userId: userId,
              isFavorite: nextIsFavorite,
            );
          },
        );
      case _ChatMenuAction.mute:
        final nextIsMuted = !isMuted;
        await _runChatPreferenceAction(
          context: context,
          successMessage: nextIsMuted
              ? 'Chat wurde stummgeschaltet.'
              : 'Benachrichtigungen wurden eingeschaltet.',
          action: ({required String chatId, required String userId}) async {
            await _chatRepository.setChatMuted(
              chatId: chatId,
              userId: userId,
              isMuted: nextIsMuted,
            );
          },
        );
      case _ChatMenuAction.readState:
        await _runChatPreferenceAction(
          context: context,
          successMessage: isUnread
              ? 'Chat wurde als gelesen markiert.'
              : 'Chat wurde als ungelesen markiert.',
          action: ({required String chatId, required String userId}) async {
            if (isUnread) {
              await _chatRepository.markChatRead(
                chatId: chatId,
                userId: userId,
              );
            } else {
              await _chatRepository.markChatUnread(
                chatId: chatId,
                userId: userId,
              );
            }
          },
        );
      case _ChatMenuAction.vehicleDetails:
        await _showVehicleDetails(context);
      case _ChatMenuAction.archive:
        await _runChatStatusAction(
          context: context,
          title: isArchived ? 'Chat aus Archiv holen?' : 'Chat archivieren?',
          message: isArchived
              ? 'Der Chat wird wieder in deiner aktiven \u00DCbersicht angezeigt.'
              : 'Der Chat wird aus der aktiven \u00DCbersicht entfernt, bleibt aber f\u00FCr Sicherheit und Meldungen nachvollziehbar.',
          confirmLabel: isArchived ? 'Zur\u00FCckholen' : 'Archivieren',
          successMessage: isArchived
              ? 'Chat wurde aus dem Archiv geholt.'
              : 'Chat wurde archiviert.',
          action: () async {
            final id = chatId?.trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            if (currentUserId == null || currentUserId.isEmpty) {
              throw StateError('Du musst angemeldet sein.');
            }

            if (isArchived) {
              await _chatRepository.unarchiveChat(
                chatId: id,
                userId: currentUserId,
              );
            } else {
              await _chatRepository.archiveChat(
                chatId: id,
                userId: currentUserId,
              );
            }
          },
        );
      case _ChatMenuAction.delete:
        await _runChatStatusAction(
          context: context,
          title: 'Chat l\u00F6schen?',
          message:
              'Der Chat wird aus deiner aktiven \u00DCbersicht entfernt. Sicherheitsrelevante Daten k\u00F6nnen gesch\u00FCtzt erhalten bleiben.',
          confirmLabel: 'L\u00F6schen',
          successMessage: 'Chat wurde gel\u00F6scht.',
          action: () async {
            final id = chatId?.trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            if (currentUserId == null || currentUserId.isEmpty) {
              throw StateError('Du musst angemeldet sein.');
            }

            await _chatRepository.deleteChat(chatId: id, userId: currentUserId);
          },
        );
      case _ChatMenuAction.block:
        await _runChatStatusAction(
          context: context,
          title: 'Nutzer blockieren?',
          message:
              'Blockierte Nutzer k\u00F6nnen dich nicht mehr \u00FCber diesen Chat kontaktieren.',
          confirmLabel: 'Blockieren',
          successMessage: 'Nutzer wurde blockiert.',
          action: () async {
            final id = chatId?.trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            if (currentUserId == null || currentUserId.isEmpty) {
              throw StateError('Du musst angemeldet sein.');
            }

            await _chatRepository.blockChat(
              chatId: id,
              blockedByUserId: currentUserId,
            );
          },
        );
      case _ChatMenuAction.unblock:
        await _runChatStatusAction(
          context: context,
          title: 'Blockierung aufheben?',
          message:
              'Der Chat wird wieder freigegeben und kann erneut Nachrichten empfangen.',
          confirmLabel: 'Aufheben',
          successMessage: 'Blockierung wurde aufgehoben.',
          action: () async {
            final id = chatId?.trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            if (id == null || id.isEmpty) {
              throw StateError('Chat-ID fehlt.');
            }

            if (currentUserId == null || currentUserId.isEmpty) {
              throw StateError('Du musst angemeldet sein.');
            }

            await _chatRepository.unblockChat(
              chatId: id,
              userId: currentUserId,
            );
          },
        );
      case _ChatMenuAction.report:
        await _runReportAction(context);
    }
  }

  Future<void> _runChatPreferenceAction({
    required BuildContext context,
    required Future<void> Function({
      required String chatId,
      required String userId,
    })
    action,
    required String successMessage,
  }) async {
    final id = chatId?.trim();

    if (id == null || id.isEmpty) {
      _showSnackBar(
        context,
        'Diese Aktion ist f\u00FCr lokale Beispielchats noch nicht verf\u00FCgbar.',
      );
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      await action(chatId: id, userId: currentUserId);

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, successMessage);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Aktion konnte nicht ausgef\u00FChrt werden: $error',
      );
    }
  }

  Future<void> _runChatStatusAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final id = chatId?.trim();

    if (id == null || id.isEmpty) {
      _showSnackBar(
        context,
        'Diese Aktion ist f\u00FCr lokale Beispielchats noch nicht verf\u00FCgbar.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101827),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.76)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await action();

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, successMessage);
      if (popAfterStatusAction) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Aktion konnte nicht ausgef\u00FChrt werden: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChatMenuAction>(
      tooltip: 'Chat-Einstellungen',
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
      color: const Color(0xFF101827),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) {
        return [
          if (isBlocked)
            const PopupMenuItem(
              value: _ChatMenuAction.unblock,
              child: Text('Blockierung aufheben'),
            )
          else ...[
            PopupMenuItem(
              value: _ChatMenuAction.pin,
              child: Text(isPinned ? 'Nicht mehr anpinnen' : 'Chat anpinnen'),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.favorite,
              child: Text(
                isFavorite
                    ? 'Aus Favoriten entfernen'
                    : 'Zu Favoriten hinzufuegen',
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.mute,
              child: Text(
                isMuted
                    ? 'Benachrichtigungen einschalten'
                    : 'Benachrichtigungen stummschalten',
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.readState,
              child: Text(
                isUnread ? 'Als gelesen markieren' : 'Als ungelesen markieren',
              ),
            ),
          ],
          const PopupMenuItem(
            value: _ChatMenuAction.vehicleDetails,
            child: Text('Fahrzeugdetails anzeigen'),
          ),
          if (!isBlocked) ...[
            PopupMenuItem(
              value: _ChatMenuAction.archive,
              child: Text(isArchived ? 'Aus Archiv holen' : 'Chat archivieren'),
            ),
            const PopupMenuItem(
              value: _ChatMenuAction.delete,
              child: Text('Chat l\u00F6schen'),
            ),
            const PopupMenuItem(
              value: _ChatMenuAction.block,
              child: Text('Nutzer blockieren'),
            ),
          ],
          const PopupMenuItem(
            value: _ChatMenuAction.report,
            child: Text('Nutzer melden'),
          ),
        ];
      },
    );
  }
}

// ignore: unused_element
