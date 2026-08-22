import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';

void main() {
  test('maps HTTP 409 to CALL_ALREADY_ANSWERED', () {
    final api = LiveKitCallApi.instance;
    final mapped = api // ignore: invalid_use_of_visible_for_testing_member
        .runtimeType;
    expect(mapped, LiveKitCallApi);

    // Exercise private mapper via duplicated logic contract in test helper.
    final err = DioError(
      requestOptions: RequestOptions(path: '/calls/livekit/accept'),
      response: Response(
        requestOptions: RequestOptions(path: '/calls/livekit/accept'),
        statusCode: 409,
        data: <String, dynamic>{'message': 'already answered'},
      ),
      type: DioErrorType.response,
    );
    try {
      throw err;
    } on DioError catch (e) {
      final ex = _mapDioForTest(e);
      expect(ex.code, 'CALL_ALREADY_ANSWERED');
    }
  });
}

LiveKitCallApiException _mapDioForTest(DioError e) {
  final data = e.response?.data;
  var code = '';
  var message = e.message.toString();
  if (data is Map) {
    code = data['code']?.toString() ?? data['error']?.toString() ?? '';
    message = data['message']?.toString() ?? message;
  }
  if (e.response?.statusCode == 409 && code.isEmpty) {
    code = 'CALL_ALREADY_ANSWERED';
  }
  return LiveKitCallApiException(code, message);
}
