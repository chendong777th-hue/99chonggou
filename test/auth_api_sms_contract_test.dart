import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';

void main() {
  test('sends international SMS through the unified endpoint', () async {
    RequestOptions? capturedOptions;
    final dio = _stubDio((options) {
      capturedOptions = options;
    });

    await AuthApi.withDio(dio).sendSms(
      phone: ' +14155552671 ',
      scene: ' login ',
      phoneCountry: ' us ',
    );

    expect(capturedOptions?.path, '/sms/send');
    expect(capturedOptions?.method, 'POST');
    expect(capturedOptions?.data, {
      'phone': '+14155552671',
      'scene': 'LOGIN',
      'phoneCountry': 'US',
    });
  });

  test('includes a trimmed challenge id for device verification', () async {
    RequestOptions? capturedOptions;
    final dio = _stubDio((options) {
      capturedOptions = options;
    });

    await AuthApi.withDio(dio).sendSms(
      phone: '+447911123456',
      scene: 'DEVICE',
      phoneCountry: 'GB',
      challengeId: ' challenge-1 ',
    );

    expect(capturedOptions?.data, {
      'phone': '+447911123456',
      'scene': 'DEVICE',
      'phoneCountry': 'GB',
      'challengeId': 'challenge-1',
    });
  });
}

Dio _stubDio(void Function(RequestOptions options) capture) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        capture(options);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {'ok': true},
          ),
        );
      },
    ),
  );
  return dio;
}
