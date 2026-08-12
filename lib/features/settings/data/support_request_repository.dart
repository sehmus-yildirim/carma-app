import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/firebase/carisma_firestore_paths.dart';

enum SupportRequestType { problem, verification, feedback }

class SupportRequestDraft {
  const SupportRequestDraft({
    required this.type,
    required this.category,
    required this.description,
    required this.allowContact,
    this.affectedArea,
    this.reproductionSteps,
  });

  final SupportRequestType type;
  final String category;
  final String description;
  final bool allowContact;
  final String? affectedArea;
  final String? reproductionSteps;

  bool get isValid {
    return category.trim().isNotEmpty && description.trim().length >= 20;
  }
}

class SupportRequestRepository {
  SupportRequestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> submit({
    required String userId,
    required String? accountEmail,
    required SupportRequestDraft draft,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw StateError('Melde dich erneut an, um die Anfrage zu senden.');
    }
    if (!draft.isValid) {
      throw ArgumentError(
        'Beschreibe dein Anliegen bitte mit mindestens 20 Zeichen.',
      );
    }

    final reference = _firestore
        .collection(
          '${CaRismaFirestorePaths.user(normalizedUserId)}/support_requests',
        )
        .doc();
    await reference.set({
      'requestId': reference.id,
      'userId': normalizedUserId,
      'type': draft.type.name,
      'category': draft.category.trim(),
      'affectedArea': _trimmedOrNull(draft.affectedArea),
      'description': draft.description.trim(),
      'reproductionSteps': _trimmedOrNull(draft.reproductionSteps),
      'allowContact': draft.allowContact,
      'accountEmail': draft.allowContact ? _trimmedOrNull(accountEmail) : null,
      'appVersion': CaRismaAppConfig.appVersionLabel,
      'status': 'received',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  static String? _trimmedOrNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
