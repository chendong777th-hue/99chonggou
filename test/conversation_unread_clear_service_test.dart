import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_clear_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConversationLocalStore.instance.debugOwnerUserId = 'test_owner';
  });

  tearDown(() {
    ConversationUnreadClearService.resetCoordinatorStateForTesting();
    ConversationSyncService.instance.resetChatTransitionStateForTesting();
    ConversationSyncService.instance.markReadStoreOverride = null;
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  group('ConversationUnreadClearService retry delays', () {
    test('open path uses shorter delays than leave path', () {
      expect(
        ConversationUnreadClearService.openSdkRetryDelays,
        equals(const <Duration>[
          Duration.zero,
          Duration(milliseconds: 300),
          Duration(milliseconds: 800),
        ]),
      );
      expect(
        ConversationUnreadClearService.leaveSdkRetryDelays,
        equals(const <Duration>[
          Duration.zero,
          Duration(milliseconds: 600),
          Duration(milliseconds: 1500),
        ]),
      );
    });
  });

  group('ConversationUnreadClearService.shouldStopSdkRetry', () {
    test('stops open-path retry after SDK success', () {
      expect(
        ConversationUnreadClearService.shouldStopSdkRetry(
          breakOnSuccess: true,
          resultCode: 0,
        ),
        isTrue,
      );
    });

    test('keeps leave-path retry after SDK success', () {
      expect(
        ConversationUnreadClearService.shouldStopSdkRetry(
          breakOnSuccess: false,
          resultCode: 0,
        ),
        isFalse,
      );
    });

    test('continues retry when SDK returns non-zero on open path', () {
      expect(
        ConversationUnreadClearService.shouldStopSdkRetry(
          breakOnSuccess: true,
          resultCode: 1,
        ),
        isFalse,
      );
    });
  });

  group('SdkUnreadCleanCoordinator', () {
    test('dedupes concurrent scheduleSdkUnreadClean for same conversation',
        () async {
      var calls = 0;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return V2TimCallback(code: 0, desc: '');
      };

      final first = ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_g1',
        trigger: SdkUnreadCleanTrigger.open,
        hadUnread: true,
      );
      final second = ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_g1',
        trigger: SdkUnreadCleanTrigger.open,
        hadUnread: true,
      );

      await Future.wait([first, second]);
      expect(calls, 1);
    });

    test('records frequency block and defers retry after -10113', () async {
      var calls = 0;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls++;
        return V2TimCallback(code: -10113, desc: 'frequency block');
      };

      await ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_g2',
        trigger: SdkUnreadCleanTrigger.open,
        hadUnread: true,
      );
      expect(calls, 1);

      await ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_g2',
        trigger: SdkUnreadCleanTrigger.open,
        hadUnread: true,
      );
      expect(calls, 1);
    });

    test('skips leave clean within 3s after successful open clean', () async {
      var calls = 0;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls++;
        return V2TimCallback(code: 0, desc: '');
      };

      await ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_g3',
        trigger: SdkUnreadCleanTrigger.open,
        hadUnread: true,
      );
      expect(calls, 1);

      await ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_g3',
        trigger: SdkUnreadCleanTrigger.leave,
        hadUnread: true,
      );
      expect(calls, 1);
    });

    test('successful leave clean does not issue fallback duplicates', () async {
      var calls = 0;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls++;
        return V2TimCallback(code: 0, desc: '');
      };

      await ConversationUnreadClearService.scheduleSdkUnreadClean(
        conversationID: 'group_leave_once',
        trigger: SdkUnreadCleanTrigger.leave,
        hadUnread: true,
      );

      expect(calls, 1);
    });

    test('clearLocalOnLeave does not invoke SDK clean', () async {
      var calls = 0;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls++;
        return V2TimCallback(code: 0, desc: '');
      };
      ConversationSyncService.instance.markReadStoreOverride =
          (conversationID) async {};

      await ConversationUnreadClearService.clearLocalOnLeave(
        conversationID: 'c2c_alice',
      );

      expect(calls, 0);

      await ConversationUnreadClearService.clearLocalOnLeave(
        conversationID: 'c2c_alice',
      );
      expect(calls, 0);
    });

    test('concurrent leave finalizers await the same local commit', () async {
      final localCommit = Completer<void>();
      var localCommitCalls = 0;
      ConversationSyncService.instance.markReadStoreOverride =
          (conversationID) {
        localCommitCalls++;
        return localCommit.future;
      };
      ConversationUnreadClearService.beginConversationChatSession(
        'c2c_single_flight',
      );

      var firstDone = false;
      var secondDone = false;
      final first =
          ConversationUnreadClearService.finalizeConversationLeaveOnce(
        conversationID: 'c2c_single_flight',
        scheduleSdkUnreadCleanOnLeave: false,
      ).whenComplete(() => firstDone = true);
      final second =
          ConversationUnreadClearService.finalizeConversationLeaveOnce(
        conversationID: 'c2c_single_flight',
        scheduleSdkUnreadCleanOnLeave: false,
      ).whenComplete(() => secondDone = true);

      await Future<void>.delayed(Duration.zero);
      expect(localCommitCalls, 1);
      expect(firstDone, isFalse);
      expect(secondDone, isFalse);

      localCommit.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(localCommitCalls, 1);
      expect(firstDone, isTrue);
      expect(secondDone, isTrue);
    });

    test('failed leave finalizer can retry the same generation', () async {
      var localCommitCalls = 0;
      ConversationSyncService.instance.markReadStoreOverride =
          (conversationID) async {
        localCommitCalls++;
        if (localCommitCalls == 1) {
          throw StateError('first write failed');
        }
      };
      ConversationUnreadClearService.beginConversationChatSession(
        'c2c_retry_finalize',
      );

      await expectLater(
        ConversationUnreadClearService.finalizeConversationLeaveOnce(
          conversationID: 'c2c_retry_finalize',
          scheduleSdkUnreadCleanOnLeave: false,
        ),
        throwsStateError,
      );
      await ConversationUnreadClearService.finalizeConversationLeaveOnce(
        conversationID: 'c2c_retry_finalize',
        scheduleSdkUnreadCleanOnLeave: false,
      );

      expect(localCommitCalls, 2);
    });
  });

  group('ConversationUnreadClearService type bulk / queue', () {
    test('shouldUseTypeBulkClean when all visible c2c selected', () {
      final visible = [
        V2TimConversation(conversationID: 'c2c_a', type: 1, userID: 'a'),
        V2TimConversation(conversationID: 'c2c_b', type: 1, userID: 'b'),
      ];
      final decision = ConversationUnreadClearService.shouldUseTypeBulkClean(
        visible: visible,
        selectedIds: {'c2c_a', 'c2c_b'},
      );
      expect(decision, isNotNull);
      expect(decision!.isGroup, isFalse);
    });

    test('shouldUseTypeBulkClean when all visible group selected', () {
      final visible = [
        V2TimConversation(conversationID: 'group_g1', type: 2, groupID: 'g1'),
        V2TimConversation(conversationID: 'group_g2', type: 2, groupID: 'g2'),
      ];
      final decision = ConversationUnreadClearService.shouldUseTypeBulkClean(
        visible: visible,
        selectedIds: {'group_g1', 'group_g2'},
      );
      expect(decision, isNotNull);
      expect(decision!.isGroup, isTrue);
    });

    test('shouldUseTypeBulkClean null when partial or mixed', () {
      final c2c = [
        V2TimConversation(conversationID: 'c2c_a', type: 1, userID: 'a'),
        V2TimConversation(conversationID: 'c2c_b', type: 1, userID: 'b'),
      ];
      expect(
        ConversationUnreadClearService.shouldUseTypeBulkClean(
          visible: c2c,
          selectedIds: {'c2c_a'},
        ),
        isNull,
      );

      final mixed = [
        V2TimConversation(conversationID: 'c2c_a', type: 1, userID: 'a'),
        V2TimConversation(conversationID: 'group_g1', type: 2, groupID: 'g1'),
      ];
      expect(
        ConversationUnreadClearService.shouldUseTypeBulkClean(
          visible: mixed,
          selectedIds: {'c2c_a', 'group_g1'},
        ),
        isNull,
      );
    });

    test('cleanSdkUnreadForType invokes SDK once with type id', () async {
      final calls = <String>[];
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls.add(id);
        return V2TimCallback(code: 0, desc: '');
      };
      ConversationSyncService.instance.markReadStoreOverride =
          (conversationID) async {};

      await ConversationUnreadClearService.cleanSdkUnreadForType(
          isGroup: false);
      expect(calls, ['c2c']);

      calls.clear();
      await ConversationUnreadClearService.cleanSdkUnreadForType(isGroup: true);
      expect(calls, ['group']);
    });

    test('enqueueSdkUnreadClean serializes across conversations', () async {
      final calls = <String>[];
      ConversationUnreadClearService.queuedSdkCleanInterval =
          const Duration(milliseconds: 30);
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls.add(id);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return V2TimCallback(code: 0, desc: '');
      };

      final first = ConversationUnreadClearService.enqueueSdkUnreadClean(
        'c2c_a',
        hadUnread: true,
      );
      final second = ConversationUnreadClearService.enqueueSdkUnreadClean(
        'c2c_b',
        hadUnread: true,
      );
      await Future.wait([first, second]);
      expect(calls, ['c2c_a', 'c2c_b']);
    });

    test('enqueue continues next conversation after -10113 on previous',
        () async {
      final calls = <String>[];
      ConversationUnreadClearService.queuedSdkCleanInterval = Duration.zero;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        calls.add(id);
        if (id == 'c2c_a') {
          return V2TimCallback(code: -10113, desc: 'frequency block');
        }
        return V2TimCallback(code: 0, desc: '');
      };

      final first = ConversationUnreadClearService.enqueueSdkUnreadClean(
        'c2c_a',
        hadUnread: true,
      );
      final second = ConversationUnreadClearService.enqueueSdkUnreadClean(
        'c2c_b',
        hadUnread: true,
      );
      await Future.wait([first, second]);
      expect(calls, ['c2c_a', 'c2c_b']);
    });

    test('markReadForEditAction selected uses queue never type bulk', () async {
      const owner = 'mark_read_selected_owner';
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: 'c2c_a',
            type: 1,
            userID: 'a',
            unreadCount: 3,
          ),
          V2TimConversation(
            conversationID: 'c2c_b',
            type: 1,
            userID: 'b',
            unreadCount: 5,
          ),
        ],
      );
      final sdkCalls = <String>[];
      ConversationUnreadClearService.queuedSdkCleanInterval = Duration.zero;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        sdkCalls.add(id);
        return V2TimCallback(code: 0, desc: '');
      };

      final result = await ConversationUnreadClearService.markReadForEditAction(
        mode: MarkReadEditMode.selected,
        listScope: MarkReadListScope.c2c,
        selectedIds: {'c2c_a'},
      );
      expect(result.conversationCount, 1);
      expect(result.unreadSumBefore, 3);
      expect(result.sdkPath, 'queue');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sdkCalls, ['c2c_a']);

      final still = await ConversationLocalStore.instance.conversationById(
        'c2c_b',
      );
      expect(still?.unreadCount, 5);
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('markReadForEditAction scopeAll group uses type sdk path', () async {
      const owner = 'mark_read_scope_owner';
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: 'group_g1',
            type: 2,
            groupID: 'g1',
            unreadCount: 2,
          ),
          V2TimConversation(
            conversationID: 'c2c_x',
            type: 1,
            userID: 'x',
            unreadCount: 9,
          ),
        ],
      );
      final sdkCalls = <String>[];
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        sdkCalls.add(id);
        return V2TimCallback(code: 0, desc: '');
      };

      final result = await ConversationUnreadClearService.markReadForEditAction(
        mode: MarkReadEditMode.scopeAll,
        listScope: MarkReadListScope.group,
        archivedIds: const <String>{},
      );
      expect(result.conversationCount, 1);
      expect(result.unreadSumBefore, 2);
      expect(result.sdkPath, 'type');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sdkCalls, ['group']);

      final c2c = await ConversationLocalStore.instance.conversationById(
        'c2c_x',
      );
      expect(c2c?.unreadCount, 9);
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('markReadForEditAction archivedAll never uses type sdk', () async {
      const owner = 'mark_read_archive_owner';
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          V2TimConversation(
            conversationID: 'group_g1',
            type: 2,
            groupID: 'g1',
            unreadCount: 4,
          ),
          V2TimConversation(
            conversationID: 'group_g2',
            type: 2,
            groupID: 'g2',
            unreadCount: 1,
          ),
        ],
      );
      final sdkCalls = <String>[];
      ConversationUnreadClearService.queuedSdkCleanInterval = Duration.zero;
      ConversationUnreadClearService.sdkCleanOverride = (id) async {
        sdkCalls.add(id);
        return V2TimCallback(code: 0, desc: '');
      };

      final result = await ConversationUnreadClearService.markReadForEditAction(
        mode: MarkReadEditMode.archivedAll,
        listScope: MarkReadListScope.group,
        archivedIds: {'group_g1'},
      );
      expect(result.conversationCount, 1);
      expect(result.sdkPath, 'queue');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sdkCalls, ['group_g1']);
      expect(sdkCalls.contains('group'), isFalse);

      final other = await ConversationLocalStore.instance.conversationById(
        'group_g2',
      );
      expect(other?.unreadCount, 1);
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });
  });
}
