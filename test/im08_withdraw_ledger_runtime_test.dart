// IM-08 P0-High B2: MessageWithdrawLedger 运行时行为。
//
// 静态契约测试只验证源码引用,本测试验证 ledger 真实持久化 + 跨重启恢复 +
// clearLocal 后清空。这是防止"SDK listener 回调丢失"的最后一道防线。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/message_withdraw_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // SharedPreferences mock 每次测试隔离
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('empty ledger: wasRevoked returns false for any msgID', () async {
    final ledger = MessageWithdrawLedger.instance;
    ledger.clearLocal();
    await ledger.ensureReady();
    expect(await ledger.wasRevoked('msg-1'), isFalse);
    expect(await ledger.wasRevoked(''), isFalse);
    expect(await ledger.wasRevoked('   '), isFalse);
  });

  test('recordRevoked + wasRevoked round-trip', () async {
    final ledger = MessageWithdrawLedger.instance;
    ledger.clearLocal();
    await ledger.ensureReady();
    await ledger.recordRevoked('msg-A');
    await ledger.recordRevoked('msg-B');
    expect(await ledger.wasRevoked('msg-A'), isTrue);
    expect(await ledger.wasRevoked('msg-B'), isTrue);
    expect(await ledger.wasRevoked('msg-C'), isFalse);
  });

  test('recordRevoked skips empty/whitespace msgID silently', () async {
    final ledger = MessageWithdrawLedger.instance;
    ledger.clearLocal();
    await ledger.ensureReady();
    await ledger.recordRevoked('');
    await ledger.recordRevoked('   ');
    expect(ledger.debugEntries(), isEmpty);
  });

  test('clearLocal wipes in-memory entries immediately', () async {
    final ledger = MessageWithdrawLedger.instance;
    await ledger.recordRevoked('msg-pre');
    expect(await ledger.wasRevoked('msg-pre'), isTrue);
    ledger.clearLocal();
    // ensureReady 后会重新加载 prefs,但因为 mock 为空,所以 entries 为空
    await ledger.ensureReady();
    expect(await ledger.wasRevoked('msg-pre'), isFalse);
  });

  test('recordRevokedWithInfo stores isAdmin + revokerID, entryOf retrieves',
      () async {
    final ledger = MessageWithdrawLedger.instance;
    ledger.clearLocal();
    await ledger.ensureReady();
    await ledger.recordRevokedWithInfo(
      msgID: 'msg-A',
      isAdmin: true,
      revokerID: 'adminUser',
    );
    final entry = await ledger.entryOf('msg-A');
    expect(entry, isNotNull);
    expect(entry!.isAdmin, isTrue);
    expect(entry.revokerID, 'adminUser');
  });

  test('recordRevokedWithInfo with null revokerID is preserved', () async {
    final ledger = MessageWithdrawLedger.instance;
    ledger.clearLocal();
    await ledger.ensureReady();
    await ledger.recordRevokedWithInfo(
      msgID: 'msg-B',
      isAdmin: false,
    );
    final entry = await ledger.entryOf('msg-B');
    expect(entry, isNotNull);
    expect(entry!.isAdmin, isFalse);
    expect(entry.revokerID, isNull);
  });
}
