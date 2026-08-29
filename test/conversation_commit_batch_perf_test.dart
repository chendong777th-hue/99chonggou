import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

const _owner = 'conversation_batch_perf_owner';

ConversationDatabaseCommitPlan<V2TimConversation> _plan(int index) {
  final id = 'group_batch_$index';
  return ConversationDatabaseCommitPlan<V2TimConversation>(
    ownerUserId: _owner,
    canonicalConversationId: id,
    conversationType: ConversationMutationConversationType.group,
    changeType: ConversationDatabaseChangeType.upsert,
    generation: 1,
    tombstone: false,
    idempotencyKey: 'batch-plan-$index',
    recreatesDeletedConversation: false,
    fieldPatch: <ConversationMutationField, Object?>{
      ConversationMutationField.unread: index + 1,
      ConversationMutationField.order: index + 1,
    },
    fullSnapshot: V2TimConversation(
      conversationID: id,
      type: 2,
      groupID: 'batch_$index',
      unreadCount: index + 1,
      orderkey: index + 1,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() async {
    ConversationLocalStore.instance.debugOwnerUserId = _owner;
    await ConversationLocalStore.instance.clearForOwner(_owner);
    ConversationLocalStore.instance.resetBatchProfileForTest();
  });

  tearDown(() async {
    await ConversationLocalStore.instance.clearForOwner(_owner);
    ConversationLocalStore.instance.resetBatchProfileForTest();
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  test('baseline exposes per-plan coordinator commit cost', () async {
    const count = 10;
    for (var index = 0; index < count; index++) {
      final result = await ConversationLocalStore.instance
          .commitCoordinatorPlan(plan: _plan(index));
      expect(
        result.disposition,
        ConversationDatabaseCommitDisposition.applied,
      );
    }

    final profile = ConversationLocalStore.instance.batchProfileForTest;
    expect(profile.coordinatorPlanCommits, count);
    expect(profile.durableStateQueries, count);
    expect(profile.coordinatorStateWrites, count);
    expect(
      await ConversationLocalStore.instance.countRows(ownerUserId: _owner),
      count,
    );
  });

  test('sdk batch path loads durable states once and writes all rows',
      () async {
    const count = 10;
    final merged = await ConversationLocalStore.instance
        .commitCoordinatorSdkUpsertPlansBatch(
      plans: List<ConversationDatabaseCommitPlan<V2TimConversation>>.generate(
        count,
        _plan,
      ),
    );

    final profile = ConversationLocalStore.instance.batchProfileForTest;
    expect(merged, hasLength(count));
    expect(profile.coordinatorPlanCommits, count);
    expect(profile.durableStateQueries, 1);
    expect(profile.coordinatorStateWrites, count);
    expect(profile.atomicSdkTransactions, 1);
    expect(
      await ConversationLocalStore.instance.countRows(ownerUserId: _owner),
      count,
    );
  });

  test('typed sdk result carries old and new unread projection', () async {
    final first = await ConversationLocalStore.instance
        .commitCoordinatorSdkUpsertPlansBatchResult(
      plans: <ConversationDatabaseCommitPlan<V2TimConversation>>[_plan(0)],
    );
    expect(first.upserted, hasLength(1));
    expect(first.unreadProjectionComplete, isTrue);
    expect(first.unreadDeltas.single.oldNotifiable, 0);
    expect(first.unreadDeltas.single.newNotifiable, 1);

    final nextPlan = ConversationDatabaseCommitPlan<V2TimConversation>(
      ownerUserId: _owner,
      canonicalConversationId: 'group_batch_0',
      conversationType: ConversationMutationConversationType.group,
      changeType: ConversationDatabaseChangeType.upsert,
      generation: 2,
      tombstone: false,
      idempotencyKey: 'batch-plan-0-v2',
      recreatesDeletedConversation: false,
      fieldPatch: const <ConversationMutationField, Object?>{
        ConversationMutationField.unread: 7,
      },
      fullSnapshot: V2TimConversation(
        conversationID: 'group_batch_0',
        type: 2,
        groupID: 'batch_0',
        unreadCount: 7,
      ),
    );
    final second = await ConversationLocalStore.instance
        .commitCoordinatorSdkUpsertPlansBatchResult(
      plans: <ConversationDatabaseCommitPlan<V2TimConversation>>[nextPlan],
    );
    expect(second.upserted, hasLength(1));
    expect(second.unreadDeltas.single.oldNotifiable, 1);
    expect(second.unreadDeltas.single.newNotifiable, 7);
  });
}
