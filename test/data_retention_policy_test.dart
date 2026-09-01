import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/privacy/data_retention_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 1, 12);

  test('normale und sicherheitsbezogene Supportfristen sind getrennt', () {
    expect(
      DataRetentionPolicy.supportRequestExpiry(
        isSafetyRequest: false,
        now: now,
      ),
      now.add(const Duration(days: 365)),
    );
    expect(
      DataRetentionPolicy.supportRequestExpiry(isSafetyRequest: true, now: now),
      now.add(const Duration(days: 730)),
    );
  });

  test('Datenrechtsnachweise laufen nach drei Jahren ab', () {
    expect(
      DataRetentionPolicy.dataRightsEvidenceExpiry(now: now),
      now.add(const Duration(days: 1095)),
    );
  });
}
