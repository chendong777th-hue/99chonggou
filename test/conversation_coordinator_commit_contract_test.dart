import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

const _owner = 'owner_commit_contract';
const _conversationId = 'group_room';

V2TimConversation _conversation({
  String id = _conversationId,
  int unread = 0,
  int orderkey = 0,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 2,
    groupID: id.replaceFirst('group_', ''),
    unreadCount: unread,
    orderkey: orderkey,
  );
}

ConversationMutationEvent _event({
  required String eventId,
  required int ownerGeneration,
  required int conversationGeneration,
  required int sourceVersion,
  ConversationMutationKind kind = ConversationMutationKind.upsert,
  Map<ConversationMutationField, Object?> values = const {
    ConversationMutationField.unread: 1,
  },
}) {
  return ConversationMutationEvent(
    eventId: eventId,
    ownerUserId: _owner,
    conversationId: _conversationId,
    conversationType: ConversationMutationConversationType.group,
    kind: kind,
    source: kind == ConversationMutationKind.delete
        ? ConversationMutationSource.sdkDelete
        : ConversationMutationSource.sdkRealtime,
    ownerGeneration: ownerGeneration,
    conversationGeneration: conversationGeneration,
    sourceVersion: sourceVersion,
    values: values,
  );
}

ConversationDatabaseCommitPlan<V2TimConversation> _plan({
  required String key,
  required ConversationDatabaseChangeType changeType,
  required int generation,
  V2TimConversation? snapshot,
  bool tombstone = false,
  bool recreate = false,
  Map<ConversationMutationField, Object?> fieldPatch = const {},
}) {
  return ConversationDatabaseCommitPlan<V2TimConversation>(
    ownerUserId: _owner,
    canonicalConversationId: _conversationId,
    conversationType: ConversationMutationConversationType.group,
    changeType: changeType,
    generation: generation,
    tombstone: tombstone,
    idempotencyKey: key,
    recreatesDeletedConversation: recreate,
    fieldPatch: fieldPatch,
    fullSnapshot: snapshot,
  );
}

Future<ConversationDatabaseCommitPlan<V2TimConversation>> _coordinatorPlan({
  required ConversationMutationCoordinator coordinator,
  required String eventId,
  required int ownerGeneration,
  required int conversationGeneration,
  required int sourceVersion,
  required V2TimConversation snapshot,
  ConversationMutationKind kind = ConversationMutationKind.upsert,
}) async {
  final result = await coordinator.submitForDatabaseCommit<V2TimConversation>(
    _event(
      eventId: eventId,
      ownerGeneration: ownerGeneration,
      conversationGeneration: conversationGeneration,
      sourceVersion: sourceVersion,
      kind: kind,
    ),
    fullSnapshot: snapshot,
  );
  expect(result.mutationResult.disposition,
      ConversationMutationDisposition.applied);
  return result.plan!;
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
    ConversationLocalStore.bypassUpsertCoalesceForTest = true;
    await ConversationLocalStore.instance.clearForOwner(_owner);
  });

  tearDown(() async {
    await ConversationLocalStore.instance.clearForOwner(_owner);
    ConversationLocalStore.bypassUpsertCoalesceForTest = false;
    ConversationLocalStore.instance.debugOwnerUserId = null;
  });

  test('coordinator emits a concrete database commit plan', () async {
    final coordinator = ConversationMutationCoordinator(shadowOnly: false);
    final ownerGeneration = coordinator.beginOwnerGeneration(_owner);

    final plan = await _coordinatorPlan(
      coordinator: coordinator,
      eventId: 'upsert-1',
      ownerGeneration: ownerGeneration,
      conversationGeneration: 1,
      sourceVersion: 10,
      snapshot: _conversation(unread: 3, orderkey: 10),
    );

    expect(plan.ownerUserId, _owner);
    expect(plan.canonicalConversationId, _conversationId);
    expect(plan.changeType, ConversationDatabaseChangeType.upsert);
    expect(plan.generation, 1);
    expect(plan.tombstone, isFalse);
    expect(plan.idempotencyKey, 'upsert-1');
    expect(plan.fullSnapshot?.unreadCount, 3);
    expect(plan.fieldPatch[ConversationMutationField.unread], 1);
  });

  test('duplicate plan is idempotent and emits one notify result', () async {
    final plan = _plan(
      key: 'same-key',
      changeType: ConversationDatabaseChangeType.upsert,
      generation: 1,
      snapshot: _conversation(unread: 2),
    );

    final first = await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: plan,
    );
    final duplicate =
        await ConversationLocalStore.instance.commitCoordinatorPlan(plan: plan);

    expect(first.disposition, ConversationDatabaseCommitDisposition.applied);
    expect(first.shouldNotifyUi, isTrue);
    expect(first.uiBatch.commitGeneration, 1);
    expect(first.uiBatch.upsertedSnapshots, hasLength(1));
    expect(first.uiBatch.deletedCanonicalIds, isEmpty);
    expect(first.uiBatch.structureChanged, isTrue);
    expect(
      duplicate.disposition,
      ConversationDatabaseCommitDisposition.ignoredDuplicate,
    );
    expect(duplicate.shouldNotifyUi, isFalse);
    expect(await ConversationLocalStore.instance.countRows(ownerUserId: _owner),
        1);
  });

  test('older generation is rejected before it can overwrite the row',
      () async {
    final current = _plan(
      key: 'current',
      changeType: ConversationDatabaseChangeType.upsert,
      generation: 2,
      snapshot: _conversation(unread: 5),
    );
    final stale = _plan(
      key: 'stale',
      changeType: ConversationDatabaseChangeType.upsert,
      generation: 1,
      snapshot: _conversation(unread: 1),
    );

    await ConversationLocalStore.instance.commitCoordinatorPlan(plan: current);
    final rejected = await ConversationLocalStore.instance
        .commitCoordinatorPlan(plan: stale);
    final stored = await ConversationLocalStore.instance.conversationById(
      _conversationId,
      ownerUserId: _owner,
    );

    expect(
      rejected.disposition,
      ConversationDatabaseCommitDisposition.rejectedStaleGeneration,
    );
    expect(rejected.shouldNotifyUi, isFalse);
    expect(stored?.unreadCount, 5);
  });

  test('delete tombstone blocks non-recreate upsert and allows new generation',
      () async {
    await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'initial',
        changeType: ConversationDatabaseChangeType.upsert,
        generation: 1,
        snapshot: _conversation(unread: 7),
      ),
    );
    final delete = await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'delete',
        changeType: ConversationDatabaseChangeType.delete,
        generation: 2,
        tombstone: true,
      ),
    );
    final blocked = await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'late-upsert',
        changeType: ConversationDatabaseChangeType.upsert,
        generation: 2,
        snapshot: _conversation(unread: 9),
      ),
    );
    final recreated =
        await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'recreate',
        changeType: ConversationDatabaseChangeType.upsert,
        generation: 3,
        snapshot: _conversation(unread: 11),
        recreate: true,
      ),
    );
    final stored = await ConversationLocalStore.instance.conversationById(
      _conversationId,
      ownerUserId: _owner,
    );

    expect(delete.disposition, ConversationDatabaseCommitDisposition.applied);
    expect(delete.shouldNotifyUi, isTrue);
    expect(
      blocked.disposition,
      ConversationDatabaseCommitDisposition.rejectedByTombstone,
    );
    expect(blocked.shouldNotifyUi, isFalse);
    expect(
        recreated.disposition, ConversationDatabaseCommitDisposition.applied);
    expect(recreated.shouldNotifyUi, isTrue);
    expect(stored?.unreadCount, 11);
  });

  test('delete tombstone still blocks a late snapshot after session restart',
      () async {
    await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'restart-initial',
        changeType: ConversationDatabaseChangeType.upsert,
        generation: 1,
        snapshot: _conversation(unread: 4),
      ),
    );
    await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'restart-delete',
        changeType: ConversationDatabaseChangeType.delete,
        generation: 2,
        tombstone: true,
      ),
    );

    // Simulate logout/process memory loss without deleting owner-scoped disk
    // state. The next commit must hydrate the durable tombstone first.
    await ConversationLocalStore.instance.clearSession();

    final lateSnapshot =
        await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'restart-late-snapshot',
        changeType: ConversationDatabaseChangeType.upsert,
        generation: 2,
        snapshot: _conversation(unread: 9),
      ),
    );

    expect(
      lateSnapshot.disposition,
      ConversationDatabaseCommitDisposition.rejectedByTombstone,
    );
    expect(
      await ConversationLocalStore.instance.conversationById(
        _conversationId,
        ownerUserId: _owner,
      ),
      isNull,
    );

    final recreated =
        await ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: _plan(
        key: 'restart-authoritative-recreate',
        changeType: ConversationDatabaseChangeType.upsert,
        generation: 3,
        snapshot: _conversation(unread: 1),
        recreate: true,
      ),
    );
    expect(
      recreated.disposition,
      ConversationDatabaseCommitDisposition.applied,
    );
  });
}
