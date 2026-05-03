import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carma_models.dart';
import '../../../shared/widgets/carma_background.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/carma_sub_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/chat_repository.dart';
import '../data/contact_request_repository.dart';
import '../domain/accept_contact_request_use_case.dart';

enum ContactRequestListMode { incoming, outgoing }

class ContactRequestListScreen extends StatefulWidget {
  const ContactRequestListScreen({
    super.key,
    required this.userState,
    required this.mode,
  });

  final AppUserState userState;
  final ContactRequestListMode mode;

  @override
  State<ContactRequestListScreen> createState() =>
      _ContactRequestListScreenState();
}

class _ContactRequestListScreenState extends State<ContactRequestListScreen> {
  final FirestoreContactRequestRepository _repository =
      FirestoreContactRequestRepository();
  final FirestoreChatRepository _chatRepository = FirestoreChatRepository();

  late Future<List<ContactRequestRecord>> _future;

  final Set<String> _busyRequestIds = <String>{};

  bool get _isIncoming {
    return widget.mode == ContactRequestListMode.incoming;
  }

  String get _effectiveUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadRequests();
  }

  Future<List<ContactRequestRecord>> _loadRequests() {
    final userId = _effectiveUserId.trim();

    if (userId.isEmpty) {
      return Future.value(const <ContactRequestRecord>[]);
    }

    if (_isIncoming) {
      return _repository.loadIncomingRequests(userId: userId);
    }

    return _repository.loadOutgoingRequests(userId: userId);
  }

  void _reload() {
    setState(() {
      _future = _loadRequests();
    });
  }

  Future<void> _runRequestAction({
    required ContactRequestRecord request,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));

      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _acceptRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage:
          'Kontaktanfrage wurde angenommen. Ein Chat wurde erstellt.',
      action: () async {
        final useCase = AcceptContactRequestUseCase(
          contactRequestRepository: _repository,
          chatRepository: _chatRepository,
        );

        await useCase(request: request);
      },
    );
  }

  Future<void> _declineRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage: 'Kontaktanfrage wurde abgelehnt.',
      action: () async {
        await _repository.declineRequest(requestId: request.id);
      },
    );
  }

  Future<void> _withdrawRequest(ContactRequestRecord request) {
    return _runRequestAction(
      request: request,
      successMessage: 'Kontaktanfrage wurde zurückgezogen.',
      action: () async {
        await _repository.withdrawRequest(requestId: request.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return CarmaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 112 + keyboardInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarmaSubPageHeader(
                  icon: _isIncoming
                      ? Icons.move_to_inbox_rounded
                      : Icons.outbox_rounded,
                  title: _isIncoming
                      ? 'Eingehende Anfragen'
                      : 'Gesendete Anfragen',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 18),
                Text(
                  _isIncoming
                      ? 'Hier siehst du echte Kontaktanfragen, die andere Nutzer an dich gesendet haben.'
                      : 'Hier siehst du echte Kontaktanfragen, die du nach einer Kennzeichen-Suche gesendet hast.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<ContactRequestRecord>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _RequestLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return _RequestErrorCard(
                        error: snapshot.error.toString(),
                        onRetry: _reload,
                      );
                    }

                    final requests =
                        snapshot.data ?? const <ContactRequestRecord>[];

                    if (requests.isEmpty) {
                      return _RequestEmptyCard(isIncoming: _isIncoming);
                    }

                    return Column(
                      children: [
                        for (final request in requests) ...[
                          _RequestListCard(
                            request: request,
                            isIncoming: _isIncoming,
                            isBusy: _busyRequestIds.contains(request.id),
                            onAccept: () => _acceptRequest(request),
                            onDecline: () => _declineRequest(request),
                            onWithdraw: () => _withdrawRequest(request),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestListCard extends StatelessWidget {
  const _RequestListCard({
    required this.request,
    required this.isIncoming,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
  });

  final ContactRequestRecord request;
  final bool isIncoming;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;

  String get _title {
    return request.vehicleTitle;
  }

  String get _subtitle {
    return _safeText(request.displayPlate, request.plateKey);
  }

  static String _safeText(String? value, String fallback) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmaBlueIconBox(
            icon: isIncoming
                ? Icons.mark_email_unread_rounded
                : Icons.schedule_send_rounded,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kennzeichen: $_subtitle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    request.introMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                if (request.isPending) ...[
                  const SizedBox(height: 14),
                  _RequestActions(
                    isIncoming: isIncoming,
                    isBusy: isBusy,
                    onAccept: onAccept,
                    onDecline: onDecline,
                    onWithdraw: onWithdraw,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestActions extends StatelessWidget {
  const _RequestActions({
    required this.isIncoming,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
  });

  final bool isIncoming;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    if (isIncoming) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _RequestActionButton(
            label: 'Annehmen',
            icon: Icons.check_rounded,
            isBusy: isBusy,
            isPrimary: true,
            onPressed: onAccept,
          ),
          _RequestActionButton(
            label: 'Ablehnen',
            icon: Icons.close_rounded,
            isBusy: isBusy,
            isPrimary: false,
            onPressed: onDecline,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _RequestActionButton(
          label: 'Zurückziehen',
          icon: Icons.undo_rounded,
          isBusy: isBusy,
          isPrimary: false,
          onPressed: onWithdraw,
        ),
      ],
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  const _RequestActionButton({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isBusy;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBusy) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ] else ...[
          Icon(icon, size: 18),
        ],
        const SizedBox(width: 8),
        Text(label),
      ],
    );

    if (isPrimary) {
      return FilledButton(onPressed: isBusy ? null : onPressed, child: child);
    }

    return OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _RequestLoadingCard extends StatelessWidget {
  const _RequestLoadingCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Kontaktanfragen werden geladen...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestErrorCard extends StatelessWidget {
  const _RequestErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anfragen konnten nicht geladen werden',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Erneut versuchen',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestEmptyCard extends StatelessWidget {
  const _RequestEmptyCard({required this.isIncoming});

  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          CarmaBlueIconBox(
            icon: isIncoming
                ? Icons.mark_email_unread_outlined
                : Icons.schedule_send_outlined,
            size: 64,
            iconSize: 32,
          ),
          const SizedBox(height: 18),
          Text(
            isIncoming
                ? 'Keine eingehenden Anfragen'
                : 'Keine gesendeten Anfragen',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isIncoming
                ? 'Sobald dich jemand über dein Kennzeichen kontaktiert, erscheint die Anfrage hier.'
                : 'Wenn du eine Kontaktanfrage sendest, erscheint sie hier, bis sie angenommen, abgelehnt oder zurückgezogen wird.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
