part of '../chats_screen.dart';

class _ChatVehicleDetailPill extends StatelessWidget {
  const _ChatVehicleDetailPill({
    required this.icon,
    required this.title,
    required this.label,
  });

  final IconData icon;
  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: CaRismaDesignTokens.controlSurface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CaRismaDesignTokens.bluePrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatOverflowMenu extends StatelessWidget {
  static final FirestoreChatRepository _chatRepository =
      FirestoreChatRepository();
  static final Set<String> _runningChatActions = <String>{};

  const _ChatOverflowMenu({
    this.chatId,
    this.title,
    this.subtitle,
    this.vehicleLabel,
    this.plateLabel,
    this.isFavorite = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isUnread = false,
    this.isArchived = false,
    this.isBlocked = false,
    this.canUnblock,
    this.popAfterStatusAction = true,
  });

  final String? chatId;
  final String? title;
  final String? subtitle;
  final String? vehicleLabel;
  final String? plateLabel;
  final bool isFavorite;
  final bool isPinned;
  final bool isMuted;
  final bool isUnread;
  final bool isArchived;
  final bool isBlocked;
  final bool? canUnblock;
  final bool popAfterStatusAction;

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyActionError(Object error) {
    return _friendlyChatUiError(error);
  }

  String _runningActionKey(String chatId, String userId) {
    return '$chatId::$userId';
  }

  Future<void> _showVehicleDetails(BuildContext context) async {
    final safeTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'plaqa Nutzer';

    final safeSubtitle = subtitle?.trim().isNotEmpty == true
        ? subtitle!.trim()
        : 'Fahrzeugdetails sind aktuell nicht verfügbar.';
    final detailParts = safeSubtitle.split(RegExp(r'\s+-\s+'));
    final parsedVehicleLabel = detailParts.first.trim().isEmpty
        ? 'Fahrzeug'
        : detailParts.first.trim();
    final parsedPlateLabel = detailParts.length > 1
        ? _formatChatPlateLabel(detailParts.sublist(1).join(' - '))
        : '';
    final resolvedVehicleLabel = vehicleLabel?.trim().isNotEmpty == true
        ? vehicleLabel!.trim()
        : parsedVehicleLabel;
    final resolvedPlateLabel = plateLabel?.trim().isNotEmpty == true
        ? _formatChatPlateLabel(plateLabel)
        : parsedPlateLabel;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: CaRismaDesignTokens.surfaceDecoration(
              radius: 24,
              borderAlpha: 0.08,
              darkShadowAlpha: 0.56,
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
                      tooltip: 'Schließen',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ChatVehicleDetailPill(
                      icon: Icons.directions_car_filled_rounded,
                      title: 'Fahrzeug',
                      label: resolvedVehicleLabel,
                    ),
                    if (resolvedPlateLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ChatVehicleDetailPill(
                        icon: Icons.confirmation_number_rounded,
                        title: 'Kennzeichen',
                        label: resolvedPlateLabel,
                      ),
                    ],
                  ],
                ),
                if (resolvedPlateLabel.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    safeSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
          scrollable: true,
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
        'Diese Aktion ist für lokale Beispielchats noch nicht verfügbar.',
      );
      return;
    }

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: CaRismaDesignTokens.card,
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
              fillColor: CaRismaDesignTokens.controlSurface,
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

    if (!context.mounted) {
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      final runningActionKey = _runningActionKey(id, currentUserId);
      if (!_runningChatActions.add(runningActionKey)) {
        _showSnackBar(context, 'Eine Chat-Aktion wird bereits ausgeführt.');
        return;
      }

      try {
        await _chatRepository.reportChat(
          chatId: id,
          reporterUserId: currentUserId,
          reason: reason.isEmpty ? 'Chat gemeldet' : reason,
        );
      } finally {
        _runningChatActions.remove(runningActionKey);
      }

      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, 'Meldung wurde gesendet.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(
        context,
        'Meldung konnte nicht gesendet werden: ${_friendlyActionError(error)}',
      );
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
              : 'Chat wurde gelöst.',
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
              ? 'Chat wurde zu Favoriten hinzugefügt.'
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
              ? 'Der Chat wird wieder in deiner aktiven Übersicht angezeigt.'
              : 'Der Chat wird aus der aktiven Übersicht entfernt, bleibt aber für Sicherheit und Meldungen nachvollziehbar.',
          confirmLabel: isArchived ? 'Zurückholen' : 'Archivieren',
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
          title: 'Chat löschen?',
          message:
              'Der Chat wird aus deiner aktiven Übersicht entfernt. Sicherheitsrelevante Daten können geschützt erhalten bleiben.',
          confirmLabel: 'Löschen',
          successMessage: 'Chat wurde gelöscht.',
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
              'Blockierte Nutzer können dich nicht mehr über diesen Chat kontaktieren.',
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
        'Diese Aktion ist für lokale Beispielchats noch nicht verfügbar.',
      );
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      final runningActionKey = _runningActionKey(id, currentUserId);
      if (!_runningChatActions.add(runningActionKey)) {
        _showSnackBar(context, 'Eine Chat-Aktion wird bereits ausgeführt.');
        return;
      }

      try {
        await action(chatId: id, userId: currentUserId);
      } finally {
        _runningChatActions.remove(runningActionKey);
      }

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
        'Aktion konnte nicht ausgeführt werden: ${_friendlyActionError(error)}',
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
        'Diese Aktion ist für lokale Beispielchats noch nicht verfügbar.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: CaRismaDesignTokens.card,
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

    if (!context.mounted) {
      return;
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

      if (currentUserId.isEmpty) {
        throw StateError('Du musst angemeldet sein.');
      }

      final runningActionKey = _runningActionKey(id, currentUserId);
      if (!_runningChatActions.add(runningActionKey)) {
        _showSnackBar(context, 'Eine Chat-Aktion wird bereits ausgeführt.');
        return;
      }

      try {
        await action();
      } finally {
        _runningChatActions.remove(runningActionKey);
      }

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
        'Aktion konnte nicht ausgeführt werden: ${_friendlyActionError(error)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuTheme = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      popupMenuTheme: PopupMenuThemeData(
        color: CaRismaDesignTokens.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CaRismaDesignTokens.border),
        ),
      ),
    );

    return Theme(
      data: menuTheme,
      child: PopupMenuButton<_ChatMenuAction>(
        tooltip: 'Chat-Einstellungen',
        icon: const Icon(
          Icons.more_vert_rounded,
          color: CaRismaDesignTokens.textSecondary,
        ),
        color: CaRismaDesignTokens.surface1,
        onSelected: (action) => _handleAction(context, action),
        itemBuilder: (context) {
          return [
            if (isBlocked && (canUnblock ?? true))
              const PopupMenuItem(
                value: _ChatMenuAction.unblock,
                child: Text('Blockierung aufheben'),
              )
            else if (!isBlocked) ...[
              PopupMenuItem(
                value: _ChatMenuAction.pin,
                child: Text(isPinned ? 'Nicht mehr anpinnen' : 'Chat anpinnen'),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.favorite,
                child: Text(
                  isFavorite
                      ? 'Aus Favoriten entfernen'
                      : 'Zu Favoriten hinzufügen',
                ),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.mute,
                child: Text(
                  isMuted ? 'Stummschaltung aufheben' : 'Stummschalten',
                ),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.readState,
                child: Text(
                  isUnread
                      ? 'Als gelesen markieren'
                      : 'Als ungelesen markieren',
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
                child: Text(isArchived ? 'Aus Archiv holen' : 'Archivieren'),
              ),
              const PopupMenuItem(
                value: _ChatMenuAction.delete,
                child: Text('Chat löschen'),
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
      ),
    );
  }
}

// ignore: unused_element
