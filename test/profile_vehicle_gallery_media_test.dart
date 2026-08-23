import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/features/profile/data/profile_vehicle.dart';
import 'package:plaqa/features/profile/data/profile_vehicle_gallery_media.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_gallery_card.dart';
import 'package:plaqa/features/profile/presentation/widgets/profile_vehicle_panel.dart';

void main() {
  const media = ProfileVehicleGalleryMedia(
    id: 'media-1',
    ownerUserId: 'user-1',
    vehicleId: 'vehicle-1',
    mediaUrl: 'https://example.com/image.jpg',
    mediaPath: 'vehicle_gallery/user-1/vehicle-1/media-1',
    category: ProfileVehicleGalleryCategory.modifications,
    caption: 'Neue Felgen',
    isMain: true,
    visibility: ProfileVehicleVisibility.contacts,
  );

  test('Bild ist nur für Kontakte öffentlich sichtbar', () {
    expect(media.isPubliclyVisible, isTrue);
    expect(
      media
          .copyWith(visibility: ProfileVehicleVisibility.onlyMe)
          .isPubliclyVisible,
      isFalse,
    );
    expect(media.copyWith(isDeleted: true).isPubliclyVisible, isFalse);
  });

  test('öffentliche Projektion enthält nur freigegebene Bilddaten', () {
    final data = media.toPublicFirestore();

    expect(data['ownerUserId'], 'user-1');
    expect(data['vehicleId'], 'vehicle-1');
    expect(data['category'], 'modifications');
    expect(data['mediaType'], 'image');
    expect(data['isMain'], isTrue);
    expect(data['visibility'], 'contacts');
    expect(data['isDeleted'], isFalse);
  });

  test('Video wird als eigener Medientyp gespeichert', () {
    const video = ProfileVehicleGalleryMedia(
      id: 'video-1',
      ownerUserId: 'user-1',
      vehicleId: 'vehicle-1',
      mediaUrl: 'https://example.com/video.mp4',
      mediaPath: 'vehicle_gallery/user-1/vehicle-1/video-1',
      mediaType: ProfileVehicleGalleryMediaType.video,
      visibility: ProfileVehicleVisibility.contacts,
    );

    expect(video.toPublicFirestore()['mediaType'], 'video');
    expect(video.isPubliclyVisible, isTrue);
  });

  testWidgets('Galerieraster übernimmt keinen unteren Navigationsabstand', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildGallery(double bottomPadding) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 900),
            padding: EdgeInsets.only(bottom: bottomPadding),
          ),
          child: Scaffold(
            body: ProfileVehicleGalleryCard(
              vehicle: debugProfileVehicle,
              media: Stream.value(const <ProfileVehicleGalleryMedia>[]),
              isOwnProfile: true,
              onAdd: () {},
              onSetMain: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildGallery(0));
    await tester.pumpAndSettle();
    final heightWithoutNavigation = tester
        .getSize(find.byKey(const ValueKey('profile-vehicle-gallery-grid')))
        .height;

    await tester.pumpWidget(buildGallery(120));
    await tester.pumpAndSettle();
    final heightWithNavigation = tester
        .getSize(find.byKey(const ValueKey('profile-vehicle-gallery-grid')))
        .height;

    expect(heightWithNavigation, heightWithoutNavigation);
  });
}
