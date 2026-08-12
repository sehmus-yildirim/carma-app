import 'package:carisma/features/settings/data/support_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportRequestDraft', () {
    test('requires a category and a useful description', () {
      const invalid = SupportRequestDraft(
        type: SupportRequestType.problem,
        category: 'Technik',
        description: 'Zu kurz',
        allowContact: true,
      );
      const valid = SupportRequestDraft(
        type: SupportRequestType.problem,
        category: 'Technik',
        description:
            'Der Chat friert nach dem Öffnen der Kamera vollständig ein.',
        allowContact: true,
      );

      expect(invalid.isValid, isFalse);
      expect(valid.isValid, isTrue);
    });

    test('support request types use stable server values', () {
      expect(SupportRequestType.problem.name, 'problem');
      expect(SupportRequestType.verification.name, 'verification');
      expect(SupportRequestType.feedback.name, 'feedback');
    });
  });
}
