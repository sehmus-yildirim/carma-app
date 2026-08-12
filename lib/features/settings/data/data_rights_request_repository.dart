import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/config/carisma_app_config.dart';
import '../../../shared/firebase/carisma_firestore_paths.dart';

class DataRightsRequestRepository {
  DataRightsRequestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> requestExport({
    required String userId,
    required String? accountEmail,
    String? note,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw StateError('Melde dich erneut an, um den Export anzufordern.');
    }
    final normalizedNote = note?.trim() ?? '';
    if (normalizedNote.length > 500) {
      throw ArgumentError(
        'Der optionale Hinweis darf höchstens 500 Zeichen lang sein.',
      );
    }

    final requestId = requestIdForDate(DateTime.now().toUtc());
    final exportReference = _firestore.doc(
      '${CaRismaFirestorePaths.user(normalizedUserId)}/'
      'data_rights_requests/$requestId',
    );

    return _firestore.runTransaction<String>((transaction) async {
      final existing = await transaction.get(exportReference);
      if (existing.exists) return exportReference.id;

      transaction.set(exportReference, {
        'requestId': exportReference.id,
        'userId': normalizedUserId,
        'type': 'export',
        'status': 'requested',
        'accountEmail': _trimmedOrNull(accountEmail),
        'note': _trimmedOrNull(normalizedNote),
        'appVersion': CaRismaAppConfig.appVersionLabel,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return exportReference.id;
    });
  }

  static String requestIdForDate(DateTime date) {
    final utc = date.toUtc();
    return 'export_${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static String? _trimmedOrNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
