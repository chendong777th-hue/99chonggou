import 'message_reconciliation_coordinator.dart';
import 'message_reconciliation_identity.dart';
import 'message_history_coverage.dart';
import 'message_delta.dart';

class MessageReconciliationWriterCommit<T> {
  const MessageReconciliationWriterCommit({
    required this.conversationKey,
    required this.generation,
    required this.revision,
    required this.records,
    required this.missingSeqRanges,
    required this.seqIdentityConflicts,
  });

  final String conversationKey;
  final int generation;
  final int revision;
  final List<MessageReconciliationRecord<T>> records;
  final List<MessageSeqRange> missingSeqRanges;
  final List<MessageSeqIdentityConflict> seqIdentityConflicts;
}

class _MessageReconciliationWriterState<T> {
  _MessageReconciliationWriterState();

  int revision = 0;
  int clearEpoch = 0;
  int lastDeltaGeneration = 0;
  bool trackSeqGaps = false;
  MessageReconciliationRequest? activeRequest;
  List<MessageReconciliationRecord<T>> committed =
      <MessageReconciliationRecord<T>>[];
  final List<MessageDelta<T>> pendingDeltas = <MessageDelta<T>>[];
  final Set<String> appliedDeltaEventIDs = <String>{};
  final Set<String> serverTombstones = <String>{};
  /// Revoke rows remain visible as a local placeholder while their server
  /// identity is tombstoned. Ordinary deletes do not add to this set.
  final Set<String> retainedTombstoneOverlays = <String>{};
  final Map<String, MessageReconciliationRecord<T>> authoritativeOverlays =
      <String, MessageReconciliationRecord<T>>{};
}

/// Serializes history completions and realtime callbacks into one authoritative
/// commit per active reconciliation generation.
///
/// This class deliberately does not fetch data or notify UI listeners. The
/// caller publishes [MessageReconciliationWriterCommit.records] through the
/// existing message-list writer and therefore keeps one revision boundary.
class MessageReconciliationWriter<T> {
  MessageReconciliationWriter({
    required Comparator<MessageReconciliationRecord<T>> comparator,
    MessageReconciliationCoordinator? coordinator,
  })  : _comparator = comparator,
        coordinator = coordinator ?? MessageReconciliationCoordinator();

  final Comparator<MessageReconciliationRecord<T>> _comparator;
  final MessageReconciliationCoordinator coordinator;
  final Map<String, _MessageReconciliationWriterState<T>> _states =
      <String, _MessageReconciliationWriterState<T>>{};
  static const int _maxRememberedServerMutations = 512;

  void seedAuthoritative({
    required String conversationID,
    required Iterable<MessageReconciliationRecord<T>> records,
    bool trackSeqGaps = false,
    int? clearEpoch,
  }) {
    final state = _stateFor(conversationID);
    if (clearEpoch != null && clearEpoch > state.clearEpoch) {
      state.clearEpoch = clearEpoch;
      state.serverTombstones.clear();
      state.retainedTombstoneOverlays.clear();
      state.authoritativeOverlays.clear();
      state.pendingDeltas.clear();
    }
    state.trackSeqGaps = trackSeqGaps;
    state.committed = _mergeAndSort(
      _applyRememberedAuthority(state, records),
      trackSeqGaps: state.trackSeqGaps,
    ).records;
  }

  MessageReconciliationRequest beginInitialHistory({
    required String conversationID,
    required MessageReconciliationSource requestedSource,
    required MessageReconciliationNetworkState networkState,
  }) {
    final state = _stateFor(conversationID);
    final request = coordinator.beginInitialHistory(
      conversationID: conversationID,
      requestedSource: requestedSource,
      networkState: networkState,
    );
    state.activeRequest = request;
    return request;
  }

  MessageReconciliationRequest beginCloudCatchUp({
    required String conversationID,
    required MessageReconciliationNetworkState networkState,
  }) {
    final state = _stateFor(conversationID);
    final request = coordinator.beginCloudCatchUp(
      conversationID: conversationID,
      networkState: networkState,
    );
    state.activeRequest = request;
    return request;
  }

  /// Returns null while a history request is active. Those messages are
  /// published together with that request's current completion.
  MessageReconciliationWriterCommit<T>? enqueueRealtime({
    required String conversationID,
    required String eventID,
    required Iterable<MessageReconciliationRecord<T>> records,
  }) {
    final incoming = records.toList(growable: false);
    if (incoming.isEmpty) return null;
    final state = _stateFor(conversationID);
    return applyDelta(
      MessageDelta<T>(
        conversationKey: conversationID,
        eventID: eventID,
        kind: MessageDeltaKind.realtimeUpsert,
        source: MessageDeltaSource.sdkRealtime,
        generation: coordinator.stateFor(conversationID).requestGeneration,
        clearEpoch: state.clearEpoch,
        upserts: incoming,
      ),
    );
  }

  /// Applies every authoritative non-history mutation through one writer.
  ///
  /// Deltas that arrive during a history request are held and published with
  /// that request. Deletions install server-ID tombstones before merge, while
  /// edits/revokes install overlays that stale history cannot overwrite.
  MessageReconciliationWriterCommit<T>? applyDelta(MessageDelta<T> delta) {
    final conversationID = _canonicalKey(delta.conversationKey);
    final state = _stateFor(conversationID);
    if (!delta.hasMutation || delta.clearEpoch < state.clearEpoch) {
      return null;
    }
    if (!state.appliedDeltaEventIDs.add(delta.eventID)) {
      return null;
    }
    while (state.appliedDeltaEventIDs.length > _maxRememberedServerMutations * 2) {
      state.appliedDeltaEventIDs.remove(state.appliedDeltaEventIDs.first);
    }
    if (delta.clearEpoch > state.clearEpoch) {
      state.clearEpoch = delta.clearEpoch;
      state.committed = <MessageReconciliationRecord<T>>[];
      state.pendingDeltas.clear();
      state.serverTombstones.clear();
      state.retainedTombstoneOverlays.clear();
      state.authoritativeOverlays.clear();
    }
    if (delta.generation < state.lastDeltaGeneration) {
      return null;
    }
    state.lastDeltaGeneration = delta.generation;

    final first = delta.upserts.isEmpty ? null : delta.upserts.first;
    if (delta.kind == MessageDeltaKind.realtimeUpsert) {
      final accepted = coordinator.noteRealtimePending(
        conversationID: conversationID,
        eventID: delta.eventID,
        msgID: first?.serverIdentity,
        seq: first?.numericSeq,
      );
      if (!accepted) return null;
    }

    _rememberDeltaAuthority(state, delta);
    if (state.activeRequest != null) {
      state.pendingDeltas.add(delta);
      return null;
    }
    return _publish(
      conversationID: conversationID,
      state: state,
      input: _applyDeltaRecords(state.committed, <MessageDelta<T>>[delta]),
      generation: delta.generation,
    );
  }

  /// A stale completion is ignored and cannot consume realtime messages that
  /// belong to the newer generation.
  MessageReconciliationWriterCommit<T>? completeHistory({
    required MessageReconciliationRequest request,
    required Iterable<MessageReconciliationRecord<T>> history,
    required MessageReconciliationSource actualSource,
    required MessageReconciliationNetworkState networkState,
    bool cloudHasMoreNewer = false,
    MessageHistoryBatchKind batchKind = MessageHistoryBatchKind.olderPage,
    MessageHistoryProofKind proofKind = MessageHistoryProofKind.none,
    bool? historyIsFinished,
    Iterable<MessageReconciliationRecord<T>>? authoritativeBase,
    Iterable<String> explicitDeletes = const <String>[],
    Iterable<String> tombstones = const <String>[],
  }) {
    final state = _stateFor(request.conversationKey);
    if (state.activeRequest?.generation != request.generation) return null;

    final batchDeletes = <String>{
      ...explicitDeletes.map((id) => id.trim()).where((id) => id.isNotEmpty),
      ...tombstones.map((id) => id.trim()).where((id) => id.isNotEmpty),
    };
    if (batchDeletes.isNotEmpty) {
      for (final id in batchDeletes) {
        state.serverTombstones.add(id);
        if (!state.retainedTombstoneOverlays.contains(id)) {
          state.authoritativeOverlays.remove(id);
        }
      }
      _trimRememberedAuthority(state);
    }

    final merged = _mergeAndSort(
      _applyRememberedAuthority(
        state,
        _applyDeltaRecords(
          <MessageReconciliationRecord<T>>[
            ...history,
            ...(authoritativeBase ?? state.committed),
          ],
          state.pendingDeltas,
        ),
      ),
      trackSeqGaps: state.trackSeqGaps,
    );
    final lastConfirmed = _lastConfirmedMsgID(merged.records);
    final accepted = coordinator.completeRequest(
      request: request,
      actualSource: actualSource,
      networkState: networkState,
      resultCount: merged.records.length,
      lastConfirmedMsgID: lastConfirmed,
      oldestSeq: merged.oldestSeq,
      newestSeq: merged.newestSeq,
      missingSeqRanges: merged.missingSeqRanges,
      cloudHasMoreNewer: cloudHasMoreNewer,
      batchKind: batchKind,
      proofKind: proofKind,
      historyIsFinished: historyIsFinished,
    );
    if (!accepted) return null;

    state.activeRequest = null;
    state.pendingDeltas.clear();
    state.committed = merged.records;
    state.revision += 1;
    return _commitFromMerge(
      request.conversationKey,
      request.generation,
      state.revision,
      merged,
    );
  }

  /// Failure releases queued realtime messages instead of leaving the visible
  /// list frozen behind a failed history request.
  MessageReconciliationWriterCommit<T>? failHistory({
    required MessageReconciliationRequest request,
    required String reason,
    required MessageReconciliationNetworkState networkState,
  }) {
    final state = _stateFor(request.conversationKey);
    if (state.activeRequest?.generation != request.generation) return null;
    if (!coordinator.failRequest(
      request: request,
      reason: reason,
      networkState: networkState,
    )) {
      return null;
    }
    state.activeRequest = null;
    if (state.pendingDeltas.isEmpty) return null;
    final pending = List<MessageDelta<T>>.of(state.pendingDeltas);
    state.pendingDeltas.clear();
    return _publish(
      conversationID: request.conversationKey,
      state: state,
      input: _applyDeltaRecords(state.committed, pending),
      generation: request.generation,
    );
  }

  List<MessageReconciliationRecord<T>> recordsFor(String conversationID) {
    return List<MessageReconciliationRecord<T>>.unmodifiable(
      _stateFor(conversationID).committed,
    );
  }

  int revisionFor(String conversationID) => _stateFor(conversationID).revision;

  int pendingRealtimeCount(String conversationID) =>
      _stateFor(conversationID).pendingDeltas
          .where((delta) => delta.kind == MessageDeltaKind.realtimeUpsert)
          .fold<int>(0, (count, delta) => count + delta.upserts.length);

  int pendingDeltaCount(String conversationID) =>
      _stateFor(conversationID).pendingDeltas.length;

  Set<String> tombstonesFor(String conversationID) =>
      Set<String>.unmodifiable(_stateFor(conversationID).serverTombstones);

  void releaseTombstones(
    String conversationID,
    Iterable<String> msgIDs,
  ) {
    final state = _stateFor(conversationID);
    final normalizedIDs = msgIDs
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in normalizedIDs) {
      final normalized = id.trim();
      if (normalized.isEmpty) continue;
      state.serverTombstones.remove(normalized);
      state.retainedTombstoneOverlays.remove(normalized);
      state.authoritativeOverlays.remove(normalized);
    }
    // A delete/revoke can be accepted while a history request is in flight.
    // If the SDK operation fails, discard the queued removal before publishing
    // the rollback upsert; otherwise the same tombstone would be re-applied
    // when history completes.
    state.pendingDeltas.removeWhere((delta) {
      final affected = <String>{
        ...delta.explicitDeletes,
        ...delta.tombstones,
      };
      return affected.any(normalizedIDs.contains);
    });
  }

  bool hasActiveRequest(String conversationID) =>
      _stateFor(conversationID).activeRequest != null;

  void reset(String conversationID) {
    final key = _canonicalKey(conversationID);
    // Flush pending realtime messages before clearing state so they are
    // not silently lost when the conversation is torn down.
    final state = _states[key];
    if (state != null && state.pendingDeltas.isNotEmpty) {
      final pending = List<MessageDelta<T>>.of(state.pendingDeltas);
      state.pendingDeltas.clear();
      if (state.activeRequest == null) {
        _publish(
          conversationID: conversationID,
          state: state,
          input: _applyDeltaRecords(state.committed, pending),
          generation: coordinator.stateFor(conversationID).requestGeneration,
        );
      }
    }
    _states.remove(key);
    coordinator.reset(key);
  }

  void resetAll() {
    final keys = _states.keys.toList(growable: false);
    for (final key in keys) {
      reset(key);
    }
  }

  MessageReconciliationWriterCommit<T> _publish({
    required String conversationID,
    required _MessageReconciliationWriterState<T> state,
    required Iterable<MessageReconciliationRecord<T>> input,
    required int generation,
  }) {
    final merged = _mergeAndSort(
      _applyRememberedAuthority(state, input),
      trackSeqGaps: state.trackSeqGaps,
    );
    state.committed = merged.records;
    state.revision += 1;
    return _commitFromMerge(
      _canonicalKey(conversationID),
      generation,
      state.revision,
      merged,
    );
  }

  MessageReconciliationWriterCommit<T> _commitFromMerge(
    String conversationKey,
    int generation,
    int revision,
    MessageIdentityMergeResult<T> merged,
  ) {
    return MessageReconciliationWriterCommit<T>(
      conversationKey: conversationKey,
      generation: generation,
      revision: revision,
      records: merged.records,
      missingSeqRanges: merged.missingSeqRanges,
      seqIdentityConflicts: merged.seqIdentityConflicts,
    );
  }

  MessageIdentityMergeResult<T> _mergeAndSort(
    Iterable<MessageReconciliationRecord<T>> records, {
    required bool trackSeqGaps,
  }) {
    final merged = MessageReconciliationIdentity.merge(records);
    final sorted = List<MessageReconciliationRecord<T>>.of(merged.records)
      ..sort(_comparator);
    return MessageIdentityMergeResult<T>(
      records: List<MessageReconciliationRecord<T>>.unmodifiable(sorted),
      oldestSeq: merged.oldestSeq,
      newestSeq: merged.newestSeq,
      missingSeqRanges:
          trackSeqGaps ? merged.missingSeqRanges : const <MessageSeqRange>[],
      seqIdentityConflicts: merged.seqIdentityConflicts,
    );
  }

  Iterable<MessageReconciliationRecord<T>> _applyDeltaRecords(
    Iterable<MessageReconciliationRecord<T>> base,
    Iterable<MessageDelta<T>> deltas,
  ) sync* {
    final records = <MessageReconciliationRecord<T>>[...base];
    final deleted = <String>{};
    final upserts = <MessageReconciliationRecord<T>>[];
    for (final delta in deltas) {
      deleted.addAll(delta.explicitDeletes);
      deleted.addAll(delta.tombstones);
      upserts.addAll(delta.upserts);
    }
    for (final record in records) {
      final id = record.serverIdentity;
      if (id == null || !deleted.contains(id)) {
        yield record;
      }
    }
    yield* upserts;
  }

  Iterable<MessageReconciliationRecord<T>> _applyRememberedAuthority(
    _MessageReconciliationWriterState<T> state,
    Iterable<MessageReconciliationRecord<T>> base,
  ) sync* {
    for (final record in base) {
      final id = record.serverIdentity;
      if (id == null || !state.serverTombstones.contains(id)) {
        yield record;
      }
    }
    for (final overlay in state.authoritativeOverlays.values) {
      final id = overlay.serverIdentity;
      if (id == null ||
          !state.serverTombstones.contains(id) ||
          state.retainedTombstoneOverlays.contains(id)) {
        yield overlay;
      }
    }
  }

  void _rememberDeltaAuthority(
    _MessageReconciliationWriterState<T> state,
    MessageDelta<T> delta,
  ) {
    final removals = <String>{
      ...delta.explicitDeletes,
      ...delta.tombstones,
    };
    for (final id in removals) {
      state.serverTombstones.add(id);
      state.retainedTombstoneOverlays.remove(id);
      state.authoritativeOverlays.remove(id);
    }
    for (final record in delta.upserts) {
      final id = record.serverIdentity;
      if (id == null) continue;
      if (state.serverTombstones.contains(id) &&
          delta.kind != MessageDeltaKind.revoke) {
        continue;
      }
      if (delta.kind == MessageDeltaKind.revoke) {
        state.serverTombstones.add(id);
        state.retainedTombstoneOverlays.add(id);
      }
      if (delta.kind == MessageDeltaKind.edit ||
          delta.kind == MessageDeltaKind.revoke ||
          delta.kind == MessageDeltaKind.optimisticAdoption ||
          delta.kind == MessageDeltaKind.realtimeUpsert) {
        state.authoritativeOverlays.remove(id);
        state.authoritativeOverlays[id] = record;
      }
    }
    _trimRememberedAuthority(state);
  }

  void _trimRememberedAuthority(_MessageReconciliationWriterState<T> state) {
    while (state.serverTombstones.length > _maxRememberedServerMutations) {
      final oldest = state.serverTombstones.first;
      state.serverTombstones.remove(oldest);
      state.retainedTombstoneOverlays.remove(oldest);
    }
    while (state.authoritativeOverlays.length >
        _maxRememberedServerMutations) {
      state.authoritativeOverlays.remove(state.authoritativeOverlays.keys.first);
    }
    while (state.retainedTombstoneOverlays.length >
        _maxRememberedServerMutations) {
      state.retainedTombstoneOverlays.remove(
        state.retainedTombstoneOverlays.first,
      );
    }
  }

  _MessageReconciliationWriterState<T> _stateFor(String conversationID) {
    return _states.putIfAbsent(
      _canonicalKey(conversationID),
      _MessageReconciliationWriterState<T>.new,
    );
  }

  static String _canonicalKey(String conversationID) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    return key;
  }

  static String? _lastConfirmedMsgID<T>(
    List<MessageReconciliationRecord<T>> records,
  ) {
    for (final record in records.reversed) {
      final id = record.serverIdentity;
      if (id != null) return id;
    }
    return null;
  }
}
