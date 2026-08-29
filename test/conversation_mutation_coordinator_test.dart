import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';

ConversationMutationEvent _event({
  required String id,
  required ConversationMutationSource source,
  required int ownerGeneration,
  required int conversationGeneration,
  required int sourceVersion,
  ConversationMutationKind kind = ConversationMutationKind.patch,
  ConversationMutationConversationType type =
      ConversationMutationConversationType.group,
  Map<ConversationMutationField, Object?> values = const {},
}) {
  return ConversationMutationEvent(
    eventId: id,
    ownerUserId: 'owner',
    conversationId: 'group_room',
    conversationType: type,
    kind: kind,
    source: source,
    ownerGeneration: ownerGeneration,
    conversationGeneration: conversationGeneration,
    sourceVersion: sourceVersion,
    values: values,
  );
}

void main() {
  group('ConversationMutationCoordinator shadow projection', () {
    late ConversationMutationCoordinator coordinator;
    late int ownerGeneration;

    setUp(() {
      coordinator = ConversationMutationCoordinator();
      ownerGeneration = coordinator.beginOwnerGeneration('owner');
    });

    test('canonical identity preserves conversation type', () {
      expect(
        canonicalizeConversationMutationId(
          'group_room',
          ConversationMutationConversationType.group,
        ),
        'group_room',
      );
      expect(
        canonicalizeConversationMutationId(
          'c2c_room',
          ConversationMutationConversationType.c2c,
        ),
        'c2c_room',
      );
      expect(
        canonicalizeConversationMutationId(
          'room',
          ConversationMutationConversationType.group,
        ),
        'group_room',
      );
    });

    test('newer realtime field rejects an older SDK page', () async {
      await coordinator.submit(
        _event(
          id: 'realtime',
          source: ConversationMutationSource.sdkRealtime,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 1,
          sourceVersion: 20,
          values: const {
            ConversationMutationField.lastMessage: 'new',
            ConversationMutationField.unread: 4,
          },
        ),
      );
      final result = await coordinator.submit(
        _event(
          id: 'old_page',
          source: ConversationMutationSource.sdkPage,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 1,
          sourceVersion: 10,
          values: const {
            ConversationMutationField.lastMessage: 'old',
            ConversationMutationField.unread: 1,
          },
        ),
      );

      expect(
        result.disposition,
        ConversationMutationDisposition.ignoredLowerAuthority,
      );
      final snapshot = coordinator.snapshot(
        ownerUserId: 'owner',
        conversationId: 'group_room',
        conversationType: ConversationMutationConversationType.group,
      );
      expect(snapshot?.values[ConversationMutationField.lastMessage], 'new');
      expect(snapshot?.values[ConversationMutationField.unread], 4);
    });

    test('field authority prevents newer local cache metadata rollback',
        () async {
      await coordinator.submit(
        _event(
          id: 'remote_name',
          source: ConversationMutationSource.remoteMetadata,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 1,
          sourceVersion: 7,
          values: const {ConversationMutationField.name: 'Remote'},
        ),
      );
      await coordinator.submit(
        _event(
          id: 'local_name',
          source: ConversationMutationSource.localCache,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 1,
          // Cache timestamps are not comparable with remote metadata
          // generations. Source authority must win for metadata fields.
          sourceVersion: 999,
          values: const {ConversationMutationField.name: 'Cached'},
        ),
      );

      final snapshot = coordinator.snapshot(
        ownerUserId: 'owner',
        conversationId: 'room',
        conversationType: ConversationMutationConversationType.group,
      );
      expect(snapshot?.values[ConversationMutationField.name], 'Remote');
    });

    test('delete tombstone rejects late events until authoritative recreate',
        () async {
      await coordinator.submit(
        _event(
          id: 'delete',
          source: ConversationMutationSource.sdkDelete,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 3,
          sourceVersion: 30,
          kind: ConversationMutationKind.delete,
        ),
      );
      final late = await coordinator.submit(
        _event(
          id: 'late_page',
          source: ConversationMutationSource.sdkPage,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 2,
          sourceVersion: 40,
          values: const {ConversationMutationField.lastMessage: 'late'},
        ),
      );
      expect(
        late.disposition,
        ConversationMutationDisposition.rejectedStaleConversation,
      );

      final sameGeneration = await coordinator.submit(
        _event(
          id: 'same_generation',
          source: ConversationMutationSource.sdkRealtime,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 3,
          sourceVersion: 41,
          values: const {ConversationMutationField.lastMessage: 'late'},
        ),
      );
      expect(
        sameGeneration.disposition,
        ConversationMutationDisposition.rejectedByTombstone,
      );

      final recreated = await coordinator.submit(
        _event(
          id: 'rejoin',
          source: ConversationMutationSource.membershipExplicit,
          ownerGeneration: ownerGeneration,
          conversationGeneration: 4,
          sourceVersion: 42,
          kind: ConversationMutationKind.recreate,
          values: const {ConversationMutationField.membership: true},
        ),
      );
      expect(recreated.disposition, ConversationMutationDisposition.applied);
      expect(
        coordinator
            .snapshot(
              ownerUserId: 'owner',
              conversationId: 'room',
              conversationType: ConversationMutationConversationType.group,
            )
            ?.deleted,
        isFalse,
      );
    });

    test('owner generation rejects results from a previous login', () async {
      final firstGeneration = ownerGeneration;
      ownerGeneration = coordinator.beginOwnerGeneration('owner');

      final stale = await coordinator.submit(
        _event(
          id: 'old_owner_result',
          source: ConversationMutationSource.sdkRealtime,
          ownerGeneration: firstGeneration,
          conversationGeneration: 1,
          sourceVersion: 1,
          values: const {ConversationMutationField.unread: 99},
        ),
      );
      expect(
        stale.disposition,
        ConversationMutationDisposition.rejectedStaleOwner,
      );
      expect(
        coordinator.snapshot(
          ownerUserId: 'owner',
          conversationId: 'room',
          conversationType: ConversationMutationConversationType.group,
        ),
        isNull,
      );
    });

    test('duplicate event is idempotent', () async {
      final event = _event(
        id: 'same_event',
        source: ConversationMutationSource.sdkRealtime,
        ownerGeneration: ownerGeneration,
        conversationGeneration: 1,
        sourceVersion: 1,
        values: const {ConversationMutationField.unread: 2},
      );
      expect(
        (await coordinator.submit(event)).disposition,
        ConversationMutationDisposition.applied,
      );
      expect(
        (await coordinator.submit(event)).disposition,
        ConversationMutationDisposition.ignoredDuplicate,
      );
    });
  });
}
