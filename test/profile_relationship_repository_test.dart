import 'package:carisma/features/profile/data/follow_repository.dart';
import 'package:carisma/features/profile/data/profile_connection_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileConnectionRepository.connectionIdFor', () {
    test('is independent of user order', () {
      expect(
        ProfileConnectionRepository.connectionIdFor('user-b', 'user-a'),
        'user-a_user-b',
      );
      expect(
        ProfileConnectionRepository.connectionIdFor('user-a', 'user-b'),
        'user-a_user-b',
      );
    });

    test('rejects empty and identical user IDs', () {
      expect(
        () => ProfileConnectionRepository.connectionIdFor('', 'user-b'),
        throwsArgumentError,
      );
      expect(
        () => ProfileConnectionRepository.connectionIdFor('user-a', 'user-a'),
        throwsArgumentError,
      );
    });
  });

  group('FollowRepository.relationshipIdFor', () {
    test('keeps follow direction', () {
      expect(
        FollowRepository.relationshipIdFor('user-a', 'user-b'),
        'user-a_user-b',
      );
      expect(
        FollowRepository.relationshipIdFor('user-b', 'user-a'),
        'user-b_user-a',
      );
    });

    test('rejects following yourself', () {
      expect(
        () => FollowRepository.relationshipIdFor('user-a', 'user-a'),
        throwsArgumentError,
      );
    });
  });
}
