import 'package:plaqa/features/reports/domain/report_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReportDraft draft({
    ReportDraftCategory? category = ReportDraftCategory.vehicleOpen,
    bool useGpsLocation = true,
    String? manualAddress,
    double? latitude = 53.5511,
    double? longitude = 9.9937,
    String region = 'HH',
    String letters = 'SY',
    String numbers = '4700',
    String message = '',
    String? gpsAddressLabel,
  }) {
    return ReportDraft(
      senderUserId: 'reporter-1',
      countryCode: 'DE',
      region: region,
      letters: letters,
      numbers: numbers,
      category: category,
      message: message,
      useGpsLocation: useGpsLocation,
      manualAddress: manualAddress,
      gpsAddressLabel: gpsAddressLabel,
      latitude: latitude,
      longitude: longitude,
    );
  }

  group('ReportDraft', () {
    test('allows a complete report with GPS location', () {
      expect(draft().canSubmit, isTrue);
    });

    test('allows a complete report with a manual address', () {
      final report = draft(
        useGpsLocation: false,
        manualAddress: 'Musterstrasse 1, 20095 Hamburg',
        latitude: null,
        longitude: null,
      );

      expect(report.canSubmit, isTrue);
    });

    test('uses the resolved GPS address as location label', () {
      final report = draft(gpsAddressLabel: 'Musterstrasse 1, 20095 Hamburg');

      expect(report.locationLabel, 'Musterstrasse 1, 20095 Hamburg');
    });

    test('falls back to a neutral GPS label without a resolved address', () {
      expect(draft().locationLabel, 'GPS-Standort erfasst');
    });

    test('uses the manual address as location label', () {
      final report = draft(
        useGpsLocation: false,
        manualAddress: 'Musterstrasse 1, 20095 Hamburg',
        latitude: null,
        longitude: null,
      );

      expect(report.locationLabel, 'Musterstrasse 1, 20095 Hamburg');
    });

    test('requires category, complete plate and location', () {
      expect(draft(category: null).canSubmit, isFalse);
      expect(draft(numbers: '').canSubmit, isFalse);
      expect(draft(latitude: null).canSubmit, isFalse);
    });

    test('uses the category label when no note was entered', () {
      expect(draft().normalizedMessage, 'Fahrzeug offen');
    });
  });
}
