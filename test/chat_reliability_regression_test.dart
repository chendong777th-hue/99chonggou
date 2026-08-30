import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('silent group tips never schedule repeated full unread clears', () {
    final source = File(
      'lib/src/services/group_conversation_unread_helper.dart',
    ).readAsStringSync();
    expect(source, contains('scheduleAbsorbOnce'));
    expect(source, contains('_absorbedEffectIds'));
    expect(source, isNot(contains('scheduleClearRepeatedly')));
    expect(source, isNot(contains('Duration(milliseconds: 1500)')));
    expect(source, isNot(contains('Duration(milliseconds: 3000)')));
  });

  test('notification tip absorption carries a stable effect id', () {
    final source = File(
      'lib/src/services/notification_settings_service.dart',
    ).readAsStringSync();
    expect(source, contains('effectId: msgKey'));
  });

  test('login state can never manufacture realtime socket readiness', () {
    final source = File(
      'lib/src/services/im_connect_status_service.dart',
    ).readAsStringSync();
    final staleMethod = source.substring(
      source.indexOf('reconcileStaleConnectingAfterColdStart'),
      source.indexOf('static Future<bool> isImLoggedIn'),
    );
    expect(staleMethod, isNot(contains('_sdkSocketConnected = true')));
    expect(staleMethod, contains('ConnectStatus.connecting'));
  });

  test('read receipt flag changes only after SDK acknowledgement', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _setMsgReadReceipt(');
    final end = source.indexOf('sendMessageReadReceipts(', start);
    final collectPhase = source.substring(start, end);
    expect(collectPhase, isNot(contains('item.needReadReceipt = false')));
    expect(source, contains('if (result?.code == 0)'));
    expect(source, contains('_readReceiptMap.putIfAbsent'));
  });

  test('Prepared recovery reuses the persisted payload identity', () {
    final coordinator = File(
      'lib/src/services/im/outgoing_send_coordinator.dart',
    ).readAsStringSync();
    final recovery = File(
      'lib/src/services/im/outgoing_outbox_recovery_service.dart',
    ).readAsStringSync();
    expect(coordinator, contains('recoverPreparedOutbox'));
    expect(
      coordinator,
      contains('recoveredPrepared?.main?.payloadReference'),
    );
    expect(coordinator, contains('prepared Outbox payload fingerprint'));
    expect(recovery, contains('recoverPreparedOutbox: true'));
  });

  test('provider evidence is the only OutcomeUnknown success adoption path',
      () {
    final persistence = File(
      'lib/src/services/im/im05_persistence.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/src/services/im/outgoing_send_coordinator.dart',
    ).readAsStringSync();
    expect(persistence, contains('adoptOutboxProviderSucceeded'));
    expect(persistence, contains('main.clientCorrelationId !='));
    expect(persistence, contains('main.payloadHash != payloadHash'));
    expect(coordinator, contains('adoptProviderHistory'));
  });

  test('conversation listener registration has its own retry path', () {
    final source = File(
      'lib/src/services/conversation_local/conversation_sync_service.dart',
    ).readAsStringSync();
    expect(source, contains('_ensureConversationListenerAttached'));
    expect(source, contains('_scheduleConversationListenerRetry'));
    expect(source, contains('_conversationListenerAttached = true'));
    expect(
      source,
      contains('conversation listener attach failed'),
    );
  });

  test('durable read queues use bounded retry and dead-letter retention', () {
    for (final path in <String>[
      'lib/src/services/im/read_outbox_store.dart',
      'lib/src/services/im/read_receipt_outbox_store.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('maxRetryAttempts = 10'), reason: path);
      expect(source, contains('_deadLetterRetryAtMs'), reason: path);
    }
  });

  test('provider confirmation wins a late SDK failure or timeout race', () {
    final source = File(
      'lib/src/services/im/outgoing_send_coordinator.dart',
    ).readAsStringSync();
    expect(source, contains('_providerAlreadyConfirmed'));
    expect(source, contains('provider evidence confirmed delivery'));
    expect(
      source,
      contains('sdk.isOutcomeUnknown && !providerConfirmed'),
    );
  });
}
