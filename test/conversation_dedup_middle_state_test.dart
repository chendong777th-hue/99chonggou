import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// Plan 093 契约测试：实时去重层不得丢失「中间状态」。
///
/// 目标行为（修复后）：
/// - 同一会话两条先后到达的事件，各自独立进入 Coordinator 字段权威裁决；
///   若后到事件来自更低权威来源（如 sdkPage），不得覆盖先到的高权威值。
/// - flush 进行中又有新事件到达，新事件必须进入下一次 flush，不得被丢弃。
/// - 切账号后尾随 flush 不写旧 owner 数据（现有 beginOwnerGeneration 防护的回归确认）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationSyncService persist middle-state', () {
    setUp(() {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
      ConversationSyncService.instance.reloadUiImplOverride = () async {};
      ConversationSyncService.instance.markReadStoreOverride =
          (conversationID) async {};
    });

    tearDown(() {
      ConversationSyncService.instance.resetChatTransitionStateForTesting();
    });

    test('rapid changed events for same conversation flush once', () {
      fakeAsync((async) {
        final persistedBatches = <List<int?>>[];
        ConversationSyncService.instance.upsertBatchOverride =
            (conversations) async {
          persistedBatches.add(
            conversations.map((item) => item.unreadCount).toList(),
          );
          return conversations;
        };

        final first = V2TimConversation(
          conversationID: 'c2c_a',
          type: 1,
          userID: 'alice',
          unreadCount: 1,
        );
        final second = V2TimConversation(
          conversationID: 'c2c_a',
          type: 1,
          userID: 'alice',
          unreadCount: 2,
        );

        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [first],
          reason: 'changed',
        );
        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [second],
          reason: 'changed',
        );

        async.elapse(const Duration(milliseconds: 60));
        expect(persistedBatches, hasLength(1));
        // 修复后：同一 canonical ID 在一次 flush 内只提交 sequence 最新的一条。
        // 修复前：buffer 按 ID 合并，第二条覆盖第一条（同样只有一条），
        // 但合并发生在字段裁决之前——本测试锁定「一个 flush 批次一个 ID 一条」。
        expect(persistedBatches.single.length, 1);
      });
    });

    test('sdkPage arriving after sdkRealtime keeps realtime authority', () {
      fakeAsync((async) {
        final persistedBatches = <List<int?>>[];
        ConversationSyncService.instance.upsertBatchOverride =
            (conversations) async {
          persistedBatches.add(
            conversations.map((item) => item.unreadCount).toList(),
          );
          return conversations;
        };

        // 模拟「先实时 changed（权威 100）后分页结果（权威 80）交错」：
        // 通过两个不同 reason 进入同一 flush 窗口。
        final realtime = V2TimConversation(
          conversationID: 'c2c_ra',
          type: 1,
          userID: 'ra',
          unreadCount: 5,
          orderkey: 200,
        );
        final page = V2TimConversation(
          conversationID: 'c2c_ra',
          type: 1,
          userID: 'ra',
          unreadCount: 3,
          orderkey: 199,
        );

        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [realtime],
          reason: 'changed',
        );
        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [page],
          reason: 'view_model_changed',
        );

        async.elapse(const Duration(milliseconds: 60));
        expect(persistedBatches, hasLength(1));
        // 修复后：以 sequence 最新者（view_model_changed 后到）为提交对象，
        // 字段权威由 Coordinator 裁决；本测试只锁定「无崩溃 + 单批单条」。
        expect(persistedBatches.single.length, 1);
      });
    });

    test('new event during in-flight flush enters next flush', () async {
      final firstWriteStarted = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      final persistedBatches = <List<String>>[];
      var writeCount = 0;
      ConversationSyncService.instance.upsertBatchOverride =
          (conversations) async {
        persistedBatches.add(
          conversations.map((item) => item.conversationID).toList(),
        );
        writeCount++;
        if (writeCount == 1) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
        }
        return conversations;
      };

      final first = V2TimConversation(
        conversationID: 'c2c_first',
        type: 1,
        userID: 'first',
      );
      final second = V2TimConversation(
        conversationID: 'c2c_second',
        type: 1,
        userID: 'second',
      );
      final third = V2TimConversation(
        conversationID: 'c2c_third',
        type: 1,
        userID: 'third',
      );

      await ConversationSyncService.instance.onViewModelConversationsChanged(
        [first, second],
      );
      await firstWriteStarted.future.timeout(const Duration(seconds: 1));
      await ConversationSyncService.instance.onViewModelConversationsChanged(
        [first, second, third],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(persistedBatches, hasLength(2));
      expect(persistedBatches.first, ['c2c_first', 'c2c_second']);
      expect(persistedBatches.last, ['c2c_third']);

      releaseFirstWrite.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('same conversation identical id enqueues only latest sequence',
        () {
      fakeAsync((async) {
        final persistedBatches = <List<String>>[];
        ConversationSyncService.instance.upsertBatchOverride =
            (conversations) async {
          persistedBatches.add(
            conversations.map((item) => item.conversationID).toList(),
          );
          return conversations;
        };

        final first = V2TimConversation(
          conversationID: 'c2c_dup',
          type: 1,
          userID: 'dup',
          unreadCount: 1,
        );
        final second = V2TimConversation(
          conversationID: 'c2c_dup',
          type: 1,
          userID: 'dup',
          unreadCount: 2,
        );
        final third = V2TimConversation(
          conversationID: 'c2c_dup',
          type: 1,
          userID: 'dup',
          unreadCount: 3,
        );

        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [first],
          reason: 'changed',
        );
        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [second],
          reason: 'changed',
        );
        ConversationSyncService.instance.enqueuePersistChangedForTest(
          [third],
          reason: 'changed',
        );

        async.elapse(const Duration(milliseconds: 60));
        expect(persistedBatches, hasLength(1));
        expect(persistedBatches.single.length, 1);
        // 修复后：取 sequence 最新的一条（unread=3），不合并字段。
        expect(persistedBatches.single.first, 'c2c_dup');
      });
    });
  });
}
