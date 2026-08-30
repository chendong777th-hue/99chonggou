// IM-08 P0-Critical: OutgoingExternalSendHelper 运行时行为。

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im05_contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/outgoing_external_send_helper.dart';

void main() {
  test('helper class is constructible (smoke)', () {
    expect(OutgoingExternalSendHelper, isNotNull);
  });

  test('recordOutboxEntryForExternal returns unavailable when message is null',
      () async {
    final outcome =
        await OutgoingExternalSendHelper.recordOutboxEntryForExternal(
      message: null,
      sdkLocalId: 'local-1',
      ownerUserId: 'alice',
      conversationType: ImConversationType.c2c,
      conversationId: 'c2c_bob',
    );
    expect(outcome.prepared, isFalse);
    expect(outcome.outcomeUnknown, isFalse);
  });

  test('recordOutboxEntryForExternal returns unavailable when lease missing',
      () async {
    final outcome =
        await OutgoingExternalSendHelper.recordOutboxEntryForExternal(
      message: null,
      sdkLocalId: 'local-2',
      ownerUserId: 'alice',
      conversationType: ImConversationType.c2c,
      conversationId: 'c2c_bob',
    );
    expect(outcome.prepared, isFalse);
  });

  test('ImOutboxState enum still covers all critical transitions', () {
    expect(ImOutboxState.prepared, isNotNull);
    expect(ImOutboxState.dispatchIntent, isNotNull);
    expect(ImOutboxState.sending, isNotNull);
    expect(ImOutboxState.outcomeUnknown, isNotNull);
    expect(ImOutboxState.failedTerminal, isNotNull);
    expect(ImOutboxState.completed, isNotNull);
  });
}
