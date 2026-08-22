import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _conversation({
  required String id,
  bool pinned = false,
  int orderkey = 0,
  int activeTimestamp = 0,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    isPinned: pinned,
    orderkey: orderkey,
    draftTimestamp: activeTimestamp,
  );
}

void main() {
  group('ConversationLocalStore conversation sort', () {
    test('unpinned conversations sort by active time, not stale orderkey', () {
      final older = _conversation(
        id: 'group_internal',
        orderkey: 9999999999,
        activeTimestamp: 1718000000,
      );
      final newer = _conversation(
        id: 'c2c_recent',
        orderkey: 100,
        activeTimestamp: 1719000000,
      );

      expect(
        ConversationLocalStore.compareConversationsForTest(newer, older),
        lessThan(0),
      );
      expect(
        ConversationLocalStore.compareConversationsForTest(older, newer),
        greaterThan(0),
      );
    });

    test('pinned conversations stay above unpinned ones', () {
      final pinnedOlder = _conversation(
        id: 'group_pinned',
        pinned: true,
        orderkey: 1,
        activeTimestamp: 1718000000,
      );
      final unpinnedNewer = _conversation(
        id: 'c2c_recent',
        orderkey: 9999999999,
        activeTimestamp: 1719000000,
      );

      expect(
        ConversationLocalStore.compareConversationsForTest(
          pinnedOlder,
          unpinnedNewer,
        ),
        lessThan(0),
      );
    });

    test('equal sort keys use conversationID as stable tie-break', () {
      final a = _conversation(
        id: 'c2c_a',
        orderkey: 100,
        activeTimestamp: 1719000000,
      );
      final b = _conversation(
        id: 'c2c_b',
        orderkey: 100,
        activeTimestamp: 1719000000,
      );

      expect(
        ConversationLocalStore.compareConversationsForUi(a, b),
        lessThan(0),
      );
      expect(
        ConversationLocalStore.compareConversationsForUi(b, a),
        greaterThan(0),
      );
      expect(
        ConversationLocalStore.compareConversationsForUi(a, a),
        0,
      );
    });

    test('merge helper preserves UI order across two sorted lists', () {
      final c1 = _conversation(
        id: 'c2c_1',
        orderkey: 0,
        activeTimestamp: 4,
      );
      final c3 = _conversation(
        id: 'c2c_3',
        orderkey: 0,
        activeTimestamp: 1,
      );
      final c2 = _conversation(
        id: 'c2c_2',
        orderkey: 0,
        activeTimestamp: 3,
      );
      final c4 = _conversation(
        id: 'c2c_4',
        orderkey: 0,
        activeTimestamp: 0,
      );

      final merged = ConversationLocalStore.mergeConversationsForUi(
        [c1, c3],
        [c2, c4],
      );

      expect(
        merged.map((c) => c.conversationID),
        ['c2c_1', 'c2c_2', 'c2c_3', 'c2c_4'],
      );
    });
  });
}
