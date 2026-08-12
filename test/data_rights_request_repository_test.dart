import 'package:carisma/features/settings/data/data_rights_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Datenexport verwendet pro UTC-Tag eine stabile Anfrage-ID', () {
    expect(
      DataRightsRequestRepository.requestIdForDate(
        DateTime.parse('2026-08-12T23:59:59Z'),
      ),
      'export_20260812',
    );
    expect(
      DataRightsRequestRepository.requestIdForDate(
        DateTime.parse('2026-08-13T01:30:00+02:00'),
      ),
      'export_20260812',
    );
  });
}
