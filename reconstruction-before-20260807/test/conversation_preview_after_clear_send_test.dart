import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

V2TimMessage _message({
  required String msgID,
  required int tsSec,
  bool isSelf = true,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': tsSec,
    'message_msg_id': msgID,
    'message_is_from_self': isSelf,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('preview after history clear then send', () {
    const owner = 'owner_clear_send';
    const conversationId = 'c2c_peer_clear_send';

    setUp(() async {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      ConversationLocalStore.instance.resetAnchorStateForTest();
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearSession();
      ConversationListNotifier.instance.clearSession();
    });

    tearDown(() async {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      await ConversationLocalStore.instance.clearSession();
      ConversationListNotifier.instance.clearSession();
      ConversationLocalStore.instance.resetAnchorStateForTest();
    });

    Future<void> seedAndClear() async {
      final oldTsSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'old_msg', tsSec: oldTsSec),
            orderkey: oldTsSec,
          ),
        ],
        ownerUserId: owner,
      );
      final cleared = await ConversationLocalStore.instance
          .clearConversationLastMessage(conversationId, ownerUserId: owner);
      expect(cleared?.lastMessage, isNull);
    }

    test('store merge accepts newer message sent after clear', () async {
      await seedAndClear();

      // 发送发生在清空之后（下一秒起）。
      final sendTsSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2;
      final merged = await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'new_msg', tsSec: sendTsSec),
            orderkey: sendTsSec,
          ),
        ],
        ownerUserId: owner,
      );
      expect(merged.single.lastMessage?.msgID, 'new_msg');

      final stored = await ConversationLocalStore.instance
          .conversationById(conversationId, ownerUserId: owner);
      expect(stored?.lastMessage?.msgID, 'new_msg');
    });

    test('sync service persistChanged path shows preview after clear',
        () async {
      await seedAndClear();

      final sendTsSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2;
      await ConversationSyncService.instance.persistChangedForTest(
        [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'new_msg', tsSec: sendTsSec),
            orderkey: sendTsSec,
          ),
        ],
        reason: 'changed',
      );

      final stored = await ConversationLocalStore.instance
          .conversationById(conversationId, ownerUserId: owner);
      expect(stored?.lastMessage?.msgID, 'new_msg');

      final uiItem = ConversationListNotifier.instance.conversations
          .where((c) => c.conversationID == conversationId)
          .toList();
      expect(uiItem, isNotEmpty);
      expect(uiItem.first.lastMessage?.msgID, 'new_msg');
    });

    test('late sdk delete after send keeps new preview visible', () async {
      await seedAndClear();
      // 后端归档 DELETE 仍在途：pending 保持。
      ArchiveHistoryProvider.markHistoryClearPending(conversationId);
      addTearDown(
        () => ArchiveHistoryProvider.clearHistoryClearPending(conversationId),
      );

      // 清空后发送新消息，预览已恢复。
      final sendTsSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2;
      await ConversationSyncService.instance.persistChangedForTest(
        [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'new_msg', tsSec: sendTsSec),
            orderkey: sendTsSec,
          ),
        ],
        reason: 'changed',
      );

      // SDK 清空联动的 onConversationDeleted 迟到：删除被抑制、保壳，
      // 但不能把清空之后新发的预览抹掉。
      await ConversationSyncService.instance.persistDeletedForTest(
        [conversationId],
      );

      final uiItem = ConversationListNotifier.instance.conversations
          .where((c) => c.conversationID == conversationId)
          .toList();
      expect(uiItem, isNotEmpty);
      expect(uiItem.first.lastMessage?.msgID, 'new_msg');

      final stored = await ConversationLocalStore.instance
          .conversationById(conversationId, ownerUserId: owner);
      expect(stored?.lastMessage?.msgID, 'new_msg');
    });

    test(
        'clock skew: message sent after clear with server ts behind device '
        'clock keeps preview', () async {
      // 设备时钟比 IM 服务器快约 2 分钟：清空前的最后一条消息服务器时间
      // 是「5 分钟前」，清空后立刻发送的新消息服务器时间是「90 秒前」——
      // 仍早于清空那一刻的本机 now。水位若取本机 now 会把新消息误判为
      // 清空前的旧预览。水位应取被清的最后一条消息时间。
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final clearedPreviewTsSec = nowSec - 300;
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'old_msg', tsSec: clearedPreviewTsSec),
            orderkey: clearedPreviewTsSec,
          ),
        ],
        ownerUserId: owner,
      );
      final cleared = await ConversationLocalStore.instance
          .clearConversationLastMessage(conversationId, ownerUserId: owner);
      expect(cleared?.lastMessage, isNull);

      // 新消息：本机墙钟晚于清空，但服务器时间戳仍落后本机 now 90 秒。
      final skewedSendTsSec = nowSec - 90;
      final merged = await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'new_msg', tsSec: skewedSendTsSec),
            orderkey: skewedSendTsSec,
          ),
        ],
        ownerUserId: owner,
      );
      expect(merged.single.lastMessage?.msgID, 'new_msg');

      final stored = await ConversationLocalStore.instance
          .conversationById(conversationId, ownerUserId: owner);
      expect(stored?.lastMessage?.msgID, 'new_msg');

      // 水位已被更新的预览重置：清空前的旧消息不会再穿透。
      final clearedAt = await ConversationLocalStore.instance
          .historyClearedAtMs(conversationId, ownerUserId: owner);
      expect(clearedAt, 0);
    });

    test('clock skew: stale pre-clear preview is still stripped', () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final clearedPreviewTsSec = nowSec - 300;
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'old_msg', tsSec: clearedPreviewTsSec),
            orderkey: clearedPreviewTsSec,
          ),
        ],
        ownerUserId: owner,
      );
      await ConversationLocalStore.instance
          .clearConversationLastMessage(conversationId, ownerUserId: owner);

      // SDK 迟到回写清空前的旧 lastMessage（时间戳 <= 水位）：仍要抹掉。
      final merged = await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'old_msg', tsSec: clearedPreviewTsSec),
            orderkey: clearedPreviewTsSec,
          ),
        ],
        ownerUserId: owner,
      );
      // 迟到的旧预览经清历史水位合并后与库内状态完全一致，不应再产生
      // 数据库写入或下游 UI 补丁。
      expect(merged, isEmpty);
      final stored = await ConversationLocalStore.instance
          .conversationById(conversationId, ownerUserId: owner);
      expect(stored?.lastMessage, isNull);
    });

    test('sending-status message with zero timestamp then final resolves',
        () async {
      await seedAndClear();

      // 发送中：SDK 变更事件可能带 ts=0 的占位消息。
      final sending = _message(msgID: 'new_msg', tsSec: 0);
      sending.timestamp = 0;
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: sending,
          ),
        ],
        ownerUserId: owner,
      );

      // 发送成功：带最终时间戳再回写。
      final sendTsSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2;
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: conversationId,
            type: 1,
            userID: 'peer_clear_send',
            lastMessage: _message(msgID: 'new_msg', tsSec: sendTsSec),
            orderkey: sendTsSec,
          ),
        ],
        ownerUserId: owner,
      );

      final stored = await ConversationLocalStore.instance
          .conversationById(conversationId, ownerUserId: owner);
      expect(stored?.lastMessage?.msgID, 'new_msg');
    });
  });
}
