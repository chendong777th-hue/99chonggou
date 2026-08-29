import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_history_coverage_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_batch.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class _DelayedCoverageRepository implements MessageHistoryCoverageRepository {
  final Completer<MessageHistoryCoverage?> loadCompleter =
      Completer<MessageHistoryCoverage?>();
  final List<MessageHistoryCoverage> saved = <MessageHistoryCoverage>[];

  @override
  Future<MessageHistoryCoverage?> load(String conversationID) {
    return loadCompleter.future;
  }

  @override
  Future<void> save(MessageHistoryCoverage coverage) async {
    saved.add(coverage);
  }

  @override
  Future<void> clearConversation(
    String conversationID, {
    required bool isGroup,
    required int clearEpoch,
  }) async {}

  @override
  Future<void> clearSession() async {}
}

V2TimMessage _coverageMessage(String msgID, int timestamp) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp,
    'message_msg_id': msgID,
    'message_seq': '1',
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = msgID;
  message.timestamp = timestamp;
  message.userID = 'coverage_peer';
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupServiceLocator();
  });

  group('MessageHistoryCoverage', () {
    test('round-trips group holes without message payloads', () {
      final coverage = MessageHistoryCoverage(
        conversationKey: 'group_g1',
        isGroup: true,
        clearEpoch: 12,
        coverageRevision: 4,
        status: MessageHistoryCoverageStatus.partial,
        verifiedOldestMsgID: 'm100',
        verifiedNewestMsgID: 'm150',
        verifiedOldestSeq: 100,
        verifiedNewestSeq: 150,
        olderExhausted: false,
        newerHasMore: true,
        holes: const <MessageHistoryHole>[
          MessageHistoryHole(
            key: 'seq:121-123',
            kind: MessageHistoryHoleKind.groupSeq,
            status: MessageHistoryHoleStatus.open,
            startSeq: 121,
            endSeq: 123,
            generation: 7,
          ),
        ],
        cloudVerifiedAtMs: 1000,
        updatedAtMs: 1001,
        lastRequestGeneration: 8,
        lastRequestedSource: 'cloud',
        lastActualSource: 'cloud',
        lastBatchKind: 'latestWindow',
        lastCursorDirection: 'latest',
        lastCursorMsgID: 'm150',
        lastReturnedOldestMsgID: 'm140',
        lastReturnedNewestMsgID: 'm150',
        lastReturnedOldestSeq: 140,
        lastReturnedNewestSeq: 150,
        lastCloudResponseProven: true,
      );

      final decoded = MessageHistoryCoverage.fromJson(coverage.toJson());

      expect(decoded.conversationKey, 'group_g1');
      expect(decoded.verifiedOldestSeq, 100);
      expect(decoded.verifiedNewestSeq, 150);
      expect(decoded.holes.single.startSeq, 121);
      expect(decoded.holes.single.endSeq, 123);
      expect(decoded.hasOpenHoles, isTrue);
      expect(decoded.lastRequestGeneration, 8);
      expect(decoded.lastRequestedSource, 'cloud');
      expect(decoded.lastBatchKind, 'latestWindow');
      expect(decoded.lastCursorMsgID, 'm150');
      expect(decoded.lastReturnedOldestSeq, 140);
      expect(decoded.lastProofKind, MessageHistoryProofKind.transportObserved);
      expect(decoded.lastCloudResponseProven, isTrue);
      expect(decoded.toJson().containsKey('messages'), isFalse);
    });

    test('round-trips durable ranges, page chain and continuation cursor', () {
      const coverage = MessageHistoryCoverage(
        conversationKey: 'c2c_chain',
        isGroup: false,
        clearEpoch: 4,
        coverageRevision: 9,
        status: MessageHistoryCoverageStatus.partial,
        olderExhausted: false,
        newerHasMore: false,
        holes: <MessageHistoryHole>[],
        ranges: <MessageHistoryCoverageRange>[
          MessageHistoryCoverageRange(
            key: 'page:older:m1:m9',
            direction: MessageHistoryCoverageDirection.older,
            oldestMsgID: 'm1',
            newestMsgID: 'm9',
            proofKind: MessageHistoryProofKind.transportObserved,
          ),
        ],
        pages: <MessageHistoryPageRecord>[
          MessageHistoryPageRecord(
            key: 'p:9:older:m9:',
            direction: MessageHistoryCoverageDirection.older,
            cursorMsgID: 'm9',
            returnedOldestMsgID: 'm1',
            returnedNewestMsgID: 'm9',
            hasMore: true,
            proofKind: MessageHistoryProofKind.transportObserved,
          ),
        ],
        continuationPending: true,
        continuationDirection: MessageHistoryCoverageDirection.older,
        continuationCursorMsgID: 'm1',
        lastBatchKind: 'cloud_catch_up_stalled',
        lastCursorDirection: 'newer',
        lastCursorMsgID: 'm9',
      );

      final decoded = MessageHistoryCoverage.fromJson(coverage.toJson());

      expect(decoded.ranges.single.oldestMsgID, 'm1');
      expect(decoded.pages.single.cursorMsgID, 'm9');
      expect(decoded.pages.single.hasMore, isTrue);
      expect(decoded.continuationPending, isTrue);
      expect(
          decoded.continuationDirection, MessageHistoryCoverageDirection.older);
      expect(decoded.continuationCursorMsgID, 'm1');
      expect(decoded.lastBatchKind, 'cloud_catch_up_stalled');
      expect(decoded.lastCursorDirection, 'newer');
      expect(decoded.lastCursorMsgID, 'm9');
      expect(decoded.cloudContinuationStalled, isFalse,
          reason: 'this fixture continues an older page, not C2C newer');

      final stalled = decoded.copyWith(
        continuationPending: true,
        continuationDirection: MessageHistoryCoverageDirection.newer,
        continuationCursorMsgID: 'm9',
        lastBatchKind: 'cloud_catch_up_stalled',
      );
      expect(stalled.cloudContinuationStalled, isTrue);
    });
  });

  group('MessageReconciliationCoordinator coverage phase', () {
    test('local snapshot is visible but remains provisional', () {
      final coordinator = MessageReconciliationCoordinator();
      final request = coordinator.beginInitialHistory(
        conversationID: 'c2c_alice',
        requestedSource: MessageReconciliationSource.local,
        networkState: MessageReconciliationNetworkState.online,
      );

      expect(
        coordinator.completeRequest(
          request: request,
          actualSource: MessageReconciliationSource.local,
          networkState: MessageReconciliationNetworkState.online,
          resultCount: 3,
          batchKind: MessageHistoryBatchKind.localSnapshot,
        ),
        isTrue,
      );

      final state = coordinator.stateFor('c2c_alice');
      expect(state.phase, MessageReconciliationPhase.localVisibleProvisional);
      expect(state.isComplete, isFalse);
      expect(state.needsCloudRetry, isTrue);
    });
  });

  group('TUIChatGlobalModel coverage ordering', () {
    test('uppercase C2C batch commits across typed and bare storage aliases',
        () {
      final model = serviceLocator<TUIChatGlobalModel>();
      model.clearData();
      const bareConversationID = 'userabc';
      const typedConversationID = 'c2c_UserABC';
      model.setCurrentConversation(
        CurrentConversation(bareConversationID, ConvType.c2c),
        notify: false,
      );

      final request = model.beginHistoryReconciliation(
        conversationID: typedConversationID,
        requestedSource: MessageReconciliationSource.local,
        networkState: MessageReconciliationNetworkState.online,
      );
      expect(request.conversationKey, bareConversationID);

      final batch = MessageHistoryBatch<V2TimMessage>(
        conversationKey: typedConversationID,
        requestedSource: MessageReconciliationSource.local,
        actualSource: MessageReconciliationSource.local,
        batchKind: MessageHistoryBatchKind.localSnapshot,
        requestGeneration: request.generation,
        clearEpoch: 0,
        isFinished: true,
        hasMoreOlder: false,
        cloudHasMoreNewer: false,
        messages: <V2TimMessage>[_coverageMessage('alias-message', 10)],
      );

      final commit = model.completeHistoryBatch(
        request: request,
        batch: batch,
        networkState: MessageReconciliationNetworkState.online,
        clearEpoch: 0,
      );

      expect(commit, isNotNull);
      expect(model.rawMessageCount(bareConversationID), 1);
      expect(model.rawMessageCount(typedConversationID), 1);
      model.clearData();
    });

    test('typed group batch cannot commit into a C2C request', () {
      final model = serviceLocator<TUIChatGlobalModel>();
      model.clearData();
      const bareConversationID = 'userabc';
      model.setCurrentConversation(
        CurrentConversation(bareConversationID, ConvType.c2c),
        notify: false,
      );
      final request = model.beginHistoryReconciliation(
        conversationID: 'c2c_$bareConversationID',
        requestedSource: MessageReconciliationSource.local,
        networkState: MessageReconciliationNetworkState.online,
      );
      final batch = MessageHistoryBatch<V2TimMessage>(
        conversationKey: 'group_UserABC',
        requestedSource: MessageReconciliationSource.local,
        actualSource: MessageReconciliationSource.local,
        batchKind: MessageHistoryBatchKind.localSnapshot,
        requestGeneration: request.generation,
        clearEpoch: 0,
        isFinished: true,
        hasMoreOlder: false,
        cloudHasMoreNewer: false,
        messages: <V2TimMessage>[_coverageMessage('wrong-conversation', 10)],
      );

      expect(
        model.completeHistoryBatch(
          request: request,
          batch: batch,
          networkState: MessageReconciliationNetworkState.online,
          clearEpoch: 0,
        ),
        isNull,
      );
      expect(model.rawMessageCount(bareConversationID), 0);
      model.clearData();
    });

    test('typed cloud batch without proof remains incomplete', () {
      final model = serviceLocator<TUIChatGlobalModel>();
      model.clearData();
      const conversationID = 'c2c_batch_provenance';
      final request = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      );
      final batch = MessageHistoryBatch<V2TimMessage>(
        conversationKey: conversationID,
        requestedSource: MessageReconciliationSource.cloud,
        actualSource: MessageReconciliationSource.cloud,
        batchKind: MessageHistoryBatchKind.latestWindow,
        requestGeneration: request.generation,
        clearEpoch: 0,
        isFinished: true,
        hasMoreOlder: false,
        cloudHasMoreNewer: false,
        cloudResponseProven: false,
        messages: <V2TimMessage>[_coverageMessage('batch-local', 10)],
      );

      final commit = model.completeHistoryBatch(
        request: request,
        batch: batch,
        networkState: MessageReconciliationNetworkState.online,
        clearEpoch: 0,
      );

      expect(commit, isNotNull);
      expect(
        model.messageReconciliationStateFor(conversationID).phase,
        MessageReconciliationPhase.cloudWindowPartial,
      );
      final metadata = model.messageHistoryCommitMetadataFor(conversationID);
      expect(metadata, isNotNull);
      expect(metadata!.source, MessageReconciliationSource.cloud);
      expect(metadata.batchKind, MessageHistoryBatchKind.latestWindow);
      expect(metadata.generation, request.generation);
      expect(metadata.cloudProof, isFalse);
      expect(metadata.resultCount, 1);
      model.clearData();
    });

    test('local provisional commit is applied before immediate cloud verify',
        () async {
      final model = serviceLocator<TUIChatGlobalModel>();
      model.clearData();
      final repository = _DelayedCoverageRepository();
      model.appMessageHistoryCoverageRepository = repository;
      const conversationID = 'c2c_coverage_peer';
      final message = _coverageMessage('server-1', 100);

      final localRequest = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.local,
        networkState: MessageReconciliationNetworkState.online,
      );
      expect(
        model.completeHistoryReconciliation(
          request: localRequest,
          history: <V2TimMessage>[message],
          actualSource: MessageReconciliationSource.local,
          networkState: MessageReconciliationNetworkState.online,
          batchKind: MessageHistoryBatchKind.localSnapshot,
        ),
        isNotNull,
      );

      final cloudRequest = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      );
      expect(
        model.completeHistoryReconciliation(
          request: cloudRequest,
          history: <V2TimMessage>[message],
          actualSource: MessageReconciliationSource.cloud,
          networkState: MessageReconciliationNetworkState.online,
          batchKind: MessageHistoryBatchKind.latestWindow,
          historyIsFinished: true,
          proofKind: MessageHistoryProofKind.serverContinuity,
        ),
        isNotNull,
      );

      repository.loadCompleter.complete(null);
      await model.waitForMessageHistoryCoverageUpdates(conversationID);
      final coverage = model.messageHistoryCoverageFor(conversationID);

      expect(coverage, isNotNull);
      expect(coverage!.coverageRevision, 2);
      expect(coverage.status, MessageHistoryCoverageStatus.verified);
      expect(coverage.localNewestMsgID, 'server-1');
      expect(coverage.verifiedNewestMsgID, 'server-1');
      model.clearData();
    });

    test('C2C boundary closes only when an older page reaches local msgID',
        () async {
      final model = serviceLocator<TUIChatGlobalModel>();
      model.clearData();
      final repository = _DelayedCoverageRepository();
      repository.loadCompleter.complete(null);
      model.appMessageHistoryCoverageRepository = repository;
      const conversationID = 'c2c_coverage_boundary';
      await model.ensureMessageHistoryCoverageLoaded(conversationID);
      final localMessage = _coverageMessage('local-server-id', 300)
        ..userID = 'coverage_boundary';
      final cloudMessage = _coverageMessage('cloud-server-id', 200)
        ..userID = 'coverage_boundary';

      final localRequest = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.local,
        networkState: MessageReconciliationNetworkState.online,
      );
      model.completeHistoryReconciliation(
        request: localRequest,
        history: <V2TimMessage>[localMessage],
        actualSource: MessageReconciliationSource.local,
        networkState: MessageReconciliationNetworkState.online,
        batchKind: MessageHistoryBatchKind.localSnapshot,
      );

      final latestRequest = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      );
      model.completeHistoryReconciliation(
        request: latestRequest,
        history: <V2TimMessage>[cloudMessage],
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
        batchKind: MessageHistoryBatchKind.latestWindow,
        historyIsFinished: false,
      );

      final partial = model.messageHistoryCoverageFor(conversationID);
      expect(partial, isNotNull);
      expect(partial!.holes, hasLength(1));
      expect(partial.holes.single.kind, MessageHistoryHoleKind.c2cBoundary);
      expect(partial.holes.single.olderMsgID, 'local-server-id');

      final unrelatedOlderRequest = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      );
      model.completeHistoryReconciliation(
        request: unrelatedOlderRequest,
        history: <V2TimMessage>[cloudMessage],
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
        batchKind: MessageHistoryBatchKind.olderPage,
        historyIsFinished: false,
      );
      expect(
        model.messageHistoryCoverageFor(conversationID)!.holes,
        hasLength(1),
      );

      final olderRequest = model.beginHistoryReconciliation(
        conversationID: conversationID,
        requestedSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
      );
      model.completeHistoryReconciliation(
        request: olderRequest,
        history: <V2TimMessage>[localMessage],
        actualSource: MessageReconciliationSource.cloud,
        networkState: MessageReconciliationNetworkState.online,
        batchKind: MessageHistoryBatchKind.olderPage,
        historyIsFinished: false,
      );

      final connected = model.messageHistoryCoverageFor(conversationID);
      expect(connected, isNotNull);
      expect(connected!.holes, isEmpty);
      model.clearData();
    });
  });

  group('MessageHistoryCoverageStore', () {
    late Directory tempDir;
    final store = MessageHistoryCoverageStore.instance;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('history_coverage_');
      store.debugOwnerUserId = 'owner_a';
      store.debugDatabasePath = p.join(tempDir.path, 'coverage.db');
      await store.clearSession();
    });

    tearDown(() async {
      await store.clearSession();
      store.debugOwnerUserId = null;
      store.debugDatabasePath = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('persists coverage and holes across memory reset', () async {
      final coverage = MessageHistoryCoverage(
        conversationKey: 'group_@TGS#room',
        isGroup: true,
        clearEpoch: 20,
        coverageRevision: 2,
        status: MessageHistoryCoverageStatus.partial,
        verifiedOldestSeq: 100,
        verifiedNewestSeq: 103,
        olderExhausted: false,
        newerHasMore: false,
        holes: const <MessageHistoryHole>[
          MessageHistoryHole(
            key: 'seq:101-102',
            kind: MessageHistoryHoleKind.groupSeq,
            status: MessageHistoryHoleStatus.open,
            startSeq: 101,
            endSeq: 102,
          ),
        ],
        updatedAtMs: 30,
        lastRequestGeneration: 4,
        lastRequestedSource: 'cloud',
        lastActualSource: 'cloud',
        lastBatchKind: 'gapFill',
        lastCursorDirection: 'older',
        lastCursorSeq: 100,
        lastReturnedOldestSeq: 101,
        lastReturnedNewestSeq: 103,
        lastCloudResponseProven: true,
      );

      await store.save(coverage);
      await store.clearSession();
      final loaded = await store.load('group_@TGS#room');

      expect(loaded, isNotNull);
      expect(loaded!.clearEpoch, 20);
      expect(loaded.coverageRevision, 2);
      expect(loaded.holes.single.key, 'seq:101-102');
      expect(loaded.lastRequestGeneration, 4);
      expect(loaded.lastBatchKind, 'gapFill');
      expect(loaded.lastCursorSeq, 100);
      expect(loaded.lastReturnedNewestSeq, 103);
      expect(loaded.lastCloudResponseProven, isTrue);
    });

    test('newer clear epoch rejects stale reconciliation save', () async {
      await store.clearConversation(
        'c2c_alice',
        isGroup: false,
        clearEpoch: 100,
      );
      await store.save(
        const MessageHistoryCoverage(
          conversationKey: 'c2c_alice',
          isGroup: false,
          clearEpoch: 99,
          coverageRevision: 50,
          status: MessageHistoryCoverageStatus.verified,
          olderExhausted: true,
          newerHasMore: false,
          holes: <MessageHistoryHole>[],
          updatedAtMs: 101,
        ),
      );
      await store.clearSession();

      final loaded = await store.load('c2c_alice');
      expect(loaded, isNotNull);
      expect(loaded!.clearEpoch, 100);
      expect(loaded.status, MessageHistoryCoverageStatus.empty);
      expect(loaded.coverageRevision, 0);
    });
  });
}
