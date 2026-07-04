import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/firebase/carisma_firestore_paths.dart';
import 'profile_verification_request.dart';
import 'user_profile.dart';

class ProfileVerificationRepository {
  ProfileVerificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> createVerificationRequest(UserProfile profile) async {
    final submittedAt = profile.verificationSubmittedAt ?? DateTime.now();
    final requestId =
        '${profile.uid}_${submittedAt.millisecondsSinceEpoch.toString()}';

    await _firestore
        .doc(CaRismaFirestorePaths.verificationRequest(requestId))
        .set({
          'requestId': requestId,
          'userId': profile.uid,
          'profilePath': CaRismaFirestorePaths.userProfile(profile.uid),
          'status': 'pending',
          'displayName': profile.displayName.trim(),
          'email': profile.email.trim(),
          'countryCode': profile.countryCode?.trim(),
          'plateRegion': profile.plateRegion?.trim().toUpperCase(),
          'plateLetters': profile.plateLetters?.trim().toUpperCase(),
          'plateNumbers': profile.plateNumbers?.trim().toUpperCase(),
          'vehicleBrand': profile.vehicleBrand?.trim(),
          'vehicleModel': profile.vehicleModel?.trim(),
          'vehicleColor': profile.vehicleColor?.trim(),
          'photoUrl': profile.photoUrl,
          'documentRemoteUrls': profile.documentRemoteUrls,
          'submittedAt': Timestamp.fromDate(submittedAt),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<List<ProfileVerificationRequest>> watchPendingRequests({
    int limit = 50,
  }) {
    return _firestore
        .collection(CaRismaFirestoreCollections.verificationRequests)
        .where('status', isEqualTo: 'pending')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(ProfileVerificationRequest.fromFirestore)
              .toList();

          requests.sort((a, b) {
            final aSubmittedAt = a.submittedAt;
            final bSubmittedAt = b.submittedAt;

            if (aSubmittedAt == null && bSubmittedAt == null) {
              return a.requestId.compareTo(b.requestId);
            }
            if (aSubmittedAt == null) {
              return 1;
            }
            if (bSubmittedAt == null) {
              return -1;
            }

            return aSubmittedAt.compareTo(bSubmittedAt);
          });

          return requests;
        });
  }

  Future<void> approveRequest({
    required ProfileVerificationRequest request,
    required String adminUserId,
  }) async {
    final batch = _firestore.batch();
    final requestRef = _firestore.doc(
      CaRismaFirestorePaths.verificationRequest(request.requestId),
    );
    final profileRef = _firestore.doc(_profilePathForRequest(request));

    batch.update(requestRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUserId,
      'rejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(profileRef, {
      'verificationStatus': 'verified',
      'verificationReviewedAt': FieldValue.serverTimestamp(),
      'verificationRejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> rejectRequest({
    required ProfileVerificationRequest request,
    required String adminUserId,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Ablehnungsgrund darf nicht leer sein.',
      );
    }

    final batch = _firestore.batch();
    final requestRef = _firestore.doc(
      CaRismaFirestorePaths.verificationRequest(request.requestId),
    );
    final profileRef = _firestore.doc(_profilePathForRequest(request));

    batch.update(requestRef, {
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUserId,
      'rejectionReason': trimmedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(profileRef, {
      'verificationStatus': 'rejected',
      'verificationReviewedAt': FieldValue.serverTimestamp(),
      'verificationRejectionReason': trimmedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  String _profilePathForRequest(ProfileVerificationRequest request) {
    final profilePath = request.profilePath.trim();
    if (profilePath.isNotEmpty) {
      return profilePath;
    }

    return CaRismaFirestorePaths.userProfile(request.userId);
  }
}
