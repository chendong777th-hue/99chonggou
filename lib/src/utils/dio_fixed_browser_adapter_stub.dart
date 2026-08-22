import 'package:dio/dio.dart';

/// Non-web stub — callers must guard with [kIsWeb] before invoking.
HttpClientAdapter createFixedWebHttpClientAdapter() {
  throw UnsupportedError(
    'createFixedWebHttpClientAdapter is only available on web.',
  );
}
