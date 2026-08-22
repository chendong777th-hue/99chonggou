import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';

void main() {
  group('GroupPrivacyGuard manager role', () {
    test('owner and admin are manager roles', () {
      expect(
        GroupPrivacyGuard.isManagerRoleForTest(
          GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER,
        ),
        isTrue,
      );
      expect(
        GroupPrivacyGuard.isManagerRoleForTest(
          GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN,
        ),
        isTrue,
      );
      expect(
        GroupPrivacyGuard.isManagerRoleForTest(
          GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
        ),
        isFalse,
      );
    });

    test('isTargetGroupManager reads cached member role', () async {
      const groupId = 'group_privacy_test';
      const ownerId = 'owner_user';
      GroupMemberStore.instance.putMember(
        groupId,
        V2TimGroupMemberFullInfo(
          userID: ownerId,
          role: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER,
        ),
        notify: false,
      );

      expect(
        await GroupPrivacyGuard.isTargetGroupManager(
          groupId: groupId,
          targetUserId: ownerId,
        ),
        isTrue,
      );
      expect(
        await GroupPrivacyGuard.isTargetGroupManager(
          groupId: groupId,
          targetUserId: 'normal_user',
        ),
        isFalse,
      );

      GroupMemberStore.instance.clear(notify: false);
    });
  });

  group('GroupPrivacyGuard.isGroupAddEntry', () {
    test('explicit card source is not group add even with groupId', () {
      expect(
        GroupPrivacyGuard.isGroupAddEntry(
          groupId: 'g1',
          addSource: FriendAddSource.card,
        ),
        isFalse,
      );
    });

    test('explicit group source is group add', () {
      expect(
        GroupPrivacyGuard.isGroupAddEntry(
          groupId: 'g1',
          addSource: FriendAddSource.group,
        ),
        isTrue,
      );
    });

    test('groupId alone without source still counts as group add', () {
      expect(
        GroupPrivacyGuard.isGroupAddEntry(groupId: 'g1', addSource: null),
        isTrue,
      );
    });
  });
}
