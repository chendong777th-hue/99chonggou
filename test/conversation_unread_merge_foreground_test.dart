import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

const _owner = 'user1';
const _conversationId = 'c2c_alice';

V2TimMessage _peerMessage({
  required String msgID,
  required int tsSec,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': tsSec,
    'message_msg_id': msgID,
    'message_is_from_self': false,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.timestamp = tsSec;
  message.elemType = 1;
  return message;
}

V2TimConversation _conversation({
  required int unreadCount,
  V2TimMessage? lastMessage,
}) {
  return V2TimConversation(
    conversationID: _conversationId,
    type: 1,
    userID: 'alice',
    unreadCount: unreadCount,
    lastMessage: lastMessage,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConversationLocalStore.instance.debugOwnerUserId = _owner;
  });

  tearDown(() {
    ForegroundChatGuard.debugOverride = null;
    ConversationLocalStore.instance.resetAnchorStateForTest();
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  group('ConversationLocalStore merge unread (sdk source of truth)', () {
    test('accepts sdk unread when local was zeroed after read', () {
      final existing = _conversation(unreadCount: 0);
      final incoming = _conversation(unreadCount: 1);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 5000,
      );

      expect(incoming.unreadCount, 1);
    });

    test('accepts sdk unread after grace would have expired', () {
      final existing = _conversation(unreadCount: 0);
      final incoming = _conversation(unreadCount: 3);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 20000,
      );

      expect(incoming.unreadCount, 3);
    });

    test('forces unread 0 for foreground chat', () {
      ForegroundChatGuard.debugOverride = (_) => true;
      final existing = _conversation(unreadCount: 0);
      final incoming = _conversation(unreadCount: 3);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 20000,
      );

      expect(incoming.unreadCount, 0);
    });

    test('accepts sdk unread decrease for cross-device read sync', () {
      final existing = _conversation(unreadCount: 5);
      final incoming = _conversation(unreadCount: 0);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 20000,
      );

      expect(incoming.unreadCount, 0);
    });

    test('accepts residual sdk unread decrease without new message', () {
      final existing = _conversation(unreadCount: 5);
      final incoming = _conversation(unreadCount: 2);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 20000,
      );

      expect(incoming.unreadCount, 2);
    });

    test('accepts sdk zero when db still has old unread after remote read', () {
      final existing = _conversation(unreadCount: 5);
      final incoming = _conversation(unreadCount: 0);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 1000,
      );

      expect(incoming.unreadCount, 0);
    });

    test('accepts sdk unread when lastMessage is newer than read watermark', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final readAtMs = now - 10000;
      final existing = _conversation(unreadCount: 0);
      final incoming = _conversation(
        unreadCount: 2,
        lastMessage: _peerMessage(
          msgID: 'new_msg',
          tsSec: (readAtMs ~/ 1000) + 30,
        ),
      );

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: readAtMs,
      );

      expect(incoming.unreadCount, 2);
    });

    test('trusts sdk unread when no local read anchor', () {
      final existing = _conversation(unreadCount: 0);
      final incoming = _conversation(unreadCount: 4);

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: existing,
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: 0,
      );

      expect(incoming.unreadCount, 4);
    });

    test('suppresses sdk unread replay with same lastMessage after read anchor', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      );

      final first = _conversation(
        unreadCount: 3,
        lastMessage: _peerMessage(msgID: 'anchor_msg', tsSec: now ~/ 1000 - 5),
      );
      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: _conversation(unreadCount: 0),
        incoming: first,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 5000,
      );
      expect(first.unreadCount, 0);

      final second = _conversation(
        unreadCount: 5,
        lastMessage: _peerMessage(msgID: 'anchor_msg', tsSec: now ~/ 1000 - 5),
      );
      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: _conversation(unreadCount: 0),
        incoming: second,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 5000,
      );
      expect(second.unreadCount, 0);
    });

    test('accepts a genuinely newer message after read anchor', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      );
      final incoming = _conversation(
        unreadCount: 1,
        lastMessage: _peerMessage(
          msgID: 'new_msg_after_open',
          tsSec: now ~/ 1000,
        ),
      );

      ConversationLocalStore.instance.mergeConversationUnreadForTest(
        existing: _conversation(unreadCount: 0),
        incoming: incoming,
        owner: _owner,
        conversationId: _conversationId,
        readClearedAtMs: now - 1000,
      );

      expect(incoming.unreadCount, 1);
    });
  });
}
