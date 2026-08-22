import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_party_name_resolver.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

void main() {
  group('TransferPartyNameResolver.pickPreferredName', () {
    test('skips group name and keeps person name', () {
      DisplayNameStore.instance.setGroup(
        'g1',
        '阿伦_99CHAT六合彩在用',
        notify: false,
      );
      final picked = TransferPartyNameResolver.pickPreferredName(
        userId: 'u1',
        groupId: 'g1',
        candidates: [
          '阿伦_99CHAT六合彩在用',
          '京111111',
        ],
      );
      expect(picked, '京111111');
    });

    test('strips assembled group-transfer title from person name', () {
      final picked = TransferPartyNameResolver.pickPreferredName(
        userId: 'u1',
        candidates: [
          '京444444群转账转我',
          '我',
        ],
      );
      expect(picked, '京444444');
    });

    test('drops title that is only group-transfer copy', () {
      expect(
        TransferPartyNameResolver.sanitizeDisplayName('群转账转我'),
        isEmpty,
      );
    });

    test('skips raw userId', () {
      final picked = TransferPartyNameResolver.pickPreferredName(
        userId: 'abc1234',
        candidates: ['abc1234', '张三'],
      );
      expect(picked, '张三');
    });
  });

  group('TransferPartyNameResolver.nicknameOf', () {
    test('keeps real nickname and drops raw userId hint', () {
      expect(
        TransferPartyNameResolver.nicknameOf(
          userId: 'abc1234',
          nickHint: 'abc1234',
        ),
        isEmpty,
      );
      expect(
        TransferPartyNameResolver.nicknameOf(
          userId: 'u1',
          nickHint: '真实昵称',
        ),
        '真实昵称',
      );
    });
  });
}
