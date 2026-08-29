import 'message_history_coverage.dart';
import 'message_reconciliation_coordinator.dart';

/// Direction of the cursor used to request a history batch.
///
/// [latest] is used for a bounded latest-window verification request where
/// the caller does not advance an older/newer pagination cursor.
enum MessageHistoryCursorDirection {
  older,
  newer,
  latest,
}

/// Cursor supplied to a history loader.
///
/// C2C conversations use [lastMsgID], while group conversations may also use
/// [lastMsgSeq].  The two fields are deliberately optional because the SDK
/// uses different pagination identities for those conversation kinds.
class MessageHistoryCursor {
  const MessageHistoryCursor({
    required this.direction,
    this.lastMsgID,
    this.lastMsgSeq,
  }) : assert(
          lastMsgID != null || lastMsgSeq != null ||
              direction == MessageHistoryCursorDirection.latest,
          'An older/newer cursor must contain a message ID or Seq.',
        );

  final MessageHistoryCursorDirection direction;
  final String? lastMsgID;
  final int? lastMsgSeq;

  bool get isEmpty => lastMsgID == null && lastMsgSeq == null;

  Map<String, Object?> toJson() => <String, Object?>{
        'direction': direction.name,
        'lastMsgID': lastMsgID,
        'lastMsgSeq': lastMsgSeq,
      };

  @override
  bool operator ==(Object other) {
    return other is MessageHistoryCursor &&
        other.direction == direction &&
        other.lastMsgID == lastMsgID &&
        other.lastMsgSeq == lastMsgSeq;
  }

  @override
  int get hashCode => Object.hash(direction, lastMsgID, lastMsgSeq);
}

/// Inclusive bounds returned by a history request.
///
/// A bound is metadata only; it does not assert that the whole conversation
/// between the two IDs is present. Coverage and hole tracking provide that
/// stronger guarantee separately.
class MessageHistoryBounds {
  const MessageHistoryBounds({
    this.oldestMsgID,
    this.newestMsgID,
    this.oldestSeq,
    this.newestSeq,
  });

  const MessageHistoryBounds.empty() : this();

  final String? oldestMsgID;
  final String? newestMsgID;
  final int? oldestSeq;
  final int? newestSeq;

  bool get isEmpty =>
      oldestMsgID == null &&
      newestMsgID == null &&
      oldestSeq == null &&
      newestSeq == null;

  Map<String, Object?> toJson() => <String, Object?>{
        'oldestMsgID': oldestMsgID,
        'newestMsgID': newestMsgID,
        'oldestSeq': oldestSeq,
        'newestSeq': newestSeq,
      };

  @override
  bool operator ==(Object other) {
    return other is MessageHistoryBounds &&
        other.oldestMsgID == oldestMsgID &&
        other.newestMsgID == newestMsgID &&
        other.oldestSeq == oldestSeq &&
        other.newestSeq == newestSeq;
  }

  @override
  int get hashCode =>
      Object.hash(oldestMsgID, newestMsgID, oldestSeq, newestSeq);
}

/// Typed result envelope for all history reads.
///
/// The envelope intentionally carries both the requested and actual source.
/// A cloud request can return a local fallback (for example when an SDK
/// loader is offline), so callers must inspect [actualSource] and
/// [proofKind] instead of inferring continuity from the request
/// type or from a non-empty message list.
class MessageHistoryBatch<T> {
  MessageHistoryBatch({
    required this.conversationKey,
    required this.requestedSource,
    required this.actualSource,
    required this.batchKind,
    required int requestGeneration,
    required this.clearEpoch,
    this.requestedCursor,
    MessageHistoryBounds? returnedBounds,
    required this.isFinished,
    required this.hasMoreOlder,
    required this.cloudHasMoreNewer,
    MessageHistoryProofKind? proofKind,
    @Deprecated('Use proofKind') bool? cloudResponseProven,
    Iterable<T> messages = const [],
    Iterable<String> explicitDeletes = const <String>[],
    Iterable<String> tombstones = const <String>[],
  })  : _requestGeneration = requestGeneration,
        proofKind = proofKind ??
            (cloudResponseProven == true
                ? MessageHistoryProofKind.transportObserved
                : MessageHistoryProofKind.none),
        returnedBounds = returnedBounds ?? const MessageHistoryBounds.empty(),
        messages = List<T>.unmodifiable(messages),
        explicitDeletes = Set<String>.unmodifiable(
          explicitDeletes.map((id) => id.trim()).where((id) => id.isNotEmpty),
        ),
        tombstones = Set<String>.unmodifiable(
          tombstones.map((id) => id.trim()).where((id) => id.isNotEmpty),
        );

  final String conversationKey;
  final MessageReconciliationSource requestedSource;
  final MessageReconciliationSource actualSource;
  final MessageHistoryBatchKind batchKind;
  final int _requestGeneration;
  final int clearEpoch;
  final MessageHistoryCursor? requestedCursor;
  final MessageHistoryBounds returnedBounds;
  final bool isFinished;
  final bool hasMoreOlder;
  final bool cloudHasMoreNewer;
  final MessageHistoryProofKind proofKind;
  final List<T> messages;
  final Set<String> explicitDeletes;
  final Set<String> tombstones;

  @Deprecated('Use proofKind; this proves transport only, not continuity')
  bool get cloudResponseProven => proofKind != MessageHistoryProofKind.none;

  bool get cloudTransportConfirmed =>
      proofKind == MessageHistoryProofKind.transportObserved ||
      proofKind == MessageHistoryProofKind.serverContinuity;

  bool get serverContinuityProven =>
      proofKind == MessageHistoryProofKind.serverContinuity;

  /// Generation is the preferred short name used by reconciliation code.
  int get generation => _requestGeneration;

  /// Compatibility name matching [MessageReconciliationRequest].
  int get requestGeneration => _requestGeneration;

  String? get returnedOldest => returnedBounds.oldestMsgID;

  String? get returnedNewest => returnedBounds.newestMsgID;

  String? get returnedOldestMsgID => returnedBounds.oldestMsgID;

  String? get returnedNewestMsgID => returnedBounds.newestMsgID;

  int? get returnedOldestSeq => returnedBounds.oldestSeq;

  int? get returnedNewestSeq => returnedBounds.newestSeq;

  /// A batch is stale when it belongs to a previous request or clear epoch.
  /// Callers should drop stale batches before mutating the list or coverage.
  bool isStale({required int generation, required int clearEpoch}) {
    return this.generation != generation || this.clearEpoch != clearEpoch;
  }

  bool matches({required int generation, required int clearEpoch}) {
    return !isStale(generation: generation, clearEpoch: clearEpoch);
  }

  /// Metadata safe for diagnostics; message bodies are intentionally omitted.
  Map<String, Object?> toMetadataJson() => <String, Object?>{
        'conversationKey': conversationKey,
        'requestedSource': requestedSource.name,
        'actualSource': actualSource.name,
        'batchKind': batchKind.name,
        'generation': generation,
        'clearEpoch': clearEpoch,
        'requestedCursor': requestedCursor?.toJson(),
        'returnedBounds': returnedBounds.toJson(),
        'isFinished': isFinished,
        'hasMoreOlder': hasMoreOlder,
        'cloudHasMoreNewer': cloudHasMoreNewer,
        'proofKind': proofKind.name,
        'cloudResponseProven': cloudResponseProven,
        'messageCount': messages.length,
        'explicitDeleteCount': explicitDeletes.length,
        'tombstoneCount': tombstones.length,
      };
}
