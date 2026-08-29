import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_batch.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';

void main() {
  test('local snapshot records provisional local provenance and bounds', () {
    final batch = MessageHistoryBatch<String>(
      conversationKey: 'c2c:alice',
      requestedSource: MessageReconciliationSource.local,
      actualSource: MessageReconciliationSource.local,
      batchKind: MessageHistoryBatchKind.localSnapshot,
      requestGeneration: 4,
      clearEpoch: 11,
      requestedCursor: const MessageHistoryCursor(
        direction: MessageHistoryCursorDirection.older,
        lastMsgID: 'm200',
      ),
      returnedBounds: const MessageHistoryBounds(
        oldestMsgID: 'm190',
        newestMsgID: 'm200',
      ),
      isFinished: true,
      hasMoreOlder: false,
      cloudHasMoreNewer: false,
      cloudResponseProven: false,
      messages: const <String>['m190', 'm200'],
    );

    expect(batch.generation, 4);
    expect(batch.requestGeneration, 4);
    expect(batch.actualSource, MessageReconciliationSource.local);
    expect(batch.cloudResponseProven, isFalse);
    expect(batch.returnedOldest, 'm190');
    expect(batch.returnedNewestMsgID, 'm200');
    expect(batch.messages, <String>['m190', 'm200']);
    expect(batch.toMetadataJson()['messageCount'], 2);
  });

  test('cloud response can be proven even when it is empty', () {
    final batch = MessageHistoryBatch<String>(
      conversationKey: 'group:g1',
      requestedSource: MessageReconciliationSource.cloud,
      actualSource: MessageReconciliationSource.cloud,
      batchKind: MessageHistoryBatchKind.latestWindow,
      requestGeneration: 8,
      clearEpoch: 2,
      requestedCursor: const MessageHistoryCursor(
        direction: MessageHistoryCursorDirection.latest,
      ),
      isFinished: true,
      hasMoreOlder: true,
      cloudHasMoreNewer: false,
      cloudResponseProven: true,
      explicitDeletes: const <String>{'deleted-1'},
      tombstones: const <String>{'revoked-1'},
    );

    expect(batch.messages, isEmpty);
    expect(batch.cloudResponseProven, isTrue);
    expect(batch.explicitDeletes, contains('deleted-1'));
    expect(batch.tombstones, contains('revoked-1'));
    expect(batch.returnedBounds.isEmpty, isTrue);
  });

  test('cloud request that falls back locally is distinguishable', () {
    final batch = MessageHistoryBatch<String>(
      conversationKey: 'c2c:offline',
      requestedSource: MessageReconciliationSource.cloud,
      actualSource: MessageReconciliationSource.local,
      batchKind: MessageHistoryBatchKind.latestWindow,
      requestGeneration: 9,
      clearEpoch: 3,
      isFinished: false,
      hasMoreOlder: true,
      cloudHasMoreNewer: true,
      cloudResponseProven: false,
      messages: const <String>['cached'],
    );

    expect(batch.requestedSource, MessageReconciliationSource.cloud);
    expect(batch.actualSource, MessageReconciliationSource.local);
    expect(batch.cloudResponseProven, isFalse);
    expect(batch.isFinished, isFalse);
    expect(batch.hasMoreOlder, isTrue);
    expect(batch.cloudHasMoreNewer, isTrue);
  });

  test('generation and clear epoch reject stale batches', () {
    final batch = MessageHistoryBatch<String>(
      conversationKey: 'c2c:alice',
      requestedSource: MessageReconciliationSource.cloud,
      actualSource: MessageReconciliationSource.cloud,
      batchKind: MessageHistoryBatchKind.newerCatchUp,
      requestGeneration: 10,
      clearEpoch: 20,
      isFinished: false,
      hasMoreOlder: false,
      cloudHasMoreNewer: true,
      cloudResponseProven: true,
    );

    expect(batch.matches(generation: 10, clearEpoch: 20), isTrue);
    expect(batch.isStale(generation: 9, clearEpoch: 20), isTrue);
    expect(batch.isStale(generation: 10, clearEpoch: 19), isTrue);
    expect(batch.isStale(generation: 9, clearEpoch: 19), isTrue);
  });

  test('cursor captures group Seq and direction explicitly', () {
    const cursor = MessageHistoryCursor(
      direction: MessageHistoryCursorDirection.newer,
      lastMsgSeq: 42,
    );

    expect(cursor.lastMsgID, isNull);
    expect(cursor.lastMsgSeq, 42);
    expect(cursor.direction, MessageHistoryCursorDirection.newer);
    expect(cursor.toJson()['direction'], 'newer');
  });
}
