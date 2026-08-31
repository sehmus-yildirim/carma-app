import 'document_profiles.dart';
import 'verification_models.dart';

enum ConfidenceSignal {
  anchorFound,
  expectedRegion,
  formatValid,
  uniqueCandidate,
  mrzCheckDigitValid,
  mrzMatchesVisual,
  conflict,
}

class FieldConfidenceAssessment {
  const FieldConfidenceAssessment({
    required this.field,
    required this.level,
    required this.signals,
  });

  final VerificationField field;
  final FieldConfidence level;
  final Set<ConfidenceSignal> signals;
}

class VerificationConfidenceEngine {
  const VerificationConfidenceEngine();

  FieldConfidenceAssessment assess({
    required VerificationField field,
    required Set<ConfidenceSignal> signals,
    required DocumentConfidenceThresholds thresholds,
  }) {
    if (signals.contains(ConfidenceSignal.conflict)) {
      return FieldConfidenceAssessment(
        field: field,
        level: FieldConfidence.low,
        signals: Set.unmodifiable(signals),
      );
    }
    final positiveSignals = signals
        .where((signal) => signal != ConfidenceSignal.conflict)
        .length;
    final level = positiveSignals >= thresholds.minimumSignalsForHigh
        ? FieldConfidence.high
        : positiveSignals >= thresholds.minimumSignalsForMedium
        ? FieldConfidence.medium
        : FieldConfidence.low;
    return FieldConfidenceAssessment(
      field: field,
      level: level,
      signals: Set.unmodifiable(signals),
    );
  }

  bool permitsAutomaticAcceptance(
    Map<VerificationField, FieldConfidence> confidence, {
    required Set<VerificationField> requiredFields,
  }) => requiredFields.every(
    (field) => confidence[field] == FieldConfidence.high,
  );
}
