// IM-08 P0-Critical 第二刀:ChatExternalMessageSender.sendCreatedMessage
// 必须调用 OutgoingExternalSendHelper 在 Outbox 主表写入 prepared 记录,
// 然后根据 UIKit 返回码写最终态 (succeeded / failed / outcomeUnknown)。
//
// 这是钱包/名片/群创建/分享等自定义消息类型的统一 Outbox 路径。
// 之前外发路径只调 UIKit,失败/超时无 Outbox 兜底。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const senderPath = 'lib/src/services/chat_external_message_sender.dart';
  const helperPath = 'lib/src/services/im/outgoing_external_send_helper.dart';

  test('helper file exists and exports the public surface', () {
    final f = File('${Directory.current.path}/$helperPath');
    expect(f.existsSync(), isTrue, reason: '$helperPath missing');
    final src = f.readAsStringSync();
    expect(src, contains('class OutgoingExternalSendHelper'));
    expect(src, contains('recordOutboxEntryForExternal'));
    expect(src, contains('finalizeOutboxForExternal'));
    expect(src, contains('prepareOutbox'));
    expect(src, contains('recordDispatchIntent'));
    expect(src, contains('transitionOutbox'));
    expect(src, contains('recordOutboxSdkSucceeded'));
    expect(src, contains('recordOutboxSdkFailed'));
    expect(src, contains('recordOutcomeUnknown'));
  });

  test('ChatExternalMessageSender routes through the helper before SDK call',
      () {
    final src =
        File('${Directory.current.path}/$senderPath').readAsStringSync();
    expect(
      src.replaceAll(' ', '').replaceAll('\n', ''),
      contains('OutgoingExternalSendHelper.recordOutboxEntryForExternal'),
      reason: 'sender must write Outbox entry before UIKit send',
    );
    expect(
      src.replaceAll(' ', '').replaceAll('\n', ''),
      contains('OutgoingExternalSendHelper.finalizeOutboxForExternal'),
      reason: 'sender must finalize Outbox state after UIKit returns',
    );
    expect(
      src,
      contains('SessionIdentityService.instance.capture'),
      reason: 'sender must capture identity for owner scope',
    );
  });
}
