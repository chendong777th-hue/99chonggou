import 'dart:async';

import 'package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart';

enum MessageMutationType {
  statusOrProgress,
  contentOrMedia,
  removeOrRevoke,
  insert,
  replaceRow,
  historyWindow,
  reorder,
}

extension MessageMutationPriority on MessageMutationType {
  int get priority => switch (this) {
        MessageMutationType.statusOrProgress => 0,
        MessageMutationType.contentOrMedia => 1,
        MessageMutationType.removeOrRevoke => 2,
        MessageMutationType.insert || MessageMutationType.replaceRow => 1,
        MessageMutationType.historyWindow || MessageMutationType.reorder => 3,
      };
}

class MessageMutation {
  const MessageMutation({
    required this.conversationID,
    required this.type,
    required this.generation,
    required this.source,
    this.stableIdentity,
    this.expectedFirstIdentity,
    this.expectedLastIdentity,
  });

  final String conversationID;
  final MessageMutationType type;
  final int generation;
  final String source;
  final String? stableIdentity;
  final String? expectedFirstIdentity;
  final String? expectedLastIdentity;
}

class MessageMutationBatch {
  const MessageMutationBatch({
    required this.conversationID,
    required this.generation,
    required this.highestPriority,
    required this.mutations,
  });

  final String conversationID;
  final int generation;
  final int highestPriority;
  final List<MessageMutation> mutations;
}

/// Facts supplied by the host after the authoritative message writer commits.
/// This DTO deliberately carries no conversation or SQLite side effects.
class CommittedMessageFacts {
  const CommittedMessageFacts({
    required this.conversationID,
    required this.generation,
    required this.acceptedMessageIds,
    this.topMessageId,
    this.topMessageTimestamp = 0,
    this.hasRealInbound = false,
    this.isReplay = false,
  });

  final String conversationID;
  final int generation;
  final List<String> acceptedMessageIds;
  final String? topMessageId;
  final int topMessageTimestamp;
  final bool hasRealInbound;
  final bool isReplay;
}

/// Notification sent when a staged mutation batch is dropped because the
/// commit guard rejected it (stale generation after page/conversation switch).
/// The caller should roll back any optimistic UI associated with the mutations.
class MessageStaleDrop {
  const MessageStaleDrop({
    required this.conversationID,
    required this.generation,
    required this.mutations,
  });

  final String conversationID;
  final int generation;
  final List<MessageMutation> mutations;
}

class MessageCommitStageResult {
  const MessageCommitStageResult({
    required this.generation,
    required this.shouldAdvanceListRevision,
  });

  final int generation;
  final bool shouldAdvanceListRevision;
}

class _PendingMessageMutations {
  _PendingMessageMutations(this.generation, this.commitToken);

  final int generation;
  final MobileAsyncCommitToken commitToken;
  final Map<String, MessageMutation> byIdentity = <String, MessageMutation>{};
  int anonymousSequence = 0;
  bool listRevisionReserved = false;
}

/// Coalesces the presentation commit boundary while authoritative list writes
/// remain synchronous. It never fetches, sorts or rewrites SDK history.
class MessageCommitCoordinator {
  MessageCommitCoordinator({
    this.onFlush,
    this.onStaleDrop,
    this.onCommittedBatch,
    this.onCommittedFacts,
  });

  final void Function(MessageMutationBatch batch)? onFlush;

  /// Called when a staged batch is dropped due to a stale commit guard token.
  /// The caller should roll back optimistic UI for the affected mutations.
  final void Function(MessageStaleDrop drop)? onStaleDrop;

  /// Fires after [onFlush] accepts a batch at the message commit boundary.
  /// The callback is intentionally transport-agnostic: the host must resolve
  /// accepted message facts before deriving a conversation mutation.
  final void Function(MessageMutationBatch batch)? onCommittedBatch;

  final CommittedMessageFacts? Function(MessageMutationBatch batch)?
      onCommittedFacts;
  final Map<String, _PendingMessageMutations> _pending =
      <String, _PendingMessageMutations>{};
  final Map<String, int> _generationByConversation = <String, int>{};
  final MobileAsyncCommitGuard _commitGuard = MobileAsyncCommitGuard();
  bool _flushScheduled = false;

  MessageCommitStageResult stage(
    MessageMutation mutation, {
    bool requiresListRevision = true,
  }) {
    final conversationID = mutation.conversationID.trim();
    final wasPending = _pending.containsKey(conversationID);
    final generation = wasPending
        ? _pending[conversationID]!.generation
        : (_generationByConversation[conversationID] ?? 0) + 1;
    _generationByConversation[conversationID] = generation;
    final pending = _pending.putIfAbsent(conversationID, () {
      final token = _commitGuard.begin('message-commit', key: conversationID);
      return _PendingMessageMutations(generation, token);
    });
    final identity = mutation.stableIdentity?.trim();
    final key = identity == null || identity.isEmpty
        ? '@${pending.anonymousSequence++}'
        : identity;
    final normalized = MessageMutation(
      conversationID: conversationID,
      type: mutation.type,
      generation: generation,
      source: mutation.source,
      stableIdentity: mutation.stableIdentity,
      expectedFirstIdentity: mutation.expectedFirstIdentity,
      expectedLastIdentity: mutation.expectedLastIdentity,
    );
    final previous = pending.byIdentity[key];
    if (previous == null ||
        normalized.type.priority >= previous.type.priority) {
      pending.byIdentity[key] = normalized;
    }
    final shouldAdvanceListRevision =
        requiresListRevision && !pending.listRevisionReserved;
    if (requiresListRevision) {
      pending.listRevisionReserved = true;
    }
    _scheduleFlush();
    return MessageCommitStageResult(
      generation: generation,
      shouldAdvanceListRevision: shouldAdvanceListRevision,
    );
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(flush);
  }

  /// Flushes staged mutations. Stale batches (guard token invalidated by a
  /// page/conversation generation advance) are not silently discarded: the
  /// [onStaleDrop] callback is invoked so the caller can roll back optimistic
  /// UI. Both stale and committed entries are removed from [_pending].
  void flush() {
    _flushScheduled = false;
    final batches = _pending.entries.toList(growable: false);
    for (final entry in batches) {
      _pending.remove(entry.key);
      if (!_commitGuard.canCommit(entry.value.commitToken)) {
        final mutations =
            entry.value.byIdentity.values.toList(growable: false);
        onStaleDrop?.call(
          MessageStaleDrop(
            conversationID: entry.key,
            generation: entry.value.generation,
            mutations: mutations,
          ),
        );
        continue;
      }
      final mutations = entry.value.byIdentity.values.toList(growable: false)
        ..sort((a, b) => b.type.priority.compareTo(a.type.priority));
      onFlush?.call(
        MessageMutationBatch(
          conversationID: entry.key,
          generation: entry.value.generation,
          highestPriority:
              mutations.isEmpty ? 0 : mutations.first.type.priority,
          mutations: mutations,
        ),
      );
      final committedBatch = MessageMutationBatch(
          conversationID: entry.key,
          generation: entry.value.generation,
          highestPriority:
              mutations.isEmpty ? 0 : mutations.first.type.priority,
          mutations: mutations,
        );
      onCommittedBatch?.call(committedBatch);
      // Resolution is explicit and read-only. The host may use the facts to
      // derive a conversation mutation after its message writer commits.
      onCommittedFacts?.call(committedBatch);
    }
  }

  int pendingCountForTesting(String conversationID) =>
      _pending[conversationID.trim()]?.byIdentity.length ?? 0;
}
