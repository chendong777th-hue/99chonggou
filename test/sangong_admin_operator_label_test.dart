import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_admin_operator_label.dart';

void main() {
  group('formatSangongAdminOperatorLabel', () {
    test('combines nickname and user id', () {
      expect(
        formatSangongAdminOperatorLabel(
          nickname: '管理员张三',
          userId: 'admin_01',
        ),
        '管理员张三(admin_01)',
      );
    });

    test('falls back to nickname or user id alone', () {
      expect(
        formatSangongAdminOperatorLabel(nickname: '张三', userId: ''),
        '张三',
      );
      expect(
        formatSangongAdminOperatorLabel(nickname: '', userId: 'admin_01'),
        'admin_01',
      );
      expect(
        formatSangongAdminOperatorLabel(nickname: '', userId: ''),
        '',
      );
    });
  });
}
