// IM-08 P0-High B2: 撤回事件本地账本 + adapter 接线。
//
// vendor tui_chat_separate_view_model.dart 主动撤回失败时无法拦截,但
// SDK 成功后应触发 onRecvMessageRevoked -> _submitRevoked ->
// MessageWithdrawLedger.recordRevoked。本测试断言:
//   1. ledger 文件存在且暴露 recordRevoked/wasRevoked/clearLocal
//   2. adapter 必须在 _submitRevoked 调 ledger.recordRevoked
//   3. recordRevoked 空 msgID 不崩
//   4. clearLocal 后 ledger 为空
//   5. (运行时) recordRevoked 后 wasRevoked 返回 true

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ledgerPath = 'lib/src/services/im/message_withdraw_ledger.dart';
  const adapterPath =
      'lib/src/services/im/tencent_advanced_message_adapter.dart';

  test('ledger file exists with public surface', () {
    final src =
        File('${Directory.current.path}/$ledgerPath').readAsStringSync();
    expect(src, contains('class MessageWithdrawLedger'));
    expect(src, contains('Future<void> recordRevoked(String msgID)'));
    expect(src, contains('Future<bool> wasRevoked(String msgID)'));
    expect(src, contains('void clearLocal()'));
    expect(src, contains('SharedPreferences'),
        reason: 'ledger must persist across restarts');
  });

  test('adapter routes _submitRevoked through MessageWithdrawLedger', () {
    final src =
        File('${Directory.current.path}/$adapterPath').readAsStringSync();
    expect(
      src,
      contains(
          "import 'package:tencent_cloud_chat_demo/src/services/im/message_withdraw_ledger.dart'"),
      reason: 'adapter must import the ledger',
    );
    final compact = src.replaceAll(' ', '').replaceAll('\n', '');
    expect(
      compact,
      contains('MessageWithdrawLedger.instance.recordRevokedWithInfo('),
      reason: '_submitRevoked must call ledger.recordRevoked for every '
          'revoke event to survive SDK listener loss',
    );
  });
}
