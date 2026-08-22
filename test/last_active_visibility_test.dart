import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';

void main() {
  group('LastActiveVisibility.shouldShowLastActive', () {
    test('everyone is visible to anyone', () {
      expect(
        LastActiveVisibility.shouldShowLastActive(
          visibility: LastActiveVisibility.everyone,
          isMutualFriend: false,
        ),
        isTrue,
      );
    });

    test('friends_only requires mutual friend', () {
      expect(
        LastActiveVisibility.shouldShowLastActive(
          visibility: LastActiveVisibility.friendsOnly,
          isMutualFriend: true,
        ),
        isTrue,
      );
      expect(
        LastActiveVisibility.shouldShowLastActive(
          visibility: LastActiveVisibility.friendsOnly,
          isMutualFriend: false,
        ),
        isFalse,
      );
    });

    test('hidden is never visible even with timestamp', () {
      expect(
        LastActiveVisibility.shouldShowLastActive(
          visibility: LastActiveVisibility.hidden,
          isMutualFriend: true,
        ),
        isFalse,
      );
    });

    test('hidden shows coarse label only', () {
      expect(
        LastActiveVisibility.shouldShowCoarseLastActive(
          visibility: LastActiveVisibility.hidden,
        ),
        isTrue,
      );
      expect(
        LastActiveVisibility.shouldShowAnyLastActive(
          visibility: LastActiveVisibility.hidden,
          isMutualFriend: false,
        ),
        isTrue,
      );
    });

    test('friends_only non-friend shows nothing', () {
      expect(
        LastActiveVisibility.shouldShowAnyLastActive(
          visibility: LastActiveVisibility.friendsOnly,
          isMutualFriend: false,
        ),
        isFalse,
      );
    });

    test('unknown visibility defaults to hidden', () {
      expect(
        LastActiveVisibility.shouldShowLastActive(
          visibility: null,
          isMutualFriend: true,
        ),
        isFalse,
      );
    });
  });

  group('UserSearchResult.fromJson', () {
    test('parses lastActiveVisibility', () {
      final result = UserSearchResult.fromJson(<String, dynamic>{
        'userId': 'u1',
        'nickname': 'Alice',
        'lastActiveAt': 1718592000000,
        'lastActiveVisibility': 'hidden',
      });

      expect(result.lastActiveAt, 1718592000000);
      expect(result.lastActiveVisibility, 'hidden');
    });
  });
}
