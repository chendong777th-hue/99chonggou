import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/durable_ingress_gateway.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_mailbox.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_recovery_worker.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/tencent_advanced_message_adapter.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/tencent_message_adapter.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/writer_lease.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

class _FakeMessagePort implements ImTencentMessagePort {
  String? cloudCustomData;
  HistoryMsgGetTypeEnum? historyType;
  bool throwOnSend = false;
  String syncMsgID = 'server-1';

  @override
  Future<V2TimValueCallback<V2TimMessage>> sendMessage({
    required String id,
    required String receiver,
    required String groupID,
    required MessagePriorityEnum priority,
    required bool onlineUserOnly,
    required bool isExcludedFromUnreadCount,
    required bool needReadReceipt,
    required OfflinePushInfo? offlinePushInfo,
    required String cloudCustomData,
    required String? localCustomData,
    required bool isExcludedFromContentModeration,
    required void Function(String syncMsgID) onSyncMsgID,
  }) async {
    this.cloudCustomData = cloudCustomData;
    if (throwOnSend) throw StateError('transport failed');
    onSyncMsgID(syncMsgID);
    return V2TimValueCallback<V2TimMessage>(
      code: 0,
      desc: 'ok',
    );
  }

  @override
  Future<ImSdkHistoryResponse?> getHistoryMessageListWithComplete({
    required HistoryMsgGetTypeEnum getType,
    required String? userID,
    required String? groupID,
    required int lastMsgSeq,
    required int count,
    required String? lastMsgID,
    required List<int>? messageTypeList,
    required List<int>? messageSeqList,
    required int? timeBegin,
    required int? timePeriod,
  }) async {
    historyType = getType;
    return ImSdkHistoryResponse(
      result: V2TimMessageListResult(
        isFinished: true,
        messageList: <V2TimMessage>[],
      ),
      actualSource:
          getType.index >= 3 ? ImHistorySource.local : ImHistorySource.cloud,
      proofLevel: ImHistoryProofLevel.transportObserved,
    );
  }
}

class _FakeAdvancedMessageService implements MessageService {
  V2TimAdvancedMsgListener? listener;
  int addCalls = 0;
  int removeCalls = 0;
  int addFailuresRemaining = 0;

  @override
  Future<void> addAdvancedMsgListener({
    required V2TimAdvancedMsgListener listener,
  }) async {
    addCalls++;
    if (addFailuresRemaining > 0) {
      addFailuresRemaining--;
      throw StateError('listener registration failed');
    }
    this.listener = listener;
  }

  @override
  Future<void> removeAdvancedMsgListener({
    V2TimAdvancedMsgListener? listener,
  }) async {
    removeCalls++;
    if (listener == null || identical(this.listener, listener)) {
      this.listener = null;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingOnceImIngressStore implements ImIngressStore {
  _FailingOnceImIngressStore(this.delegate);

  final InMemoryImIngressStore delegate;
  int failuresRemaining = 1;

  @override
  Future<T> transaction<T>(
    Future<T> Function(ImIngressTransaction transaction) action,
  ) {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      return Future<T>.error(StateError('injected ingress failure'));
    }
    return delegate.transaction<T>(action);
  }
}

AccountScopedConversationKey _c2c({String owner = 'alice'}) {
  return AccountScopedConversationKey(
    ownerUserId: owner,
    conversationType: ImConversationType.c2c,
    conversationId: 'c2c_bob',
  );
}

void main() {
  group('AccountScopedConversationKey', () {
    test('canonicalizes account and conversation without mixing types', () {
      final c2c = AccountScopedConversationKey(
        ownerUserId: '@alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'c2c_bob',
      );
      final group = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.group,
        conversationId: 'group_g1',
      );

      expect(c2c.ownerUserId, 'alice');
      expect(c2c.canonicalConversationId, 'c2c_bob');
      expect(group.canonicalConversationId, 'group_g1');
      expect(c2c.storageKey, isNot(group.storageKey));
      expect(
        () => AccountScopedConversationKey(
          ownerUserId: 'alice',
          conversationType: ImConversationType.c2c,
          conversationId: 'group_bob',
        ),
        throwsArgumentError,
      );
      expect(
        () => AccountScopedConversationKey(
          ownerUserId: 'alice',
          conversationType: ImConversationType.group,
          conversationId: 'c2c_bob',
        ),
        throwsArgumentError,
      );
    });

    test('keeps the same raw conversation separate across accounts', () {
      expect(_c2c(owner: 'alice'), isNot(equals(_c2c(owner: 'charlie'))));
      expect(
          AccountScopedConversationKey.tryParse(
            ownerUserId: '',
            conversationType: ImConversationType.c2c,
            conversationId: 'bob',
          ),
          isNull);
    });
  });

  group('EventEnvelope', () {
    test('separates account/domain generations and namespace in inbox key', () {
      final event = EventEnvelope<String>(
        eventId: 'evt-1',
        eventNamespace: 'chat',
        kind: ImEventKind.realtimeMessage,
        scope: _c2c(),
        ownerUserId: 'alice',
        accountGeneration: 3,
        domainGeneration: 4,
        clearEpoch: 0,
        accountIngressSequence: 10,
        scopeIngressSequence: 2,
        source: ImEventSource.sdkListener,
        authority: ImEventAuthority.provider,
        observedAtMs: 100,
        providerSequence: 88,
        payload: 'message',
      );
      final callEvent = EventEnvelope<String>(
        eventId: 'evt-1',
        eventNamespace: 'call-signaling',
        kind: ImEventKind.notification,
        ownerUserId: 'alice',
        accountGeneration: 3,
        domainGeneration: 4,
        clearEpoch: 0,
        accountIngressSequence: 11,
        scopeIngressSequence: 0,
        source: ImEventSource.sdkListener,
        authority: ImEventAuthority.provider,
        observedAtMs: 100,
      );

      expect(event.inboxKey, isNot(callEvent.inboxKey));
      expect(
          event.belongsToAccount(ownerUserId: '@alice', accountGeneration: 3),
          isTrue);
      expect(
          event.belongsToDomain(
            ownerUserId: 'alice',
            accountGeneration: 3,
            domainGeneration: 4,
          ),
          isTrue);
      expect(
          event.belongsToDomain(
            ownerUserId: 'alice',
            accountGeneration: 2,
            domainGeneration: 4,
          ),
          isFalse);
      expect(
          event.belongsToDomain(
            ownerUserId: 'alice',
            accountGeneration: 3,
            domainGeneration: 5,
          ),
          isFalse);
    });

    test('rejects scope/account mismatch and invalid input sequence', () {
      expect(
        () => EventEnvelope<void>(
          eventId: 'evt',
          eventNamespace: 'chat',
          kind: ImEventKind.realtimeMessage,
          scope: _c2c(),
          ownerUserId: 'charlie',
          accountGeneration: 1,
          domainGeneration: 1,
          clearEpoch: 0,
          accountIngressSequence: 1,
          scopeIngressSequence: 1,
          source: ImEventSource.sdkListener,
          authority: ImEventAuthority.provider,
          observedAtMs: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventEnvelope<void>(
          eventId: 'evt',
          eventNamespace: 'chat',
          kind: ImEventKind.realtimeMessage,
          ownerUserId: 'alice',
          accountGeneration: 1,
          domainGeneration: 1,
          clearEpoch: 0,
          accountIngressSequence: 0,
          scopeIngressSequence: 0,
          source: ImEventSource.sdkListener,
          authority: ImEventAuthority.provider,
          observedAtMs: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('OutgoingIdentityContract', () {
    test('round-trips cloudCustomData while keeping local IDs local', () {
      final identity = OutgoingIdentityContract(
        scope: _c2c(),
        operationId: 'op-1',
        clientCorrelationId: '99chat:correlation-1',
        messageKind: OutgoingMessageKind.image,
        payloadFingerprint: 'sha256:image-1',
        createdAtMs: 123,
        sdkLocalId: 'sdk-local',
        serverMsgId: 'server-msg',
      );
      final raw = identity.encodeCloudCustomData();
      final decoded = OutgoingIdentityContract.fromCloudCustomData(
        raw,
        scope: _c2c(),
      );

      expect(decoded, isNotNull);
      expect(decoded!.operationId, 'op-1');
      expect(decoded.clientCorrelationId, '99chat:correlation-1');
      expect(decoded.messageKind, OutgoingMessageKind.image);
      expect(decoded.sdkLocalId, isNull);
      expect(decoded.serverMsgId, isNull);
      expect(raw, isNot(contains('sdk-local')));
      expect(raw, isNot(contains('server-msg')));
      final withBusiness = identity.encodeCloudCustomData(
        businessCloudCustomData: '{"messageFeature":{"version":1}}',
      );
      expect(withBusiness, contains('"business"'));
      expect(withBusiness, contains('messageFeature'));
      expect(
          decoded.matchesCandidate(
            candidateScope: _c2c(),
            candidateKind: OutgoingMessageKind.image,
            candidatePayloadFingerprint: 'sha256:image-1',
            candidateCorrelationId: '99chat:correlation-1',
          ),
          isTrue);
      expect(
          OutgoingIdentityContract.fromCloudCustomData(
            '{"schema":"unknown"}',
            scope: _c2c(),
          ),
          isNull);
    });
  });

  group('HistoryProof and SdkResult', () {
    test('does not allow Web to claim native local history', () {
      expect(
        () => HistoryProof(
          scope: _c2c(),
          platform: ImPlatform.web,
          accountGeneration: 1,
          domainGeneration: 1,
          requestGeneration: 1,
          requestId: 'history-1',
          direction: ImHistoryDirection.older,
          requestedSource: ImHistorySource.local,
          actualSource: ImHistorySource.local,
          level: ImHistoryProofLevel.transportObserved,
          returnedCount: 1,
          isFinished: true,
        ),
        throwsArgumentError,
      );
      final proof = HistoryProof(
        scope: _c2c(),
        platform: ImPlatform.web,
        accountGeneration: 1,
        domainGeneration: 1,
        requestGeneration: 1,
        requestId: 'history-1',
        direction: ImHistoryDirection.older,
        requestedSource: ImHistorySource.local,
        actualSource: ImHistorySource.cloud,
        level: ImHistoryProofLevel.transportObserved,
        returnedCount: 1,
        isFinished: true,
        overlapMessageIds: const <String>['m1', 'm1'],
      );
      expect(proof.closesCurrentDirection, isTrue);
      expect(proof.claimsCompleteHistory, isFalse);
      expect(proof.overlapMessageIds, <String>['m1']);
    });

    test('uses typed result states including OutcomeUnknown', () {
      final success = SdkResult<int>.success(data: 7, code: 0);
      final unknown = SdkResult<int>.outcomeUnknown(resultDesc: 'timeout');
      final failure = SdkResult<int>.failure(
        errorKind: SdkErrorKind.permissionDenied,
        code: -1,
      );

      expect(success.isSuccess, isTrue);
      expect(success.data, 7);
      expect(unknown.isOutcomeUnknown, isTrue);
      expect(failure.isFailure, isTrue);
      expect(failure.errorKind, SdkErrorKind.permissionDenied);
    });
  });

  group('SdkCapabilityRegistry', () {
    test('records documented support and official Web limitations separately',
        () {
      final registry = SdkCapabilityRegistry.officialTencentHighestPackage();

      expect(
        registry.stateFor('message.send.text', ImPlatform.android),
        SdkCapabilityState.sdkDocSupported,
      );
      expect(
        registry.stateFor('history.local', ImPlatform.web),
        SdkCapabilityState.platformUnavailable,
      );
      expect(
        registry.stateFor('search.local', ImPlatform.web),
        SdkCapabilityState.platformUnavailable,
      );
      expect(
        registry.stateFor('history.groupLastMsgSeq', ImPlatform.web),
        SdkCapabilityState.platformUnavailable,
      );
      expect(
        () => registry.stateFor('does.not.exist', ImPlatform.android),
        throwsStateError,
      );

      final integrated = registry.update(
        'message.send.text',
        ImPlatform.android,
        state: SdkCapabilityState.codeIntegrated,
      );
      final verified = integrated.update(
        'message.send.text',
        ImPlatform.android,
        state: SdkCapabilityState.runtimeVerified,
        evidenceRef: 'proof://test',
      );
      expect(
        verified.stateFor('message.send.text', ImPlatform.android),
        SdkCapabilityState.runtimeVerified,
      );
      expect(
        () => verified.update(
          'history.local',
          ImPlatform.web,
          state: SdkCapabilityState.codeIntegrated,
        ),
        throwsStateError,
      );
    });
  });

  test('enforces event-specific generations at the boundary', () {
    expect(
      () => EventEnvelope<void>(
        eventId: 'history-event',
        eventNamespace: 'chat',
        kind: ImEventKind.historyPage,
        scope: _c2c(),
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        clearEpoch: 0,
        accountIngressSequence: 1,
        scopeIngressSequence: 1,
        source: ImEventSource.sdkHistory,
        authority: ImEventAuthority.provider,
        observedAtMs: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => EventEnvelope<void>(
        eventId: 'ui-event',
        eventNamespace: 'chat',
        kind: ImEventKind.uiProjection,
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        clearEpoch: 0,
        accountIngressSequence: 1,
        scopeIngressSequence: 0,
        source: ImEventSource.localStore,
        authority: ImEventAuthority.localProjection,
        observedAtMs: 1,
      ),
      throwsArgumentError,
    );
  });

  group('TencentMessageAdapter', () {
    test('injects one cloudCustomData envelope and emits sync identity event',
        () async {
      final port = _FakeMessagePort();
      final events = <EventEnvelope<OutgoingIdentityContract>>[];
      var accountSequence = 0;
      final adapter = TencentMessageAdapter(
        port: port,
        platform: ImPlatform.android,
        ownerUserId: '@alice',
        accountGeneration: 2,
        domainGeneration: 3,
        nextAccountIngressSequence: () => ++accountSequence,
        nextScopeIngressSequence: (_) => 1,
        onSyncIdentity: events.add,
      );
      final identity = OutgoingIdentityContract(
        scope: _c2c(),
        operationId: 'op-send-1',
        clientCorrelationId: 'correlation-1',
        messageKind: OutgoingMessageKind.text,
        payloadFingerprint: 'sha256:text-1',
        createdAtMs: 1,
      );

      final result = await adapter.send(
        identity: identity,
        sdkLocalId: 'sdk-local-1',
        receiver: 'bob',
        groupID: '',
        sendOperationGeneration: 4,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.identity.serverMsgId, isNull);
      expect(port.cloudCustomData, identity.encodeCloudCustomData());
      expect(events, hasLength(1));
      expect(events.single.kind, ImEventKind.outgoingAdoption);
      expect(events.single.ownerUserId, 'alice');
      expect(events.single.scope, identity.scope);
      expect(events.single.sendOperationGeneration, 4);
      expect(events.single.payload!.serverMsgId, 'server-1');
    });

    test('rejects an address that does not match the scoped identity',
        () async {
      final port = _FakeMessagePort();
      final adapter = TencentMessageAdapter(
        port: port,
        platform: ImPlatform.android,
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        nextAccountIngressSequence: () => 1,
        nextScopeIngressSequence: (_) => 1,
      );
      final result = await adapter.send(
        identity: OutgoingIdentityContract(
          scope: _c2c(),
          operationId: 'op-send-2',
          clientCorrelationId: 'correlation-2',
          messageKind: OutgoingMessageKind.text,
          payloadFingerprint: 'sha256:text-2',
          createdAtMs: 1,
        ),
        sdkLocalId: 'sdk-local-2',
        receiver: 'charlie',
        groupID: '',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorKind, SdkErrorKind.invalidArgument);
      expect(port.cloudCustomData, isNull);
    });

    test('uses OutcomeUnknown for an exception after send may have started',
        () async {
      final port = _FakeMessagePort()..throwOnSend = true;
      final adapter = TencentMessageAdapter(
        port: port,
        platform: ImPlatform.android,
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        nextAccountIngressSequence: () => 1,
        nextScopeIngressSequence: (_) => 1,
      );
      final result = await adapter.send(
        identity: OutgoingIdentityContract(
          scope: _c2c(),
          operationId: 'op-send-3',
          clientCorrelationId: 'correlation-3',
          messageKind: OutgoingMessageKind.text,
          payloadFingerprint: 'sha256:text-3',
          createdAtMs: 1,
        ),
        sdkLocalId: 'sdk-local-3',
        receiver: 'bob',
        groupID: '',
      );

      expect(result.isOutcomeUnknown, isTrue);
    });

    test('maps Web local requests to a cloud SDK request and records proof',
        () async {
      final port = _FakeMessagePort();
      final adapter = TencentMessageAdapter(
        port: port,
        platform: ImPlatform.web,
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        nextAccountIngressSequence: () => 1,
        nextScopeIngressSequence: (_) => 1,
      );
      final result = await adapter.readHistory(
        scope: _c2c(),
        direction: ImHistoryDirection.older,
        requestedSource: ImHistorySource.local,
        requestGeneration: 2,
        requestId: 'history-web-1',
        count: 20,
      );

      expect(result.isSuccess, isTrue);
      expect(
        port.historyType,
        HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
      );
      expect(result.data!.proof.actualSource, ImHistorySource.cloud);
      expect(result.data!.proof.platform, ImPlatform.web);
      expect(result.data!.proof.isFinished, isTrue);
      expect(result.data!.proof.claimsCompleteHistory, isFalse);
    });
  });

  group('DurableIngressGateway', () {
    ImIngressDraft<String> draft({
      required String eventId,
      String owner = 'alice',
      AccountScopedConversationKey? scope,
      String? payloadHash,
    }) {
      return ImIngressDraft<String>(
        eventId: eventId,
        eventNamespace: 'chat',
        kind: ImEventKind.realtimeMessage,
        scope: scope ?? _c2c(owner: owner),
        ownerUserId: owner,
        accountGeneration: 1,
        domainGeneration: 1,
        clearEpoch: 0,
        source: ImEventSource.sdkListener,
        authority: ImEventAuthority.provider,
        observedAtMs: 100,
        payloadHash: payloadHash ?? 'msg:$eventId',
        recoveryMode: ImRecoveryMode.sdkOverlapReplay,
        recoveryRef: 'msgID:$eventId',
        payload: eventId,
      );
    }

    test('allocates both sequences atomically and reuses them for duplicates',
        () async {
      final store = InMemoryImIngressStore();
      final gateway = DurableIngressGateway(store: store);

      final first = await gateway.append(draft(eventId: 'm1'));
      final duplicate = await gateway.append(draft(eventId: 'm1'));
      final second = await gateway.append(draft(eventId: 'm2'));

      expect(first.wasDuplicate, isFalse);
      expect(duplicate.wasDuplicate, isTrue);
      expect(second.wasDuplicate, isFalse);
      expect(first.event.accountIngressSequence, 1);
      expect(duplicate.event.accountIngressSequence, 1);
      expect(second.event.accountIngressSequence, 2);
      expect(first.event.scopeIngressSequence, 1);
      expect(second.event.scopeIngressSequence, 2);
      expect(store.inbox, hasLength(2));
      expect(store.counters['alice|'], 2);
      expect(store.counters['alice|c2c_bob'], 2);
    });

    test('rejects reuse of an event identity with a different payload hash',
        () async {
      final gateway = DurableIngressGateway(
        store: InMemoryImIngressStore(),
      );
      await gateway.append(draft(eventId: 'm-conflict'));

      expect(
        () => gateway.append(
          draft(eventId: 'm-conflict', payloadHash: 'different'),
        ),
        throwsA(isA<ImIngressConflictException>()),
      );
    });

    test('keeps account and scope identities separate', () async {
      final store = InMemoryImIngressStore();
      final gateway = DurableIngressGateway(store: store);

      final alice = await gateway.append(draft(eventId: 'm1'));
      final charlie = await gateway.append(
        draft(eventId: 'm1', owner: 'charlie'),
      );

      expect(alice.event.inboxKey, isNot(charlie.event.inboxKey));
      expect(alice.event.accountIngressSequence, 1);
      expect(charlie.event.accountIngressSequence, 1);
      expect(store.inbox, hasLength(2));
    });

    test('round-trips idempotency through the production SQLite store',
        () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final owner =
          'im_contract_sqlite_${DateTime.now().microsecondsSinceEpoch}';
      final localStore = ConversationLocalStore.instance;
      final gateway = DurableIngressGateway(
        store: ConversationLocalImIngressStore(owner: localStore),
      );

      try {
        final first = await gateway.append(
          draft(eventId: 'sqlite-m1', owner: owner),
        );
        await localStore.closeDatabaseForTest();
        final afterReopen = await gateway.append(
          draft(eventId: 'sqlite-m1', owner: owner),
        );

        expect(first.wasDuplicate, isFalse);
        expect(afterReopen.wasDuplicate, isTrue);
        expect(afterReopen.event.accountIngressSequence, 1);
        expect(afterReopen.event.scopeIngressSequence, 1);
      } finally {
        await localStore.closeDatabaseForTest();
        final dbPath = p.join(
          await getDatabasesPath(),
          'conversation_local_v1.db',
        );
        final db = await openDatabase(dbPath, singleInstance: false);
        final batch = db.batch();
        batch.delete(
          'message_event_inbox',
          where: 'owner_user_id = ?',
          whereArgs: <Object?>[owner],
        );
        batch.delete(
          'message_writer_lease',
          where: 'owner_user_id = ?',
          whereArgs: <Object?>[owner],
        );
        batch.delete(
          'message_ingress_counter',
          where: 'owner_user_id = ?',
          whereArgs: <Object?>[owner],
        );
        await batch.commit(noResult: true);
        await db.close();
      }
    });

    test('advances inbox only with the current writer fencing token', () async {
      final store = InMemoryImIngressStore();
      final gateway = DurableIngressGateway(store: store);
      final leases = ImWriterLeaseService(store: store);
      final appended = await gateway.append(draft(eventId: 'status-m1'));
      final firstLease = await leases.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'core-a',
        nowMs: 0,
        ttlMs: 10,
      );
      final claimed = await gateway.claimForWriter(
        event: appended.event,
        lease: firstLease!,
        nowMs: 1,
      );
      expect(claimed!.status, ImInboxStatus.processing);
      expect(
        await gateway.advanceForWriter(
          event: appended.event,
          expectedStatus: ImInboxStatus.processing,
          nextStatus: ImInboxStatus.metadataCommitted,
          lease: firstLease,
          nowMs: 2,
          committedAtMs: 2,
        ),
        isTrue,
      );

      final takeover = await leases.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'core-b',
        nowMs: 10,
        ttlMs: 10,
      );
      expect(takeover!.fencingToken, greaterThan(firstLease.fencingToken));
      expect(
        await gateway.advanceForWriter(
          event: appended.event,
          expectedStatus: ImInboxStatus.metadataCommitted,
          nextStatus: ImInboxStatus.projectionPublished,
          lease: firstLease,
          nowMs: 10,
        ),
        isFalse,
      );
      expect(
        await gateway.advanceForWriter(
          event: appended.event,
          expectedStatus: ImInboxStatus.metadataCommitted,
          nextStatus: ImInboxStatus.projectionPublished,
          lease: takeover,
          nowMs: 10,
        ),
        isTrue,
      );
    });

    test('recovery candidates include only unfinished or stale rows', () async {
      final store = InMemoryImIngressStore();
      final gateway = DurableIngressGateway(store: store);
      final leases = ImWriterLeaseService(store: store);

      Future<EventEnvelope<String>> append(String id) async {
        final result = await gateway.append(
          ImIngressDraft<String>(
            eventId: id,
            eventNamespace: 'chat',
            kind: ImEventKind.realtimeMessage,
            scope: _c2c(),
            ownerUserId: 'alice',
            accountGeneration: 1,
            domainGeneration: 1,
            clearEpoch: 0,
            source: ImEventSource.sdkListener,
            authority: ImEventAuthority.provider,
            observedAtMs: 1,
            payloadHash: id,
            recoveryMode: ImRecoveryMode.sdkOverlapReplay,
            recoveryRef: 'msgID:$id',
            payload: id,
          ),
        );
        return result.event;
      }

      await append('prepared');
      final metadata = await append('metadata');
      final projection = await append('projection');
      final completed = await append('completed');
      final stale = await append('stale');
      final fresh = await append('fresh');
      final lease = await leases.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'recovery-test',
        nowMs: 0,
        ttlMs: 10000,
      );
      expect(lease, isNotNull);
      final writerLease = lease!;

      Future<void> claim(EventEnvelope<String> event, int now) async {
        expect(
          await gateway.claimForWriter(
            event: event,
            lease: writerLease,
            nowMs: now,
          ),
          isNotNull,
        );
      }

      await claim(metadata, 100);
      await gateway.advanceForWriter(
        event: metadata,
        expectedStatus: ImInboxStatus.processing,
        nextStatus: ImInboxStatus.metadataCommitted,
        lease: writerLease,
        nowMs: 100,
      );
      await claim(projection, 100);
      await gateway.advanceForWriter(
        event: projection,
        expectedStatus: ImInboxStatus.processing,
        nextStatus: ImInboxStatus.metadataCommitted,
        lease: writerLease,
        nowMs: 100,
      );
      await gateway.advanceForWriter(
        event: projection,
        expectedStatus: ImInboxStatus.metadataCommitted,
        nextStatus: ImInboxStatus.projectionPublished,
        lease: writerLease,
        nowMs: 100,
      );
      await claim(completed, 100);
      await gateway.advanceForWriter(
        event: completed,
        expectedStatus: ImInboxStatus.processing,
        nextStatus: ImInboxStatus.metadataCommitted,
        lease: writerLease,
        nowMs: 100,
      );
      await gateway.advanceForWriter(
        event: completed,
        expectedStatus: ImInboxStatus.metadataCommitted,
        nextStatus: ImInboxStatus.projectionPublished,
        lease: writerLease,
        nowMs: 100,
      );
      await gateway.advanceForWriter(
        event: completed,
        expectedStatus: ImInboxStatus.projectionPublished,
        nextStatus: ImInboxStatus.completed,
        lease: writerLease,
        nowMs: 100,
      );
      await claim(stale, 100);
      await claim(fresh, 900);

      final candidates = await gateway.listForRecovery(
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        nowMs: 1000,
        processingTimeoutMs: 300,
        limit: 20,
      );
      expect(
        candidates.map((record) => record.event.eventId),
        <String>['prepared', 'metadata', 'projection', 'stale'],
      );
      expect(
        candidates.any((record) => record.event.eventId == 'fresh'),
        isFalse,
      );
    });

    test('claims stale processing but does not claim a live processing row',
        () async {
      final store = InMemoryImIngressStore();
      final gateway = DurableIngressGateway(store: store);
      final leases = ImWriterLeaseService(store: store);
      final result = await gateway.append(
        ImIngressDraft<String>(
          eventId: 'stale-claim',
          eventNamespace: 'chat',
          kind: ImEventKind.realtimeMessage,
          scope: _c2c(),
          ownerUserId: 'alice',
          accountGeneration: 1,
          domainGeneration: 1,
          clearEpoch: 0,
          source: ImEventSource.sdkListener,
          authority: ImEventAuthority.provider,
          observedAtMs: 1,
          payloadHash: 'stale-claim',
          recoveryMode: ImRecoveryMode.sdkOverlapReplay,
          recoveryRef: 'msgID:stale-claim',
          payload: 'payload',
        ),
      );
      final lease = await leases.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'recovery-test',
        nowMs: 0,
        ttlMs: 10000,
      );
      final writerLease = lease!;
      await gateway.claimForWriter(
        event: result.event,
        lease: writerLease,
        nowMs: 100,
      );
      expect(
        await gateway.claimForWriter(
          event: result.event,
          lease: writerLease,
          nowMs: 150,
          allowStaleProcessing: true,
          processingTimeoutMs: 100,
        ),
        isNull,
      );
      final takeover = await gateway.claimForWriter(
        event: result.event,
        lease: writerLease,
        nowMs: 250,
        allowStaleProcessing: true,
        processingTimeoutMs: 100,
      );
      expect(takeover?.status, ImInboxStatus.processing);
      expect(takeover?.processingStartedAtMs, 250);
    });
  });

  group('ImRecoveryWorker', () {
    test(
        'loads formal messages, marks ephemeral rows, and defers unknown commands',
        () async {
      final store = InMemoryImIngressStore();
      final gateway = DurableIngressGateway(store: store);
      final leases = ImWriterLeaseService(store: store);
      final lease = await leases.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'recovery-worker-test',
        nowMs: 0,
        ttlMs: 10000,
      );
      final formal = await gateway.append(
        ImIngressDraft<String>(
          eventId: 'formal-recovery',
          eventNamespace: 'chat',
          kind: ImEventKind.realtimeMessage,
          scope: _c2c(),
          ownerUserId: 'alice',
          accountGeneration: 1,
          domainGeneration: 1,
          clearEpoch: 0,
          source: ImEventSource.sdkListener,
          authority: ImEventAuthority.provider,
          observedAtMs: 1,
          payloadHash: 'formal',
          recoveryMode: ImRecoveryMode.sdkOverlapReplay,
          recoveryRef: 'msgID:formal-recovery',
          payload: 'lost-process-payload',
        ),
      );
      await gateway.append(
        ImIngressDraft<String>(
          eventId: 'ephemeral-recovery',
          eventNamespace: 'chat',
          kind: ImEventKind.notification,
          ownerUserId: 'alice',
          accountGeneration: 1,
          domainGeneration: 1,
          clearEpoch: 0,
          source: ImEventSource.sdkListener,
          authority: ImEventAuthority.provider,
          observedAtMs: 1,
          payloadHash: 'ephemeral',
          recoveryMode: ImRecoveryMode.ephemeralUi,
          recoveryRef: 'send-progress:local-1',
          payload: 'not-durable',
        ),
      );
      await gateway.append(
        ImIngressDraft<String>(
          eventId: 'unknown-command',
          eventNamespace: 'chat',
          kind: ImEventKind.notification,
          ownerUserId: 'alice',
          accountGeneration: 1,
          domainGeneration: 1,
          clearEpoch: 0,
          source: ImEventSource.sdkListener,
          authority: ImEventAuthority.provider,
          observedAtMs: 1,
          payloadHash: 'command',
          recoveryMode: ImRecoveryMode.commandArguments,
          recoveryRef: 'message-extension:formal-recovery',
          payload: 'not-durable',
        ),
      );

      final payloads = <Object?>[];
      final router = ImMailboxRouter(
        handler: (event) async => payloads.add(event.payload),
      );
      var loaderCalls = 0;
      final worker = ImRecoveryWorker(
        gateway: gateway,
        router: router,
        lease: lease!,
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        loadPayload: (record) async {
          loaderCalls++;
          if (record.recoveryRef == 'msgID:formal-recovery') {
            return const ImRecoveryPayload.recovered('formal-restored');
          }
          return const ImRecoveryPayload.unavailable();
        },
      );

      final result = await worker.run(nowMs: 100, limit: 20);
      expect(result.scanned, 3);
      expect(result.dispatched, 2);
      expect(result.deferred, 1);
      expect(loaderCalls, 2);
      expect(payloads, <Object?>[
        'formal-restored',
        isA<ImRecoveredEphemeralUiEvent>(),
      ]);
      expect(formal.event.eventId, 'formal-recovery');
    });
  });

  group('TencentAdvancedMessageAdapter', () {
    test('registers once, persists before dispatch, and unregisters', () async {
      final service = _FakeAdvancedMessageService();
      final store = InMemoryImIngressStore();
      final delivered = Completer<EventEnvelope<dynamic>>();
      final adapter = TencentAdvancedMessageAdapter(
        messageService: service,
        ingress: DurableIngressGateway(store: store),
        ownerUserId: 'alice',
        accountGeneration: 2,
        domainGeneration: 3,
        onEvent: (event) {
          if (!delivered.isCompleted) delivered.complete(event);
        },
      );

      await Future.wait<void>(<Future<void>>[
        adapter.register(),
        adapter.register(),
      ]);
      expect(service.addCalls, 1);
      expect(service.listener, isNotNull);

      final message = V2TimMessage.fromJson(<String, Object?>{
        'message_msg_id': 'listener-msg-1',
        'message_sender': 'bob',
        'message_conv_type': ConversationType.V2TIM_C2C,
        'message_conv_id': 'bob',
        'message_risk_type_identified': 0,
        'message_elem_array': <Object?>[],
      });
      service.listener!.onRecvNewMessage(message);
      final event = await delivered.future.timeout(const Duration(seconds: 2));

      expect(event.eventId, 'received:listener-msg-1');
      expect(event.scope, _c2c());
      expect(event.payload, same(message));
      expect(store.inbox, hasLength(1));
      expect(
        imInboxRecordToStorageMap(store.inbox.values.single),
        isNot(contains('payload')),
      );

      await adapter.unregister();
      expect(service.removeCalls, 1);
      expect(service.listener, isNull);
      expect(adapter.isRegistered, isFalse);
    });

    test('listener ingress failure is reported and retried, not swallowed',
        () async {
      final service = _FakeAdvancedMessageService();
      final memory = InMemoryImIngressStore();
      final store = _FailingOnceImIngressStore(memory);
      final delivered = Completer<EventEnvelope<dynamic>>();
      var reported = 0;
      final adapter = TencentAdvancedMessageAdapter(
        messageService: service,
        ingress: DurableIngressGateway(store: store),
        ownerUserId: 'alice',
        accountGeneration: 2,
        domainGeneration: 3,
        onEvent: (event) {
          if (!delivered.isCompleted) delivered.complete(event);
        },
        onIngestFailure: (
          draft,
          error,
          stackTrace, {
          required int attempt,
          required bool dropped,
        }) {
          reported++;
          expect(draft.eventId, 'received:listener-retry-1');
          expect(dropped, isFalse);
        },
      );
      await adapter.register();
      final message = V2TimMessage.fromJson(<String, Object?>{
        'message_msg_id': 'listener-retry-1',
        'message_sender': 'bob',
        'message_conv_type': ConversationType.V2TIM_C2C,
        'message_conv_id': 'bob',
        'message_risk_type_identified': 0,
        'message_elem_array': <Object?>[],
      });

      service.listener!.onRecvNewMessage(message);
      await delivered.future.timeout(const Duration(seconds: 2));

      expect(reported, 1);
      expect(adapter.ingestFailureCount, 1);
      expect(adapter.ingestDroppedCount, 0);
      expect(adapter.pendingFailedIngressCount, 0);
      expect(memory.inbox, hasLength(1));
      await adapter.unregister();
    });

    test('can retry registration after the SDK rejects the first listener',
        () async {
      final service = _FakeAdvancedMessageService()..addFailuresRemaining = 1;
      final adapter = TencentAdvancedMessageAdapter(
        messageService: service,
        ingress: DurableIngressGateway(store: InMemoryImIngressStore()),
        ownerUserId: 'alice',
        accountGeneration: 1,
        domainGeneration: 1,
        onEvent: (_) {},
      );

      await expectLater(adapter.register(), throwsStateError);
      expect(adapter.isRegistered, isFalse);
      expect(service.listener, isNull);

      await adapter.register();
      expect(adapter.isRegistered, isTrue);
      expect(service.addCalls, 2);
      expect(service.listener, isNotNull);
    });

    test('coalesces plain and detailed revoke callbacks by message identity',
        () async {
      final service = _FakeAdvancedMessageService();
      final store = InMemoryImIngressStore();
      final delivered = <EventEnvelope<dynamic>>[];
      final deliveredTwice = Completer<void>();
      final adapter = TencentAdvancedMessageAdapter(
        messageService: service,
        ingress: DurableIngressGateway(store: store),
        ownerUserId: 'alice',
        accountGeneration: 2,
        domainGeneration: 3,
        onEvent: (event) {
          delivered.add(event);
          if (delivered.length == 2 && !deliveredTwice.isCompleted) {
            deliveredTwice.complete();
          }
        },
      );

      await adapter.register();
      service.listener!.onRecvMessageRevoked('revoke-1');
      service.listener!.onRecvMessageRevokedWithInfo(
        'revoke-1',
        V2TimUserFullInfo(userID: 'admin'),
        'admin revoke',
      );
      await deliveredTwice.future.timeout(const Duration(seconds: 2));

      expect(delivered.map((event) => event.eventId).toSet(),
          <String>{'revoked:revoke-1'});
      expect(store.inbox, hasLength(1));
    });
  });

  group('ImMailboxRouter', () {
    EventEnvelope<String> event(String id, AccountScopedConversationKey scope) {
      return EventEnvelope<String>(
        eventId: id,
        eventNamespace: 'chat',
        kind: ImEventKind.realtimeMessage,
        scope: scope,
        ownerUserId: scope.ownerUserId,
        accountGeneration: 1,
        domainGeneration: 1,
        clearEpoch: 0,
        accountIngressSequence: int.parse(id.substring(1)),
        scopeIngressSequence: int.parse(id.substring(1)),
        source: ImEventSource.sdkListener,
        authority: ImEventAuthority.provider,
        observedAtMs: 1,
        payload: id,
      );
    }

    test('serializes one scope while allowing another scope to proceed',
        () async {
      final order = <String>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final router = ImMailboxRouter(
        handler: (incoming) async {
          order.add(incoming.eventId);
          if (incoming.eventId == 'e1') {
            firstStarted.complete();
            await releaseFirst.future;
          }
        },
      );
      final scope = _c2c();
      final otherScope = AccountScopedConversationKey(
        ownerUserId: 'alice',
        conversationType: ImConversationType.c2c,
        conversationId: 'c2c_carol',
      );

      final first = router.dispatch(event('e1', scope));
      await firstStarted.future;
      final sameScope = router.dispatch(event('e2', scope));
      final other = router.dispatch(event('e3', otherScope));
      await other;
      expect(order, contains('e3'));
      expect(order, isNot(contains('e2')));
      releaseFirst.complete();
      await Future.wait<void>(<Future<void>>[first, sameScope]);
      expect(order, <String>['e1', 'e3', 'e2']);
    });
  });

  group('ImWriterLeaseService', () {
    test('fences an expired owner and rejects its old token', () async {
      final store = InMemoryImIngressStore();
      final service = ImWriterLeaseService(store: store);
      final first = await service.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'core-a',
        nowMs: 0,
        ttlMs: 10,
      );
      final blocked = await service.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'core-b',
        nowMs: 5,
        ttlMs: 10,
      );
      final takeover = await service.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'core-b',
        nowMs: 10,
        ttlMs: 10,
      );

      expect(first, isNotNull);
      expect(blocked, isNull);
      expect(takeover, isNotNull);
      expect(takeover!.fencingToken, 2);
      expect(await service.isCurrent(lease: first!, nowMs: 10), isFalse);
      expect(await service.isCurrent(lease: takeover, nowMs: 10), isTrue);
      expect(await service.release(first), isFalse);

      expect(await service.release(takeover), isTrue);
      final afterRelease = await service.acquire(
        ownerUserId: 'alice',
        leaseOwnerId: 'core-c',
        nowMs: 11,
        ttlMs: 10,
      );
      expect(afterRelease!.fencingToken, 3);
    });
  });
}
