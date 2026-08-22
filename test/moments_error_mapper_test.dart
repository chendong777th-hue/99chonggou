import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';

void main() {
  DioError dioError({
    required int statusCode,
    required Map<String, dynamic> data,
  }) {
    final request = RequestOptions(path: '/moments/feed');
    return DioError(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: statusCode,
        data: data,
      ),
    );
  }

  test('maps missing moment to safe not found message', () {
    final error = MomentsErrorMapper.map(
      dioError(
        statusCode: 404,
        data: {'code': 'MOMENT_NOT_FOUND', 'message': 'raw backend text'},
      ),
    );

    expect(error.code, 'MOMENT_NOT_FOUND');
    expect(error.retryable, isFalse);
    expect(error.userMessage, isNot(contains('raw backend text')));
  });

  test('maps forbidden moment to non retryable permission error', () {
    final error = MomentsErrorMapper.map(
      dioError(
        statusCode: 403,
        data: {'code': 'FRIEND_REQUIRED'},
      ),
    );

    expect(error.code, 'MOMENTS_FORBIDDEN');
    expect(error.retryable, isFalse);
  });

  test('maps rate limit to retryable user safe error', () {
    final error = MomentsErrorMapper.map(
      dioError(
        statusCode: 429,
        data: {'code': 'RATE_LIMITED'},
      ),
    );

    expect(error.code, 'MOMENTS_RATE_LIMITED');
    expect(error.retryable, isTrue);
  });
}
