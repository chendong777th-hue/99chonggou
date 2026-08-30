import 'contracts/account_scoped_conversation_key.dart';
import 'contracts/history_proof.dart';
import 'contracts/sdk_result.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_history_coverage_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_param.dart'
    if (dart.library.html)
        'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result.dart'
    if (dart.library.html)
        'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html)
        'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart'
    as uikit_history;
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

/// The routing decision made before an SDK call is issued.
///
/// [webLocalHistoryUnsupported] and [webLocalSearchUnsupported] are explicit
/// outcomes. A Web caller must not be made to look like it has a native local
/// message database by falling back to an application cache.
enum Im06HistoryRoute {
  flutterLocal,
  flutterCloud,
  webCloud,
  webLocalHistoryUnsupported,
}

enum Im06SearchRoute {
  flutterLocal,
  flutterCloud,
  webCloud,
  webLocalSearchUnsupported,
}

enum Im06HistoryCoverageDirection { older, newer, latest }

enum Im06CoordinatorError {
  invalidArgument,
  platformUnavailable,
  sourceMismatch,
  proofMismatch,
  adapterFailure,
  cloudSearchUnavailable,
  staleResponse,
}

class Im06HistoryRequest {
  Im06HistoryRequest({
    required this.scope,
    required this.platform,
    required this.requestedSource,
    required this.direction,
    required this.requestId,
    required this.requestGeneration,
    required this.accountGeneration,
    required this.domainGeneration,
    this.clearEpoch = 0,
    required this.count,
    this.cursor = const Im06HistoryCursor.latest(),
  }) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be empty');
    }
    if (requestGeneration < 0) {
      throw ArgumentError.value(
        requestGeneration,
        'requestGeneration',
        'must not be negative',
      );
    }
    if (accountGeneration < 0 || domainGeneration < 0) {
      throw ArgumentError('history generations must not be negative');
    }
    if (clearEpoch < 0) {
      throw ArgumentError.value(
        clearEpoch,
        'clearEpoch',
        'must not be negative',
      );
    }
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'must be positive');
    }
    if (direction != ImHistoryDirection.latest && cursor.isEmpty) {
      throw ArgumentError(
        'older/newer history requests require a message cursor',
      );
    }
    if (scope.conversationType == ImConversationType.c2c &&
        cursor.sequence != null) {
      throw ArgumentError(
        'C2C history must not carry a group sequence cursor',
      );
    }
  }

  final AccountScopedConversationKey scope;
  final ImPlatform platform;
  final ImHistorySource requestedSource;
  final ImHistoryDirection direction;
  final String requestId;
  final int requestGeneration;
  final int accountGeneration;
  final int domainGeneration;
  final int clearEpoch;
  final int count;
  final Im06HistoryCursor cursor;

  String get normalizedRequestId => requestId.trim();

  /// The only cursor shape allowed to cross the Tencent history adapter.
  /// C2C uses message ID; groups may use the provider's group Seq.
  String? get providerLastMsgId => cursor.messageId;

  int? get providerLastMsgSeq =>
      scope.conversationType == ImConversationType.group
          ? cursor.sequence
          : null;
}

class Im06HistoryCursor {
  const Im06HistoryCursor({this.messageId, this.sequence})
      : assert(
          (messageId != null && messageId != '') || sequence != null,
          'a cursor needs a message ID or sequence',
        );

  const Im06HistoryCursor.latest()
      : messageId = null,
        sequence = null;

  final String? messageId;
  final int? sequence;

  bool get isEmpty => (messageId?.trim().isEmpty ?? true) && sequence == null;
}

class Im06MessageBounds {
  const Im06MessageBounds({
    this.oldestMessageId,
    this.newestMessageId,
    this.oldestSequence,
    this.newestSequence,
  });

  const Im06MessageBounds.empty() : this();

  final String? oldestMessageId;
  final String? newestMessageId;
  final int? oldestSequence;
  final int? newestSequence;

  bool get isEmpty =>
      oldestMessageId == null &&
      newestMessageId == null &&
      oldestSequence == null &&
      newestSequence == null;
}

/// One adapter response. This is deliberately metadata-only: message bodies
/// remain owned by the SDK adapter and are committed through the Writer.
class Im06HistoryPage {
  Im06HistoryPage({
    required this.actualSource,
    required this.proof,
    required this.isCompleted,
    required this.returnedBounds,
    this.messages = const <Object?>[],
  }) {
    if (proof.actualSource != actualSource) {
      throw ArgumentError('history page source and proof source differ');
    }
    if (proof.isFinished != isCompleted) {
      throw ArgumentError('history page completion and proof differ');
    }
    if (proof.returnedCount != messages.length) {
      throw ArgumentError('history page count and proof count differ');
    }
  }

  final ImHistorySource actualSource;
  final HistoryProof proof;
  final bool isCompleted;
  final Im06MessageBounds returnedBounds;
  final List<Object?> messages;
}

abstract interface class Im06HistorySearchAdapter {
  Future<SdkResult<Im06HistoryPage>> readHistory(
    Im06HistoryRequest request,
  );

  Future<SdkResult<Im06SearchPage>> search(Im06SearchRequest request);
}

/// SDK call boundary for message search. Global search has no single
/// conversation scope, so it is kept separate from [Im06HistorySearchAdapter].
abstract interface class Im06MessageSearchAdapter {
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchLocal(
    V2TimMessageSearchParam searchParam,
  );

  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchCloud(
    V2TimMessageSearchParam searchParam,
  );
}

class TUIKitIm06MessageSearchAdapter implements Im06MessageSearchAdapter {
  const TUIKitIm06MessageSearchAdapter(this.service);

  final MessageService service;

  @override
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchLocal(
    V2TimMessageSearchParam searchParam,
  ) {
    return service.searchLocalMessages(searchParam: searchParam);
  }

  @override
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchCloud(
    V2TimMessageSearchParam searchParam,
  ) {
    return service.searchCloudMessages(searchParam: searchParam);
  }
}

class Im06MessageSearchResponse {
  const Im06MessageSearchResponse.success({
    required this.requestedSource,
    required this.result,
  })  : error = null,
        errorDescription = null;

  const Im06MessageSearchResponse.failure({
    required this.requestedSource,
    required this.error,
    required this.errorDescription,
  }) : result = null;

  final ImHistorySource requestedSource;
  final V2TimValueCallback<V2TimMessageSearchResult>? result;
  final Im06CoordinatorError? error;
  final String? errorDescription;

  bool get isSuccess => result != null && error == null;
}

/// Routes SDK message search while preserving the SDK result shape expected
/// by the existing ViewModel. Web local search is rejected before the adapter
/// is called because the Web SDK has no native local message index.
class Im06MessageSearchCoordinator {
  const Im06MessageSearchCoordinator({required this.adapter});

  final Im06MessageSearchAdapter adapter;

  Future<Im06MessageSearchResponse> search({
    required ImPlatform platform,
    required ImHistorySource requestedSource,
    required V2TimMessageSearchParam searchParam,
  }) async {
    if (platform == ImPlatform.web &&
        requestedSource == ImHistorySource.local) {
      return const Im06MessageSearchResponse.failure(
        requestedSource: ImHistorySource.local,
        error: Im06CoordinatorError.platformUnavailable,
        errorDescription: 'Web has no native local message search API',
      );
    }
    try {
      final result = requestedSource == ImHistorySource.local
          ? await adapter.searchLocal(searchParam)
          : await adapter.searchCloud(searchParam);
      return Im06MessageSearchResponse.success(
        requestedSource: requestedSource,
        result: result,
      );
    } on Object catch (error) {
      return Im06MessageSearchResponse.failure(
        requestedSource: requestedSource,
        error: Im06CoordinatorError.adapterFailure,
        errorDescription: error.toString(),
      );
    }
  }
}

class Im06SearchRequest {
  Im06SearchRequest({
    required this.scope,
    required this.platform,
    required this.requestedSource,
    required this.requestId,
    required this.requestGeneration,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.keyword,
    this.cursor,
  }) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be empty');
    }
    if (requestGeneration < 0) {
      throw ArgumentError.value(
        requestGeneration,
        'requestGeneration',
        'must not be negative',
      );
    }
    if (keyword.trim().isEmpty) {
      throw ArgumentError.value(keyword, 'keyword', 'must not be empty');
    }
  }

  final AccountScopedConversationKey scope;
  final ImPlatform platform;
  final ImHistorySource requestedSource;
  final String requestId;
  final int requestGeneration;
  final int accountGeneration;
  final int domainGeneration;
  final String keyword;
  final String? cursor;
}

class Im06SearchHit {
  const Im06SearchHit({required this.scope, required this.messageId});

  final AccountScopedConversationKey scope;
  final String messageId;
}

class Im06SearchProof {
  Im06SearchProof({
    required this.scope,
    required this.platform,
    required this.requestedSource,
    required this.actualSource,
    required this.requestId,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.requestGeneration,
    required this.returnedCount,
    required this.isCompleted,
    required this.cloudResponseProven,
  }) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be empty');
    }
    if (returnedCount < 0) {
      throw ArgumentError.value(
        returnedCount,
        'returnedCount',
        'must not be negative',
      );
    }
    if (accountGeneration < 0 ||
        domainGeneration < 0 ||
        requestGeneration < 0) {
      throw ArgumentError('search generations must not be negative');
    }
    if (platform == ImPlatform.web && actualSource != ImHistorySource.cloud) {
      throw ArgumentError('Web search cannot claim a local source');
    }
    if (actualSource == ImHistorySource.local && cloudResponseProven) {
      throw ArgumentError('local search cannot claim cloud response proof');
    }
  }

  final AccountScopedConversationKey scope;
  final ImPlatform platform;
  final ImHistorySource requestedSource;
  final ImHistorySource actualSource;
  final String requestId;
  final int accountGeneration;
  final int domainGeneration;
  final int requestGeneration;
  final int returnedCount;
  final bool isCompleted;
  final bool cloudResponseProven;
}

class Im06SearchPage {
  Im06SearchPage({
    required this.actualSource,
    required this.proof,
    this.nextCursor,
    this.hits = const <Im06SearchHit>[],
  }) {
    if (proof.actualSource != actualSource) {
      throw ArgumentError('search page source and proof source differ');
    }
    if (proof.returnedCount != hits.length) {
      throw ArgumentError('search page count and proof count differ');
    }
  }

  final ImHistorySource actualSource;
  final Im06SearchProof proof;
  final String? nextCursor;
  final List<Im06SearchHit> hits;
}

class Im06CoverageRange {
  const Im06CoverageRange({
    required this.direction,
    required this.source,
    required this.proof,
    required this.requestedCursor,
    required this.returnedBounds,
    required this.closed,
    required this.requestGeneration,
  });

  final Im06HistoryCoverageDirection direction;
  final ImHistorySource source;
  final HistoryProof proof;
  final Im06HistoryCursor requestedCursor;
  final Im06MessageBounds returnedBounds;
  final bool closed;
  final int requestGeneration;
}

class Im06HistoryCoverage {
  const Im06HistoryCoverage({
    required this.scope,
    this.clearEpoch = 0,
    this.coverageRevision = 0,
    this.ranges = const <Im06CoverageRange>[],
  });

  final AccountScopedConversationKey scope;
  final int clearEpoch;
  final int coverageRevision;
  final List<Im06CoverageRange> ranges;

  bool isClosed(Im06HistoryCoverageDirection direction) => ranges.any(
        (range) => range.direction == direction && range.closed,
      );

  Im06HistoryCoverage add(Im06CoverageRange range) {
    final retained = ranges
        .where(
          (item) => !(item.direction == range.direction &&
              item.requestGeneration == range.requestGeneration),
        )
        .toList(growable: false);
    return Im06HistoryCoverage(
      scope: scope,
      clearEpoch: clearEpoch,
      coverageRevision: coverageRevision + 1,
      ranges: List<Im06CoverageRange>.unmodifiable(<Im06CoverageRange>[
        ...retained,
        range,
      ]),
    );
  }
}

class Im06HistoryReadResult {
  const Im06HistoryReadResult._({
    required this.route,
    this.page,
    this.error,
    this.errorDescription,
    required this.coverage,
  });

  factory Im06HistoryReadResult.success({
    required Im06HistoryRoute route,
    required Im06HistoryPage page,
    required Im06HistoryCoverage coverage,
  }) =>
      Im06HistoryReadResult._(
        route: route,
        page: page,
        coverage: coverage,
      );

  factory Im06HistoryReadResult.failure({
    required Im06HistoryRoute route,
    required Im06CoordinatorError error,
    required String errorDescription,
    required Im06HistoryCoverage coverage,
  }) =>
      Im06HistoryReadResult._(
        route: route,
        error: error,
        errorDescription: errorDescription,
        coverage: coverage,
      );

  final Im06HistoryRoute route;
  final Im06HistoryPage? page;
  final Im06CoordinatorError? error;
  final String? errorDescription;
  final Im06HistoryCoverage coverage;

  bool get isSuccess => page != null && error == null;

  bool get isCompleted => page?.isCompleted ?? false;

  HistoryProof? get proof => page?.proof;

  Im06MessageBounds get returnedBounds =>
      page?.returnedBounds ?? const Im06MessageBounds.empty();
}

class SearchJumpCommand {
  const SearchJumpCommand({
    required this.scope,
    required this.targetMessageId,
    required this.route,
    required this.proof,
  });

  final AccountScopedConversationKey scope;
  final String targetMessageId;
  final Im06SearchRoute route;
  final Im06SearchProof proof;
}

class Im06SearchResult {
  const Im06SearchResult._({
    required this.route,
    required this.hits,
    this.proof,
    this.nextCursor,
    this.jump,
    this.error,
    this.errorDescription,
  });

  factory Im06SearchResult.success({
    required Im06SearchRoute route,
    required Im06SearchPage page,
    SearchJumpCommand? jump,
  }) =>
      Im06SearchResult._(
        route: route,
        hits: page.hits,
        proof: page.proof,
        nextCursor: page.nextCursor,
        jump: jump,
      );

  factory Im06SearchResult.failure({
    required Im06SearchRoute route,
    required Im06CoordinatorError error,
    required String errorDescription,
  }) =>
      Im06SearchResult._(
        route: route,
        hits: const <Im06SearchHit>[],
        error: error,
        errorDescription: errorDescription,
      );

  final Im06SearchRoute route;
  final List<Im06SearchHit> hits;
  final Im06SearchProof? proof;
  final String? nextCursor;
  final SearchJumpCommand? jump;
  final Im06CoordinatorError? error;
  final String? errorDescription;

  bool get isSuccess => error == null;

  bool get isCompleted => proof?.isCompleted ?? false;
}

/// UI-independent acknowledgement for a [SearchJumpCommand].
///
/// The command is only an instruction to load/locate a formal message. A
/// caller may report success after all four facts are true; a hit alone is
/// never permission to jump to the latest visible row.
class SearchJumpResolutionProof {
  const SearchJumpResolutionProof({
    required this.formalMessagePresent,
    required this.visibleRow,
    required this.layoutComplete,
    required this.stableRowKey,
  });

  final bool formalMessagePresent;
  final bool visibleRow;
  final bool layoutComplete;
  final String stableRowKey;

  bool get canReportSuccess =>
      formalMessagePresent &&
      visibleRow &&
      layoutComplete &&
      stableRowKey.trim().isNotEmpty;
}

/// Persistence boundary for Coverage. The existing repository is coupled to
/// the TUIKit coverage DTO, so production wiring remains a follow-up adapter.
/// TODO(IM-06): implement this port against the existing coverage repository
/// after IM-04/IM-05 publish through the single Writer.
abstract interface class Im06HistoryCoverageStore {
  Future<Im06HistoryCoverage?> load(AccountScopedConversationKey scope);

  Future<void> save(Im06HistoryCoverage coverage);
}

/// Adapter for the existing persistent Coverage DTO.
///
/// The legacy DTO does not store the full account/domain/request proof. Loads
/// therefore reconstruct only a metadata-level proof (level `none`) from the
/// persisted range. New SDK responses still receive their complete proof from
/// the Coordinator; this adapter never upgrades legacy metadata to a stronger
/// claim.
class Im06MessageHistoryCoverageStoreAdapter
    implements Im06HistoryCoverageStore {
  const Im06MessageHistoryCoverageStoreAdapter(this.store);

  final MessageHistoryCoverageStore store;

  @override
  Future<Im06HistoryCoverage?> load(
    AccountScopedConversationKey scope,
  ) async {
    final persisted = await store.loadForOwner(
      scope.ownerUserId,
      scope.conversationId,
    );
    if (persisted == null) return null;
    final ranges = persisted.ranges
        .map((range) => _rangeFromLegacy(scope, persisted, range))
        .toList(growable: false);
    return Im06HistoryCoverage(
      scope: scope,
      clearEpoch: persisted.clearEpoch,
      coverageRevision: persisted.coverageRevision,
      ranges: ranges,
    );
  }

  @override
  Future<void> save(Im06HistoryCoverage coverage) {
    final latest = coverage.ranges.isEmpty ? null : coverage.ranges.last;
    final isGroup = coverage.scope.conversationType == ImConversationType.group;
    final ranges = coverage.ranges
        .map((range) => _rangeToLegacy(coverage.scope, range))
        .toList(growable: false);
    final legacy = uikit_history.MessageHistoryCoverage(
      conversationKey: coverage.scope.conversationId,
      isGroup: isGroup,
      clearEpoch: coverage.clearEpoch,
      coverageRevision: coverage.coverageRevision,
      status: ranges.isEmpty
          ? uikit_history.MessageHistoryCoverageStatus.empty
          : uikit_history.MessageHistoryCoverageStatus.partial,
      olderExhausted:
          coverage.isClosed(Im06HistoryCoverageDirection.older),
      newerHasMore: !coverage.isClosed(Im06HistoryCoverageDirection.newer),
      holes: const <uikit_history.MessageHistoryHole>[],
      ranges: ranges,
      lastRequestGeneration: latest?.requestGeneration ?? 0,
      lastRequestedSource: latest?.proof.requestedSource.name,
      lastActualSource: latest?.source.name,
      lastCursorDirection: latest?.proof.direction.name,
      lastCursorMsgID: latest?.requestedCursor.messageId,
      lastCursorSeq: isGroup ? latest?.requestedCursor.sequence : null,
      lastReturnedOldestMsgID: latest?.returnedBounds.oldestMessageId,
      lastReturnedNewestMsgID: latest?.returnedBounds.newestMessageId,
      lastReturnedOldestSeq:
          isGroup ? latest?.returnedBounds.oldestSequence : null,
      lastReturnedNewestSeq:
          isGroup ? latest?.returnedBounds.newestSequence : null,
      lastProofKind: _legacyProofKind(latest?.proof.level),
      lastCloudResponseProven:
          latest?.proof.actualSource == ImHistorySource.cloud,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return store.saveForOwner(coverage.scope.ownerUserId, legacy);
  }
}

uikit_history.MessageHistoryCoverageRange _rangeToLegacy(
  AccountScopedConversationKey scope,
  Im06CoverageRange range,
) {
  final isGroup = scope.conversationType == ImConversationType.group;
  return uikit_history.MessageHistoryCoverageRange(
    key: 'im06:${range.source.name}:${range.proof.requestId}',
    direction: _legacyDirection(range.direction),
    oldestMsgID: range.returnedBounds.oldestMessageId,
    newestMsgID: range.returnedBounds.newestMessageId,
    startSeq: isGroup ? range.returnedBounds.oldestSequence : null,
    endSeq: isGroup ? range.returnedBounds.newestSequence : null,
    proofKind: _legacyProofKind(range.proof.level),
    closed: range.closed,
    generation: range.requestGeneration,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
  );
}

Im06CoverageRange _rangeFromLegacy(
  AccountScopedConversationKey scope,
  uikit_history.MessageHistoryCoverage persisted,
  uikit_history.MessageHistoryCoverageRange range,
) {
  final source = _sourceFromLegacyKey(range.key, persisted);
  final direction = _im06Direction(range.direction);
  final proof = HistoryProof(
    scope: scope,
    platform: ImPlatform.unknown,
    accountGeneration: 0,
    domainGeneration: 0,
    requestGeneration: range.generation,
    requestId: range.key.trim().isEmpty ? 'legacy-coverage' : range.key,
    direction: _historyDirection(direction),
    requestedSource: source,
    actualSource: source,
    level: ImHistoryProofLevel.none,
    returnedCount: 0,
    isFinished: range.closed,
    oldestSequence: scope.conversationType == ImConversationType.group
        ? range.startSeq
        : null,
    newestSequence: scope.conversationType == ImConversationType.group
        ? range.endSeq
        : null,
  );
  return Im06CoverageRange(
    direction: _im06Direction(range.direction),
    source: source,
    proof: proof,
    requestedCursor: Im06HistoryCursor.latest(),
    returnedBounds: Im06MessageBounds(
      oldestMessageId: range.oldestMsgID,
      newestMessageId: range.newestMsgID,
      oldestSequence: scope.conversationType == ImConversationType.group
          ? range.startSeq
          : null,
      newestSequence: scope.conversationType == ImConversationType.group
          ? range.endSeq
          : null,
    ),
    closed: range.closed,
    requestGeneration: range.generation,
  );
}

uikit_history.MessageHistoryCoverageDirection _legacyDirection(
  Im06HistoryCoverageDirection direction,
) {
  return switch (direction) {
    Im06HistoryCoverageDirection.older =>
      uikit_history.MessageHistoryCoverageDirection.older,
    Im06HistoryCoverageDirection.newer =>
      uikit_history.MessageHistoryCoverageDirection.newer,
    Im06HistoryCoverageDirection.latest =>
      uikit_history.MessageHistoryCoverageDirection.latest,
  };
}

Im06HistoryCoverageDirection _im06Direction(
  uikit_history.MessageHistoryCoverageDirection direction,
) {
  return switch (direction) {
    uikit_history.MessageHistoryCoverageDirection.older =>
      Im06HistoryCoverageDirection.older,
    uikit_history.MessageHistoryCoverageDirection.newer =>
      Im06HistoryCoverageDirection.newer,
    uikit_history.MessageHistoryCoverageDirection.latest =>
      Im06HistoryCoverageDirection.latest,
  };
}

ImHistoryDirection _historyDirection(Im06HistoryCoverageDirection direction) {
  return switch (direction) {
    Im06HistoryCoverageDirection.older => ImHistoryDirection.older,
    Im06HistoryCoverageDirection.newer => ImHistoryDirection.newer,
    Im06HistoryCoverageDirection.latest => ImHistoryDirection.latest,
  };
}

uikit_history.MessageHistoryProofKind _legacyProofKind(
  ImHistoryProofLevel? level,
) {
  return switch (level) {
    ImHistoryProofLevel.serverContinuity =>
      uikit_history.MessageHistoryProofKind.serverContinuity,
    ImHistoryProofLevel.transportObserved =>
      uikit_history.MessageHistoryProofKind.transportObserved,
    _ => uikit_history.MessageHistoryProofKind.none,
  };
}

ImHistorySource _sourceFromLegacyKey(
  String key,
  uikit_history.MessageHistoryCoverage persisted,
) {
  final parts = key.split(':');
  if (parts.length > 1 && parts[1] == ImHistorySource.cloud.name) {
    return ImHistorySource.cloud;
  }
  return persisted.lastActualSource == ImHistorySource.cloud.name
      ? ImHistorySource.cloud
      : ImHistorySource.local;
}

/// Platform/source coordinator for IM-06.
///
/// This class intentionally stops at a typed adapter boundary. It does not
/// publish rows, manipulate a scroll controller, or call a page/UI model.
class Im06HistorySearchCoordinator {
  Im06HistorySearchCoordinator({required this.adapter, this.coverageStore});

  final Im06HistorySearchAdapter adapter;
  final Im06HistoryCoverageStore? coverageStore;
  final Map<String, Im06HistoryCoverage> _coverage =
      <String, Im06HistoryCoverage>{};

  Im06HistoryRoute historyRoute({
    required ImPlatform platform,
    required ImHistorySource requestedSource,
  }) {
    if (platform == ImPlatform.web) {
      return requestedSource == ImHistorySource.local
          ? Im06HistoryRoute.webLocalHistoryUnsupported
          : Im06HistoryRoute.webCloud;
    }
    return requestedSource == ImHistorySource.local
        ? Im06HistoryRoute.flutterLocal
        : Im06HistoryRoute.flutterCloud;
  }

  Im06SearchRoute searchRoute({
    required ImPlatform platform,
    required ImHistorySource requestedSource,
  }) {
    if (platform == ImPlatform.web) {
      return requestedSource == ImHistorySource.local
          ? Im06SearchRoute.webLocalSearchUnsupported
          : Im06SearchRoute.webCloud;
    }
    return requestedSource == ImHistorySource.local
        ? Im06SearchRoute.flutterLocal
        : Im06SearchRoute.flutterCloud;
  }

  Im06HistoryCoverage coverageFor(AccountScopedConversationKey scope) =>
      _coverage[scope.storageKey] ?? Im06HistoryCoverage(scope: scope);

  Future<Im06HistoryReadResult> readHistory(
    Im06HistoryRequest request,
  ) async {
    final route = historyRoute(
      platform: request.platform,
      requestedSource: request.requestedSource,
    );
    final previous = await _coverageFor(request.scope);
    if (previous.clearEpoch > request.clearEpoch) {
      return Im06HistoryReadResult.failure(
        route: route,
        error: Im06CoordinatorError.staleResponse,
        errorDescription: 'history request is older than the clear barrier',
        coverage: previous,
      );
    }
    final barrierCoverage = previous.clearEpoch == request.clearEpoch
        ? previous
        : Im06HistoryCoverage(
            scope: request.scope,
            clearEpoch: request.clearEpoch,
          );
    if (route == Im06HistoryRoute.webLocalHistoryUnsupported) {
      return Im06HistoryReadResult.failure(
        route: route,
        error: Im06CoordinatorError.platformUnavailable,
        errorDescription: 'Web has no native local history API',
        coverage: barrierCoverage,
      );
    }

    final effectiveRequest = _withEffectiveSource(
      request,
      route == Im06HistoryRoute.webCloud
          ? ImHistorySource.cloud
          : request.requestedSource,
    );
    try {
      final response = await adapter.readHistory(effectiveRequest);
      if (!response.isSuccess || response.data == null) {
        return Im06HistoryReadResult.failure(
          route: route,
          error: Im06CoordinatorError.adapterFailure,
          errorDescription: response.resultDesc ?? 'history adapter failed',
          coverage: barrierCoverage,
        );
      }
      final page = response.data!;
      final validationError = _validateHistoryPage(effectiveRequest, page);
      if (validationError != null) {
        return Im06HistoryReadResult.failure(
          route: route,
          error: validationError.$1,
          errorDescription: validationError.$2,
          coverage: barrierCoverage,
        );
      }
      final updated = _recordCoverage(barrierCoverage, effectiveRequest, page);
      _coverage[request.scope.storageKey] = updated;
      await _persistCoverage(updated);
      return Im06HistoryReadResult.success(
        route: route,
        page: page,
        coverage: updated,
      );
    } on Object catch (error) {
      return Im06HistoryReadResult.failure(
        route: route,
        error: Im06CoordinatorError.adapterFailure,
        errorDescription: error.toString(),
        coverage: barrierCoverage,
      );
    }
  }

  Future<Im06HistoryCoverage> _coverageFor(
    AccountScopedConversationKey scope,
  ) async {
    final cached = _coverage[scope.storageKey];
    if (cached != null) return cached;
    final persisted = await coverageStore?.load(scope);
    if (persisted != null && persisted.scope == scope) {
      _coverage[scope.storageKey] = persisted;
      return persisted;
    }
    final empty = Im06HistoryCoverage(scope: scope);
    _coverage[scope.storageKey] = empty;
    return empty;
  }

  Future<void> _persistCoverage(Im06HistoryCoverage coverage) async {
    try {
      await coverageStore?.save(coverage);
    } catch (_) {
      // A failed metadata write must not turn a committed SDK page into a
      // false adapter failure. The next request can retry the write.
    }
  }

  Future<Im06SearchResult> search(Im06SearchRequest request) async {
    final route = searchRoute(
      platform: request.platform,
      requestedSource: request.requestedSource,
    );
    if (route == Im06SearchRoute.webLocalSearchUnsupported) {
      return Im06SearchResult.failure(
        route: route,
        error: Im06CoordinatorError.platformUnavailable,
        errorDescription: 'Web has no native local message search API',
      );
    }

    final effectiveRequest = _withEffectiveSearchSource(
      request,
      route == Im06SearchRoute.webCloud
          ? ImHistorySource.cloud
          : request.requestedSource,
    );
    try {
      final response = await adapter.search(effectiveRequest);
      if (!response.isSuccess || response.data == null) {
        return Im06SearchResult.failure(
          route: route,
          error: response.errorKind == SdkErrorKind.unsupported
              ? Im06CoordinatorError.cloudSearchUnavailable
              : Im06CoordinatorError.adapterFailure,
          errorDescription: response.resultDesc ?? 'search adapter failed',
        );
      }
      final page = response.data!;
      final validationError = _validateSearchPage(effectiveRequest, page);
      if (validationError != null) {
        return Im06SearchResult.failure(
          route: route,
          error: validationError.$1,
          errorDescription: validationError.$2,
        );
      }
      final hit = page.hits.isEmpty ? null : page.hits.first;
      final jump = hit == null
          ? null
          : SearchJumpCommand(
              scope: hit.scope,
              targetMessageId: hit.messageId,
              route: route,
              proof: page.proof,
            );
      return Im06SearchResult.success(
        route: route,
        page: page,
        jump: jump,
      );
    } on Object catch (error) {
      // In particular, do not manufacture a jump to the latest message.
      return Im06SearchResult.failure(
        route: route,
        error: Im06CoordinatorError.adapterFailure,
        errorDescription: error.toString(),
      );
    }
  }

  Im06HistoryRequest _withEffectiveSource(
    Im06HistoryRequest request,
    ImHistorySource source,
  ) {
    return Im06HistoryRequest(
      scope: request.scope,
      platform: request.platform,
      requestedSource: source,
      direction: request.direction,
      requestId: request.requestId,
      requestGeneration: request.requestGeneration,
      accountGeneration: request.accountGeneration,
      domainGeneration: request.domainGeneration,
      clearEpoch: request.clearEpoch,
      count: request.count,
      cursor: request.cursor,
    );
  }

  Im06SearchRequest _withEffectiveSearchSource(
    Im06SearchRequest request,
    ImHistorySource source,
  ) {
    return Im06SearchRequest(
      scope: request.scope,
      platform: request.platform,
      requestedSource: source,
      requestId: request.requestId,
      requestGeneration: request.requestGeneration,
      accountGeneration: request.accountGeneration,
      domainGeneration: request.domainGeneration,
      keyword: request.keyword,
      cursor: request.cursor,
    );
  }

  (Im06CoordinatorError, String)? _validateHistoryPage(
    Im06HistoryRequest request,
    Im06HistoryPage page,
  ) {
    final expected = request.platform == ImPlatform.web
        ? ImHistorySource.cloud
        : request.requestedSource;
    if (page.actualSource != expected) {
      return (
        Im06CoordinatorError.sourceMismatch,
        'adapter returned ${page.actualSource.name} for ${expected.name} request',
      );
    }
    if (page.proof.scope != request.scope ||
        page.proof.platform != request.platform ||
        page.proof.requestedSource != request.requestedSource ||
        page.proof.requestGeneration != request.requestGeneration ||
        page.proof.accountGeneration != request.accountGeneration ||
        page.proof.domainGeneration != request.domainGeneration ||
        page.proof.requestId != request.normalizedRequestId) {
      return (
        Im06CoordinatorError.proofMismatch,
        'history proof does not match account, scope, or request',
      );
    }
    return null;
  }

  (Im06CoordinatorError, String)? _validateSearchPage(
    Im06SearchRequest request,
    Im06SearchPage page,
  ) {
    final expected = request.platform == ImPlatform.web
        ? ImHistorySource.cloud
        : request.requestedSource;
    if (page.actualSource != expected) {
      return (
        Im06CoordinatorError.sourceMismatch,
        'adapter returned ${page.actualSource.name} for ${expected.name} search',
      );
    }
    final proof = page.proof;
    if (proof.scope != request.scope ||
        proof.platform != request.platform ||
        proof.requestedSource != request.requestedSource ||
        proof.accountGeneration != request.accountGeneration ||
        proof.domainGeneration != request.domainGeneration ||
        proof.requestGeneration != request.requestGeneration ||
        proof.requestId != request.requestId.trim()) {
      return (
        Im06CoordinatorError.proofMismatch,
        'search proof does not match account, scope, or request',
      );
    }
    for (final hit in page.hits) {
      if (hit.messageId.trim().isEmpty || hit.scope != request.scope) {
        return (
          Im06CoordinatorError.proofMismatch,
          'search result does not belong to the requested conversation',
        );
      }
    }
    return null;
  }

  Im06HistoryCoverage _recordCoverage(
    Im06HistoryCoverage previous,
    Im06HistoryRequest request,
    Im06HistoryPage page,
  ) {
    final direction = switch (request.direction) {
      ImHistoryDirection.older => Im06HistoryCoverageDirection.older,
      ImHistoryDirection.newer => Im06HistoryCoverageDirection.newer,
      ImHistoryDirection.latest => Im06HistoryCoverageDirection.latest,
    };
    final closed = page.isCompleted &&
        (page.messages.isNotEmpty ||
            page.proof.level == ImHistoryProofLevel.serverContinuity);
    return previous.add(
      Im06CoverageRange(
        direction: direction,
        source: page.actualSource,
        proof: _coverageProof(request, page.proof),
        requestedCursor: request.cursor,
        returnedBounds: _coverageBounds(request, page.returnedBounds),
        closed: closed,
        requestGeneration: request.requestGeneration,
      ),
    );
  }

  HistoryProof _coverageProof(
    Im06HistoryRequest request,
    HistoryProof proof,
  ) {
    final isGroup = request.scope.conversationType == ImConversationType.group;
    return HistoryProof(
      scope: proof.scope,
      platform: proof.platform,
      accountGeneration: proof.accountGeneration,
      domainGeneration: proof.domainGeneration,
      requestGeneration: proof.requestGeneration,
      requestId: proof.requestId,
      direction: proof.direction,
      requestedSource: proof.requestedSource,
      actualSource: proof.actualSource,
      level: proof.level,
      returnedCount: proof.returnedCount,
      isFinished: proof.isFinished,
      boundaryMessageIds: proof.boundaryMessageIds,
      overlapMessageIds: proof.overlapMessageIds,
      cursor: proof.cursor,
      oldestSequence: isGroup ? proof.oldestSequence : null,
      newestSequence: isGroup ? proof.newestSequence : null,
      requestFingerprint: proof.requestFingerprint,
    );
  }

  Im06MessageBounds _coverageBounds(
    Im06HistoryRequest request,
    Im06MessageBounds bounds,
  ) {
    if (request.scope.conversationType == ImConversationType.group) {
      return bounds;
    }
    return Im06MessageBounds(
      oldestMessageId: bounds.oldestMessageId,
      newestMessageId: bounds.newestMessageId,
    );
  }
}
