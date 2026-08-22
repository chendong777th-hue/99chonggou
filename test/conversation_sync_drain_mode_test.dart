import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_badge_unread_utils.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';

void main() {
  group('ConversationSdkDrainMode resolve', () {
    test('paced: reset maps to foregroundLimited not full drain', () {
      expect(
        ConversationSyncService.resolveDrainMode(
          pacedSdkPersist: true,
          reset: true,
          force: false,
          loadAllPages: false,
        ),
        ConversationSdkDrainMode.foregroundLimited,
      );
    });

    test('paced: force maps to foregroundLimited', () {
      expect(
        ConversationSyncService.resolveDrainMode(
          pacedSdkPersist: true,
          reset: false,
          force: true,
          loadAllPages: false,
        ),
        ConversationSdkDrainMode.foregroundLimited,
      );
    });

    test('paced: plain call is singlePage', () {
      expect(
        ConversationSyncService.resolveDrainMode(
          pacedSdkPersist: true,
          reset: false,
          force: false,
          loadAllPages: false,
        ),
        ConversationSdkDrainMode.singlePage,
      );
    });

    test('paced: explicit drainMode wins', () {
      expect(
        ConversationSyncService.resolveDrainMode(
          pacedSdkPersist: true,
          reset: true,
          force: true,
          loadAllPages: true,
          drainMode: ConversationSdkDrainMode.singlePage,
        ),
        ConversationSdkDrainMode.singlePage,
      );
    });

    test('unpaced: reset behaves like multi-page continue', () {
      expect(
        ConversationSyncService.resolveDrainMode(
          pacedSdkPersist: false,
          reset: true,
          force: false,
          loadAllPages: false,
        ),
        ConversationSdkDrainMode.backgroundContinue,
      );
    });
  });

  group('ConversationPerfFlags', () {
    test('locked constants match plan', () {
      expect(ConversationPerfFlags.bootstrapForegroundPages, 2);
      expect(ConversationPerfFlags.backgroundPageYield.inMilliseconds, 80);
      expect(ConversationPerfFlags.backgroundUiRefreshEveryPages, 0);
      expect(ConversationPerfFlags.uiWindowHardCap, lessThanOrEqualTo(0));
      expect(ConversationPerfFlags.uiWindowHardCapEnabled, isFalse);
      expect(ConversationPerfFlags.uiSlidingWindowEnabled, isTrue);
      expect(ConversationPerfFlags.uiSlidingWindowActive, isTrue);
      expect(ConversationPerfFlags.uiSlidingWindowBudget, 120);
      expect(ConversationPerfFlags.softReloadByIdsMax, lessThanOrEqualTo(0));
      expect(ConversationPerfFlags.upsertWriteCoalesceEnabled, isTrue);
      expect(ConversationPerfFlags.sdkSyncAdmitColdConversations, isFalse);
      expect(ConversationPerfFlags.uiSnapshotEnabled, isTrue);
      expect(ConversationPerfFlags.uiSnapshotC2cLimit, 40);
      expect(ConversationPerfFlags.uiSnapshotGroupLimit, 40);
      expect(ConversationPerfFlags.idleDrainStartDelay.inSeconds, 3);
      expect(ConversationPerfFlags.snapshotDrainStartDelay.inSeconds, 8);
      expect(ConversationPerfFlags.snapshotPriorityC2cLimit, 20);
      expect(ConversationPerfFlags.snapshotRequestGroupFloor, 1);
      expect(ConversationPerfFlags.snapshotRequestMessageFloor, 30);
      expect(ConversationPerfFlags.pacedSdkPersist, isTrue);
      expect(ConversationPerfFlags.idleBackgroundDrainEnabled, isTrue);
      expect(ConversationPerfFlags.idleDrainSessionPageBudget, 64);
      expect(ConversationPerfFlags.postPopLightReloadEnabled, isTrue);
      expect(ConversationPerfFlags.isolateRowDecodeEnabled, isTrue);
      expect(ConversationPerfFlags.isolateRowDecodeMinRows, 24);
    });
  });

  group('idle drain resume gate', () {
    test('disabled flag never resumes', () {
      expect(
        ConversationSyncService.shouldScheduleIdleDrainResume(
          idleBackgroundDrainEnabled: false,
          haveMore: true,
          sessionDrainPages: 0,
          sessionDrainPageBudget: 4,
        ),
        isFalse,
      );
    });

    test('no haveMore never resumes', () {
      expect(
        ConversationSyncService.shouldScheduleIdleDrainResume(
          idleBackgroundDrainEnabled: true,
          haveMore: false,
          sessionDrainPages: 0,
          sessionDrainPageBudget: 4,
        ),
        isFalse,
      );
    });

    test('budget exhausted never resumes', () {
      expect(
        ConversationSyncService.shouldScheduleIdleDrainResume(
          idleBackgroundDrainEnabled: true,
          haveMore: true,
          sessionDrainPages: 4,
          sessionDrainPageBudget: 4,
        ),
        isFalse,
      );
    });

    test('enabled haveMore under budget resumes', () {
      expect(
        ConversationSyncService.shouldScheduleIdleDrainResume(
          idleBackgroundDrainEnabled: true,
          haveMore: true,
          sessionDrainPages: 1,
          sessionDrainPageBudget: 4,
        ),
        isTrue,
      );
    });
  });

  group('conversation sync account generation gate', () {
    test('accepts only the same owner and generation', () {
      expect(
        ConversationSyncService.isSyncResultCurrent(
          startedOwner: 'a',
          startedGeneration: 7,
          currentOwner: 'a',
          currentGeneration: 7,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.isSyncResultCurrent(
          startedOwner: 'a',
          startedGeneration: 7,
          currentOwner: 'b',
          currentGeneration: 7,
        ),
        isFalse,
      );
      expect(
        ConversationSyncService.isSyncResultCurrent(
          startedOwner: 'a',
          startedGeneration: 7,
          currentOwner: 'a',
          currentGeneration: 8,
        ),
        isFalse,
      );
    });
  });

  group('sync-finish feedback gate', () {
    test('ordinary callback during an active page is not queued', () {
      expect(
        ConversationSyncService.shouldQueueSyncServerFinishDuringPageSync(
          needsFullReset: false,
          awaitingPostServerSync: false,
        ),
        isFalse,
      );
    });

    test('cold rebuild and one bootstrap catch-up are preserved', () {
      expect(
        ConversationSyncService.shouldQueueSyncServerFinishDuringPageSync(
          needsFullReset: true,
          awaitingPostServerSync: false,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.shouldQueueSyncServerFinishDuringPageSync(
          needsFullReset: false,
          awaitingPostServerSync: true,
        ),
        isTrue,
      );
    });
  });

  group('post-pop light reload gate', () {
    test('requires both post-pop window and flag', () {
      expect(
        ConversationSyncService.shouldUsePostPopLightReload(
          inPostPopWindow: true,
          postPopLightReloadEnabled: true,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.shouldUsePostPopLightReload(
          inPostPopWindow: false,
          postPopLightReloadEnabled: true,
        ),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldUsePostPopLightReload(
          inPostPopWindow: true,
          postPopLightReloadEnabled: false,
        ),
        isFalse,
      );
    });
  });

  group('cold sync policy', () {
    test(
        'shouldAttemptImSnapshotOnLoginBootstrap disables C2C priority snapshot',
        () {
      expect(
        ConversationSyncService.shouldAttemptImSnapshotOnLoginBootstrap(),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldUseImSnapshotBootstrap(rowCount: 0),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldUseImSnapshotBootstrap(rowCount: 3),
        isFalse,
      );
    });

    test('shouldFullResetOnServerFinish only when empty or never synced', () {
      expect(
        ConversationSyncService.shouldFullResetOnServerFinish(
          hasSyncedOnce: false,
          rowCount: 10,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.shouldFullResetOnServerFinish(
          hasSyncedOnce: true,
          rowCount: 0,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.shouldFullResetOnServerFinish(
          hasSyncedOnce: true,
          rowCount: 50,
        ),
        isFalse,
      );
    });

    test('shouldSkipPostHomeConversationReset follows bootstrap done', () {
      expect(
        ConversationSyncService.shouldSkipPostHomeConversationReset(
          conversationListBootstrapDone: true,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.shouldSkipPostHomeConversationReset(
          conversationListBootstrapDone: false,
        ),
        isFalse,
      );
    });

    test('shouldPauseIdleDrain when scrolling or transition; not active chat',
        () {
      expect(
        ConversationSyncService.shouldPauseIdleDrain(
          isScrolling: false,
          inChatTransition: false,
        ),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldPauseIdleDrain(
          isScrolling: true,
          inChatTransition: false,
        ),
        isTrue,
      );
      expect(
        ConversationSyncService.shouldPauseIdleDrain(
          isScrolling: false,
          inChatTransition: true,
        ),
        isTrue,
      );
    });
  });

  group('badge aggregate', () {
    tearDown(() {
      ConversationUnreadAggregate.instance.resetForTest();
    });

    test('AppBadgeUnreadUtils reads aggregate sums', () {
      ConversationUnreadAggregate.instance.setSumsForTest(c2c: 7, group: 3);
      expect(AppBadgeUnreadUtils.visibleUnreadForC2c(), 7);
      expect(AppBadgeUnreadUtils.visibleUnreadForGroup() >= 3, isTrue);
    });
  });

  group('ConversationListSyncNotifier draining', () {
    tearDown(() {
      ConversationListSyncNotifier.instance.clearSession();
    });

    test('setDraining notifies sync listeners only', () {
      var syncNotifications = 0;
      ConversationListSyncNotifier.instance.addListener(() {
        syncNotifications++;
      });

      ConversationListSyncNotifier.instance.setDraining(true);
      expect(ConversationListSyncNotifier.instance.isDraining, isTrue);
      ConversationListSyncNotifier.instance.setDraining(true);
      ConversationListSyncNotifier.instance.setDraining(false);
      expect(ConversationListSyncNotifier.instance.isDraining, isFalse);
      expect(syncNotifications, 2);
    });
  });
}
