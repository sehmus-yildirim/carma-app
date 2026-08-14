import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plaqa/features/plate_search/data/plate_search_result.dart';
import 'package:plaqa/features/plate_search/data/plate_search_service.dart';
import 'package:plaqa/shared/config/carisma_app_config.dart';
import 'package:plaqa/shared/plate/dach_plate_presentation.dart';

void main() {
  test('maps a dynamic production hit including DACH plate parts', () {
    final result = PlateSearchResult.fromMap(const {
      'found': true,
      'targetUid': 'target-user',
      'vehicleId': 'vehicle-mercedes-gls',
      'displayName': 'Mara Beispiel',
      'profilePhotoUrl': 'https://example.test/profile.jpg',
      'isVerified': true,
      'vehicleBrand': 'Mercedes-Benz',
      'vehicleModel': 'GLS',
      'vehicleColor': 'Weiß',
      'countryCode': 'DE',
      'region': 'FD',
      'letters': 'RT',
      'numbers': '2918',
      'displayPlate': 'FD-RT 2918',
    });

    expect(result.targetUid, 'target-user');
    expect(result.vehicleId, 'vehicle-mercedes-gls');
    expect(result.profilePhotoUrl, isNotEmpty);
    expect(result.isVerified, isTrue);
    expect(result.vehicleBrand, 'Mercedes-Benz');
    expect(result.vehicleModel, 'GLS');
    expect(result.vehicleColor, 'Weiß');
    expect(result.countryCode, 'DE');
    expect(result.region, 'FD');
    expect(result.letters, 'RT');
    expect(result.numbers, '2918');
  });

  test('uses a real regional presentation for the returned plate region', () {
    final presentation = registrationRegionPresentationFor(
      countryCode: 'DE',
      plateCode: 'FD',
    );

    expect(presentation.plateCode, 'FD');
    expect(presentation.regionCoatAsset, isNotEmpty);
  });

  test('debug plate search is never enabled outside debug mode', () {
    expect(CaRismaAppConfig.useMockPlateSearch, kDebugMode);
    expect(
      PlateSearchService.isDemoPlate(
        countryCode: 'DE',
        plateKey: PlateSearchService.demoPlateKey,
      ),
      kDebugMode,
    );
  });
}
