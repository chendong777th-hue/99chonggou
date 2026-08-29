import 'message_reconciliation_coordinator.dart';

class MessageReconciliationRecord<T> {
  const MessageReconciliationRecord({
    required this.value,
    this.msgID,
    this.localID,
    this.outgoingStableID,
    this.seq,
  });

  final T value;

  /// Tencent server identity. This is the only exact cloud identity.
  final String? msgID;

  /// Plugin-local progress correlation. Never used as a cloud identity.
  final String? localID;

  /// Existing optimistic-send stable identity from plans 018/045/049.
  final String? outgoingStableID;

  /// Tencent group server Seq as received from the SDK.
  final String? seq;

  String? get serverIdentity {
    final id = msgID?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  String? get optimisticIdentity {
    final id = outgoingStableID?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  int? get numericSeq {
    final parsed = int.tryParse(seq?.trim() ?? '');
    return parsed == null || parsed <= 0 ? null : parsed;
  }
}

class MessageSeqIdentityConflict {
  const MessageSeqIdentityConflict({
    required this.seq,
    required this.msgIDs,
  });

  final int seq;
  final Set<String> msgIDs;
}

class MessageIdentityMergeResult<T> {
  const MessageIdentityMergeResult({
    required this.records,
    required this.oldestSeq,
    required this.newestSeq,
    required this.missingSeqRanges,
    required this.seqIdentityConflicts,
  });

  final List<MessageReconciliationRecord<T>> records;
  final int? oldestSeq;
  final int? newestSeq;
  final List<MessageSeqRange> missingSeqRanges;
  final List<MessageSeqIdentityConflict> seqIdentityConflicts;
}

/// Deterministic identity/continuity rules for reconciliation inputs.
///
/// This utility intentionally does not sort messages. The message single
/// writer must continue using the app's existing chronological comparator.
class MessageReconciliationIdentity {
  const MessageReconciliationIdentity._();

  static MessageIdentityMergeResult<T> merge<T>(
    Iterable<MessageReconciliationRecord<T>> input,
  ) {
    final output = <MessageReconciliationRecord<T>>[];
    final serverIndex = <String, int>{};
    final optimisticIndex = <String, int>{};

    for (final incoming in input) {
      final serverID = incoming.serverIdentity;
      final stableID = incoming.optimisticIdentity;

      if (serverID != null) {
        final exactIndex = serverIndex[serverID];
        if (exactIndex != null) {
          output[exactIndex] = incoming;
          if (stableID != null) optimisticIndex[stableID] = exactIndex;
          continue;
        }

        // A server-confirmed row replaces its correlated optimistic row, but
        // two different server msgIDs are always retained even if a malformed
        // payload gives them the same optimistic stable ID.
        final optimisticMatch =
            stableID == null ? null : optimisticIndex[stableID];
        if (optimisticMatch != null &&
            output[optimisticMatch].serverIdentity == null) {
          output[optimisticMatch] = incoming;
          serverIndex[serverID] = optimisticMatch;
          optimisticIndex[stableID!] = optimisticMatch;
          continue;
        }

        final index = output.length;
        output.add(incoming);
        serverIndex[serverID] = index;
        if (stableID != null) optimisticIndex[stableID] = index;
        continue;
      }

      if (stableID != null) {
        final existingIndex = optimisticIndex[stableID];
        if (existingIndex != null) {
          // Never let a later optimistic retry replace a confirmed server row.
          if (output[existingIndex].serverIdentity == null) {
            output[existingIndex] = incoming;
          }
          continue;
        }
        optimisticIndex[stableID] = output.length;
      }
      // No msgID and no outgoing stable ID is deliberately retained as an
      // anonymous row. SDK-local id is progress correlation, not cloud dedup.
      output.add(incoming);
    }

    final seqToMsgIDs = <int, Set<String>>{};
    for (final record in output) {
      final seq = record.numericSeq;
      if (seq == null) continue;
      final msgID = record.serverIdentity;
      if (msgID != null) {
        (seqToMsgIDs[seq] ??= <String>{}).add(msgID);
      } else {
        seqToMsgIDs.putIfAbsent(seq, () => <String>{});
      }
    }
    final seqs = seqToMsgIDs.keys.toList(growable: false)..sort();
    final missing = <MessageSeqRange>[];
    for (var index = 1; index < seqs.length; index++) {
      final previous = seqs[index - 1];
      final current = seqs[index];
      if (current > previous + 1) {
        missing.add(MessageSeqRange(previous + 1, current - 1));
      }
    }
    final conflicts = <MessageSeqIdentityConflict>[
      for (final entry in seqToMsgIDs.entries)
        if (entry.value.length > 1)
          MessageSeqIdentityConflict(
            seq: entry.key,
            msgIDs: Set<String>.unmodifiable(entry.value),
          ),
    ]..sort((a, b) => a.seq.compareTo(b.seq));

    return MessageIdentityMergeResult<T>(
      records: List<MessageReconciliationRecord<T>>.unmodifiable(output),
      oldestSeq: seqs.isEmpty ? null : seqs.first,
      newestSeq: seqs.isEmpty ? null : seqs.last,
      missingSeqRanges: List<MessageSeqRange>.unmodifiable(missing),
      seqIdentityConflicts:
          List<MessageSeqIdentityConflict>.unmodifiable(conflicts),
    );
  }
}
