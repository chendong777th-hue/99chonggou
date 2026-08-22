import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_history_peer.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

void main() {
  group('ConversationHistoryPeer.resolve', () {
    test('c2c_ forces C2C even when groupID/type wrongly set', () {
      final peer = ConversationHistoryPeer.resolve(
        V2TimConversation(
          conversationID: 'c2c_peer1',
          type: 2,
          userID: 'peer1',
          groupID: 'c2c_peer1',
        ),
      );
      expect(peer, isNotNull);
      expect(peer!.isGroup, isFalse);
      expect(peer.userID, 'peer1');
      expect(peer.groupID, isNull);
      expect(peer.canFetch, isTrue);
    });

    test('c2c_ derives userID from conversationID when userID empty', () {
      final peer = ConversationHistoryPeer.resolve(
        V2TimConversation(conversationID: 'c2c_abc', type: 1),
      );
      expect(peer!.isGroup, isFalse);
      expect(peer.userID, 'abc');
    });

    test('group_ forces group', () {
      final peer = ConversationHistoryPeer.resolve(
        V2TimConversation(
          conversationID: 'group_g1',
          type: 1,
          userID: 'should_ignore',
          groupID: 'g1',
        ),
      );
      expect(peer!.isGroup, isTrue);
      expect(peer.groupID, 'g1');
      expect(peer.userID, isNull);
    });

    test('empty conversationID returns null', () {
      expect(
        ConversationHistoryPeer.resolve(
          V2TimConversation(conversationID: '  ', type: 1),
        ),
        isNull,
      );
    });
  });
}
