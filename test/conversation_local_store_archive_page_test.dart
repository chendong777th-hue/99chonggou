import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

V2TimConversation _c2c({
  required String id,
  required int activeSec,
  int type = 1,
}) {
  final peer = id.replaceFirst('c2c_', '').replaceFirst('group_', '');
  return V2TimConversation(
    conversationID: id,
    type: type,
    userID: type == 1 ? peer : null,
    groupID: type == 2 ? peer : null,
    draftTimestamp: activeSec,
    orderkey: activeSec,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ConversationLocalStore.loadOlderAmongIds', () {
    const owner = 'archive_page_owner';

    setUp(() async {
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
    });

    tearDown(() async {
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('returns newest-first page limited among ids', () async {
      final items = <V2TimConversation>[
        for (var i = 0; i < 5; i++)
          _c2c(id: 'c2c_u$i', activeSec: 1700000000 + i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: items);

      final page = await ConversationLocalStore.instance.loadOlderAmongIds(
        conversationIds: {
          'c2c_u0',
          'c2c_u1',
          'c2c_u2',
          'c2c_u3',
          'c2c_u4',
        },
        limit: 2,
        convType: 1,
      );

      expect(page.length, 2);
      expect(page[0].conversationID, 'c2c_u4');
      expect(page[1].conversationID, 'c2c_u3');
    });

    test('cursor skips to older page', () async {
      final items = <V2TimConversation>[
        for (var i = 0; i < 5; i++)
          _c2c(id: 'c2c_p$i', activeSec: 1800000000 + i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: items);

      final first = await ConversationLocalStore.instance.loadOlderAmongIds(
        conversationIds: {
          'c2c_p0',
          'c2c_p1',
          'c2c_p2',
          'c2c_p3',
          'c2c_p4',
        },
        limit: 2,
      );
      expect(first.map((e) => e.conversationID).toList(), ['c2c_p4', 'c2c_p3']);

      final second = await ConversationLocalStore.instance.loadOlderAmongIds(
        conversationIds: {
          'c2c_p0',
          'c2c_p1',
          'c2c_p2',
          'c2c_p3',
          'c2c_p4',
        },
        beforeActiveTime: ConversationLocalStore.activeTimeMs(first.last),
        beforeConversationId: first.last.conversationID,
        limit: 2,
      );
      expect(
        second.map((e) => e.conversationID).toList(),
        ['c2c_p2', 'c2c_p1'],
      );
    });

    test('convType filters group vs c2c', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(id: 'c2c_only', activeSec: 1900000010),
          _c2c(id: 'group_g1', activeSec: 1900000020, type: 2),
        ],
      );
      final groups = await ConversationLocalStore.instance.loadOlderAmongIds(
        conversationIds: {'c2c_only', 'group_g1'},
        limit: 10,
        convType: 2,
      );
      expect(groups.length, 1);
      expect(groups.single.conversationID, 'group_g1');
    });
  });

  group('ConversationLocalStore.prepareArchiveIdSet + true page', () {
    const owner = 'archive_true_page_owner';

    setUp(() async {
      ConversationLocalStore.instance.debugOwnerUserId = owner;
      await ConversationLocalStore.instance.clearForOwner(owner);
    });

    tearDown(() async {
      await ConversationLocalStore.instance.clearForOwner(owner);
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('prepared page returns newest-first without full materialize API',
        () async {
      final items = <V2TimConversation>[
        for (var i = 0; i < 5; i++)
          _c2c(id: 'c2c_t$i', activeSec: 1700000100 + i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: items);
      final ids = {for (var i = 0; i < 5; i++) 'c2c_t$i'};
      final prepared =
          await ConversationLocalStore.instance.prepareArchiveIdSet(
        conversationIds: ids,
      );
      expect(prepared.originalCount, 5);
      expect(prepared.joinTokenCount, greaterThanOrEqualTo(5));

      final page =
          await ConversationLocalStore.instance.loadOlderAmongPreparedArchiveIds(
        limit: 2,
        convType: 1,
      );
      expect(page.length, 2);
      expect(page[0].conversationID, 'c2c_t4');
      expect(page[1].conversationID, 'c2c_t3');

      final second =
          await ConversationLocalStore.instance.loadOlderAmongPreparedArchiveIds(
        beforeActiveTime: ConversationLocalStore.activeTimeMs(page.last),
        beforeConversationId: page.last.conversationID,
        limit: 2,
        convType: 1,
      );
      expect(
        second.map((e) => e.conversationID).toList(),
        ['c2c_t2', 'c2c_t1'],
      );
    });

    test('large id set first page stays limited', () async {
      final items = <V2TimConversation>[
        for (var i = 0; i < 120; i++)
          _c2c(id: 'c2c_big$i', activeSec: 1600000000 + i),
      ];
      await ConversationLocalStore.instance.upsertBatch(conversations: items);
      final ids = {for (var i = 0; i < 120; i++) 'c2c_big$i'};
      await ConversationLocalStore.instance.prepareArchiveIdSet(
        conversationIds: ids,
      );
      final page =
          await ConversationLocalStore.instance.loadOlderAmongPreparedArchiveIds(
        limit: 40,
        convType: 1,
      );
      expect(page.length, 40);
      expect(page.first.conversationID, 'c2c_big119');
      expect(page.last.conversationID, 'c2c_big80');
    });

    test('listColdArchivedIds finds missing shells', () async {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: [
          _c2c(id: 'c2c_present', activeSec: 2000000001),
        ],
      );
      await ConversationLocalStore.instance.prepareArchiveIdSet(
        conversationIds: {'c2c_present', 'c2c_missing_shell'},
      );
      final cold = await ConversationLocalStore.instance.listColdArchivedIds(
        originalArchivedIds: {'c2c_present', 'c2c_missing_shell'},
      );
      expect(cold, contains('c2c_missing_shell'));
      expect(cold, isNot(contains('c2c_present')));
    });
  });
}
