import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_recovery_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

void main() {
  tearDown(() {
    ChatHistoryRecoveryCoordinator.instance.resetForTest();
  });

  group('ChatHistoryRecoveryCoordinator.shouldSkipForegroundRecovery', () {
    test('skips sync_server_finish when recently recovered with messages', () {
      const key = 'alice';
      ChatHistoryRecoveryCoordinator.instance.recordSuccessfulRecovery(key);

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
          conversationKey: key,
          hasVisibleMessages: true,
          previewAhead: false,
          reason: 'sync_server_finish',
        ),
        isTrue,
      );
    });

    test('does not skip when preview is ahead for sync reasons', () {
      const key = 'alice';
      ChatHistoryRecoveryCoordinator.instance.recordSuccessfulRecovery(key);

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
          conversationKey: key,
          hasVisibleMessages: true,
          previewAhead: true,
          reason: 'sync_server_finish',
        ),
        isFalse,
      );
    });

    test('skips conversation_open_preview_ahead when recently recovered', () {
      const key = 'alice';
      ChatHistoryRecoveryCoordinator.instance.recordSuccessfulRecovery(key);

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
          conversationKey: key,
          hasVisibleMessages: true,
          previewAhead: true,
          reason: 'conversation_open_preview_ahead',
        ),
        isTrue,
      );
    });

    test('does not skip first warm app_resumed without a prior recovery', () {
      const key = 'alice';

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
          conversationKey: key,
          hasVisibleMessages: true,
          previewAhead: false,
          reason: 'app_resumed',
        ),
        isFalse,
      );
    });

    test('does not skip app_resumed when preview is ahead', () {
      const key = 'alice';
      ChatHistoryRecoveryCoordinator.instance.recordSuccessfulRecovery(key);

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
          conversationKey: key,
          hasVisibleMessages: true,
          previewAhead: true,
          reason: 'app_resumed',
        ),
        isFalse,
      );
    });

    test('does not skip app_resumed when deferred incoming remains', () {
      const key = 'alice';
      ChatHistoryRecoveryCoordinator.instance.recordSuccessfulRecovery(key);

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
          conversationKey: key,
          hasVisibleMessages: true,
          previewAhead: false,
          reason: 'app_resumed',
          hasDeferredIncoming: true,
        ),
        isFalse,
      );
    });
  });

  group('ChatHistoryRecoveryCoordinator foreground request coalescing', () {
    test('coalesces resume and reconnect signals from the same unlock', () {
      const key = 'unlock-chat';

      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldCoalesceForegroundRequest(
          conversationKey: key,
          reason: 'app_resumed',
        ),
        isFalse,
      );
      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldCoalesceForegroundRequest(
          conversationKey: key,
          reason: 'im_reconnected',
        ),
        isTrue,
      );
    });

    test('does not coalesce unrelated recovery reasons', () {
      expect(
        ChatHistoryRecoveryCoordinator.instance.shouldCoalesceForegroundRequest(
          conversationKey: 'sync-chat',
          reason: 'sync_server_finish',
        ),
        isFalse,
      );
    });
  });

  group('ChatHistoryRecoveryCoordinator.runExclusive', () {
    test('runs tasks for the same key sequentially', () async {
      const key = 'bob';
      final order = <int>[];

      await Future.wait<void>([
        ChatHistoryRecoveryCoordinator.instance.runExclusive(
          conversationKey: key,
          reason: 'first',
          priority: ChatHistoryRecoveryCoordinator.priorityUser,
          task: () async {
            order.add(1);
            await Future<void>.delayed(const Duration(milliseconds: 40));
            order.add(2);
          },
        ),
        ChatHistoryRecoveryCoordinator.instance.runExclusive(
          conversationKey: key,
          reason: 'second',
          priority: ChatHistoryRecoveryCoordinator.priorityUser,
          task: () async {
            order.add(3);
          },
        ),
      ]);

      expect(order, <int>[1, 2, 3]);
    });

    test('keeps only the latest trigger while a task is active', () async {
      const key = 'latest-chat';
      final gate = Completer<void>();
      final order = <int>[];

      final first = ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'first',
        priority: ChatHistoryRecoveryCoordinator.priorityUser,
        task: () async {
          order.add(1);
          await gate.future;
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final stale = ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'stale',
        priority: ChatHistoryRecoveryCoordinator.priorityUser,
        task: () async => order.add(2),
      );
      final latest = ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'latest',
        priority: ChatHistoryRecoveryCoordinator.priorityUser,
        task: () async => order.add(3),
      );

      gate.complete();
      await Future.wait<void>(<Future<void>>[first, stale, latest]);
      expect(order, <int>[1, 3]);
    });

    test('lifecycle invalidation drops pending recovery without running it',
        () async {
      const key = 'lifecycle-chat';
      final gate = Completer<void>();
      var runs = 0;
      final first = ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'first',
        priority: ChatHistoryRecoveryCoordinator.priorityUser,
        task: () async {
          runs++;
          await gate.future;
        },
      );
      for (var i = 0; i < 20 && runs == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final pending = ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'pending',
        priority: ChatHistoryRecoveryCoordinator.priorityUser,
        task: () async => runs++,
      );
      ChatHistoryRecoveryCoordinator.instance.invalidateLifecycle();
      gate.complete();
      await Future.wait<void>(<Future<void>>[first, pending]);
      expect(runs, 1);
    });
  });

  group('ChatHistoryRecoveryCoordinator initial load gate', () {
    test('waits for initial load completion before lower priority work',
        () async {
      const key = 'carol';
      ChatHistoryRecoveryCoordinator.instance.beginInitialLoad(key);

      var ran = false;
      final pending = ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'user',
        priority: ChatHistoryRecoveryCoordinator.priorityUser,
        task: () async {
          ran = true;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ran, isFalse);

      ChatHistoryRecoveryCoordinator.instance.markInitialLoadComplete(key);
      await pending;
      expect(ran, isTrue);
    });
  });

  group('ChatHistoryRecoveryCoordinator post-open retry', () {
    test('allows scheduling again after previous retry finishes', () async {
      const key = 'erin';
      var runs = 0;

      void schedule() {
        ChatHistoryRecoveryCoordinator.instance.schedulePostOpenRetry(
          conversationKey: key,
          conversationID: key,
          conversationType: ConvType.c2c,
          delay: Duration.zero,
          retry: ({
            required String conversationID,
            ConvType? conversationType,
          }) async {
            runs += 1;
          },
        );
      }

      schedule();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      schedule();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(runs, 2);
    });
  });

  group('ChatHistoryRecoveryCoordinator priority drop', () {
    test('drops lower-priority task while higher-priority task is active',
        () async {
      const key = 'dave';
      final gate = Completer<void>();
      var backgroundRan = false;

      unawaited(
        ChatHistoryRecoveryCoordinator.instance.runExclusive(
          conversationKey: key,
          reason: 'user',
          priority: ChatHistoryRecoveryCoordinator.priorityUser,
          task: () async {
            await gate.future;
          },
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      await ChatHistoryRecoveryCoordinator.instance.runExclusive(
        conversationKey: key,
        reason: 'background',
        priority: ChatHistoryRecoveryCoordinator.priorityBackground,
        task: () async {
          backgroundRan = true;
        },
      );

      expect(backgroundRan, isFalse);
      gate.complete();
    });
  });
}
