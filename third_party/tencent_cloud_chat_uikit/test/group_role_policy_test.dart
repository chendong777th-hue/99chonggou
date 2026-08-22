import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';

void main() {
  const owner = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
  const admin = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
  const member = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;

  group('isManagerRole / isOwnerRole / isMuteExemptRole', () {
    test('owner and admin are managers and mute-exempt', () {
      expect(GroupRolePolicy.isOwnerRole(owner), isTrue);
      expect(GroupRolePolicy.isManagerRole(owner), isTrue);
      expect(GroupRolePolicy.isMuteExemptRole(owner), isTrue);

      expect(GroupRolePolicy.isOwnerRole(admin), isFalse);
      expect(GroupRolePolicy.isManagerRole(admin), isTrue);
      expect(GroupRolePolicy.isMuteExemptRole(admin), isTrue);
    });

    test('member and null are not managers', () {
      expect(GroupRolePolicy.isManagerRole(member), isFalse);
      expect(GroupRolePolicy.isManagerRole(null), isFalse);
      expect(GroupRolePolicy.isMuteExemptRole(member), isFalse);
    });
  });

  group('canSpeakInGroup', () {
    const now = 1000000;

    test('managers always can speak', () {
      expect(
        GroupRolePolicy.canSpeakInGroup(
          role: owner,
          isAllMuted: true,
          muteUntilSeconds: now + 100,
          nowSeconds: now,
        ),
        isTrue,
      );
      expect(
        GroupRolePolicy.canSpeakInGroup(
          role: admin,
          isAllMuted: true,
          muteUntilSeconds: now + 100,
          nowSeconds: now,
        ),
        isTrue,
      );
    });

    test('member blocked by all-mute', () {
      expect(
        GroupRolePolicy.canSpeakInGroup(
          role: member,
          isAllMuted: true,
          muteUntilSeconds: 0,
          nowSeconds: now,
        ),
        isFalse,
      );
    });

    test('member blocked by personal muteUntil', () {
      expect(
        GroupRolePolicy.canSpeakInGroup(
          role: member,
          isAllMuted: false,
          muteUntilSeconds: now + 1,
          nowSeconds: now,
        ),
        isFalse,
      );
    });

    test('member can speak when not muted', () {
      expect(
        GroupRolePolicy.canSpeakInGroup(
          role: member,
          isAllMuted: false,
          muteUntilSeconds: now - 1,
          nowSeconds: now,
        ),
        isTrue,
      );
    });
  });

  group('canKickMemberEntry', () {
    test('Work only owner', () {
      expect(
        GroupRolePolicy.canKickMemberEntry(
          selfRole: owner,
          groupType: GroupType.Work,
        ),
        isTrue,
      );
      expect(
        GroupRolePolicy.canKickMemberEntry(
          selfRole: admin,
          groupType: GroupType.Work,
        ),
        isFalse,
      );
    });

    test('Public / Meeting / Community owner or admin', () {
      for (final type in [
        GroupType.Public,
        GroupType.Meeting,
        GroupType.Community,
      ]) {
        expect(
          GroupRolePolicy.canKickMemberEntry(
            selfRole: owner,
            groupType: type,
          ),
          isTrue,
        );
        expect(
          GroupRolePolicy.canKickMemberEntry(
            selfRole: admin,
            groupType: type,
          ),
          isTrue,
        );
        expect(
          GroupRolePolicy.canKickMemberEntry(
            selfRole: member,
            groupType: type,
          ),
          isFalse,
        );
      }
    });

    test('unsupported group type returns false', () {
      expect(
        GroupRolePolicy.canKickMemberEntry(
          selfRole: owner,
          groupType: GroupType.AVChatRoom,
        ),
        isFalse,
      );
    });
  });

  group('canKickTargetMember', () {
    test('owner can kick admin and member, not owner', () {
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: owner,
          targetRole: admin,
        ),
        isTrue,
      );
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: owner,
          targetRole: member,
        ),
        isTrue,
      );
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: owner,
          targetRole: owner,
        ),
        isFalse,
      );
    });

    test('admin can only kick member', () {
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: admin,
          targetRole: member,
        ),
        isTrue,
      );
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: admin,
          targetRole: admin,
        ),
        isFalse,
      );
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: admin,
          targetRole: owner,
        ),
        isFalse,
      );
    });

    test('member cannot kick anyone', () {
      expect(
        GroupRolePolicy.canKickTargetMember(
          selfRole: member,
          targetRole: member,
        ),
        isFalse,
      );
    });
  });

  group('canMuteTargetMember', () {
    test('manager can mute member when not Work and not all-muted', () {
      expect(
        GroupRolePolicy.canMuteTargetMember(
          selfRole: owner,
          targetRole: member,
          groupType: GroupType.Public,
          isAllMuted: false,
        ),
        isTrue,
      );
    });

    test('blocked for Work, all-muted, non-manager, or non-member target', () {
      expect(
        GroupRolePolicy.canMuteTargetMember(
          selfRole: owner,
          targetRole: member,
          groupType: GroupType.Work,
          isAllMuted: false,
        ),
        isFalse,
      );
      expect(
        GroupRolePolicy.canMuteTargetMember(
          selfRole: owner,
          targetRole: member,
          groupType: GroupType.Public,
          isAllMuted: true,
        ),
        isFalse,
      );
      expect(
        GroupRolePolicy.canMuteTargetMember(
          selfRole: member,
          targetRole: member,
          groupType: GroupType.Public,
          isAllMuted: false,
        ),
        isFalse,
      );
      expect(
        GroupRolePolicy.canMuteTargetMember(
          selfRole: owner,
          targetRole: admin,
          groupType: GroupType.Public,
          isAllMuted: false,
        ),
        isFalse,
      );
    });
  });

  group('memberSortRank / roleBadgeKey', () {
    test('sort rank owner < admin < other', () {
      expect(GroupRolePolicy.memberSortRank(owner), 0);
      expect(GroupRolePolicy.memberSortRank(admin), 1);
      expect(GroupRolePolicy.memberSortRank(member), 2);
    });

    test('badge keys', () {
      expect(GroupRolePolicy.roleBadgeKey(owner), 'owner');
      expect(GroupRolePolicy.roleBadgeKey(admin), 'admin');
      expect(GroupRolePolicy.roleBadgeKey(member), isNull);
    });
  });
}
