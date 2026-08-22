import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _c2c({
  required String id,
  int unread = 0,
  int recvOpt = 0,
  String? userId,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: userId ?? id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    recvOpt: recvOpt,
    showName: id,
  );
}

V2TimConversation _group({
  required String id,
  int unread = 0,
  int recvOpt = 0,
  String groupType = 'Public',
}) {
  final gid = id.replaceFirst('group_', '');
  return V2TimConversation(
    conversationID: id,
    type: 2,
    groupID: gid,
    unreadCount: unread,
    recvOpt: recvOpt,
    groupType: groupType,
    showName: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ConversationUnreadUtils aggregate rules', () {
    test('Meeting with recvOpt still notifiable', () {
      final n = ConversationUnreadUtils.notifiableUnreadForAggregate(
        _group(id: 'group_m', unread: 3, recvOpt: 2, groupType: 'Meeting'),
        archivedC2c: const {},
        archivedGroup: const {},
      );
      expect(n, 3);
    });

    test('normal disturbed not counted', () {
      final n = ConversationUnreadUtils.notifiableUnreadForAggregate(
        _c2c(id: 'c2c_a', unread: 5, recvOpt: 1),
        archivedC2c: const {},
        archivedGroup: const {},
      );
      expect(n, 0);
    });

    test('archived excluded', () {
      final n = ConversationUnreadUtils.notifiableUnreadForAggregate(
        _c2c(id: 'c2c_a', unread: 5),
        archivedC2c: const {'c2c_a'},
        archivedGroup: const {},
      );
      expect(n, 0);
    });

    test('archived excluded with bare peer id form', () {
      final n = ConversationUnreadUtils.notifiableUnreadForAggregate(
        _c2c(id: 'c2c_alice', unread: 5),
        archivedC2c: const {'alice'},
        archivedGroup: const {},
      );
      expect(n, 0);
    });
  });

  group('ConversationUnreadAggregate', () {
    setUp(() {
      ConversationUnreadAggregate.instance.resetForTest();
    });

    test('bulk reasons use longer debounce', () {
      expect(
        ConversationUnreadAggregate.instance
            .debounceForReasonForTest('apply')
            .inMilliseconds,
        220,
      );
      expect(
        ConversationUnreadAggregate.instance
            .debounceForReasonForTest('drain_db_only')
            .inMilliseconds,
        800,
      );
      expect(
        ConversationUnreadAggregate.instance
            .debounceForReasonForTest('archived_changed')
            .inMilliseconds,
        220,
      );
    });

    test('applyNotifiableDeltas updates sums', () {
      ConversationUnreadAggregate.instance.setSumsForTest(c2c: 10, group: 4);
      ConversationUnreadAggregate.instance.applyNotifiableDeltas([
        const ConversationUnreadDelta(
          isGroup: false,
          oldNotifiable: 2,
          newNotifiable: 5,
        ),
        const ConversationUnreadDelta(
          isGroup: true,
          oldNotifiable: 4,
          newNotifiable: 0,
        ),
      ]);
      expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 13);
      expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 0);
    });

    test('scheduleRefresh bulk uses longer debounce constant', () {
      expect(
        ConversationUnreadAggregate.isBulkRefreshReason('drain_db_only'),
        isTrue,
      );
      expect(
        ConversationUnreadAggregate.isBulkRefreshReason('apply'),
        isFalse,
      );
      expect(
        ConversationUnreadAggregate.instance
            .debounceForReasonForTest('paced_sync_no_full_reload')
            .inMilliseconds,
        800,
      );
    });
  });


    test('refreshFromStore skips empty owner', () async {
      ConversationUnreadAggregate.instance.setSumsForTest(c2c: 5, group: 1);
      // Non-null empty override → resolved owner empty without login/prefs.
      ConversationLocalStore.instance.debugOwnerUserId = '';
      addTearDown(() {
        ConversationLocalStore.instance.debugOwnerUserId = null;
      });
      await ConversationUnreadAggregate.instance.refreshFromStore(
        reason: 'test_empty_owner',
      );
      expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 5);
      expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 1);
    });

    test('refreshFromStore defers first surprising zero', () async {
      const owner = 'unread_zero_defer_user';
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      addTearDown(() async {
        await ConversationLocalStore.instance.clearForOwner(owner);
        ConversationLocalStore.instance.debugOwnerUserId = null;
      });
      // Empty DB for owner → sum returns (0,0).
      ConversationUnreadAggregate.instance.setSumsForTest(c2c: 3, group: 0);
      await ConversationUnreadAggregate.instance.refreshFromStore(
        reason: 'test_zero',
      );
      expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 3);
      expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 0);

      await ConversationUnreadAggregate.instance.refreshFromStore(
        reason: ConversationUnreadAggregate.zeroConfirmReason,
      );
      expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 0);
      expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 0);
    });

    test('clearSession zeros immediately without defer', () {
      ConversationUnreadAggregate.instance.setSumsForTest(c2c: 2, group: 2);
      ConversationUnreadAggregate.instance.clearSession();
      expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 0);
      expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 0);
    });

    test('zero_unread reason applies zero without defer', () async {
      const owner = 'unread_zero_allow_user';
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      addTearDown(() async {
        await ConversationLocalStore.instance.clearForOwner(owner);
        ConversationLocalStore.instance.debugOwnerUserId = null;
      });
      ConversationUnreadAggregate.instance.setSumsForTest(c2c: 4, group: 1);
      await ConversationUnreadAggregate.instance.refreshFromStore(
        reason: 'zero_unread',
      );
      expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 0);
      expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 0);
    });

  group('sumNotifiableUnreadByScope', () {
    setUp(() {
      ConversationLocalStore.instance.debugOwnerUserId = 'unread_sum_user';
    });

    tearDown(() async {
      await ConversationLocalStore.instance.clearForOwner('unread_sum_user');
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('sql sum matches utils rules', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(id: 'c2c_1', unread: 2),
          _c2c(id: 'c2c_2', unread: 5, recvOpt: 1),
          _group(id: 'group_1', unread: 3),
          _group(
            id: 'group_meet',
            unread: 4,
            recvOpt: 2,
            groupType: 'Meeting',
          ),
          _c2c(id: 'c2c_arch', unread: 7),
        ],
      );
      final sums =
          await ConversationLocalStore.instance.sumNotifiableUnreadByScope(
        archivedC2c: const {'c2c_arch'},
        archivedGroup: const {},
      );
      // c2c_1=2; c2c_2 disturbed=0; c2c_arch archived=0 → 2
      // group_1=3; meeting=4 → 7
      expect(sums.c2c, 2);
      expect(sums.group, 7);
    });

    test('sql sum excludes archived by bare peer id', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(id: 'c2c_1', unread: 2),
          _c2c(id: 'c2c_bob', unread: 9),
        ],
      );
      final sums =
          await ConversationLocalStore.instance.sumNotifiableUnreadByScope(
        archivedC2c: const {'bob'},
        archivedGroup: const {},
      );
      expect(sums.c2c, 2);
      expect(sums.group, 0);
    });
  });
}
