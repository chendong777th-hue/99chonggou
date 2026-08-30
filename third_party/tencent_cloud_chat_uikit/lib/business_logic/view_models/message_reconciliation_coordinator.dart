import 'message_history_coverage.dart';

enum MessageReconciliationPhase {
  idle,
  localVisibleProvisional,
  initialHistory,
  realtimePending,
  cloudCatchUp,
  cloudContinuationPending,
  cloudWindowPartial,
  gapDetected,
  offlineLocalOnly,
  complete,
  failed,
}

enum MessageReconciliationSource {
  realtime,
  local,
  cloud,
}

enum MessageReconciliationNetworkState {
  unknown,
  offline,
  online,
}

class MessageReconciliationProvenance {
  const MessageReconciliationProvenance({
    required this.requestedSource,
    required this.actualSource,
    required this.networkState,
    required this.proofKind,
  });

  final MessageReconciliationSource requestedSource;
  final MessageReconciliationSource actualSource;
  final MessageReconciliationNetworkState networkState;

  final MessageHistoryProofKind proofKind;

  bool get cloudTransportConfirmed =>
      proofKind == MessageHistoryProofKind.transportObserved ||
      proofKind == MessageHistoryProofKind.serverContinuity;

  @Deprecated('This proves cloud transport, not history continuity')
  bool get cloudResponseProven => cloudTransportConfirmed;

  static MessageReconciliationProvenance resolve({
    required MessageReconciliationSource requestedSource,
    required MessageReconciliationNetworkState beforeRequest,
    required MessageReconciliationNetworkState afterResponse,
  }) {
    if (requestedSource != MessageReconciliationSource.cloud) {
      return MessageReconciliationProvenance(
        requestedSource: requestedSource,
        actualSource: requestedSource,
        networkState: _resolvedNetworkState(
          beforeRequest,
          afterResponse,
        ),
        proofKind: MessageHistoryProofKind.none,
      );
    }
    final cloudProven =
        beforeRequest == MessageReconciliationNetworkState.online &&
            afterResponse == MessageReconciliationNetworkState.online;
    return MessageReconciliationProvenance(
      requestedSource: requestedSource,
      actualSource: cloudProven
          ? MessageReconciliationSource.cloud
          : MessageReconciliationSource.local,
      networkState: _resolvedNetworkState(beforeRequest, afterResponse),
      proofKind: cloudProven
          ? MessageHistoryProofKind.transportObserved
          : MessageHistoryProofKind.none,
    );
  }

  static MessageReconciliationNetworkState _resolvedNetworkState(
    MessageReconciliationNetworkState beforeRequest,
    MessageReconciliationNetworkState afterResponse,
  ) {
    if (beforeRequest == MessageReconciliationNetworkState.offline ||
        afterResponse == MessageReconciliationNetworkState.offline) {
      return MessageReconciliationNetworkState.offline;
    }
    if (beforeRequest == MessageReconciliationNetworkState.online &&
        afterResponse == MessageReconciliationNetworkState.online) {
      return MessageReconciliationNetworkState.online;
    }
    return MessageReconciliationNetworkState.unknown;
  }
}

class MessageSeqRange {
  const MessageSeqRange(this.start, this.end)
      : assert(start > 0),
        assert(end >= start);

  final int start;
  final int end;

  int get count => end - start + 1;

  @override
  bool operator ==(Object other) =>
      other is MessageSeqRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start-$end';
}

class MessageReconciliationState {
  const MessageReconciliationState({
    required this.conversationKey,
    required this.phase,
    required this.source,
    required this.requestedSource,
    required this.requestGeneration,
    required this.networkState,
    required this.missingSeqRanges,
    required this.cloudHasMoreNewer,
    this.lastConfirmedMsgID,
    this.oldestSeq,
    this.newestSeq,
    this.lastError,
  });

  factory MessageReconciliationState.idle(String conversationKey) {
    return MessageReconciliationState(
      conversationKey: conversationKey,
      phase: MessageReconciliationPhase.idle,
      source: null,
      requestedSource: null,
      requestGeneration: 0,
      networkState: MessageReconciliationNetworkState.unknown,
      missingSeqRanges: const <MessageSeqRange>[],
      cloudHasMoreNewer: false,
    );
  }

  final String conversationKey;
  final MessageReconciliationPhase phase;
  final MessageReconciliationSource? source;
  final MessageReconciliationSource? requestedSource;
  final int requestGeneration;
  final MessageReconciliationNetworkState networkState;
  final String? lastConfirmedMsgID;
  final int? oldestSeq;
  final int? newestSeq;
  final List<MessageSeqRange> missingSeqRanges;
  final bool cloudHasMoreNewer;
  final String? lastError;

  bool get isComplete => phase == MessageReconciliationPhase.complete;

  bool get needsCloudRetry =>
      phase == MessageReconciliationPhase.localVisibleProvisional ||
      phase == MessageReconciliationPhase.offlineLocalOnly ||
      phase == MessageReconciliationPhase.cloudContinuationPending ||
      phase == MessageReconciliationPhase.cloudWindowPartial ||
      phase == MessageReconciliationPhase.gapDetected ||
      phase == MessageReconciliationPhase.failed;

  MessageReconciliationState copyWith({
    MessageReconciliationPhase? phase,
    MessageReconciliationSource? source,
    bool clearSource = false,
    MessageReconciliationSource? requestedSource,
    bool clearRequestedSource = false,
    int? requestGeneration,
    MessageReconciliationNetworkState? networkState,
    String? lastConfirmedMsgID,
    bool clearLastConfirmedMsgID = false,
    int? oldestSeq,
    int? newestSeq,
    List<MessageSeqRange>? missingSeqRanges,
    bool? cloudHasMoreNewer,
    String? lastError,
    bool clearLastError = false,
  }) {
    return MessageReconciliationState(
      conversationKey: conversationKey,
      phase: phase ?? this.phase,
      source: clearSource ? null : source ?? this.source,
      requestedSource:
          clearRequestedSource ? null : requestedSource ?? this.requestedSource,
      requestGeneration: requestGeneration ?? this.requestGeneration,
      networkState: networkState ?? this.networkState,
      lastConfirmedMsgID: clearLastConfirmedMsgID
          ? null
          : lastConfirmedMsgID ?? this.lastConfirmedMsgID,
      oldestSeq: oldestSeq ?? this.oldestSeq,
      newestSeq: newestSeq ?? this.newestSeq,
      missingSeqRanges: List<MessageSeqRange>.unmodifiable(
        missingSeqRanges ?? this.missingSeqRanges,
      ),
      cloudHasMoreNewer: cloudHasMoreNewer ?? this.cloudHasMoreNewer,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}

class MessageReconciliationRequest {
  const MessageReconciliationRequest({
    required this.conversationKey,
    required this.generation,
    required this.requestedSource,
    this.ownerUserID,
    this.accountGeneration = 0,
    this.domainGeneration = 0,
    this.clearEpoch = 0,
  });

  final String conversationKey;
  final int generation;
  final MessageReconciliationSource requestedSource;
  final String? ownerUserID;
  final int accountGeneration;
  final int domainGeneration;
  final int clearEpoch;
}

class MessageReconciliationDiagnostic {
  const MessageReconciliationDiagnostic({
    required this.conversationHash,
    required this.event,
    required this.phase,
    required this.generation,
    required this.resultCount,
    required this.missingSeqCount,
    this.lastConfirmedMsgID,
  });

  final String conversationHash;
  final String event;
  final MessageReconciliationPhase phase;
  final int generation;
  final int resultCount;
  final int missingSeqCount;
  final String? lastConfirmedMsgID;
}

typedef MessageReconciliationDiagnosticSink = void Function(
  MessageReconciliationDiagnostic diagnostic,
);

/// Owns synchronization state only. It never fetches history, mutates message
/// payloads, or publishes a UI list; those remain responsibilities of the
/// message single writer.
class MessageReconciliationCoordinator {
  MessageReconciliationCoordinator({this.onDiagnostic});

  final MessageReconciliationDiagnosticSink? onDiagnostic;
  static const int _maxRememberedRealtimeEvents = 1024;
  final Map<String, MessageReconciliationState> _states =
      <String, MessageReconciliationState>{};
  final Map<String, Set<String>> _appliedRealtimeEventIds =
      <String, Set<String>>{};

  MessageReconciliationState stateFor(String conversationID) {
    final key = _canonicalKey(conversationID);
    return _states[key] ?? MessageReconciliationState.idle(key);
  }

  MessageReconciliationRequest beginInitialHistory({
    required String conversationID,
    required MessageReconciliationSource requestedSource,
    required MessageReconciliationNetworkState networkState,
    String? ownerUserID,
    int accountGeneration = 0,
    int domainGeneration = 0,
    int clearEpoch = 0,
  }) {
    return _begin(
      conversationID: conversationID,
      phase: MessageReconciliationPhase.initialHistory,
      requestedSource: requestedSource,
      networkState: networkState,
      ownerUserID: ownerUserID,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      clearEpoch: clearEpoch,
    );
  }

  MessageReconciliationRequest beginCloudCatchUp({
    required String conversationID,
    required MessageReconciliationNetworkState networkState,
    String? ownerUserID,
    int accountGeneration = 0,
    int domainGeneration = 0,
    int clearEpoch = 0,
  }) {
    return _begin(
      conversationID: conversationID,
      phase: MessageReconciliationPhase.cloudCatchUp,
      requestedSource: MessageReconciliationSource.cloud,
      networkState: networkState,
      ownerUserID: ownerUserID,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      clearEpoch: clearEpoch,
    );
  }

  MessageReconciliationRequest _begin({
    required String conversationID,
    required MessageReconciliationPhase phase,
    required MessageReconciliationSource requestedSource,
    required MessageReconciliationNetworkState networkState,
    String? ownerUserID,
    required int accountGeneration,
    required int domainGeneration,
    required int clearEpoch,
  }) {
    final key = _canonicalKey(conversationID);
    final previous = stateFor(key);
    final generation = previous.requestGeneration + 1;
    final next = previous.copyWith(
      phase: phase,
      source: requestedSource,
      requestedSource: requestedSource,
      requestGeneration: generation,
      networkState: networkState,
      missingSeqRanges: const <MessageSeqRange>[],
      cloudHasMoreNewer: false,
      clearLastError: true,
    );
    _states[key] = next;
    _diagnose(next, event: 'request_begin');
    return MessageReconciliationRequest(
      conversationKey: key,
      generation: generation,
      requestedSource: requestedSource,
      ownerUserID:
          ownerUserID?.trim().isEmpty == true ? null : ownerUserID?.trim(),
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      clearEpoch: clearEpoch,
    );
  }

  /// Records realtime intake without treating it as proof that cloud history
  /// is complete. Duplicate callback event IDs are idempotent.
  bool noteRealtimePending({
    required String conversationID,
    required String eventID,
    String? msgID,
    int? seq,
  }) {
    final key = _canonicalKey(conversationID);
    final normalizedEventID = eventID.trim();
    if (normalizedEventID.isNotEmpty) {
      final events = _appliedRealtimeEventIds[key] ??= <String>{};
      if (!events.add(normalizedEventID)) {
        return false;
      }
      while (events.length > _maxRememberedRealtimeEvents) {
        events.remove(events.first);
      }
    }
    final previous = stateFor(key);
    final normalizedMsgID = msgID?.trim() ?? '';
    final next = previous.copyWith(
      phase: MessageReconciliationPhase.realtimePending,
      source: MessageReconciliationSource.realtime,
      lastConfirmedMsgID: normalizedMsgID.isEmpty ? null : normalizedMsgID,
      oldestSeq: _minSeq(previous.oldestSeq, seq),
      newestSeq: _maxSeq(previous.newestSeq, seq),
      clearLastError: true,
    );
    _states[key] = next;
    _diagnose(next, event: 'realtime_pending', resultCount: 1);
    return true;
  }

  /// Applies metadata from an explicitly requested history result. A stale
  /// completion is ignored. A cloud request that returned local data while
  /// offline remains incomplete and is retried after network recovery.
  bool completeRequest({
    required MessageReconciliationRequest request,
    required MessageReconciliationSource actualSource,
    required MessageReconciliationNetworkState networkState,
    required int resultCount,
    String? lastConfirmedMsgID,
    int? oldestSeq,
    int? newestSeq,
    List<MessageSeqRange> missingSeqRanges = const <MessageSeqRange>[],
    bool cloudHasMoreNewer = false,
    MessageHistoryBatchKind batchKind = MessageHistoryBatchKind.olderPage,
    MessageHistoryProofKind proofKind = MessageHistoryProofKind.none,
    bool? historyIsFinished,
  }) {
    final current = stateFor(request.conversationKey);
    if (current.requestGeneration != request.generation) {
      _diagnose(current, event: 'stale_completion_ignored');
      return false;
    }
    final normalizedRanges = List<MessageSeqRange>.unmodifiable(
      missingSeqRanges,
    );
    final isOfflineCloudFallback =
        request.requestedSource == MessageReconciliationSource.cloud &&
            (actualSource == MessageReconciliationSource.local ||
                networkState == MessageReconciliationNetworkState.offline);
    final phase = batchKind == MessageHistoryBatchKind.localSnapshot
        ? MessageReconciliationPhase.localVisibleProvisional
        : isOfflineCloudFallback
            ? MessageReconciliationPhase.offlineLocalOnly
            : normalizedRanges.isNotEmpty
                ? MessageReconciliationPhase.gapDetected
                : cloudHasMoreNewer
                    ? MessageReconciliationPhase.cloudContinuationPending
                    : proofKind == MessageHistoryProofKind.serverContinuity
                        ? MessageReconciliationPhase.complete
                        : MessageReconciliationPhase.cloudWindowPartial;
    final normalizedMsgID = lastConfirmedMsgID?.trim() ?? '';
    final next = current.copyWith(
      phase: phase,
      source: actualSource,
      requestedSource: request.requestedSource,
      networkState: networkState,
      lastConfirmedMsgID: normalizedMsgID.isEmpty ? null : normalizedMsgID,
      oldestSeq: _minSeq(current.oldestSeq, oldestSeq),
      newestSeq: _maxSeq(current.newestSeq, newestSeq),
      missingSeqRanges: normalizedRanges,
      cloudHasMoreNewer: cloudHasMoreNewer,
      clearLastError: true,
    );
    _states[request.conversationKey] = next;
    _diagnose(next, event: 'request_complete', resultCount: resultCount);
    return true;
  }

  bool failRequest({
    required MessageReconciliationRequest request,
    required String reason,
    required MessageReconciliationNetworkState networkState,
  }) {
    final current = stateFor(request.conversationKey);
    if (current.requestGeneration != request.generation) {
      _diagnose(current, event: 'stale_failure_ignored');
      return false;
    }
    final next = current.copyWith(
      phase: MessageReconciliationPhase.failed,
      requestedSource: request.requestedSource,
      networkState: networkState,
      lastError: reason.trim().isEmpty ? 'unknown' : reason.trim(),
    );
    _states[request.conversationKey] = next;
    _diagnose(next, event: 'request_failed');
    return true;
  }

  void reset(String conversationID) {
    final key = _canonicalKey(conversationID);
    _states.remove(key);
    _appliedRealtimeEventIds.remove(key);
  }

  void _diagnose(
    MessageReconciliationState state, {
    required String event,
    int resultCount = 0,
  }) {
    final missingSeqCount = state.missingSeqRanges.fold<int>(
      0,
      (sum, range) => sum + range.count,
    );
    onDiagnostic?.call(
      MessageReconciliationDiagnostic(
        conversationHash: _hashConversationKey(state.conversationKey),
        event: event,
        phase: state.phase,
        generation: state.requestGeneration,
        resultCount: resultCount,
        missingSeqCount: missingSeqCount,
        lastConfirmedMsgID: state.lastConfirmedMsgID,
      ),
    );
  }

  static String _canonicalKey(String conversationID) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    return key;
  }

  static int? _minSeq(int? current, int? incoming) {
    if (incoming == null || incoming <= 0) return current;
    if (current == null || current <= 0) return incoming;
    return incoming < current ? incoming : current;
  }

  static int? _maxSeq(int? current, int? incoming) {
    if (incoming == null || incoming <= 0) return current;
    if (current == null || current <= 0) return incoming;
    return incoming > current ? incoming : current;
  }

  static String _hashConversationKey(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
