import 'package:flutter_test/flutter_test.dart';
import 'package:plaqa/shared/security/trusted_firebase_media_url.dart';

void main() {
  const path = 'chat_images/chat-1/user-1/message-1.jpg';
  const encodedPath = 'chat_images%2Fchat-1%2Fuser-1%2Fmessage-1.jpg';

  test('accepts a path-bound plaqa Firebase download URL', () {
    final value = trustedFirebaseMediaUrl(
      url:
          'https://firebasestorage.googleapis.com/v0/b/'
          'carma-a84e4.firebasestorage.app/o/$encodedPath'
          '?alt=media&token=token-123',
      storagePath: path,
      allowEmulator: false,
    );
    expect(value, isNotNull);
  });

  test('rejects external hosts and insecure production URLs', () {
    expect(
      trustedFirebaseMediaUrl(
        url: 'https://tracker.example/$encodedPath?alt=media',
        storagePath: path,
        allowEmulator: false,
      ),
      isNull,
    );
    expect(
      trustedFirebaseMediaUrl(
        url:
            'http://firebasestorage.googleapis.com/v0/b/'
            'carma-a84e4.firebasestorage.app/o/$encodedPath?alt=media',
        storagePath: path,
        allowEmulator: false,
      ),
      isNull,
    );
  });

  test('rejects a valid Firebase URL bound to a different object', () {
    expect(
      trustedFirebaseMediaUrl(
        url:
            'https://firebasestorage.googleapis.com/v0/b/'
            'carma-a84e4.firebasestorage.app/o/'
            'chat_images%2Fchat-2%2Fuser-1%2Fmessage-1.jpg?alt=media',
        storagePath: path,
        allowEmulator: false,
      ),
      isNull,
    );
  });

  test('allows only explicit local Firebase emulator URLs in debug mode', () {
    final value = trustedFirebaseMediaUrl(
      url:
          'http://127.0.0.1:9199/v0/b/'
          'carma-a84e4.firebasestorage.app/o/$encodedPath?alt=media',
      storagePath: path,
      allowEmulator: true,
    );
    expect(value, isNotNull);
    expect(
      trustedFirebaseMediaUrl(
        url:
            'http://192.168.1.50:9199/v0/b/'
            'carma-a84e4.firebasestorage.app/o/$encodedPath?alt=media',
        storagePath: path,
        allowEmulator: true,
      ),
      isNull,
    );
  });

  test('rejects traversal paths and unexpected query parameters', () {
    expect(
      trustedFirebaseMediaUrl(
        url:
            'https://firebasestorage.googleapis.com/v0/b/'
            'carma-a84e4.firebasestorage.app/o/$encodedPath'
            '?alt=media&redirect=https%3A%2F%2Fevil.example',
        storagePath: path,
        allowEmulator: false,
      ),
      isNull,
    );
    expect(
      trustedFirebaseMediaUrl(
        url:
            'https://firebasestorage.googleapis.com/v0/b/'
            'carma-a84e4.firebasestorage.app/o/$encodedPath?alt=media',
        storagePath: '../$path',
        allowEmulator: false,
      ),
      isNull,
    );
  });

  test('accepts only the profile photo owned by the supplied user', () {
    const ownerUrl =
        'https://firebasestorage.googleapis.com/v0/b/'
        'carma-a84e4.firebasestorage.app/o/'
        'profile_photos%2Fuser-a%2Fprofile.png?alt=media&token=test-token';
    expect(
      trustedProfilePhotoUrl(
        url: ownerUrl,
        userId: 'user-a',
        allowEmulator: false,
      ),
      ownerUrl,
    );
    expect(
      trustedProfilePhotoUrl(
        url: ownerUrl,
        userId: 'user-b',
        allowEmulator: false,
      ),
      isNull,
    );
    expect(
      trustedProfilePhotoUrl(
        url: 'https://tracker.example/profile.png',
        userId: 'user-a',
        allowEmulator: false,
      ),
      isNull,
    );
  });

  test('rejects unsafe user IDs and duplicate query keys', () {
    const ownerUrl =
        'https://firebasestorage.googleapis.com/v0/b/'
        'carma-a84e4.firebasestorage.app/o/'
        'profile_photos%2Fuser-a%2Fprofile.png?alt=media';
    expect(
      trustedProfilePhotoUrl(
        url: ownerUrl,
        userId: '.*',
        allowEmulator: false,
      ),
      isNull,
    );
    expect(
      isTrustedPlaqaFirebaseDownloadUrl(
        '$ownerUrl&alt=media',
        allowEmulator: false,
      ),
      isFalse,
    );
  });
}
