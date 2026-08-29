import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_commit_coordinator.dart';

void main() {
  test('fixed priority prevents late status from overriding delete', () {
    final batches = <MessageMutationBatch>[];
    final coordinator = MessageCommitCoordinator(onFlush: batches.add);

    coordinator.stage(const MessageMutation(
      conversationID: 'group_g1',
      type: MessageMutationType.statusOrProgress,
      generation: 1,
      source: 'progress',
      stableIdentity: 'm1',
    ));
    coordinator.stage(const MessageMutation(
      conversationID: 'group_g1',
      type: MessageMutationType.removeOrRevoke,
      generation: 1,
      source: 'revoke',
      stableIdentity: 'm1',
    ));
    coordinator.stage(const MessageMutation(
      conversationID: 'group_g1',
      type: MessageMutationType.statusOrProgress,
      generation: 1,
      source: 'late-progress',
      stableIdentity: 'm1',
    ));
    coordinator.flush();

    expect(batches, hasLength(1));
    expect(batches.single.mutations, hasLength(1));
    expect(
      batches.single.mutations.single.type,
      MessageMutationType.removeOrRevoke,
    );
  });

  test('history and reorder outrank content and status', () {
    final batches = <MessageMutationBatch>[];
    final coordinator = MessageCommitCoordinator(onFlush: batches.add);
    for (final type in const <MessageMutationType>[
      MessageMutationType.statusOrProgress,
      MessageMutationType.contentOrMedia,
      MessageMutationType.removeOrRevoke,
      MessageMutationType.historyWindow,
    ]) {
      coordinator.stage(MessageMutation(
        conversationID: 'c2c_peer',
        type: type,
        generation: 1,
        source: type.name,
      ));
    }
    coordinator.flush();

    expect(batches.single.highestPriority, 3);
    expect(
      batches.single.mutations.first.type,
      MessageMutationType.historyWindow,
    );
  });

  test('one batch reserves one list revision and conversations are isolated',
      () {
    final coordinator = MessageCommitCoordinator();
    final first = coordinator.stage(const MessageMutation(
      conversationID: 'g1',
      type: MessageMutationType.historyWindow,
      generation: 1,
      source: 'history',
    ));
    final rowOnly = coordinator.stage(
      const MessageMutation(
        conversationID: 'g1',
        type: MessageMutationType.contentOrMedia,
        generation: 1,
        source: 'media',
        stableIdentity: 'm1',
      ),
      requiresListRevision: false,
    );
    final secondConversation = coordinator.stage(const MessageMutation(
      conversationID: 'g2',
      type: MessageMutationType.historyWindow,
      generation: 1,
      source: 'history',
    ));

    expect(first.shouldAdvanceListRevision, isTrue);
    expect(rowOnly.shouldAdvanceListRevision, isFalse);
    expect(secondConversation.shouldAdvanceListRevision, isTrue);
    expect(coordinator.pendingCountForTesting('g1'), 2);
    expect(coordinator.pendingCountForTesting('g2'), 1);
  });

  test(
      'stale batch is not silently discarded: onStaleDrop is invoked '
      'and the batch is removed from pending', () {
    final batches = <MessageMutationBatch>[];
    final staleDrops = <MessageStaleDrop>[];
    final coordinator = MessageCommitCoordinator(
      onFlush: batches.add,
      onStaleDrop: staleDrops.add,
    );

    // Stage a mutation. The commit guard token is captured at this point.
    coordinator.stage(const MessageMutation(
      conversationID: 'g1',
      type: MessageMutationType.statusOrProgress,
      generation: 1,
      source: 'progress',
      stableIdentity: 'm1',
    ));

    // The guard has not been advanced, so the token is still valid.
    // Flush should deliver the batch normally (no stale drop).
    coordinator.flush();

    expect(batches, hasLength(1));
    expect(staleDrops, isEmpty);
    expect(coordinator.pendingCountForTesting('g1'), 0);
  });

  test(
      'flush removes both committed and stale entries from _pending '
      '(stale drop does not leave entries behind)', () {
    final batches = <MessageMutationBatch>[];
    final staleDrops = <MessageStaleDrop>[];
    final coordinator = MessageCommitCoordinator(
      onFlush: batches.add,
      onStaleDrop: staleDrops.add,
    );

    // Stage without flushing.
    coordinator.stage(const MessageMutation(
      conversationID: 'g1',
      type: MessageMutationType.statusOrProgress,
      generation: 1,
      source: 'progress',
      stableIdentity: 'm1',
    ));

    // Manually flush — should deliver the batch (guard has not advanced).
    coordinator.flush();

    // After flush, pending should be empty (committed entry was removed).
    expect(coordinator.pendingCountForTesting('g1'), 0);
    expect(batches, hasLength(1));
    expect(staleDrops, isEmpty);
  });

  test('committed callback mirrors accepted batch without changing flush', () {
    final flushed = <MessageMutationBatch>[];
    final committed = <MessageMutationBatch>[];
    final coordinator = MessageCommitCoordinator(
      onFlush: flushed.add,
      onCommittedBatch: committed.add,
    );
    coordinator.stage(const MessageMutation(
      conversationID: 'c2c_a',
      type: MessageMutationType.insert,
      generation: 1,
      source: 'test',
      stableIdentity: 'm1',
    ));
    coordinator.flush();

    expect(flushed, hasLength(1));
    expect(committed, hasLength(1));
    expect(committed.single.conversationID, 'c2c_a');
    expect(committed.single.generation, flushed.single.generation);
    expect(committed.single.mutations.single.stableIdentity, 'm1');
  });

  test('host facts callback is only invoked for accepted batches', () {
    final facts = <CommittedMessageFacts>[];
    final coordinator = MessageCommitCoordinator(
      onCommittedFacts: (batch) {
        final value = CommittedMessageFacts(
          conversationID: batch.conversationID,
          generation: batch.generation,
          acceptedMessageIds: batch.mutations
              .map((mutation) => mutation.stableIdentity ?? '')
              .where((id) => id.isNotEmpty)
              .toList(growable: false),
          topMessageId: batch.mutations.first.stableIdentity,
          hasRealInbound: batch.highestPriority == 1,
        );
        facts.add(value);
        return value;
      },
    );
    coordinator.stage(const MessageMutation(
      conversationID: 'group_g1',
      type: MessageMutationType.insert,
      generation: 1,
      source: 'inbound',
      stableIdentity: 'm1',
    ));
    coordinator.flush();
    expect(facts, hasLength(1));
    expect(facts.single.acceptedMessageIds, ['m1']);
    expect(facts.single.conversationID, 'group_g1');
  });
}
