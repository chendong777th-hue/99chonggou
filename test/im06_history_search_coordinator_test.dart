import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/history_search_coordinator.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_param.dart'
    if (dart.library.html)
        'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result.dart'
    if (dart.library.html)
        'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html)
        'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

class _FakeAdapter implements Im06HistorySearchAdapter {
  Im06HistoryPage? historyPage;
  Im06SearchPage? searchPage;
  Object? historyError;
  Object? searchError;
  Im06HistoryRequest? lastHistoryRequest;
  Im06SearchRequest? lastSearchRequest;

  @override
  Future<SdkResult<Im06HistoryPage>> readHistory(
    Im06HistoryRequest request,
  ) async {
    lastHistoryRequest = request;
    final error = historyError;
    if (error != null) throw error;
    return SdkResult<Im06HistoryPage>.success(data: historyPage);
  }

  @override
  Future<SdkResult<Im06SearchPage>> search(Im06SearchRequest request) async {
    lastSearchRequest = request;
    final error = searchError;
    if (error != null) throw error;
    return SdkResult<Im06SearchPage>.success(data: searchPage);
  }
}

class _FakeMessageSearchAdapter implements Im06MessageSearchAdapter {
  bool localCalled = false;
  bool cloudCalled = false;

  @override
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchLocal(
    V2TimMessageSearchParam searchParam,
  ) async {
    localCalled = true;
    return V2TimValueCallback<V2TimMessageSearchResult>(
      code: 0,
      desc: 'local',
      data: V2TimMessageSearchResult(totalCount: 0),
    );
  }

  @override
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchCloud(
    V2TimMessageSearchParam searchParam,
  ) async {
    cloudCalled = true;
    return V2TimValueCallback<V2TimMessageSearchResult>(
      code: 0,
      desc: 'cloud',
      data: V2TimMessageSearchResult(totalCount: 0),
    );
  }
}

class _FakeCoverageStore implements Im06HistoryCoverageStore {
  Im06HistoryCoverage? loaded;
  Im06HistoryCoverage? saved;
  AccountScopedConversationKey? loadedScope;

  @override
  Future<Im06HistoryCoverage?> load(AccountScopedConversationKey scope) async {
    loadedScope = scope;
    return loaded;
  }

  @override
  Future<void> save(Im06HistoryCoverage coverage) async {
    saved = coverage;
  }
}

void main() {
  final scope = AccountScopedConversationKey(
    ownerUserId: 'owner-a',
    conversationType: ImConversationType.group,
    conversationId: 'room-a',
  );
  final c2cScope = AccountScopedConversationKey(
    ownerUserId: 'owner-a',
    conversationType: ImConversationType.c2c,
    conversationId: 'peer-a',
  );

  HistoryProof proof({
    required AccountScopedConversationKey proofScope,
    required ImPlatform platform,
    required ImHistorySource source,
    required String requestId,
    required int generation,
    required ImHistoryDirection direction,
    required int returnedCount,
    required bool isFinished,
    ImHistoryProofLevel level = ImHistoryProofLevel.transportObserved,
  }) {
    return HistoryProof(
      scope: proofScope,
      platform: platform,
      accountGeneration: 1,
      domainGeneration: 2,
      requestGeneration: generation,
      requestId: requestId,
      direction: direction,
      requestedSource: source,
      actualSource: source,
      level: level,
      returnedCount: returnedCount,
      isFinished: isFinished,
    );
  }

  test('routes Flutter local and cloud separately, and Web local is explicit',
      () {
    final adapter = _FakeAdapter();
    final coordinator = Im06HistorySearchCoordinator(adapter: adapter);

    expect(
      coordinator.historyRoute(
        platform: ImPlatform.android,
        requestedSource: ImHistorySource.local,
      ),
      Im06HistoryRoute.flutterLocal,
    );
    expect(
      coordinator.historyRoute(
        platform: ImPlatform.android,
        requestedSource: ImHistorySource.cloud,
      ),
      Im06HistoryRoute.flutterCloud,
    );
    expect(
      coordinator.historyRoute(
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.cloud,
      ),
      Im06HistoryRoute.webCloud,
    );
    expect(
      coordinator.historyRoute(
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.local,
      ),
      Im06HistoryRoute.webLocalHistoryUnsupported,
    );
    expect(
      coordinator.searchRoute(
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.local,
      ),
      Im06SearchRoute.webLocalSearchUnsupported,
    );
  });

  test('Web local history is rejected without calling the adapter', () async {
    final adapter = _FakeAdapter();
    final coordinator = Im06HistorySearchCoordinator(adapter: adapter);
    final result = await coordinator.readHistory(
      Im06HistoryRequest(
        scope: scope,
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.local,
        direction: ImHistoryDirection.latest,
        requestId: 'history-1',
        requestGeneration: 4,
        accountGeneration: 1,
        domainGeneration: 2,
        count: 20,
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.error, Im06CoordinatorError.platformUnavailable);
    expect(adapter.lastHistoryRequest, isNull);
  });

  test(
      'cloud isCompleted closes only the requested direction and stores bounds',
      () async {
    final adapter = _FakeAdapter();
    final coordinator = Im06HistorySearchCoordinator(adapter: adapter);
    adapter.historyPage = Im06HistoryPage(
      actualSource: ImHistorySource.cloud,
      proof: proof(
        proofScope: scope,
        platform: ImPlatform.android,
        source: ImHistorySource.cloud,
        requestId: 'history-2',
        generation: 5,
        direction: ImHistoryDirection.older,
        returnedCount: 2,
        isFinished: true,
      ),
      isCompleted: true,
      returnedBounds: const Im06MessageBounds(
        oldestMessageId: 'm-1',
        newestMessageId: 'm-2',
        oldestSequence: 40,
        newestSequence: 41,
      ),
      messages: const <Object?>['m-1', 'm-2'],
    );

    final result = await coordinator.readHistory(
      Im06HistoryRequest(
        scope: scope,
        platform: ImPlatform.android,
        requestedSource: ImHistorySource.cloud,
        direction: ImHistoryDirection.older,
        requestId: 'history-2',
        requestGeneration: 5,
        accountGeneration: 1,
        domainGeneration: 2,
        count: 2,
        cursor: const Im06HistoryCursor(messageId: 'm-3', sequence: 42),
      ),
    );

    expect(result.isSuccess, isTrue);
    final range = result.coverage.ranges.single;
    expect(range.closed, isTrue);
    expect(range.direction, Im06HistoryCoverageDirection.older);
    expect(range.returnedBounds.oldestMessageId, 'm-1');
    expect(range.returnedBounds.newestSequence, 41);
    expect(
        result.coverage.isClosed(Im06HistoryCoverageDirection.newer), isFalse);
  });

  test('C2C history never sends or records group Seq', () async {
    final adapter = _FakeAdapter();
    final coordinator = Im06HistorySearchCoordinator(adapter: adapter);
    adapter.historyPage = Im06HistoryPage(
      actualSource: ImHistorySource.cloud,
      proof: proof(
        proofScope: c2cScope,
        platform: ImPlatform.android,
        source: ImHistorySource.cloud,
        requestId: 'c2c-1',
        generation: 1,
        direction: ImHistoryDirection.older,
        returnedCount: 1,
        isFinished: false,
      ),
      isCompleted: false,
      returnedBounds: const Im06MessageBounds(
        oldestMessageId: 'c2c-old',
        newestMessageId: 'c2c-new',
      ),
      messages: const <Object?>['c2c-old'],
    );

    final result = await coordinator.readHistory(
      Im06HistoryRequest(
        scope: c2cScope,
        platform: ImPlatform.android,
        requestedSource: ImHistorySource.cloud,
        direction: ImHistoryDirection.older,
        requestId: 'c2c-1',
        requestGeneration: 1,
        accountGeneration: 1,
        domainGeneration: 2,
        count: 1,
        cursor: const Im06HistoryCursor(messageId: 'c2c-anchor'),
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(adapter.lastHistoryRequest!.providerLastMsgId, 'c2c-anchor');
    expect(adapter.lastHistoryRequest!.providerLastMsgSeq, isNull);
    expect(result.coverage.ranges.single.returnedBounds.oldestSequence, isNull);
  });

  test('search failure has no jump and never falls back to the latest message',
      () async {
    final adapter = _FakeAdapter()..searchError = StateError('cloud timeout');
    final coordinator = Im06HistorySearchCoordinator(adapter: adapter);
    final result = await coordinator.search(
      Im06SearchRequest(
        scope: scope,
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.cloud,
        requestId: 'search-1',
        requestGeneration: 1,
        accountGeneration: 1,
        domainGeneration: 2,
        keyword: 'needle',
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.error, Im06CoordinatorError.adapterFailure);
    expect(result.jump, isNull);
    expect(result.hits, isEmpty);
  });

  test('search result produces a proof-carrying jump only for a real hit',
      () async {
    final adapter = _FakeAdapter();
    adapter.searchPage = Im06SearchPage(
      actualSource: ImHistorySource.cloud,
      proof: Im06SearchProof(
        scope: scope,
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.cloud,
        actualSource: ImHistorySource.cloud,
        requestId: 'search-2',
        accountGeneration: 1,
        domainGeneration: 2,
        requestGeneration: 1,
        returnedCount: 1,
        isCompleted: true,
        cloudResponseProven: true,
      ),
      hits: <Im06SearchHit>[
        Im06SearchHit(scope: scope, messageId: 'target-message'),
      ],
    );

    final result = await _coordinatorFor(adapter).search(
      Im06SearchRequest(
        scope: scope,
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.cloud,
        requestId: 'search-2',
        requestGeneration: 1,
        accountGeneration: 1,
        domainGeneration: 2,
        keyword: 'needle',
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.jump!.targetMessageId, 'target-message');
    expect(result.jump!.proof.cloudResponseProven, isTrue);
  });

  test('jump success requires the formal row and completed layout proof', () {
    const incomplete = SearchJumpResolutionProof(
      formalMessagePresent: true,
      visibleRow: true,
      layoutComplete: false,
      stableRowKey: 'row-target',
    );
    expect(incomplete.canReportSuccess, isFalse);

    const complete = SearchJumpResolutionProof(
      formalMessagePresent: true,
      visibleRow: true,
      layoutComplete: true,
      stableRowKey: 'row-target',
    );
    expect(complete.canReportSuccess, isTrue);
  });

  test('message-search coordinator rejects Web local before adapter call', () async {
    final adapter = _FakeMessageSearchAdapter();
    final coordinator = Im06MessageSearchCoordinator(adapter: adapter);
    final result = await coordinator.search(
      platform: ImPlatform.web,
      requestedSource: ImHistorySource.local,
       searchParam: V2TimMessageSearchParam(
         type: 0,
         keywordList: const ['needle'],
       ),
    );

    expect(result.error, Im06CoordinatorError.platformUnavailable);
    expect(result.result, isNull);
    expect(adapter.localCalled, isFalse);
    expect(adapter.cloudCalled, isFalse);
  });

  test('message-search coordinator delegates Flutter source unchanged', () async {
    final adapter = _FakeMessageSearchAdapter();
    final coordinator = Im06MessageSearchCoordinator(adapter: adapter);
    final result = await coordinator.search(
      platform: ImPlatform.android,
      requestedSource: ImHistorySource.local,
       searchParam: V2TimMessageSearchParam(
         type: 0,
         keywordList: const ['needle'],
       ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.requestedSource, ImHistorySource.local);
    expect(adapter.localCalled, isTrue);
    expect(adapter.cloudCalled, isFalse);
  });

  test('history coordinator loads and saves Coverage through its port', () async {
    final adapter = _FakeAdapter();
    final coverageStore = _FakeCoverageStore();
    final persisted = Im06HistoryCoverage(scope: scope, clearEpoch: 7);
    coverageStore.loaded = persisted;
    final coordinator = Im06HistorySearchCoordinator(
      adapter: adapter,
      coverageStore: coverageStore,
    );

    final result = await coordinator.readHistory(
      Im06HistoryRequest(
        scope: scope,
        platform: ImPlatform.web,
        requestedSource: ImHistorySource.local,
        direction: ImHistoryDirection.latest,
        requestId: 'coverage-web-local',
        requestGeneration: 1,
        accountGeneration: 1,
        domainGeneration: 2,
        clearEpoch: 7,
        count: 1,
      ),
    );

    expect(result.error, Im06CoordinatorError.platformUnavailable);
    expect(coverageStore.loadedScope, scope);
    expect(coverageStore.saved, isNull);
  });
}

Im06HistorySearchCoordinator _coordinatorFor(_FakeAdapter adapter) =>
    Im06HistorySearchCoordinator(adapter: adapter);
