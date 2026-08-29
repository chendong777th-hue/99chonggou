import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_guard.dart';
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
    ConversationUnreadGuard.clearOptimisticUnread(_conversationId);
    ConversationLocalStore.instance.resetAnchorStateForTest();
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  group('ConversationUnreadGuard.resolveForListApply', () {
    test('passes through sdk unread when no read anchor', () {
      final incoming = _conversation(unreadCount: 3);

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 0,
        incoming: incoming,
      );

      expect(resolved, 3);
      expect(incoming.unreadCount, 3);
    });

    test('accepts sdk unread decrease for cross-device read', () {
      final incoming = _conversation(unreadCount: 0);

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 5,
        incoming: incoming,
      );

      expect(resolved, 0);
    });

    test('forces zero for foreground chat', () {
      ForegroundChatGuard.debugOverride = (_) => true;
      final incoming = _conversation(unreadCount: 4);

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 0,
        incoming: incoming,
      );

      expect(resolved, 0);
      expect(incoming.unreadCount, 0);
    });

    test('suppresses sdk unread replay when last message equals read anchor',
        () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      );
      final incoming = _conversation(
        unreadCount: 4,
        lastMessage: _peerMessage(msgID: 'anchor_msg', tsSec: nowSec - 10),
      );

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 0,
        incoming: incoming,
        ownerUserId: _owner,
      );

      expect(resolved, 0);
      expect(incoming.unreadCount, 0);
    });

    test('preserves optimistic unread when sdk lags on new lastMessage', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final existingLast = _peerMessage(msgID: 'old_msg', tsSec: nowSec - 20);
      final incomingLast = _peerMessage(msgID: 'new_msg', tsSec: nowSec);
      final incoming = _conversation(
        unreadCount: 2,
        lastMessage: incomingLast,
      );

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 3,
        incoming: incoming,
        existingLastMessage: existingLast,
      );

      expect(resolved, 3);
      expect(incoming.unreadCount, 3);
    });

    test('accepts sdk unread decrease when lastMessage unchanged', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final last = _peerMessage(msgID: 'same_msg', tsSec: nowSec);
      final incoming = _conversation(unreadCount: 0, lastMessage: last);

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 5,
        incoming: incoming,
        existingLastMessage: last,
      );

      expect(resolved, 0);
    });

    test('preserves optimistic unread when sdk replays same message with zero',
        () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final latest = _peerMessage(msgID: 'new_msg', tsSec: nowSec);
      ConversationUnreadGuard.recordOptimisticUnread(
        conversationId: _conversationId,
        message: latest,
        unreadCount: 1,
      );
      final incoming = _conversation(
        unreadCount: 0,
        lastMessage: _peerMessage(msgID: 'new_msg', tsSec: nowSec),
      );

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 1,
        incoming: incoming,
        existingLastMessage: latest,
      );

      expect(resolved, 1);
      expect(incoming.unreadCount, 1);
    });

    test('preserves optimistic unread when sdk replays an older message', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final latest = _peerMessage(msgID: 'new_msg', tsSec: nowSec);
      ConversationUnreadGuard.recordOptimisticUnread(
        conversationId: _conversationId,
        message: latest,
        unreadCount: 1,
      );
      final incoming = _conversation(
        unreadCount: 0,
        lastMessage: _peerMessage(msgID: 'old_msg', tsSec: nowSec - 1),
      );

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 1,
        incoming: incoming,
        existingLastMessage: latest,
      );

      expect(resolved, 1);
      expect(incoming.unreadCount, 1);
    });

    test('explicit read barrier overrides optimistic unread protection', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final latest = _peerMessage(msgID: 'new_msg', tsSec: nowSec);
      ConversationUnreadGuard.recordOptimisticUnread(
        conversationId: _conversationId,
        message: latest,
        unreadCount: 1,
      );
      ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'new_msg',
      );
      final incoming = _conversation(
        unreadCount: 0,
        lastMessage: latest,
      );

      final resolved = ConversationUnreadGuard.resolveForListApply(
        conversationId: _conversationId,
        existingUnread: 1,
        incoming: incoming,
        existingLastMessage: latest,
        ownerUserId: _owner,
      );

      expect(resolved, 0);
      expect(incoming.unreadCount, 0);
    });
  });

  group('ConversationUnreadGuard.shouldOptimisticBumpUnread', () {
    test('returns false for self messages', () {
      final message = _peerMessage(msgID: 'm1', tsSec: 1);
      message.isSelf = true;

      expect(
        ConversationUnreadGuard.shouldOptimisticBumpUnread(
          conversationId: _conversationId,
          message: message,
        ),
        isFalse,
      );
    });

    test('returns false for foreground chat', () {
      ForegroundChatGuard.debugOverride = (_) => true;
      final message = _peerMessage(msgID: 'm1', tsSec: 1);

      expect(
        ConversationUnreadGuard.shouldOptimisticBumpUnread(
          conversationId: _conversationId,
          message: message,
        ),
        isFalse,
      );
    });
  });

  group('ConversationUnreadGuard.resolveForPersist', () {
    test('passes through sdk unread when no read anchor', () {
      final conversation = _conversation(unreadCount: 2);

      final resolved = ConversationUnreadGuard.resolveForPersist(
        conversation: conversation,
        uiUnread: 0,
        suppressStaleForRecentlyLeft: false,
      );

      expect(resolved, 2);
      expect(conversation.unreadCount, 2);
    });

    test(
        'suppresses persisted unread replay when last message equals read anchor',
        () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      );
      final conversation = _conversation(
        unreadCount: 2,
        lastMessage: _peerMessage(msgID: 'anchor_msg', tsSec: nowSec - 10),
      );

      final resolved = ConversationUnreadGuard.resolveForPersist(
        conversation: conversation,
        uiUnread: 0,
        suppressStaleForRecentlyLeft: false,
        ownerUserId: _owner,
      );

      expect(resolved, 0);
      expect(conversation.unreadCount, 0);
    });
  });

  group('ConversationLocalStore read version barrier', () {
    test('rejects delayed sdk replay in the same read version', () {
      final barrier = ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      );
      final replay = _conversation(
        unreadCount: 6,
        lastMessage: _peerMessage(msgID: 'anchor_msg', tsSec: 1),
      );

      final floor =
          ConversationLocalStore.instance.resolveSdkUnreadAgainstReadBarrier(
        replay,
        ownerUserId: _owner,
      );

      expect(barrier, isNotNull);
      expect(floor, barrier!.version);
      expect(replay.unreadCount, 0);
      expect(
        ConversationLocalStore.instance.readBarrierFor(
          _conversationId,
          ownerUserId: _owner,
        ),
        isNotNull,
      );
    });

    test('provably newer message consumes barrier at a higher version', () {
      final barrier = ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      )!;
      final incoming = _conversation(
        unreadCount: 1,
        lastMessage: _peerMessage(msgID: 'new_msg', tsSec: 2),
      );

      final floor =
          ConversationLocalStore.instance.resolveSdkUnreadAgainstReadBarrier(
        incoming,
        ownerUserId: _owner,
      );

      expect(floor, greaterThan(barrier.version));
      expect(incoming.unreadCount, 1);
      expect(
        ConversationLocalStore.instance.readBarrierFor(
          _conversationId,
          ownerUserId: _owner,
        ),
        isNull,
      );
    });

    test('old snapshot with a larger orderkey cannot consume barrier', () {
      final barrier = ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
        lastMessageTimestamp: 100,
        orderKey: 100,
      )!;
      final replay = _conversation(
        unreadCount: 9,
        lastMessage: _peerMessage(msgID: 'anchor_msg', tsSec: 100),
      )..orderkey = 999999999;

      final floor =
          ConversationLocalStore.instance.resolveSdkUnreadAgainstReadBarrier(
        replay,
        ownerUserId: _owner,
      );

      expect(floor, barrier.version);
      expect(replay.unreadCount, 0);
      expect(
        ConversationLocalStore.instance.readBarrierFor(
          _conversationId,
          ownerUserId: _owner,
        ),
        isNotNull,
      );
    });

    test('group aliases resolve to one read barrier', () {
      const canonical = 'group_@TGS#watermark';
      const sdkAlias = '@TGS#watermark';
      ConversationLocalStore.instance.recordReadClearedAnchor(
        canonical,
        ownerUserId: _owner,
        lastMessageId: 'anchor_group',
        lastMessageTimestamp: 100,
      );
      final replay = V2TimConversation(
        conversationID: sdkAlias,
        type: 2,
        groupID: sdkAlias,
        unreadCount: 4,
        lastMessage: _peerMessage(msgID: 'anchor_group', tsSec: 100),
      );

      ConversationLocalStore.instance.resolveSdkUnreadAgainstReadBarrier(
        replay,
        ownerUserId: _owner,
      );

      expect(replay.unreadCount, 0);
      expect(
        ConversationLocalStore.instance.readBarrierFor(
          sdkAlias,
          ownerUserId: _owner,
        ),
        isNotNull,
      );
    });

    test('each local clear advances the barrier version', () {
      final first = ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      )!;
      final second = ConversationLocalStore.instance.recordReadClearedAnchor(
        _conversationId,
        ownerUserId: _owner,
        lastMessageId: 'anchor_msg',
      )!;

      expect(second.version, greaterThan(first.version));
    });
  });
}
