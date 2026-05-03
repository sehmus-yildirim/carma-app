import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/carma_models.dart';
import '../../../shared/widgets/carma_blue_icon_box.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/contact_request_repository.dart';

class ContactRequestCountsCard extends StatefulWidget {
  const ContactRequestCountsCard({super.key, required this.userState});

  final AppUserState userState;

  @override
  State<ContactRequestCountsCard> createState() =>
      _ContactRequestCountsCardState();
}

class _ContactRequestCountsCardState extends State<ContactRequestCountsCard> {
  final FirestoreContactRequestRepository _repository =
      FirestoreContactRequestRepository();

  late Future<_ContactRequestData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ContactRequestData> _load() async {
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;

    if (userId.trim().isEmpty) {
      return const _ContactRequestData(
        userId: '',
        incoming: [],
        outgoing: [],
        error: 'Keine eingeloggte FirebaseAuth UID gefunden.',
      );
    }

    try {
      final incoming = await _repository.loadIncomingRequests(userId: userId);
      final outgoing = await _repository.loadOutgoingRequests(userId: userId);

      return _ContactRequestData(
        userId: userId,
        incoming: incoming,
        outgoing: outgoing,
      );
    } catch (error) {
      return _ContactRequestData(
        userId: userId,
        incoming: [],
        outgoing: [],
        error: error.toString(),
      );
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContactRequestData>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final data = snapshot.data;
        final hasError = data?.error != null;

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CarmaBlueIconBox(
                icon: hasError
                    ? Icons.cloud_off_rounded
                    : Icons.mark_chat_unread_rounded,
                size: 44,
                iconSize: 23,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: isLoading
                    ? Text(
                        'Kontaktanfragen werden geladen...',
                        style: _bodyStyle(context),
                      )
                    : hasError
                    ? _ErrorContent(error: data!.error!, onReload: _reload)
                    : _RequestContent(data: data!, onReload: _reload),
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _bodyStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Colors.white.withValues(alpha: 0.78),
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
  }
}

class _RequestContent extends StatelessWidget {
  const _RequestContent({required this.data, required this.onReload});

  final _ContactRequestData data;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final incomingPreview = data.incoming.take(3).toList();
    final outgoingPreview = data.outgoing.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kontaktanfragen',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Eingehend: ${data.incoming.length} · Gesendet: ${data.outgoing.length}',
          style: _bodyStyle(context),
        ),
        const SizedBox(height: 12),
        if (incomingPreview.isNotEmpty) ...[
          _SectionTitle(label: 'Eingehend'),
          const SizedBox(height: 8),
          ...incomingPreview.map(
            (request) => _RequestMiniTile(
              title: _safeText(request.senderDisplayName, 'Carma Nutzer'),
              subtitle:
                  'Kennzeichen: ${_safeText(request.displayPlate, request.plateKey)}',
              status: request.statusLabel,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (outgoingPreview.isNotEmpty) ...[
          _SectionTitle(label: 'Gesendet'),
          const SizedBox(height: 8),
          ...outgoingPreview.map(
            (request) => _RequestMiniTile(
              title: _safeText(request.receiverDisplayName, 'Carma Nutzer'),
              subtitle:
                  'Kennzeichen: ${_safeText(request.displayPlate, request.plateKey)}',
              status: request.statusLabel,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (incomingPreview.isEmpty && outgoingPreview.isEmpty)
          Text(
            'Keine offenen Kontaktanfragen gefunden.',
            style: _bodyStyle(context),
          ),
        const SizedBox(height: 8),
        Text(
          'UID: ${data.shortUserId}',
          style: _bodyStyle(
            context,
          ).copyWith(color: Colors.white.withValues(alpha: 0.52), fontSize: 12),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onReload,
          child: Text(
            'Aktualisieren',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  static String _safeText(String? value, String fallback) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }

    return trimmed;
  }

  TextStyle _bodyStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Colors.white.withValues(alpha: 0.78),
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.error, required this.onReload});

  final String error;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kontaktanfragen',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Fehler beim Laden:\n$error',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onReload,
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _RequestMiniTile extends StatelessWidget {
  const _RequestMiniTile({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRequestData {
  const _ContactRequestData({
    required this.userId,
    required this.incoming,
    required this.outgoing,
    this.error,
  });

  final String userId;
  final List<ContactRequestRecord> incoming;
  final List<ContactRequestRecord> outgoing;
  final String? error;

  String get shortUserId {
    if (userId.length <= 10) {
      return userId;
    }

    return '${userId.substring(0, 5)}...${userId.substring(userId.length - 5)}';
  }
}
