import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class XfyunAuth {
  XfyunAuth._();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String buildIatWebSocketUrl({
    required String apiKey,
    required String apiSecret,
    String host = 'iat-api.xfyun.cn',
    String path = '/v2/iat',
  }) {
    final gmtDate = _rfc1123Now();
    final signatureOrigin = 'host: $host\ndate: $gmtDate\nGET $path HTTP/1.1';
    final signature = base64.encode(
      Hmac(sha256, utf8.encode(apiSecret)).convert(utf8.encode(signatureOrigin)).bytes,
    );
    final authorizationOrigin =
        'api_key="$apiKey", algorithm="hmac-sha256", headers="host date request-line", signature="$signature"';
    final authorization = base64.encode(utf8.encode(authorizationOrigin));
    final query = Uri(
      scheme: 'wss',
      host: host,
      path: path,
      queryParameters: {
        'authorization': authorization,
        'date': gmtDate,
        'host': host,
      },
    );
    return query.toString();
  }

  static String formatFileApiDateTime([DateTime? time]) {
    final local = time ?? DateTime.now();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-${day}T$hour:$minute:$second$sign$hours$minutes';
  }

  static String _rfc1123Now() {
    final utc = DateTime.now().toUtc();
    final weekday = _weekdays[utc.weekday - 1];
    final month = _months[utc.month - 1];
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$weekday, $day $month ${utc.year} $hour:$minute:$second GMT';
  }

  static String randomSignatureNonce([int length = 16]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String signFileApiParams(
    Map<String, String> params,
    String apiSecret,
  ) {
    final sortedKeys = params.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      if (key == 'signature') {
        continue;
      }
      final value = params[key];
      if (value == null || value.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('&');
      }
      buffer
        ..write(key)
        ..write('=')
        ..write(_javaStyleUrlEncode(value));
    }
    final baseString = buffer.toString();
    final digest = Hmac(sha1, utf8.encode(apiSecret)).convert(utf8.encode(baseString));
    return base64.encode(digest.bytes);
  }

  static String _javaStyleUrlEncode(String value) {
    return Uri.encodeComponent(value).replaceAll('%20', '+');
  }
}
