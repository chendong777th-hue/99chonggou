// IM-08 P0-Critical: voice-to-text 后台上传必须经过 ImOutgoingSendCoordinator，
// 不允许直接调用 messageService.sendMessage。这是 lib/src/services/ 下唯一
// 已知的发送路径，必须收口到统一 SDK 出口。
//
// 历史原因：voice-to-text 的 convertLocalFile 路径原本直接调用
// messageService.sendMessage，绕过 ImOutgoingSendCoordinator，导致：
//   - 不携带 OutgoingIdentityContract（operationId / clientCorrelationId）
//   - 不走 ImWriterLease（无法被 fencingToken 拒绝）
//   - 不走 OutcomeUnknown 单写者
//   - 无法被 DurableIngressGateway 持久化恢复
//
// 本测试断言：
//   1. tencent_voice_to_text_service.dart 必须调用 ImOutgoingSendCoordinator.instance.send
//   2. 调用必须传 persistOutbox: false（后台系统上传，不进 Outbox 主表）
//   3. 整文件不允许直接调 messageService.sendMessage

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targetPath = 'lib/src/services/tencent_voice_to_text_service.dart';

  test('voice-to-text source file exists and is non-empty', () {
    final f = File('${Directory.current.path}/$targetPath');
    expect(f.existsSync(), isTrue, reason: '$targetPath missing');
    final lines = f.readAsLinesSync();
    expect(lines.length, greaterThan(50), reason: 'unexpected truncation');
  });

  test(
      'voice-to-text routes through ImOutgoingSendCoordinator '
      '(no direct messageService.sendMessage call)', () {
    final src =
        File('${Directory.current.path}/$targetPath').readAsStringSync();
    expect(
      src,
      isNot(contains(r'messageService.sendMessage(')),
      reason: 'voice-to-text must not call messageService.sendMessage '
          'directly; route through ImOutgoingSendCoordinator instead',
    );
    expect(
      src,
      contains('ImOutgoingSendCoordinator.instance.send'),
      reason: 'voice-to-text must call '
          'ImOutgoingSendCoordinator.instance.send',
    );
    expect(
      src,
      contains('persistOutbox: false'),
      reason: 'voice-to-text is a system upload and must opt out of '
          'the Outbox main table to avoid polluting the user-visible '
          'retry and recovery paths',
    );
  });
}
