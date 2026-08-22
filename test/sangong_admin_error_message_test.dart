import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_admin_error_message.dart';

void main() {
  group('SangongAdminErrorMessage.fromDebit', () {
    test('maps INSUFFICIENT_BALANCE with balance', () {
      final message = SangongAdminErrorMessage.fromDebit(
        _dioError({
          'ok': false,
          'code': 'INSUFFICIENT_BALANCE',
          'balance': 200,
        }),
      );
      expect(message, contains('200'));
    });

    test('maps DEBIT_BLOCKED_BANKER with periodNo', () {
      final message = SangongAdminErrorMessage.fromDebit(
        _dioError({
          'ok': false,
          'code': 'DEBIT_BLOCKED_BANKER',
          'balance': 5000,
          'periodNo': 12,
        }),
      );
      expect(message, contains('12'));
    });

    test('prefers server message for DEBIT_BLOCKED_BANKER', () {
      final message = SangongAdminErrorMessage.fromDebit(
        _dioError({
          'code': 'DEBIT_BLOCKED_BANKER',
          'message': '当前有未结算的庄/合庄对局，暂不可下分',
        }),
      );
      expect(message, '当前有未结算的庄/合庄对局，暂不可下分');
    });
  });

  group('SangongAdminErrorMessage.fromBetting', () {
    test('maps NO_IM_MESSAGES', () {
      final message = SangongAdminErrorMessage.fromBetting(
        _dioError({
          'code': 'NO_IM_MESSAGES',
          'message': '本局尚无 IM 消息，请指定 untilMessageId',
        }),
      );
      expect(message, contains('IM'));
    });
  });
}

DioError _dioError(Map<String, dynamic> body) {
  return DioError(
    requestOptions: RequestOptions(path: '/api/v1/admin/users/debit'),
    response: Response(
      requestOptions: RequestOptions(path: '/api/v1/admin/users/debit'),
      statusCode: 400,
      data: body,
    ),
    type: DioErrorType.response,
  );
}
