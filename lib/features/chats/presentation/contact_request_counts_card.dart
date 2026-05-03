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

  late Future<_ContactRequestCounts> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ContactRequestCounts> _load() async {
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? widget.userState.userId;

    if (userId.trim().isEmpty) {
      return const _ContactRequestCounts(
        userId: '',
        incoming: 0,
        outgoing: 0,
        error: 'Keine eingeloggte FirebaseAuth UID gefunden.',
      );
    }

    try {
      final incoming = await _repository.loadIncomingRequests(userId: userId);
      final outgoing = await _repository.loadOutgoingRequests(userId: userId);

      return _ContactRequestCounts(
        userId: userId,
        incoming: incoming.length,
        outgoing: outgoing.length,
      );
    } catch (error) {
      return _ContactRequestCounts(
        userId: userId,
        incoming: 0,
        outgoing: 0,
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
    return FutureBuilder<_ContactRequestCounts>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final data = snapshot.data;

        final hasError = data?.error != null;
        final incoming = data?.incoming ?? 0;
        final outgoing = data?.outgoing ?? 0;

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
                child: Column(
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
                    if (isLoading)
                      Text(
                        'Anfragen werden geladen...',
                        style: _bodyStyle(context),
                      )
                    else if (hasError)
                      Text(
                        'Fehler beim Laden:\n${data!.error}',
                        style: _bodyStyle(context),
                      )
                    else ...[
                      Text('Eingehend: $incoming', style: _bodyStyle(context)),
                      const SizedBox(height: 3),
                      Text('Gesendet: $outgoing', style: _bodyStyle(context)),
                      const SizedBox(height: 6),
                      Text(
                        'UID: ${data?.shortUserId ?? '-'}',
                        style: _bodyStyle(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _reload,
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
                ),
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

class _ContactRequestCounts {
  const _ContactRequestCounts({
    required this.userId,
    required this.incoming,
    required this.outgoing,
    this.error,
  });

  final String userId;
  final int incoming;
  final int outgoing;
  final String? error;

  String get shortUserId {
    if (userId.length <= 10) {
      return userId;
    }

    return '${userId.substring(0, 5)}...${userId.substring(userId.length - 5)}';
  }
}
