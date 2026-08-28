import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/domain/profile_document_mapper.dart';
import 'package:plaqa/shared/models/carisma_models.dart';

void main() {
  const plate = CaRismaPlate(
    countryCode: 'DE',
    region: 'HH',
    letters: 'PQ',
    numbers: '2026',
  );

  group('active verification documents', () {
    test('requires only identity and vehicle registration documents', () {
      expect(ProfileDocumentMapper.activeDocumentTypes, [
        VerificationDocumentType.idFront,
        VerificationDocumentType.idBack,
        VerificationDocumentType.vehicleRegistrationFront,
        VerificationDocumentType.vehicleRegistrationBack,
      ]);
      expect(
        ProfileDocumentMapper.activeDocumentTypes,
        isNot(contains(VerificationDocumentType.driverLicenseFront)),
      );
      expect(
        ProfileDocumentMapper.activeDocumentTypes,
        isNot(contains(VerificationDocumentType.driverLicenseBack)),
      );
    });

    test('accepts the four active documents and rejects an incomplete set', () {
      final complete = {
        'Ausweis Vorderseite': 'id-front.jpg',
        'Ausweis Rückseite': 'id-back.jpg',
        'Fahrzeugschein Vorderseite': 'vehicle-front.jpg',
        'Fahrzeugschein Rückseite': 'vehicle-back.jpg',
      };
      final incomplete = Map<String, String?>.from(complete)
        ..['Fahrzeugschein Rückseite'] = null;

      expect(ProfileDocumentMapper.areAllDocumentsUploaded(complete), isTrue);
      expect(
        ProfileDocumentMapper.areAllDocumentsUploaded(incomplete),
        isFalse,
      );
    });
  });

  group('ContactRequest', () {
    test('round-trips status, direction, plate and dates', () {
      final createdAt = DateTime.utc(2026, 8, 27, 10);
      final request = ContactRequest(
        id: 'request-1',
        senderUserId: 'sender',
        receiverUserId: 'receiver',
        direction: ContactRequestDirection.incoming,
        status: ContactRequestStatus.pending,
        targetPlate: plate,
        messagePreview: 'Bitte Kontakt aufnehmen',
        senderDisplayName: 'Plaqa Nutzer',
        createdAt: createdAt,
      );

      final restored = ContactRequest.fromMap(request.toMap());

      expect(restored, request);
      expect(restored.displayTitle, 'Plaqa Nutzer');
      expect(restored.isPending, isTrue);
      expect(restored.isClosed, isFalse);
    });

    test('treats all terminal statuses as closed', () {
      for (final status in ContactRequestStatus.values.where(
        (value) => value != ContactRequestStatus.pending,
      )) {
        final request = ContactRequest(
          id: status.name,
          senderUserId: 'sender',
          receiverUserId: 'receiver',
          direction: ContactRequestDirection.outgoing,
          status: status,
          targetPlate: plate,
          messagePreview: '',
        );
        expect(request.isClosed, isTrue, reason: status.name);
      }
    });

    test('uses safe defaults for malformed stored values', () {
      final request = ContactRequest.fromMap({
        'direction': 'unknown',
        'status': 'unknown',
      });

      expect(request.direction, ContactRequestDirection.incoming);
      expect(request.status, ContactRequestStatus.pending);
      expect(request.targetPlate.countryCode, 'DE');
      expect(request.displayTitle, 'Neue Kontaktanfrage');
    });
  });

  group('Report', () {
    test('marks safety and abuse reports for review', () {
      for (final type in const [ReportType.danger, ReportType.abuse]) {
        final report = Report(
          id: type.name,
          senderUserId: 'sender',
          targetPlate: plate,
          type: type,
          status: ReportStatus.submitted,
          message: '',
        );
        expect(report.requiresReview, isTrue, reason: type.name);
        expect(report.previewText, report.typeLabel, reason: type.name);
      }
    });

    test('round-trips image and lifecycle metadata', () {
      final createdAt = DateTime.utc(2026, 8, 27, 10);
      final report = Report(
        id: 'report-1',
        senderUserId: 'sender',
        targetUserId: 'receiver',
        targetPlate: plate,
        type: ReportType.damageObserved,
        status: ReportStatus.delivered,
        message: ' Kratzer an der Tür ',
        imageUrl: 'https://example.test/report.jpg',
        createdAt: createdAt,
        deliveredAt: createdAt,
      );

      final restored = Report.fromMap(report.toMap());

      expect(restored, report);
      expect(restored.hasImage, isTrue);
      expect(restored.isSubmitted, isTrue);
      expect(restored.isClosed, isTrue);
      expect(restored.previewText, 'Kratzer an der Tür');
    });
  });

  group('ModerationAction', () {
    test('distinguishes restrictions from account blocks', () {
      final restriction = ModerationAction.localRestriction(
        userId: 'user-a',
        reason: ModerationReason.spam,
        now: DateTime.utc(2026),
        endsAt: DateTime.utc(2099),
      );
      final suspension = ModerationAction.localSuspension(
        userId: 'user-a',
        reason: ModerationReason.safetyRisk,
        now: DateTime.utc(2026),
      );

      expect(restriction.restrictsFeatures, isTrue);
      expect(restriction.blocksAccount, isFalse);
      expect(suspension.blocksAccount, isTrue);
      expect(suspension.restrictsFeatures, isFalse);
    });

    test('falls back safely when stored enum values are unknown', () {
      final action = ModerationAction.fromMap({
        'id': 'action-1',
        'userId': 'user-a',
        'type': 'unknown',
        'reason': 'unknown',
      });

      expect(action.type, ModerationActionType.manualReview);
      expect(action.reason, ModerationReason.other);
      expect(action.createdAt, DateTime(1970));
    });
  });

  group('Vehicle and VerificationDocument', () {
    test('vehicle round-trip preserves normalized display data', () {
      const vehicle = Vehicle(
        id: 'vehicle-1',
        plate: plate,
        brand: ' BMW ',
        model: ' X6 ',
        color: ' Schwarz ',
        isPrimary: true,
        isVerified: true,
      );

      final restored = Vehicle.fromMap(vehicle.toMap());

      expect(restored, vehicle);
      expect(restored.displayName, 'Schwarz BMW X6');
      expect(restored.hasRequiredData, isTrue);
    });

    test('pending and approved documents are locked', () {
      for (final status in const [
        VerificationDocumentStatus.pendingReview,
        VerificationDocumentStatus.approved,
      ]) {
        final document = VerificationDocument(
          id: status.name,
          type: VerificationDocumentType.idFront,
          status: status,
          remoteUrl: 'https://example.test/document.jpg',
        );
        expect(document.isUploaded, isTrue, reason: status.name);
        expect(document.isLocked, isTrue, reason: status.name);
        expect(VerificationDocument.fromMap(document.toMap()), document);
      }
    });
  });
}
