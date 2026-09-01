class DataRetentionPolicy {
  const DataRetentionPolicy._();

  static const Duration supportRequest = Duration(days: 365);
  static const Duration safetySupportRequest = Duration(days: 730);
  static const Duration dataRightsEvidence = Duration(days: 1095);

  static DateTime supportRequestExpiry({
    required bool isSafetyRequest,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return timestamp.add(
      isSafetyRequest ? safetySupportRequest : supportRequest,
    );
  }

  static DateTime dataRightsEvidenceExpiry({DateTime? now}) {
    return (now ?? DateTime.now()).toUtc().add(dataRightsEvidence);
  }
}
