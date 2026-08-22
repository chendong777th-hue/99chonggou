import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_self_involvement.dart';

void main() {
  group('isSelfRemovedFromGroupMembershipEvent', () {
    test('admin removing another member is not self-removed', () {
      expect(
        isSelfRemovedFromGroupMembershipEvent(
          action: 'member_removed',
          ownerUserId: 'admin',
          memberUserIds: const ['user_b'],
          fromUserId: 'admin',
          detailUserId: 'user_b',
        ),
        isFalse,
      );
    });

    test('removed member is self-removed', () {
      expect(
        isSelfRemovedFromGroupMembershipEvent(
          action: 'member_removed',
          ownerUserId: 'user_b',
          memberUserIds: const ['user_b'],
          fromUserId: 'admin',
        ),
        isTrue,
      );
    });

    test('member leaving voluntarily is self-removed', () {
      expect(
        isSelfRemovedFromGroupMembershipEvent(
          action: 'member_left',
          ownerUserId: 'user_b',
          memberUserIds: const ['user_b'],
          fromUserId: 'user_b',
        ),
        isTrue,
      );
    });

    test('observer of member_left is not self-removed', () {
      expect(
        isSelfRemovedFromGroupMembershipEvent(
          action: 'member_left',
          ownerUserId: 'admin',
          memberUserIds: const ['user_b'],
          fromUserId: 'user_b',
        ),
        isFalse,
      );
    });

    test('member_added never counts as self-removed', () {
      expect(
        isSelfRemovedFromGroupMembershipEvent(
          action: 'member_added',
          ownerUserId: 'admin',
          memberUserIds: const ['user_b'],
          fromUserId: 'admin',
        ),
        isFalse,
      );
    });
  });

  group('isSelfAddedToGroupMembershipEvent', () {
    test('invitee listed in memberUserIds is self-added', () {
      expect(
        isSelfAddedToGroupMembershipEvent(
          action: 'member_added',
          ownerUserId: 'user_b',
          memberUserIds: const ['user_b'],
          detailUserId: null,
        ),
        isTrue,
      );
    });

    test('invitee only in detail.userId is self-added', () {
      expect(
        isSelfAddedToGroupMembershipEvent(
          action: 'member_added',
          ownerUserId: 'user_b',
          memberUserIds: const [],
          detailUserId: 'user_b',
        ),
        isTrue,
      );
    });

    test('observer of someone else joining is not self-added', () {
      expect(
        isSelfAddedToGroupMembershipEvent(
          action: 'member_added',
          ownerUserId: 'admin',
          memberUserIds: const ['user_b'],
          detailUserId: 'user_b',
        ),
        isFalse,
      );
    });

    test('member_removed action is never self-added', () {
      expect(
        isSelfAddedToGroupMembershipEvent(
          action: 'member_removed',
          ownerUserId: 'user_b',
          memberUserIds: const ['user_b'],
        ),
        isFalse,
      );
    });
  });
}
