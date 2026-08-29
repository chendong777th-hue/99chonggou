enum MessageHistoryBatchKind {
  localSnapshot,
  latestWindow,
  olderPage,
  newerCatchUp,
  gapFill,
}

/// Strength of the evidence attached to a history response.
///
/// The Tencent client can normally prove that a cloud transport was observed,
/// but it does not expose Telegram-style difference/continuity tokens. Callers
/// must therefore not interpret [transportObserved] as complete history.
enum MessageHistoryProofKind {
  none,
  transportObserved,
  serverContinuity,
}

enum MessageHistoryCoverageStatus {
  empty,
  provisional,
  verified,
  partial,
  offlineLocalOnly,
  failed,
}

enum MessageHistoryHoleKind {
  groupSeq,
  c2cBoundary,
}

enum MessageHistoryHoleStatus {
  open,
  retryable,
  cloudUnavailable,
  resolved,
}

enum MessageHistoryCoverageDirection { older, newer, latest }

class MessageHistoryCoverageRange {
  const MessageHistoryCoverageRange({
    required this.key,
    required this.direction,
    this.oldestMsgID,
    this.newestMsgID,
    this.startSeq,
    this.endSeq,
    this.proofKind = MessageHistoryProofKind.none,
    this.closed = false,
    this.generation = 0,
    this.updatedAtMs = 0,
  });

  final String key;
  final MessageHistoryCoverageDirection direction;
  final String? oldestMsgID;
  final String? newestMsgID;
  final int? startSeq;
  final int? endSeq;
  final MessageHistoryProofKind proofKind;
  final bool closed;
  final int generation;
  final int updatedAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'direction': direction.name,
        'oldestMsgID': oldestMsgID,
        'newestMsgID': newestMsgID,
        'startSeq': startSeq,
        'endSeq': endSeq,
        'proofKind': proofKind.name,
        'closed': closed,
        'generation': generation,
        'updatedAtMs': updatedAtMs,
      };

  factory MessageHistoryCoverageRange.fromJson(Map<String, Object?> json) {
    return MessageHistoryCoverageRange(
      key: json['key']?.toString() ?? '',
      direction: _enumByName(
        MessageHistoryCoverageDirection.values,
        json['direction'],
        MessageHistoryCoverageDirection.latest,
      ),
      oldestMsgID: _nonEmpty(json['oldestMsgID']),
      newestMsgID: _nonEmpty(json['newestMsgID']),
      startSeq: _asInt(json['startSeq']),
      endSeq: _asInt(json['endSeq']),
      proofKind: _enumByName(
        MessageHistoryProofKind.values,
        json['proofKind'],
        MessageHistoryProofKind.none,
      ),
      closed: json['closed'] == true || json['closed'] == 1,
      generation: _asInt(json['generation']) ?? 0,
      updatedAtMs: _asInt(json['updatedAtMs']) ?? 0,
    );
  }
}

class MessageHistoryPageRecord {
  const MessageHistoryPageRecord({
    required this.key,
    required this.direction,
    this.cursorMsgID,
    this.cursorSeq,
    this.returnedOldestMsgID,
    this.returnedNewestMsgID,
    this.returnedOldestSeq,
    this.returnedNewestSeq,
    this.isFinished = false,
    this.hasMore = false,
    this.proofKind = MessageHistoryProofKind.none,
    this.generation = 0,
    this.updatedAtMs = 0,
  });

  final String key;
  final MessageHistoryCoverageDirection direction;
  final String? cursorMsgID;
  final int? cursorSeq;
  final String? returnedOldestMsgID;
  final String? returnedNewestMsgID;
  final int? returnedOldestSeq;
  final int? returnedNewestSeq;
  final bool isFinished;
  final bool hasMore;
  final MessageHistoryProofKind proofKind;
  final int generation;
  final int updatedAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'direction': direction.name,
        'cursorMsgID': cursorMsgID,
        'cursorSeq': cursorSeq,
        'returnedOldestMsgID': returnedOldestMsgID,
        'returnedNewestMsgID': returnedNewestMsgID,
        'returnedOldestSeq': returnedOldestSeq,
        'returnedNewestSeq': returnedNewestSeq,
        'isFinished': isFinished,
        'hasMore': hasMore,
        'proofKind': proofKind.name,
        'generation': generation,
        'updatedAtMs': updatedAtMs,
      };

  factory MessageHistoryPageRecord.fromJson(Map<String, Object?> json) {
    return MessageHistoryPageRecord(
      key: json['key']?.toString() ?? '',
      direction: _enumByName(
        MessageHistoryCoverageDirection.values,
        json['direction'],
        MessageHistoryCoverageDirection.latest,
      ),
      cursorMsgID: _nonEmpty(json['cursorMsgID']),
      cursorSeq: _asInt(json['cursorSeq']),
      returnedOldestMsgID: _nonEmpty(json['returnedOldestMsgID']),
      returnedNewestMsgID: _nonEmpty(json['returnedNewestMsgID']),
      returnedOldestSeq: _asInt(json['returnedOldestSeq']),
      returnedNewestSeq: _asInt(json['returnedNewestSeq']),
      isFinished: json['isFinished'] == true || json['isFinished'] == 1,
      hasMore: json['hasMore'] == true || json['hasMore'] == 1,
      proofKind: _enumByName(
        MessageHistoryProofKind.values,
        json['proofKind'],
        MessageHistoryProofKind.none,
      ),
      generation: _asInt(json['generation']) ?? 0,
      updatedAtMs: _asInt(json['updatedAtMs']) ?? 0,
    );
  }
}

class MessageHistoryHole {
  const MessageHistoryHole({
    required this.key,
    required this.kind,
    required this.status,
    this.startSeq,
    this.endSeq,
    this.olderMsgID,
    this.newerMsgID,
    this.generation = 0,
    this.updatedAtMs = 0,
  });

  final String key;
  final MessageHistoryHoleKind kind;
  final MessageHistoryHoleStatus status;
  final int? startSeq;
  final int? endSeq;
  final String? olderMsgID;
  final String? newerMsgID;
  final int generation;
  final int updatedAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'kind': kind.name,
        'status': status.name,
        'startSeq': startSeq,
        'endSeq': endSeq,
        'olderMsgID': olderMsgID,
        'newerMsgID': newerMsgID,
        'generation': generation,
        'updatedAtMs': updatedAtMs,
      };

  factory MessageHistoryHole.fromJson(Map<String, Object?> json) {
    return MessageHistoryHole(
      key: json['key']?.toString() ?? '',
      kind: _enumByName(
        MessageHistoryHoleKind.values,
        json['kind'],
        MessageHistoryHoleKind.c2cBoundary,
      ),
      status: _enumByName(
        MessageHistoryHoleStatus.values,
        json['status'],
        MessageHistoryHoleStatus.open,
      ),
      startSeq: _asInt(json['startSeq']),
      endSeq: _asInt(json['endSeq']),
      olderMsgID: _nonEmpty(json['olderMsgID']),
      newerMsgID: _nonEmpty(json['newerMsgID']),
      generation: _asInt(json['generation']) ?? 0,
      updatedAtMs: _asInt(json['updatedAtMs']) ?? 0,
    );
  }
}

class MessageHistoryCoverage {
  const MessageHistoryCoverage({
    required this.conversationKey,
    required this.isGroup,
    required this.clearEpoch,
    required this.coverageRevision,
    required this.status,
    required this.olderExhausted,
    required this.newerHasMore,
    required this.holes,
    this.updatedAtMs = 0,
    this.ranges = const <MessageHistoryCoverageRange>[],
    this.pages = const <MessageHistoryPageRecord>[],
    this.continuationPending = false,
    this.continuationDirection,
    this.continuationCursorMsgID,
    this.continuationCursorSeq,
    this.localOldestMsgID,
    this.localNewestMsgID,
    this.verifiedOldestMsgID,
    this.verifiedNewestMsgID,
    this.verifiedOldestSeq,
    this.verifiedNewestSeq,
    this.cloudVerifiedAtMs = 0,
    this.lastRequestGeneration = 0,
    this.lastRequestedSource,
    this.lastActualSource,
    this.lastBatchKind,
    this.lastCursorDirection,
    this.lastCursorMsgID,
    this.lastCursorSeq,
    this.lastReturnedOldestMsgID,
    this.lastReturnedNewestMsgID,
    this.lastReturnedOldestSeq,
    this.lastReturnedNewestSeq,
    MessageHistoryProofKind? lastProofKind,
    this.lastCloudResponseProven = false,
  }) : lastProofKind = lastProofKind ??
            (lastCloudResponseProven
                ? MessageHistoryProofKind.transportObserved
                : MessageHistoryProofKind.none);

  factory MessageHistoryCoverage.empty(
    String conversationKey, {
    required bool isGroup,
    int clearEpoch = 0,
  }) {
    return MessageHistoryCoverage(
      conversationKey: conversationKey,
      isGroup: isGroup,
      clearEpoch: clearEpoch,
      coverageRevision: 0,
      status: MessageHistoryCoverageStatus.empty,
      olderExhausted: false,
      newerHasMore: false,
      holes: const <MessageHistoryHole>[],
      updatedAtMs: 0,
    );
  }

  final String conversationKey;
  final bool isGroup;
  final int clearEpoch;
  final int coverageRevision;
  final MessageHistoryCoverageStatus status;
  final String? localOldestMsgID;
  final String? localNewestMsgID;
  final String? verifiedOldestMsgID;
  final String? verifiedNewestMsgID;
  final int? verifiedOldestSeq;
  final int? verifiedNewestSeq;
  final bool olderExhausted;
  final bool newerHasMore;
  final List<MessageHistoryHole> holes;
  final List<MessageHistoryCoverageRange> ranges;
  final List<MessageHistoryPageRecord> pages;
  final bool continuationPending;
  final MessageHistoryCoverageDirection? continuationDirection;
  final String? continuationCursorMsgID;
  final int? continuationCursorSeq;
  final int cloudVerifiedAtMs;
  final int updatedAtMs;
  // Request/page metadata only. Message bodies remain owned by the SDK.
  final int lastRequestGeneration;
  final String? lastRequestedSource;
  final String? lastActualSource;
  final String? lastBatchKind;
  final String? lastCursorDirection;
  final String? lastCursorMsgID;
  final int? lastCursorSeq;
  final String? lastReturnedOldestMsgID;
  final String? lastReturnedNewestMsgID;
  final int? lastReturnedOldestSeq;
  final int? lastReturnedNewestSeq;

  /// Proof attached to the most recent history response. Transport proof is
  /// intentionally weaker than server continuity proof.
  final MessageHistoryProofKind lastProofKind;
  @Deprecated('Use lastProofKind')
  final bool lastCloudResponseProven;

  bool get hasOpenHoles => holes.any(
        (hole) => hole.status != MessageHistoryHoleStatus.resolved,
      );

  /// An empty latest-window response may only end retry when a previous
  /// online cloud result already verified the visible boundary.
  bool get acceptsEmptyLatestWindow =>
      status == MessageHistoryCoverageStatus.verified &&
      cloudVerifiedAtMs > 0 &&
      ranges.any(
        (range) =>
            range.direction == MessageHistoryCoverageDirection.latest &&
            range.closed &&
            range.proofKind == MessageHistoryProofKind.serverContinuity,
      ) &&
      !hasOpenHoles &&
      !newerHasMore;

  /// The previous bounded C2C newer pull returned no progress for its anchor.
  /// This remains a retryable partial state, not a proof of completion.
  bool get cloudContinuationStalled =>
      continuationPending &&
      continuationDirection == MessageHistoryCoverageDirection.newer &&
      lastBatchKind == 'cloud_catch_up_stalled';

  MessageHistoryCoverage copyWith({
    String? conversationKey,
    bool? isGroup,
    int? clearEpoch,
    int? coverageRevision,
    MessageHistoryCoverageStatus? status,
    String? localOldestMsgID,
    bool clearLocalOldestMsgID = false,
    String? localNewestMsgID,
    bool clearLocalNewestMsgID = false,
    String? verifiedOldestMsgID,
    bool clearVerifiedOldestMsgID = false,
    String? verifiedNewestMsgID,
    bool clearVerifiedNewestMsgID = false,
    int? verifiedOldestSeq,
    bool clearVerifiedOldestSeq = false,
    int? verifiedNewestSeq,
    bool clearVerifiedNewestSeq = false,
    bool? olderExhausted,
    bool? newerHasMore,
    List<MessageHistoryHole>? holes,
    List<MessageHistoryCoverageRange>? ranges,
    List<MessageHistoryPageRecord>? pages,
    bool? continuationPending,
    MessageHistoryCoverageDirection? continuationDirection,
    bool clearContinuationDirection = false,
    String? continuationCursorMsgID,
    bool clearContinuationCursor = false,
    int? continuationCursorSeq,
    int? cloudVerifiedAtMs,
    int? updatedAtMs,
    int? lastRequestGeneration,
    String? lastRequestedSource,
    String? lastActualSource,
    String? lastBatchKind,
    String? lastCursorDirection,
    String? lastCursorMsgID,
    bool clearLastCursor = false,
    int? lastCursorSeq,
    String? lastReturnedOldestMsgID,
    String? lastReturnedNewestMsgID,
    int? lastReturnedOldestSeq,
    int? lastReturnedNewestSeq,
    bool clearLastReturnedBounds = false,
    MessageHistoryProofKind? lastProofKind,
    bool? lastCloudResponseProven,
  }) {
    final resolvedLastProofKind = lastProofKind ??
        (lastCloudResponseProven == true &&
                this.lastProofKind == MessageHistoryProofKind.none
            ? MessageHistoryProofKind.transportObserved
            : this.lastProofKind);
    return MessageHistoryCoverage(
      conversationKey: conversationKey ?? this.conversationKey,
      isGroup: isGroup ?? this.isGroup,
      clearEpoch: clearEpoch ?? this.clearEpoch,
      coverageRevision: coverageRevision ?? this.coverageRevision,
      status: status ?? this.status,
      localOldestMsgID: clearLocalOldestMsgID
          ? null
          : localOldestMsgID ?? this.localOldestMsgID,
      localNewestMsgID: clearLocalNewestMsgID
          ? null
          : localNewestMsgID ?? this.localNewestMsgID,
      verifiedOldestMsgID: clearVerifiedOldestMsgID
          ? null
          : verifiedOldestMsgID ?? this.verifiedOldestMsgID,
      verifiedNewestMsgID: clearVerifiedNewestMsgID
          ? null
          : verifiedNewestMsgID ?? this.verifiedNewestMsgID,
      verifiedOldestSeq: clearVerifiedOldestSeq
          ? null
          : verifiedOldestSeq ?? this.verifiedOldestSeq,
      verifiedNewestSeq: clearVerifiedNewestSeq
          ? null
          : verifiedNewestSeq ?? this.verifiedNewestSeq,
      olderExhausted: olderExhausted ?? this.olderExhausted,
      newerHasMore: newerHasMore ?? this.newerHasMore,
      holes: List<MessageHistoryHole>.unmodifiable(holes ?? this.holes),
      ranges: List<MessageHistoryCoverageRange>.unmodifiable(
        ranges ?? this.ranges,
      ),
      pages: List<MessageHistoryPageRecord>.unmodifiable(pages ?? this.pages),
      continuationPending: continuationPending ?? this.continuationPending,
      continuationDirection: clearContinuationDirection
          ? null
          : continuationDirection ?? this.continuationDirection,
      continuationCursorMsgID: clearContinuationCursor
          ? null
          : continuationCursorMsgID ?? this.continuationCursorMsgID,
      continuationCursorSeq: clearContinuationCursor
          ? null
          : continuationCursorSeq ?? this.continuationCursorSeq,
      cloudVerifiedAtMs: cloudVerifiedAtMs ?? this.cloudVerifiedAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      lastRequestGeneration:
          lastRequestGeneration ?? this.lastRequestGeneration,
      lastRequestedSource: lastRequestedSource ?? this.lastRequestedSource,
      lastActualSource: lastActualSource ?? this.lastActualSource,
      lastBatchKind: lastBatchKind ?? this.lastBatchKind,
      lastCursorDirection: clearLastCursor
          ? null
          : lastCursorDirection ?? this.lastCursorDirection,
      lastCursorMsgID:
          clearLastCursor ? null : lastCursorMsgID ?? this.lastCursorMsgID,
      lastCursorSeq:
          clearLastCursor ? null : lastCursorSeq ?? this.lastCursorSeq,
      lastReturnedOldestMsgID: clearLastReturnedBounds
          ? null
          : lastReturnedOldestMsgID ?? this.lastReturnedOldestMsgID,
      lastReturnedNewestMsgID: clearLastReturnedBounds
          ? null
          : lastReturnedNewestMsgID ?? this.lastReturnedNewestMsgID,
      lastReturnedOldestSeq: clearLastReturnedBounds
          ? null
          : lastReturnedOldestSeq ?? this.lastReturnedOldestSeq,
      lastReturnedNewestSeq: clearLastReturnedBounds
          ? null
          : lastReturnedNewestSeq ?? this.lastReturnedNewestSeq,
      lastProofKind: resolvedLastProofKind,
      lastCloudResponseProven:
          lastCloudResponseProven ?? this.lastCloudResponseProven,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'conversationKey': conversationKey,
        'isGroup': isGroup,
        'clearEpoch': clearEpoch,
        'coverageRevision': coverageRevision,
        'status': status.name,
        'localOldestMsgID': localOldestMsgID,
        'localNewestMsgID': localNewestMsgID,
        'verifiedOldestMsgID': verifiedOldestMsgID,
        'verifiedNewestMsgID': verifiedNewestMsgID,
        'verifiedOldestSeq': verifiedOldestSeq,
        'verifiedNewestSeq': verifiedNewestSeq,
        'olderExhausted': olderExhausted,
        'newerHasMore': newerHasMore,
        'holes': holes.map((hole) => hole.toJson()).toList(growable: false),
        'ranges': ranges.map((range) => range.toJson()).toList(growable: false),
        'pages': pages.map((page) => page.toJson()).toList(growable: false),
        'continuationPending': continuationPending,
        'continuationDirection': continuationDirection?.name,
        'continuationCursorMsgID': continuationCursorMsgID,
        'continuationCursorSeq': continuationCursorSeq,
        'cloudVerifiedAtMs': cloudVerifiedAtMs,
        'updatedAtMs': updatedAtMs,
        'lastRequestGeneration': lastRequestGeneration,
        'lastRequestedSource': lastRequestedSource,
        'lastActualSource': lastActualSource,
        'lastBatchKind': lastBatchKind,
        'lastCursorDirection': lastCursorDirection,
        'lastCursorMsgID': lastCursorMsgID,
        'lastCursorSeq': lastCursorSeq,
        'lastReturnedOldestMsgID': lastReturnedOldestMsgID,
        'lastReturnedNewestMsgID': lastReturnedNewestMsgID,
        'lastReturnedOldestSeq': lastReturnedOldestSeq,
        'lastReturnedNewestSeq': lastReturnedNewestSeq,
        'lastProofKind': lastProofKind.name,
        'lastCloudResponseProven': lastCloudResponseProven,
      };

  factory MessageHistoryCoverage.fromJson(Map<String, Object?> json) {
    final rawHoles = json['holes'];
    final holes = <MessageHistoryHole>[];
    if (rawHoles is Iterable) {
      for (final raw in rawHoles) {
        if (raw is Map) {
          holes.add(
            MessageHistoryHole.fromJson(
              raw.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    final ranges = <MessageHistoryCoverageRange>[];
    final rawRanges = json['ranges'];
    if (rawRanges is Iterable) {
      for (final raw in rawRanges) {
        if (raw is Map) {
          ranges.add(MessageHistoryCoverageRange.fromJson(
            raw.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
    }
    final pages = <MessageHistoryPageRecord>[];
    final rawPages = json['pages'];
    if (rawPages is Iterable) {
      for (final raw in rawPages) {
        if (raw is Map) {
          pages.add(MessageHistoryPageRecord.fromJson(
            raw.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
    }
    return MessageHistoryCoverage(
      conversationKey: json['conversationKey']?.toString() ?? '',
      isGroup: json['isGroup'] == true || json['isGroup'] == 1,
      clearEpoch: _asInt(json['clearEpoch']) ?? 0,
      coverageRevision: _asInt(json['coverageRevision']) ?? 0,
      status: _enumByName(
        MessageHistoryCoverageStatus.values,
        json['status'],
        MessageHistoryCoverageStatus.empty,
      ),
      localOldestMsgID: _nonEmpty(json['localOldestMsgID']),
      localNewestMsgID: _nonEmpty(json['localNewestMsgID']),
      verifiedOldestMsgID: _nonEmpty(json['verifiedOldestMsgID']),
      verifiedNewestMsgID: _nonEmpty(json['verifiedNewestMsgID']),
      verifiedOldestSeq: _asInt(json['verifiedOldestSeq']),
      verifiedNewestSeq: _asInt(json['verifiedNewestSeq']),
      olderExhausted:
          json['olderExhausted'] == true || json['olderExhausted'] == 1,
      newerHasMore: json['newerHasMore'] == true || json['newerHasMore'] == 1,
      holes: List<MessageHistoryHole>.unmodifiable(holes),
      ranges: List<MessageHistoryCoverageRange>.unmodifiable(ranges),
      pages: List<MessageHistoryPageRecord>.unmodifiable(pages),
      continuationPending: json['continuationPending'] == true ||
          json['continuationPending'] == 1,
      continuationDirection: json['continuationDirection'] == null
          ? null
          : _enumByName(
              MessageHistoryCoverageDirection.values,
              json['continuationDirection'],
              MessageHistoryCoverageDirection.latest,
            ),
      continuationCursorMsgID: _nonEmpty(json['continuationCursorMsgID']),
      continuationCursorSeq: _asInt(json['continuationCursorSeq']),
      cloudVerifiedAtMs: _asInt(json['cloudVerifiedAtMs']) ?? 0,
      updatedAtMs: _asInt(json['updatedAtMs']) ?? 0,
      lastRequestGeneration: _asInt(json['lastRequestGeneration']) ?? 0,
      lastRequestedSource: _nonEmpty(json['lastRequestedSource']),
      lastActualSource: _nonEmpty(json['lastActualSource']),
      lastBatchKind: _nonEmpty(json['lastBatchKind']),
      lastCursorDirection: _nonEmpty(json['lastCursorDirection']),
      lastCursorMsgID: _nonEmpty(json['lastCursorMsgID']),
      lastCursorSeq: _asInt(json['lastCursorSeq']),
      lastReturnedOldestMsgID: _nonEmpty(json['lastReturnedOldestMsgID']),
      lastReturnedNewestMsgID: _nonEmpty(json['lastReturnedNewestMsgID']),
      lastReturnedOldestSeq: _asInt(json['lastReturnedOldestSeq']),
      lastReturnedNewestSeq: _asInt(json['lastReturnedNewestSeq']),
      lastProofKind: _enumByName(
        MessageHistoryProofKind.values,
        json['lastProofKind'],
        json['lastCloudResponseProven'] == true ||
                json['lastCloudResponseProven'] == 1
            ? MessageHistoryProofKind.transportObserved
            : MessageHistoryProofKind.none,
      ),
      lastCloudResponseProven: json['lastCloudResponseProven'] == true ||
          json['lastCloudResponseProven'] == 1,
    );
  }
}

abstract interface class MessageHistoryCoverageRepository {
  Future<MessageHistoryCoverage?> load(String conversationID);

  Future<void> save(MessageHistoryCoverage coverage);

  Future<void> clearConversation(
    String conversationID, {
    required bool isGroup,
    required int clearEpoch,
  });

  Future<void> clearSession();
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString() ?? '';
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
