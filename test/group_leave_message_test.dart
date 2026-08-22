import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/group_leave_message.dart';

void main() {
  group('GroupLeaveMessage.failure', () {
    test('does not map leave errors to admin copy', () {
      for (final code in ['REQUEST_FAILED', 'INVALID_INPUT', 'GROUP_NOT_FOUND']) {
        final message = GroupLeaveMessage.failure(desc: code, dismiss: false);
        expect(message, isNot(contains('管理员')));
        expect(message.toLowerCase(), isNot(contains('admin')));
      }
    });

    test('maps REQUEST_FAILED to retryable leave copy', () {
      final message = GroupLeaveMessage.failure(desc: 'REQUEST_FAILED', dismiss: false);
      expect(
        message.toLowerCase(),
        anyOf(contains('leave'), contains('退出'), contains('网络'), contains('network')),
      );
    });

    test('maps dismiss failures separately from leave', () {
      final leave = GroupLeaveMessage.failure(desc: 'INVALID_INPUT', dismiss: false);
      final dismiss = GroupLeaveMessage.failure(desc: 'INVALID_INPUT', dismiss: true);
      expect(leave, isNot(equals(dismiss)));
    });

    test('maps owner cannot leave', () {
      final message =
          GroupLeaveMessage.failure(desc: 'OWNER_CANNOT_LEAVE', dismiss: false);
      expect(
        message.toLowerCase(),
        anyOf(contains('owner'), contains('群主'), contains('解散')),
      );
    });

    test('maps not group member', () {
      final message =
          GroupLeaveMessage.failure(desc: 'NOT_GROUP_MEMBER', dismiss: false);
      expect(
        message.toLowerCase(),
        anyOf(contains('member'), contains('成员')),
      );
    });
  });
}
