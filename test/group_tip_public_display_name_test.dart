import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_public_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

void main() {
  group('GroupTipPublicDisplayName.pickPublicName', () {
    test('prefers nameCard over nickName', () {
      expect(
        GroupTipPublicDisplayName.pickPublicName(
          nameCard: '群名片',
          nickName: '昵称',
        ),
        '群名片',
      );
    });

    test('falls back to nickName when nameCard empty', () {
      expect(
        GroupTipPublicDisplayName.pickPublicName(
          nameCard: '  ',
          nickName: '公开昵称',
        ),
        '公开昵称',
      );
    });

    test('returns null when both empty so caller can keep resolving', () {
      expect(
        GroupTipPublicDisplayName.pickPublicName(
          nameCard: '',
          nickName: '',
        ),
        isNull,
      );
    });

    test('skips role placeholder nick', () {
      expect(
        GroupTipPublicDisplayName.pickPublicName(
          nameCard: '管理员',
          nickName: '真实昵称',
        ),
        '真实昵称',
      );
      expect(
        GroupTipPublicDisplayName.pickPublicName(
          nameCard: 'Admin',
          nickName: '',
        ),
        isNull,
      );
    });
  });

  group('FriendDisplayName.findFriend', () {
    test('matches raw uid against @prefixed friend userID', () {
      final friend = V2TimFriendInfo(
        userID: '@alice',
        userProfile: V2TimUserFullInfo(userID: '@alice', nickName: '爱丽丝'),
      );
      final found = FriendDisplayName.findFriend(<V2TimFriendInfo>[friend], 'alice');
      expect(found, isNotNull);
      expect(ChatIdFormat.rawUserUid(found!.userID), 'alice');
    });
  });
}
