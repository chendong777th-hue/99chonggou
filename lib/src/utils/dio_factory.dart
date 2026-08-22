import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tencent_cloud_chat_demo/src/utils/dio_fixed_browser_adapter.dart';

/// Creates a [Dio] instance with the patched Web XHR adapter when needed.
Dio createAppDio(BaseOptions options) {
  final dio = Dio(options);
  if (kIsWeb) {
    dio.httpClientAdapter = createFixedWebHttpClientAdapter();
  }
  return dio;
}
