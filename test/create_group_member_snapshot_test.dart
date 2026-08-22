import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_member_user_ids.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';

V2TimFriendInfo _friend(String userId) {
  return V2TimFriendInfo(userID: userId);
}

void main() {
  group('normalizeMemberUserIds', () {
    test('trims and filters empty ids', () {
      expect(
        normalizeMemberUserIds([
          _friend(' user_a '),
          _friend(''),
          _friend('user_b'),
        ]),
        ['user_a', 'user_b'],
      );
    });

    test('preserves confirm page snapshot order', () {
      expect(
        normalizeMemberUserIds([
          _friend('user_c'),
          _friend('user_a'),
          _friend('user_b'),
        ]),
        ['user_c', 'user_a', 'user_b'],
      );
    });
  });
}
