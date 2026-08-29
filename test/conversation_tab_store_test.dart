import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_tab_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart';

V2TimConversation _c2c(String id, {int unread = 0, bool pinned = false}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    isPinned: pinned,
    orderkey: unread + (pinned ? 1000 : 0),
    showName: id,
  );
}

V2TimMessage _textMessage(
  String text, {
  String msgID = 'msg_preview',
  int timestamp = 1700000000,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': msgID,
    'message_server_time': timestamp,
    'message_is_from_self': true,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.textElem = V2TimTextElem(text: text);
  return message;
}

V2TimMessage _friendTipMessage({String msgID = 'tip_preview'}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_msg_id': msgID,
    'message_server_time': 1700001000,
    'message_is_from_self': true,
    'message_status': 1,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
  message.userID = 'peer';
  message.customElem = V2TimCustomElem(
    data:
        '{"businessID":"$kFriendBecameFriendsBusinessID","text":"你们已成为好友，现在可以开始聊天了"}',
  );
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = false;
    ConversationTabStore.debugFetchOverride = null;
    ConversationTabStore.instance.clear();
    ActiveChatRegistry.instance.reset();
    ConversationUnreadAggregate.instance.clearSession();
    ConversationListNotifier.instance.setConversationsForTest(const []);
  });

  tearDown(() {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = false;
    ConversationTabStore.debugFetchOverride = null;
    ConversationTabStore.instance.clear();
    ActiveChatRegistry.instance.reset();
    ConversationUnreadAggregate.instance.clearSession();
    ConversationListNotifier.instance.setConversationsForTest(const []);
    ConversationPinSyncService.instance.debugReplacePinnedIdsForTest(const {});
  });

  test('flag off: ensurePrimed is no-op', () async {
    var fetches = 0;
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      fetches++;
      return (
        conversationList: <V2TimConversation>[_c2c('c2c_a')],
        nextSeq: '0',
        isFinished: true,
        code: 0,
        desc: '',
      );
    };
    await ConversationTabStore.instance.ensurePrimed(convType: 1);
    expect(fetches, 0);
    expect(ConversationTabStore.instance.countForType(1), 0);
  });

  test('flag on: loadFirstPage + loadMore via filter override', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final pages = <String, List<V2TimConversation>>{
      '0': [_c2c('c2c_1'), _c2c('c2c_2')],
      '2': [_c2c('c2c_3')],
    };
    ConversationTabStore.debugFetchOverride = ({
      required int convType,
      required String nextSeq,
      required int count,
    }) async {
      expect(convType, 1);
      final page = pages[nextSeq] ?? const <V2TimConversation>[];
      final finished = nextSeq != '0';
      return (
        conversationList: page,
        nextSeq: finished ? '0' : '2',
        isFinished: finished,
        code: 0,
        desc: '',
      );
    };

    await ConversationTabStore.instance.loadFirstPage(convType: 1, count: 2);
    expect(ConversationTabStore.instance.countForType(1), 2);
    expect(ConversationTabStore.instance.finishedForType(1), isFalse);

    await ConversationTabStore.instance.loadMore(convType: 1, count: 2);
    expect(ConversationTabStore.instance.countForType(1), 3);
    expect(ConversationTabStore.instance.finishedForType(1), isTrue);
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((c) => c.conversationID),
      ['c2c_1', 'c2c_2', 'c2c_3'],
    );
  });

  test('committed view switch maintains cursor lifecycle', () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = true;
    final store = ConversationLocalStore.instance;
    store.debugOwnerUserId = 'tab_store_committed_test';
    addTearDown(() async {
      await store.clearForOwner('tab_store_committed_test');
      store.debugOwnerUserId = null;
    });
    await store.upsertBatch(
      conversations: <V2TimConversation>[
        _c2c('c2c_cursor_a'),
        _c2c('c2c_cursor_b'),
        _c2c('c2c_cursor_c'),
      ],
      ownerUserId: 'tab_store_committed_test',
    );

    await ConversationTabStore.instance.loadFirstPage(convType: 1, count: 2);
    expect(ConversationTabStore.instance.pageCursorForType(1), isNotNull);
    await ConversationTabStore.instance.loadMore(convType: 1, count: 2);
    expect(ConversationTabStore.instance.countForType(1), 3);
    ConversationTabStore.instance.clear();
    expect(ConversationTabStore.instance.pageCursorForType(1), isNull);
  });

  test('committed view retries after cold-start owner becomes available',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = true;
    final store = ConversationLocalStore.instance;
    const owner = 'tab_store_cold_start_owner';
    await store.clearForOwner(owner);
    store.debugOwnerUserId = '';
    addTearDown(() async {
      store.debugOwnerUserId = null;
      await store.clearForOwner(owner);
    });
    await store.upsertBatch(
      conversations: <V2TimConversation>[_c2c('c2c_cold_start')],
      ownerUserId: owner,
    );

    // The first restore can race account-owner restoration. It must not mark
    // the type finished or consume the page frontier on an unscoped read.
    await ConversationTabStore.instance.loadFirstPage(convType: 1);
    expect(ConversationTabStore.instance.countForType(1), 0);
    expect(ConversationTabStore.instance.finishedForType(1), isFalse);

    store.debugOwnerUserId = owner;
    await ConversationTabStore.instance.loadFirstPage(convType: 1);
    expect(ConversationTabStore.instance.countForType(1), 1);
    expect(
      ConversationTabStore.instance.atTypeIndex(1, 0)?.conversationID,
      'c2c_cold_start',
    );
  });

  test('committed view retries an empty terminal page after sync fills SQLite',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationPerfFlags.tabStoreCommittedViewEnabled = true;
    final store = ConversationLocalStore.instance;
    const owner = 'tab_store_late_sync_owner';
    store.debugOwnerUserId = owner;
    await store.clearForOwner(owner);
    addTearDown(() async {
      store.debugOwnerUserId = null;
      await store.clearForOwner(owner);
    });

    await ConversationTabStore.instance.ensurePrimed(convType: 1);
    expect(ConversationTabStore.instance.finishedForType(1), isTrue);

    await store.upsertBatch(
      conversations: <V2TimConversation>[_c2c('c2c_late_sync')],
      ownerUserId: owner,
    );
    await ConversationTabStore.instance.ensurePrimed(convType: 1);

    expect(ConversationTabStore.instance.countForType(1), 1);
    expect(
      ConversationTabStore.instance.atTypeIndex(1, 0)?.conversationID,
      'c2c_late_sync',
    );
  });

  test('view invalidation clears affected type cursor', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_invalidate')],
      finished: false,
    );
    expect(ConversationTabStore.instance.pageCursorForType(1), isNotNull);
    ConversationTabStore.instance.invalidateViewPages(
      conversationID: 'c2c_invalidate',
      convType: 1,
    );
    expect(ConversationTabStore.instance.pageCursorForType(1), isNull);
  });

  test('applyPatches preserves preview and unread on pin metadata patch', () {
    final lastMessage = _textMessage('你好');
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [
        V2TimConversation(
          conversationID: 'c2c_peer',
          type: 1,
          userID: 'peer',
          unreadCount: 2,
          isPinned: false,
          orderkey: 1700000000,
          showName: '阿阳',
          lastMessage: lastMessage,
        ),
      ],
      finished: true,
    );
    ConversationPinSyncService.instance
        .debugReplacePinnedIdsForTest(const {'c2c_peer'});
    ConversationTabStore.instance.applyPatches([
      V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
        isPinned: true,
        orderkey: 1700000100,
        showName: '阿阳',
      ),
    ], reason: 'pin_sdk_changed');
    final row = ConversationTabStore.instance
        .itemsForType(1)
        .firstWhere((c) => c.conversationID == 'c2c_peer');
    expect(row.isPinned, isTrue);
    expect(row.lastMessage?.msgID, 'msg_preview');
    expect(row.unreadCount, 2);
  });

  test('applyPatches marks last-message content changes as non-structural', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [
        _c2c('c2c_preview')..lastMessage = _textMessage('旧预览'),
      ],
      finished: true,
    );

    ConversationTabStore.instance.applyPatches([
      _c2c('c2c_preview')..lastMessage = _textMessage('新预览'),
    ], reason: 'last_message_content');

    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .single
          .lastMessage
          ?.textElem
          ?.text,
      '新预览',
    );
    expect(
      ConversationTabStore.instance.lastNotificationStructureChanged,
      isFalse,
    );
  });

  test('applyPatches marks admitted and deleted rows as structural', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_existing')],
      finished: true,
    );

    ConversationTabStore.instance.applyPatches(
      [_c2c('c2c_admitted')],
      reason: 'admit_row',
      forceAdmitIds: const {'c2c_admitted'},
    );
    expect(
      ConversationTabStore.instance.lastNotificationStructureChanged,
      isTrue,
    );

    ConversationTabStore.instance.applyDeleted(['c2c_admitted']);
    expect(
      ConversationTabStore.instance.lastNotificationStructureChanged,
      isTrue,
    );
  });

  test('zeroUnreadLocallyMany clears rows in sdk primary store', () {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationUnreadAggregate.instance.setSumsForTest(c2c: 6, group: 3);
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [
        _c2c('c2c_peer', unread: 4),
        _c2c('c2c_other', unread: 2),
      ],
      finished: true,
    );

    var notifications = 0;
    void listener() => notifications++;
    ConversationTabStore.instance.addListener(listener);
    ConversationListNotifier.instance.zeroUnreadLocallyMany(['c2c_peer']);
    ConversationTabStore.instance.removeListener(listener);

    final rows = ConversationTabStore.instance.itemsForType(1);
    expect(
        rows.firstWhere((c) => c.conversationID == 'c2c_peer').unreadCount, 0);
    expect(
        rows.firstWhere((c) => c.conversationID == 'c2c_other').unreadCount, 2);
    expect(notifications, 1);
    expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 2);
    expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 3);
  });

  test('zeroUnreadLocallyMany clears group delta without touching c2c', () {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    ConversationUnreadAggregate.instance.setSumsForTest(c2c: 5, group: 7);
    ConversationTabStore.instance.setItemsForTest(
      convType: 2,
      items: [_c2c('group_room', unread: 4)],
      finished: true,
    );

    ConversationListNotifier.instance.zeroUnreadLocallyMany(['group_room']);

    expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 5);
    expect(ConversationUnreadAggregate.instance.groupNotifiableUnreadSum, 3);
  });

  test('applyPatches keeps chat preview over newer friend became friends tip',
      () {
    final chatPreview = _textMessage('最近聊的内容');
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [
        V2TimConversation(
          conversationID: 'c2c_peer',
          type: 1,
          userID: 'peer',
          unreadCount: 0,
          isPinned: false,
          orderkey: 1700000000,
          showName: '秋',
          lastMessage: chatPreview,
        ),
      ],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches([
      V2TimConversation(
        conversationID: 'c2c_peer',
        type: 1,
        userID: 'peer',
        unreadCount: 0,
        isPinned: false,
        orderkey: 1700001000,
        showName: '秋',
        lastMessage: _friendTipMessage(),
      ),
    ], reason: 'friend_became_friends_sent');
    final row = ConversationTabStore.instance
        .itemsForType(1)
        .firstWhere((c) => c.conversationID == 'c2c_peer');
    expect(row.lastMessage?.msgID, 'msg_preview');
    expect(row.lastMessage?.textElem?.text, '最近聊的内容');
  });

  test('applyPatches updates in-window row and admits hot unread', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: [_c2c('c2c_old', unread: 0)],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches([
      _c2c('c2c_old', unread: 3),
      _c2c('c2c_hot', unread: 1),
    ], reason: 'test');
    expect(ConversationTabStore.instance.countForType(1), 2);
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((c) => c.conversationID)
          .toSet(),
      {'c2c_old', 'c2c_hot'},
    );
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .firstWhere((c) => c.conversationID == 'c2c_old')
          .unreadCount,
      3,
    );
  });

  test('applyPatches keeps batched inserts in UI order', () {
    ConversationTabStore.instance.setItemsForTest(
      convType: 1,
      items: const [],
      finished: true,
    );
    ConversationTabStore.instance.applyPatches(
      [
        _c2c('c2c_low', unread: 1),
        _c2c('c2c_high', unread: 5),
      ],
      reason: 'test',
      forceAdmitIds: {'c2c_low', 'c2c_high'},
    );
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((c) => c.conversationID),
      ['c2c_high', 'c2c_low'],
    );
  });

  test(
      'active chat defers non-visible committed projection without replaying unread',
      () {
    ActiveChatRegistry.instance.enter('c2c_active');
    ConversationTabStore.instance.applyCommittedViewBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[
          _c2c('c2c_active', unread: 5),
          _c2c('c2c_background', unread: 4),
        ],
        deletedCanonicalIds: const <String>[],
        structureChanged: true,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{},
        commitGeneration: 41,
        unreadDeltas: const <ConversationUiUnreadDelta>[
          ConversationUiUnreadDelta(
            isGroup: false,
            oldNotifiable: 0,
            newNotifiable: 5,
          ),
        ],
      ),
    );

    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((row) => row.conversationID),
      contains('c2c_active'),
    );
    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((row) => row.conversationID),
      isNot(contains('c2c_background')),
    );
    expect(ConversationTabStore.instance.deferredCommittedProjectionCount, 1);
    expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 5);

    ActiveChatRegistry.instance.leave('c2c_active');
    ConversationTabStore.instance.flushDeferredCommittedProjection();

    expect(
      ConversationTabStore.instance
          .itemsForType(1)
          .map((row) => row.conversationID),
      containsAll(<String>['c2c_active', 'c2c_background']),
    );
    expect(ConversationUnreadAggregate.instance.c2cNotifiableUnreadSum, 5);
  });

  test('explicit draft commit replaces and clears an existing draft', () {
    final seeded = _c2c('c2c_draft')..draftText = 'old draft';
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[seeded],
      reason: 'seed_draft',
      forceAdmitIds: const <String>{'c2c_draft'},
    );

    final updated = _c2c('c2c_draft')..draftText = 'new draft';
    ConversationTabStore.instance.applyCommittedViewBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[updated],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_draft': <ConversationMutationField>{
            ConversationMutationField.draft,
          },
        },
        commitGeneration: 50,
      ),
    );
    expect(
      ConversationTabStore.instance.itemsForType(1).single.draftText,
      'new draft',
    );

    final cleared = _c2c('c2c_draft');
    ConversationTabStore.instance.applyCommittedViewBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[cleared],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_draft': <ConversationMutationField>{
            ConversationMutationField.draft,
          },
        },
        commitGeneration: 51,
      ),
    );
    expect(
      ConversationTabStore.instance.itemsForType(1).single.draftText,
      isNull,
    );
  });

  test('ordinary sdk patch does not erase a local draft', () {
    final seeded = _c2c('c2c_sdk_patch')..draftText = 'keep me';
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[seeded],
      reason: 'seed_draft',
      forceAdmitIds: const <String>{'c2c_sdk_patch'},
    );

    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[_c2c('c2c_sdk_patch', unread: 3)],
      reason: 'sdk_patch',
    );

    expect(
      ConversationTabStore.instance.itemsForType(1).single.draftText,
      'keep me',
    );
  });

  test('explicit last-message commit rolls preview back and clears it', () {
    final newest = _textMessage(
      'deleted message',
      msgID: 'msg_deleted',
      timestamp: 1700000200,
    );
    final seeded = _c2c('c2c_peer')..lastMessage = newest;
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[seeded],
      reason: 'seed_preview',
      forceAdmitIds: const <String>{'c2c_peer'},
    );

    final previous = _textMessage(
      'previous message',
      msgID: 'msg_previous',
      timestamp: 1700000100,
    );
    final rolledBack = _c2c('c2c_peer')..lastMessage = previous;
    ConversationTabStore.instance.applyCommittedViewBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[rolledBack],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_peer': <ConversationMutationField>{
            ConversationMutationField.lastMessage,
          },
        },
        commitGeneration: 53,
      ),
    );
    expect(
      ConversationTabStore.instance.itemsForType(1).single.lastMessage?.msgID,
      'msg_previous',
    );

    ConversationTabStore.instance.applyCommittedViewBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[_c2c('c2c_peer')],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_peer': <ConversationMutationField>{
            ConversationMutationField.lastMessage,
          },
        },
        commitGeneration: 54,
      ),
    );
    expect(
      ConversationTabStore.instance.itemsForType(1).single.lastMessage,
      isNull,
    );
  });

  test('ordinary sdk patch cannot roll conversation preview backwards', () {
    final newest = _textMessage(
      'newest message',
      msgID: 'msg_newest',
      timestamp: 1700000200,
    );
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[_c2c('c2c_peer')..lastMessage = newest],
      reason: 'seed_preview',
      forceAdmitIds: const <String>{'c2c_peer'},
    );

    final older = _textMessage(
      'older sdk snapshot',
      msgID: 'msg_older',
      timestamp: 1700000100,
    );
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[_c2c('c2c_peer')..lastMessage = older],
      reason: 'sdk_patch',
    );

    expect(
      ConversationTabStore.instance.itemsForType(1).single.lastMessage?.msgID,
      'msg_newest',
    );
  });

  test('optimistic delete preview matches a message local id', () {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final deleted = _textMessage(
      'deleted local message',
      msgID: 'msg_sdk_id',
      timestamp: 1700000200,
    )..id = 'msg_local_id';
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[_c2c('c2c_peer')..lastMessage = deleted],
      reason: 'seed_preview',
      forceAdmitIds: const <String>{'c2c_peer'},
    );
    final previous = _textMessage(
      'previous message',
      msgID: 'msg_previous_local_id',
      timestamp: 1700000100,
    );

    final applied =
        ConversationListNotifier.instance.replaceLastMessageAfterDeleteLocally(
      conversationID: 'c2c_peer',
      deletedMessageIds: const <String>{'msg_local_id'},
      replacement: previous,
    );

    expect(applied, isTrue);
    expect(
      ConversationTabStore.instance.itemsForType(1).single.lastMessage?.msgID,
      'msg_previous_local_id',
    );
  });

  test('clear drops deferred projection from the previous chat session', () {
    ActiveChatRegistry.instance.enter('c2c_active');
    ConversationTabStore.instance.applyCommittedViewBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[_c2c('c2c_background')],
        deletedCanonicalIds: const <String>[],
        structureChanged: true,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{},
        commitGeneration: 42,
      ),
    );
    expect(ConversationTabStore.instance.deferredCommittedProjectionCount, 1);

    ConversationTabStore.instance.clear();
    ActiveChatRegistry.instance.leave('c2c_active');
    ConversationTabStore.instance.flushDeferredCommittedProjection();

    expect(ConversationTabStore.instance.deferredCommittedProjectionCount, 0);
    expect(ConversationTabStore.instance.countForType(1), 0);
  });

  test('notifier sdk-primary: applyConversationsFromStore goes to TabStore',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final notifier = ConversationListNotifier.instance;
    notifier.ensureTabStoreBridgeAttached();
    await notifier.applyConversationsFromStore(
      upserted: [_c2c('c2c_bridge', unread: 2)],
    );
    expect(ConversationTabStore.instance.countForType(1), 1);
    expect(
      notifier.conversations.any((c) => c.conversationID == 'c2c_bridge'),
      isTrue,
    );
    expect(
        notifier.conversationAtTypeIndex(1, 0)?.conversationID, 'c2c_bridge');
  });

  test('notifier preserves explicit draft clear semantics for TabStore',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final seeded = _c2c('c2c_draft_bridge')..draftText = 'sent text';
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[seeded],
      reason: 'seed_draft',
      forceAdmitIds: const <String>{'c2c_draft_bridge'},
    );

    await ConversationListNotifier.instance.applyCommittedBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[_c2c('c2c_draft_bridge')],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_draft_bridge': <ConversationMutationField>{
            ConversationMutationField.draft,
          },
        },
        commitGeneration: 52,
      ),
    );

    expect(
      ConversationTabStore.instance.itemsForType(1).single.draftText,
      isNull,
    );
  });

  test('notifier preserves explicit last-message rollback for TabStore',
      () async {
    ConversationPerfFlags.conversationListSdkPrimary = true;
    final newest = _textMessage(
      'deleted message',
      msgID: 'msg_deleted_bridge',
      timestamp: 1700000200,
    );
    ConversationTabStore.instance.applyPatches(
      <V2TimConversation>[
        _c2c('c2c_peer')..lastMessage = newest,
      ],
      reason: 'seed_preview',
      forceAdmitIds: const <String>{'c2c_peer'},
    );

    final previous = _textMessage(
      'previous message',
      msgID: 'msg_previous_bridge',
      timestamp: 1700000100,
    );
    await ConversationListNotifier.instance.applyCommittedBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[
          _c2c('c2c_peer')..lastMessage = previous,
        ],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_peer': <ConversationMutationField>{
            ConversationMutationField.lastMessage,
          },
        },
        commitGeneration: 55,
      ),
    );

    expect(
      ConversationTabStore.instance.itemsForType(1).single.lastMessage?.msgID,
      'msg_previous_bridge',
    );
  });

  test('flag off: applyConversationsFromStore stays on legacy path', () async {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    final notifier = ConversationListNotifier.instance;
    await notifier.applyConversationsFromStore(
      upserted: [_c2c('c2c_legacy', unread: 1)],
    );
    expect(ConversationTabStore.instance.countForType(1), 0);
    expect(
      notifier.conversations.any((c) => c.conversationID == 'c2c_legacy'),
      isTrue,
    );
  });

  test('legacy notifier applies explicit last-message rollback', () async {
    ConversationPerfFlags.conversationListSdkPrimary = false;
    final notifier = ConversationListNotifier.instance;
    final newest = _textMessage(
      'deleted message',
      msgID: 'msg_legacy_deleted',
      timestamp: 1700000200,
    );
    notifier.setConversationsForTest(<V2TimConversation>[
      _c2c('c2c_peer')..lastMessage = newest,
    ]);

    final previous = _textMessage(
      'previous message',
      msgID: 'msg_legacy_previous',
      timestamp: 1700000100,
    );
    await notifier.applyCommittedBatch(
      ConversationUiSnapshotBatch<V2TimConversation>(
        upsertedSnapshots: <V2TimConversation>[
          _c2c('c2c_peer')..lastMessage = previous,
        ],
        deletedCanonicalIds: const <String>[],
        structureChanged: false,
        changedFieldMasks: const <String, Set<ConversationMutationField>>{
          'c2c_peer': <ConversationMutationField>{
            ConversationMutationField.lastMessage,
          },
        },
        commitGeneration: 56,
      ),
    );

    expect(
      notifier.conversations.single.lastMessage?.msgID,
      'msg_legacy_previous',
    );
  });
}
