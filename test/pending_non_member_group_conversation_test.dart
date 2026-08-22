import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 复现「被拉进新群有消息但列表不出现」的成员可见性竞态：
/// 群列表已同步 + 本地尚无该群 → 会话会被当成非成员丢掉。
void main() {
  test('new invite group is hidden when membership cache lags', () {
    final conversation = V2TimConversation(
      conversationID: 'group_new_invite',
      type: 2,
      groupID: 'new_invite',
      unreadCount: 3,
    );
    expect(
      shouldShowConversationForMembership(
        conversation: conversation,
        groupListSyncedOnce: true,
        isJoinedGroup: (_) => false,
      ),
      isFalse,
    );
  });

  test('same group shows once membership cache catches up', () {
    final conversation = V2TimConversation(
      conversationID: 'group_new_invite',
      type: 2,
      groupID: 'new_invite',
      unreadCount: 3,
    );
    expect(
      shouldShowConversationForMembership(
        conversation: conversation,
        groupListSyncedOnce: true,
        isJoinedGroup: (id) => id == 'new_invite',
      ),
      isTrue,
    );
  });
}
