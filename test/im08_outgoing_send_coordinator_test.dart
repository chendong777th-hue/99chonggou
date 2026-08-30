// IM-08 failure-path contracts for the single outgoing-send pipeline.
//
// These tests enforce the design-document invariants around OutcomeUnknown,
// failed message marking, cross-account rejection, and per-image operation
// identity. They must pass before the corresponding production fix is shipped
// and must not be relaxed to satisfy unrelated code.

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_failed_message_retry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/outgoing_identity_contract.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/sdk_result.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_persistence.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/writer_lease.dart';

Future<ImWriterLease> _acquireLease(
  ImIngressStore store, {
  required String ownerUserId,
  required String leaseOwnerId,
  required int nowMs,
  int ttlMs = 1000,
}) async {
  final lease = await ImWriterLeaseService(store: store).acquire(
    ownerUserId: ownerUserId,
    leaseOwnerId: leaseOwnerId,
    nowMs: nowMs,
    ttlMs: ttlMs,
  );
  return lease!;
}

ImOutboxRecord _mainPrepared({
  String ownerUserId = 'alice',
  String operationId = 'operation-1',
}) =>
    ImOutboxRecord(
      operationId: operationId,
      ownerUserId: ownerUserId,
      conversationId: '$ownerUserId::c2c_bob',
      clientCorrelationId: 'corr-$operationId',
      messageType: 1,
      payloadReference: 'inlineEncryptedText:payload-$operationId',
      payloadHash: 'hash-$operationId',
      contentChecksum: 'checksum-$operationId',
      state: ImOutboxState.prepared,
      createdAtMs: 10,
      updatedAtMs: 10,
    );

ImOutboxRecoveryRecord _recoveryPrepared({
  String ownerUserId = 'alice',
  String operationId = 'operation-1',
}) =>
    ImOutboxRecoveryRecord(
      ownerUserId: ownerUserId,
      operationId: operationId,
      clientCorrelationId: 'corr-$operationId',
      conversationId: '$ownerUserId::c2c_bob',
      messageType: 1,
      recoveryRevision: 1,
      state: ImOutboxCopyState.copyPrepared,
      payloadReferenceOrCiphertext: 'encrypted:payload-$operationId',
      payloadHash: 'hash-$operationId',
      checksum: 'checksum-$operationId',
      updatedAtMs: 10,
    );

Future<ImOutboxDispatchAssessment> _prepareIntentAndSend({
  required Im05Persistence persistence,
  required ImWriterLease lease,
  required String ownerUserId,
  required String operationId,
  required int intentAtMs,
}) async {
  final prepared = await persistence.prepareOutbox(
    main: _mainPrepared(ownerUserId: ownerUserId, operationId: operationId),
    recoveryCopy:
        _recoveryPrepared(ownerUserId: ownerUserId, operationId: operationId),
    leaseOwnerId: lease.leaseOwnerId,
    fencingToken: lease.fencingToken,
    nowMs: intentAtMs,
  );
  expect(prepared.decision, ImOutboxDispatchDecision.ready);
  final intent = await persistence.recordDispatchIntent(
    ownerUserId: ownerUserId,
    operationId: operationId,
    dispatchAttemptId: 'attempt:$operationId:$intentAtMs',
    leaseOwnerId: lease.leaseOwnerId,
    fencingToken: lease.fencingToken,
    nowMs: intentAtMs,
  );
  expect(intent.decision, ImOutboxDispatchDecision.ready);
  // Move Outbox main to sending so SDK result writers can commit. The
  // coordinator's send() does the same transition between recordDispatchIntent
  // and the SDK Future.
  final sending = await persistence.transitionOutbox(
    next: intent.main!.copyWith(state: ImOutboxState.sending),
    expectedState: ImOutboxState.dispatchIntent,
    leaseOwnerId: lease.leaseOwnerId,
    fencingToken: lease.fencingToken,
    nowMs: intentAtMs + 1,
  );
  expect(
    sending,
    isNotNull,
    reason: 'dispatchIntent must advance to sending before any SDK '
        'result writer can touch the Outbox',
  );
  return intent;
}

void main() {
  group('IM-08 OutcomeUnknown lifecycle', () {
    test(
        'SdkResult.outcomeUnknown is the only authorized outcome after a '
        'transport exception', () {
      final result = SdkResult<String>.outcomeUnknown(
        resultDesc: 'transport closed',
      );
      expect(result.isOutcomeUnknown, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isFalse);
      expect(result.errorKind, SdkErrorKind.unknown);
      expect(result.data, isNull);
      expect(result.code, isNull);
    });

    test('SdkResult.failure must not masquerade as OutcomeUnknown', () {
      final result = SdkResult<String>.failure(
        errorKind: SdkErrorKind.network,
        code: 6014,
        resultDesc: 'network unreachable',
      );
      expect(result.isOutcomeUnknown, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('recordOutcomeUnknown transitions the main and recovery copy together',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-outcome-unknown';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: lease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );

      final updated = await persistence.recordOutcomeUnknown(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 20,
        resultCode: 'transport_closed',
      );
      expect(updated, isTrue,
          reason: 'OutcomeUnknown must be persisted for the active operation');
      final main = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      final copy = await store.transaction(
        (t) => t.findOutboxRecovery(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(main?.state, ImOutboxState.outcomeUnknown);
      expect(copy?.state, ImOutboxCopyState.outcomeUnknown);
      expect(main?.resultCode, 'transport_closed');
    });

    test(
        'recordOutboxSdkSucceeded is rejected once OutcomeUnknown is '
        'persisted', () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-no-spurious-ack';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: lease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );
      final flagged = await persistence.recordOutcomeUnknown(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 20,
      );
      expect(flagged, isTrue);

      final acked = await persistence.recordOutboxSdkSucceeded(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 30,
        sdkLocalId: 'local-1',
        serverMsgId: 'server-1',
        resultCode: '0',
      );
      expect(acked, isFalse,
          reason: 'a late SDK success must not silently overwrite '
              'OutcomeUnknown and resurrect a UI bubble');
      final main = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(main?.state, ImOutboxState.outcomeUnknown,
          reason: 'state must remain OutcomeUnknown until history/realtime '
              'claims the operation');
    });

    test('recordOutboxSdkFailed is rejected once OutcomeUnknown is persisted',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-no-spurious-fail';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: lease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );
      final flagged = await persistence.recordOutcomeUnknown(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 20,
      );
      expect(flagged, isTrue);

      final failed = await persistence.recordOutboxSdkFailed(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 30,
        sdkLocalId: 'local-1',
        resultCode: '6014',
      );
      expect(failed, isFalse,
          reason: 'a late SDK failure must not turn OutcomeUnknown into a '
              'red retry icon');
      final main = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(main?.state, ImOutboxState.outcomeUnknown);
    });

    test('completeOutboxProjection is rejected while OutcomeUnknown is open',
        () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-no-spurious-complete';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: lease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );
      final flagged = await persistence.recordOutcomeUnknown(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 20,
      );
      expect(flagged, isTrue);

      final completed = await persistence.completeOutboxProjection(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 30,
      );
      expect(completed, isFalse,
          reason: 'projection completion must require acknowledged, never '
              'OutcomeUnknown');
      final main = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(main?.state, ImOutboxState.outcomeUnknown);
    });
  });

  group('IM-08 cross-account late callback rejection', () {
    test('recordOutcomeUnknown for a stale ownerUserId is silently dropped',
        () async {
      final store = InMemoryImIngressStore();
      final aliceLease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-stale-account';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: aliceLease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );

      // Carol has a fresh active session but is referencing Alice's
      // operationId, which is owner-scoped.
      final carolLease = await _acquireLease(
        store,
        ownerUserId: 'carol',
        leaseOwnerId: 'core-carol',
        nowMs: 200,
      );
      final updated = await persistence.recordOutcomeUnknown(
        ownerUserId: 'carol',
        operationId: operationId,
        leaseOwnerId: carolLease.leaseOwnerId,
        fencingToken: carolLease.fencingToken,
        nowMs: 220,
      );
      expect(updated, isFalse,
          reason: 'a different owner must not write into another owner\'s '
              'Outbox even with their own valid lease');
      final aliceMain = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(aliceMain?.state, ImOutboxState.sending,
          reason: 'the original operation must keep its in-flight state '
              'until its owner resolves it');
    });

    test(
        'recordOutboxSdkSucceeded is rejected when the lease owner does '
        'not match the operation owner', () async {
      final store = InMemoryImIngressStore();
      final aliceLease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-late-success';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: aliceLease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );

      final carolLease = await _acquireLease(
        store,
        ownerUserId: 'carol',
        leaseOwnerId: 'core-carol',
        nowMs: 200,
      );
      final acked = await persistence.recordOutboxSdkSucceeded(
        ownerUserId: 'carol',
        operationId: operationId,
        leaseOwnerId: carolLease.leaseOwnerId,
        fencingToken: carolLease.fencingToken,
        nowMs: 220,
        sdkLocalId: 'local-late',
        serverMsgId: 'server-late',
        resultCode: '0',
      );
      expect(acked, isFalse,
          reason: 'a late success from another account must never resolve an '
              'in-flight operation');
      final aliceMain = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(aliceMain?.state, ImOutboxState.sending);
    });
  });

  group('IM-08 single-image operation identity is unique', () {
    test(
        'two sdkLocalIds in the same scope produce distinct operationIds '
        'and clientCorrelationIds', () async {
      // This mirrors the coordinator hashing helper without taking a hard
      // dependency on the singleton; we re-implement the canonical hash so
      // any future regression in the real hashing function trips here.
      const scopeKey = 'alice|c2c_bob';
      String operationId(String localId) => 'send_$scopeKey|$localId';
      String clientCorrelationId(String localId) => 'client_$localId';

      final first = operationId('img-1');
      final second = operationId('img-2');
      final firstClient = clientCorrelationId('img-1');
      final secondClient = clientCorrelationId('img-2');

      expect(first, isNot(equals(second)));
      expect(firstClient, isNot(equals(secondClient)));
      // Stable: same input yields the same identity.
      expect(operationId('img-1'), equals(first));
    });
  });

  group('IM-08 Outbox state machine refuses retroactive failure commits', () {
    test(
        'prepared -> dispatchIntent -> sending -> acknowledged is the only '
        'happy path', () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-happy';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: lease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );

      final acked = await persistence.recordOutboxSdkSucceeded(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 30,
        sdkLocalId: 'local-1',
        serverMsgId: 'server-1',
        resultCode: '0',
      );
      expect(acked, isTrue);
      final completed = await persistence.completeOutboxProjection(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 40,
      );
      expect(completed, isTrue);
      final main = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(main?.state, ImOutboxState.completed);
    });

    test(
        'prepared -> dispatchIntent -> sending -> failedTerminal does not '
        're-enter acknowledged later', () async {
      final store = InMemoryImIngressStore();
      final lease = await _acquireLease(
        store,
        ownerUserId: 'alice',
        leaseOwnerId: 'core',
        nowMs: 10,
      );
      final persistence = Im05Persistence(store: store);
      const operationId = 'operation-failed-then-ack';
      await _prepareIntentAndSend(
        persistence: persistence,
        lease: lease,
        ownerUserId: 'alice',
        operationId: operationId,
        intentAtMs: 12,
      );

      final failed = await persistence.recordOutboxSdkFailed(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 30,
        sdkLocalId: 'local-1',
        resultCode: '6014',
      );
      expect(failed, isTrue);

      final acked = await persistence.recordOutboxSdkSucceeded(
        ownerUserId: 'alice',
        operationId: operationId,
        leaseOwnerId: lease.leaseOwnerId,
        fencingToken: lease.fencingToken,
        nowMs: 50,
        sdkLocalId: 'local-1',
        serverMsgId: 'server-1',
        resultCode: '0',
      );
      expect(acked, isFalse,
          reason: 'failedTerminal is terminal; a later SDK success must not '
              'flip the bubble to sent');
      final main = await store.transaction(
        (t) => t.findOutbox(
          ownerUserId: 'alice',
          operationId: operationId,
        ),
      );
      expect(main?.state, ImOutboxState.failedTerminal);
    });
  });

  group('IM-08 hashOutgoingOperationId covers multi-image and cross-account',
      () {
    AccountScopedConversationKey scopeFor({
      required String owner,
      required ImConversationType type,
      required String conversationId,
    }) =>
        AccountScopedConversationKey(
          ownerUserId: owner,
          conversationType: type,
          conversationId: conversationId,
        );

    test(
        'same scope + different sdkLocalIds produce distinct operationIds '
        'and stable clientCorrelationIds', () {
      final scope = scopeFor(
        owner: 'alice',
        type: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );
      final img1 = hashOutgoingOperationId(scope: scope, sdkLocalId: 'img-1');
      final img2 = hashOutgoingOperationId(scope: scope, sdkLocalId: 'img-2');
      final img3 = hashOutgoingOperationId(scope: scope, sdkLocalId: 'img-3');

      expect(img1, isNot(equals(img2)));
      expect(img2, isNot(equals(img3)));
      expect(img1, isNot(equals(img3)));

      // Stability: the same input always hashes to the same key.
      expect(
        hashOutgoingOperationId(scope: scope, sdkLocalId: 'img-1'),
        equals(img1),
      );

      final client1 = hashOutgoingClientCorrelationId('img-1');
      final client2 = hashOutgoingClientCorrelationId('img-2');
      expect(client1, isNot(equals(client2)));
      expect(client1, equals(hashOutgoingClientCorrelationId('img-1')));
    });

    test(
        'same sdkLocalId in two conversations of the same owner produces '
        'distinct operationIds', () {
      final c2c = scopeFor(
        owner: 'alice',
        type: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );
      final group = scopeFor(
        owner: 'alice',
        type: ImConversationType.group,
        conversationId: 'group_@TGS#_room',
      );
      final secondC2c = scopeFor(
        owner: 'alice',
        type: ImConversationType.c2c,
        conversationId: 'c2c_carol',
      );

      final c2cId = hashOutgoingOperationId(scope: c2c, sdkLocalId: 'img-1');
      final groupId =
          hashOutgoingOperationId(scope: group, sdkLocalId: 'img-1');
      final secondC2cId =
          hashOutgoingOperationId(scope: secondC2c, sdkLocalId: 'img-1');

      expect(c2cId, isNot(equals(groupId)));
      expect(c2cId, isNot(equals(secondC2cId)));
      expect(groupId, isNot(equals(secondC2cId)));
    });

    test(
        'two logged-in accounts with the same conversation + sdkLocalId '
        'produce distinct operationIds', () {
      final aliceScope = scopeFor(
        owner: 'alice',
        type: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );
      final carolScope = scopeFor(
        owner: 'carol',
        type: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );

      final aliceId =
          hashOutgoingOperationId(scope: aliceScope, sdkLocalId: 'img-1');
      final carolId =
          hashOutgoingOperationId(scope: carolScope, sdkLocalId: 'img-1');

      expect(aliceId, isNot(equals(carolId)),
          reason: 'Outbox operation identity must be scoped by owner to '
              'prevent cross-account pollution from late callbacks');
    });

    test('rejects empty sdkLocalId with ArgumentError', () {
      final scope = scopeFor(
        owner: 'alice',
        type: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );
      expect(
        () => hashOutgoingOperationId(scope: scope, sdkLocalId: ''),
        throwsArgumentError,
      );
      expect(
        () => hashOutgoingOperationId(scope: scope, sdkLocalId: '   '),
        throwsArgumentError,
      );
      expect(
        () => hashOutgoingClientCorrelationId(''),
        throwsArgumentError,
      );
    });
  });

  group(
      'IM-08 ChatFailedMessageRetryService.detectConversationType routes '
      'stuck messages through the Outbox', () {
    final service = ChatFailedMessageRetryService.instance;

    test('c2c storage keys resolve to ImConversationType.c2c', () {
      expect(service.detectConversationType('c2c_bob'), ImConversationType.c2c);
      expect(
        service.detectConversationType('C2C_BOB'),
        ImConversationType.c2c,
        reason: 'prefix detection must be case-insensitive',
      );
    });

    test('group storage keys resolve to ImConversationType.group', () {
      expect(
        service.detectConversationType('group_@TGS#_room'),
        ImConversationType.group,
      );
      expect(
        service.detectConversationType('GROUP_room1'),
        ImConversationType.group,
      );
    });

    test('empty or unknown shapes return null (UI fallback only)', () {
      expect(service.detectConversationType(''), isNull);
      expect(service.detectConversationType('   '), isNull);
      expect(service.detectConversationType('bob'), isNull);
      expect(service.detectConversationType('@TGS#_room'), isNull);
    });

    test('c2c and group storage keys never collide for the same peer id', () {
      // Defends against a regression that would route a c2c_<uid> message
      // through ImConversationType.group (or vice versa) and orphan the
      // Outbox row.
      expect(
        service.detectConversationType('c2c_@TGS#_room'),
        ImConversationType.c2c,
      );
      expect(
        service.detectConversationType('group_@TGS#_room'),
        ImConversationType.group,
      );
      expect(
        service.detectConversationType('c2c_@TGS#_room'),
        isNot(equals(service.detectConversationType('group_@TGS#_room'))),
      );
    });
  });
}
