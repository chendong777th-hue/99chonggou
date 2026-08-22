import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_rows.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem, GroupSystemNoticeType;

void main() {
  test('buildConversationFeedRows inserts archived entry at top', () {
    final rows = buildConversationFeedRows(
      conversations: [
        V2TimConversation(
          conversationID: 'c2c_a',
          type: 1,
          userID: 'a',
          unreadCount: 1,
        ),
      ],
      includeArchivedEntry: true,
      includeGroupNoticeEntry: false,
      applications: const [],
      notices: const [],
      conversationTimestampMs: (_) => 100,
    );

    expect(rows.first.kind, ConversationFeedRowKind.archived);
    expect(rows.length, 2);
  });

  test(
    'buildConversationFeedRows includes archived entry when only group notice visible',
    () {
      final rows = buildConversationFeedRows(
        conversations: const [],
        includeArchivedEntry: true,
        includeGroupNoticeEntry: true,
        applications: const [],
        notices: [
          GroupSystemNoticeItem(
            id: 'n1',
            groupID: 'g1',
            groupName: 'Group',
            groupFaceUrl: '',
            type: GroupSystemNoticeType.grantAdministrator,
            operatorUserID: 'u1',
            operatorName: 'User',
            targetUserID: 'u2',
            targetName: 'Target',
            timestamp: 200,
          ),
        ],
        conversationTimestampMs: (_) => 0,
      );

      expect(rows.length, 2);
      expect(rows.first.kind, ConversationFeedRowKind.archived);
      expect(rows[1].kind, ConversationFeedRowKind.groupNotice);
    },
  );

  test('buildConversationFeedRows hides dismissed group notice entry', () {
    final rows = buildConversationFeedRows(
      conversations: const [],
      includeArchivedEntry: false,
      includeGroupNoticeEntry: true,
      applications: const [],
      notices: [
        GroupSystemNoticeItem(
          id: 'n1',
          groupID: 'g1',
          groupName: 'Group',
          groupFaceUrl: '',
          type: GroupSystemNoticeType.grantAdministrator,
          operatorUserID: 'u1',
          operatorName: 'User',
          targetUserID: 'u2',
          targetName: 'Target',
          timestamp: 200,
        ),
      ],
      conversationTimestampMs: (_) => 0,
      groupNoticeDismissWatermarkMs: 200000,
    );

    expect(rows, isEmpty);
  });

  test('buildConversationFeedRows pins group notice before non-pinned chats', () {
    final rows = buildConversationFeedRows(
      conversations: [
        V2TimConversation(
          conversationID: 'group_b',
          type: 2,
          groupID: 'b',
          isPinned: true,
        ),
        V2TimConversation(
          conversationID: 'group_a',
          type: 2,
          groupID: 'a',
          isPinned: false,
        ),
      ],
      includeArchivedEntry: false,
      includeGroupNoticeEntry: true,
      applications: const [],
      notices: [
        GroupSystemNoticeItem(
          id: 'n1',
          groupID: 'g1',
          groupName: 'Group',
          groupFaceUrl: '',
          type: GroupSystemNoticeType.grantAdministrator,
          operatorUserID: 'u1',
          operatorName: 'User',
          targetUserID: 'u2',
          targetName: 'Target',
          timestamp: 100,
        ),
      ],
      conversationTimestampMs: (_) => 300,
      groupNoticePinned: true,
    );

    expect(rows[0].kind, ConversationFeedRowKind.groupNotice);
    expect(rows[1].conversation?.conversationID, 'group_b');
    expect(rows[2].conversation?.conversationID, 'group_a');
  });

  test('buildConversationFeedRows keeps archived above pinned group notice', () {
    final rows = buildConversationFeedRows(
      conversations: [
        V2TimConversation(
          conversationID: 'group_a',
          type: 2,
          groupID: 'a',
        ),
      ],
      includeArchivedEntry: true,
      includeGroupNoticeEntry: true,
      applications: const [],
      notices: [
        GroupSystemNoticeItem(
          id: 'n1',
          groupID: 'g1',
          groupName: 'Group',
          groupFaceUrl: '',
          type: GroupSystemNoticeType.grantAdministrator,
          operatorUserID: 'u1',
          operatorName: 'User',
          targetUserID: 'u2',
          targetName: 'Target',
          timestamp: 100,
        ),
      ],
      conversationTimestampMs: (_) => 300,
      groupNoticePinned: true,
    );

    expect(rows[0].kind, ConversationFeedRowKind.archived);
    expect(rows[1].kind, ConversationFeedRowKind.groupNotice);
  });

  test('patchConversationFeedRowsById replaces conversation refs by id', () {
    final cached = buildConversationFeedRows(
      conversations: [
        V2TimConversation(
          conversationID: 'c2c_a',
          type: 1,
          userID: 'a',
          unreadCount: 1,
          showName: 'Old',
        ),
      ],
      includeArchivedEntry: true,
      includeGroupNoticeEntry: false,
      applications: const [],
      notices: const [],
      conversationTimestampMs: (_) => 100,
    );
    final patched = patchConversationFeedRowsById(
      cached: cached,
      visible: [
        V2TimConversation(
          conversationID: 'c2c_a',
          type: 1,
          userID: 'a',
          unreadCount: 9,
          showName: 'New',
        ),
      ],
      conversationTimestampMs: (_) => 200,
    );

    expect(patched.first.kind, ConversationFeedRowKind.archived);
    expect(patched[1].kind, ConversationFeedRowKind.conversation);
    expect(patched[1].conversation?.unreadCount, 9);
    expect(patched[1].conversation?.showName, 'New');
    expect(patched[1].timestampMs, 200);
  });

  test('computeGroupNoticeInsertTypeIndex places notice among non-pinned', () {
    expect(
      computeGroupNoticeInsertTypeIndex(
        groupNoticePinned: false,
        total: 5,
        pinnedCount: 2,
        nonPinnedNewerThanNoticeCount: 1,
      ),
      3,
    );
    expect(
      computeGroupNoticeInsertTypeIndex(
        groupNoticePinned: false,
        total: 5,
        pinnedCount: 2,
        nonPinnedNewerThanNoticeCount: 0,
      ),
      2,
    );
    expect(
      computeGroupNoticeInsertTypeIndex(
        groupNoticePinned: false,
        total: 5,
        pinnedCount: 2,
        nonPinnedNewerThanNoticeCount: 3,
      ),
      5,
    );
    expect(
      computeGroupNoticeInsertTypeIndex(
        groupNoticePinned: true,
        total: 5,
        pinnedCount: 2,
        nonPinnedNewerThanNoticeCount: 1,
      ),
      0,
    );
  });

  test('virtualFeed index mapping offsets around inline notice', () {
    expect(
      virtualFeedListIndexForTypeIndex(
        typeIndex: 2,
        headerCount: 1,
        noticeInsertAt: 2,
      ),
      4,
    );
    expect(
      virtualFeedListIndexForTypeIndex(
        typeIndex: 1,
        headerCount: 1,
        noticeInsertAt: 2,
      ),
      2,
    );
    expect(
      virtualFeedTypeIndexForBodyIndex(
        bodyIndex: 2,
        noticeInsertAt: 2,
        total: 5,
      ),
      isNull,
    );
    expect(
      virtualFeedTypeIndexForBodyIndex(
        bodyIndex: 3,
        noticeInsertAt: 2,
        total: 5,
      ),
      2,
    );
    expect(
      virtualFeedBodyIndexIsGroupNotice(bodyIndex: 2, noticeInsertAt: 2),
      isTrue,
    );
  });

  test('buildConversationFeedRows inserts notice by time among chats', () {
    final rows = buildConversationFeedRows(
      conversations: [
        V2TimConversation(
          conversationID: 'group_new',
          type: 2,
          groupID: 'new',
          isPinned: false,
        ),
        V2TimConversation(
          conversationID: 'group_old',
          type: 2,
          groupID: 'old',
          isPinned: false,
        ),
      ],
      includeArchivedEntry: false,
      includeGroupNoticeEntry: true,
      applications: const [],
      notices: [
        GroupSystemNoticeItem(
          id: 'n1',
          groupID: 'g1',
          groupName: 'Group',
          groupFaceUrl: '',
          type: GroupSystemNoticeType.grantAdministrator,
          operatorUserID: 'u1',
          operatorName: 'User',
          targetUserID: 'u2',
          targetName: 'Target',
          // 秒级 → normalize 成 200_000 ms，与会话 active_time 对齐
          timestamp: 200,
        ),
      ],
      conversationTimestampMs: (c) {
        if (c.conversationID == 'group_new') return 300000;
        return 100000;
      },
    );

    expect(rows[0].conversation?.conversationID, 'group_new');
    expect(rows[1].kind, ConversationFeedRowKind.groupNotice);
    expect(rows[2].conversation?.conversationID, 'group_old');
  });

  group('groupNoticeFeedSignature', () {
    GroupSystemNoticeItem notice({
      required String id,
      required int timestamp,
    }) {
      return GroupSystemNoticeItem(
        id: id,
        groupID: 'g1',
        groupName: 'Group',
        groupFaceUrl: '',
        type: GroupSystemNoticeType.grantAdministrator,
        operatorUserID: 'u1',
        operatorName: 'User',
        targetUserID: 'u2',
        targetName: 'Target',
        timestamp: timestamp,
      );
    }

    test('unchanged inputs keep the same signature', () {
      final notices = [notice(id: 'n1', timestamp: 200)];
      final a = groupNoticeFeedSignature(
        applications: const [],
        notices: notices,
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 0,
      );
      final b = groupNoticeFeedSignature(
        applications: const [],
        notices: notices,
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 0,
      );
      expect(a, b);
    });

    test('new notice changes signature', () {
      final before = groupNoticeFeedSignature(
        applications: const [],
        notices: [notice(id: 'n1', timestamp: 200)],
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 0,
      );
      final after = groupNoticeFeedSignature(
        applications: const [],
        notices: [
          notice(id: 'n1', timestamp: 200),
          notice(id: 'n2', timestamp: 500),
        ],
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 0,
      );
      expect(after, isNot(before));
    });

    test('dismiss watermark change alters signature', () {
      final notices = [notice(id: 'n1', timestamp: 200)];
      final before = groupNoticeFeedSignature(
        applications: const [],
        notices: notices,
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 0,
      );
      final after = groupNoticeFeedSignature(
        applications: const [],
        notices: notices,
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 100,
      );
      expect(after, isNot(before));
    });

    test('pinned flag change alters signature', () {
      final notices = [notice(id: 'n1', timestamp: 200)];
      final before = groupNoticeFeedSignature(
        applications: const [],
        notices: notices,
        includeGroupNoticeEntry: true,
        groupNoticePinned: false,
        dismissWatermarkMs: 0,
      );
      final after = groupNoticeFeedSignature(
        applications: const [],
        notices: notices,
        includeGroupNoticeEntry: true,
        groupNoticePinned: true,
        dismissWatermarkMs: 0,
      );
      expect(after, isNot(before));
    });
  });
}
