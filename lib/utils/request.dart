import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';

Future<Response<Map<String, dynamic>>> appRequest({
  String? method = 'get',
  Map<String, dynamic>? params,
  required String path,
  dynamic data,
  String? baseUrl,
}) async {
  BaseOptions options = BaseOptions(
    baseUrl: ApiClient.sanitizeBaseUrl(baseUrl) ?? ApiClient.resolveBaseUrl(),
    method: method,
    sendTimeout: 6000,
    queryParameters: params,
  );
  final i18n = AppI18n.current;
  try {
    return await Dio(options).request<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: params,
    );
  } on DioError catch (e) {
    // Server error 服务端问题
    if (e.response != null) {
      final option8 = e.message;
      return Response(data: {
        'errorCode': Const.SERVER_ERROR_CODE,
        'errorMessage': i18n.format(
          zhHans: '服务器错误：{detail}',
          zhHant: '伺服器錯誤：{detail}',
          en: 'Server error: {detail}',
          ja: 'サーバーエラー：{detail}',
          ko: '서버 오류: {detail}',
          vars: {'detail': option8},
        ),
      }, requestOptions: e.requestOptions);
    } else {
      // Request error 请求时的问题
      final option8 = e.message;
      return Response(data: {
        'errorCode': Const.REQUEST_ERROR_CODE,
        'errorMessage': i18n.format(
          zhHans: '请求错误：{detail}',
          zhHant: '請求錯誤：{detail}',
          en: 'Request error: {detail}',
          ja: 'リクエストエラー：{detail}',
          ko: '요청 오류: {detail}',
          vars: {'detail': option8},
        ),
      }, requestOptions: e.requestOptions);
    }
  }
}
