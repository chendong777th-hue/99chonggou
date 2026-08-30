import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';

void main() {
  const senderPath = 'lib/src/services/chat_external_message_sender.dart';
  const coordinatorPath = 'lib/src/services/im/outgoing_send_coordinator.dart';
  const globalModelPath =
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart';

  test('external result prevents automatic retry after outcome unknown', () {
    const result = ExternalMessageSendResult(
      state: ExternalMessageSendState.outcomeUnknown,
    );
    expect(result.succeeded, isFalse);
    expect(result.mayHaveBeenSent, isTrue);
  });

  test('external sender owns no second Outbox state machine', () {
    final source = File(senderPath).readAsStringSync();
    expect(source, isNot(contains('OutgoingExternalSendHelper')));
    expect(source, isNot(contains('prepareOutbox(')));
    expect(source, isNot(contains('finalizeOutboxForExternal')));
    expect(source, contains('onCoordinatedResult:'));
    expect(source, contains('coordinated?.outcomeUnknown'));
  });

  test('GlobalModel exposes the coordinated outcome to external callers', () {
    final source = File(globalModelPath).readAsStringSync();
    expect(
      source,
      contains('ValueChanged<ImCoordinatedSendResult>? onCoordinatedResult'),
    );
    expect(source, contains('onCoordinatedResult?.call(coordinatedSend)'));
  });

  test('durable Outbox stores a versioned message envelope, not local id only',
      () {
    final source = File(coordinatorPath).readAsStringSync();
    expect(source, contains("'schemaVersion': 1"));
    expect(source, contains("'message': message.toJson()"));
    expect(source, contains('offlinePushInfo?.toJson()'));
    expect(source, contains('payloadReference: payloadEnvelope!'));
    expect(
      source,
      isNot(contains("payloadReference: 'sdkLocalId:\$localId'")),
    );
  });

  test('known high-value senders stop retrying on outcome unknown', () {
    for (final path in <String>[
      'lib/src/services/red_packet_claim_notice_sender.dart',
      'lib/src/services/group_local/group_tip_custom_sender.dart',
      'lib/src/pages/wallet/order/wallet_card_im_sender.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('sendCreatedMessageDetailed'));
      expect(
        source,
        anyOf(
          contains('mayHaveBeenSent'),
          contains('ExternalMessageSendState.outcomeUnknown'),
        ),
        reason: path,
      );
    }
  });
}
