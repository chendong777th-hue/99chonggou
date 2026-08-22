import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_at_mention.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';

void main() {
  tearDown(() {
    GroupMemberStore.instance.clear(notify: false);
  });

  group('GroupAtMention', () {
    test('isAtAllToken ignores @所有人', () {
      expect(GroupAtMention.isAtAllToken('所有人'), isTrue);
      expect(GroupAtMention.isAtAllToken('@所有人'), isTrue);
      expect(GroupAtMention.isAtAllToken('__kImSDK_MesssageAtALL__'), isTrue);
      expect(GroupAtMention.isAtAllToken('做鸡不够输'), isFalse);
    });

    test('resolves Chinese nick from chat member list', () {
      final hit = GroupAtMention.resolveMember(
        [
          V2TimGroupMemberFullInfo(
            userID: 'u_chicken',
            nickName: '做鸡不够输',
          ),
        ],
        '做鸡不够输',
      );
      expect(hit?.userID, 'u_chicken');
    });

    test('resolves nick from GroupMemberStore when chat list is empty', () {
      const groupId = 'g_privacy_at';
      GroupMemberStore.instance.putMember(
        groupId,
        V2TimGroupMemberFullInfo(
          userID: 'u_store',
          nickName: '做鸡不够输',
        ),
        notify: false,
      );
      final hit = GroupAtMention.resolveInGroup(
        groupId: groupId,
        chatMembers: const [],
        mentionToken: '@做鸡不够输',
      );
      expect(hit?.userID, 'u_store');
    });

    test('Chinese nick is not a searchable UID token', () {
      expect(ChatIdFormat.isUserUidToken('做鸡不够输'), isFalse);
    });
  });
}
