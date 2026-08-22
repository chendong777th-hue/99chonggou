import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';

class MediaUrlResolver {
  MediaUrlResolver._();

  static String? resolve(String? url) {
    if (url == null) {
      return null;
    }
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _encodePath(trimmed);
    }
    final base = ApiClient.resolveBaseUrl();
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return _encodePath('$base$path');
  }

  static Map<String, String>? authHeadersFor(String url) {
    final token = ApiClient.instance.token;
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse(url);
      final base = Uri.parse(ApiClient.resolveBaseUrl());
      if (uri.host == base.host) {
        return {'Authorization': 'Bearer $token'};
      }
    } catch (_) {}
    return null;
  }

  static String _encodePath(String url) {
    final schemeIndex = url.indexOf('://');
    if (schemeIndex == -1) {
      return url.replaceAll('#', '%23');
    }
    final hostPathSeparator = url.indexOf('/', schemeIndex + 3);
    if (hostPathSeparator == -1) {
      return url;
    }
    final queryIndex = url.indexOf('?', hostPathSeparator);
    final prefix = url.substring(0, hostPathSeparator);
    final rawPath = queryIndex == -1
        ? url.substring(hostPathSeparator)
        : url.substring(hostPathSeparator, queryIndex);
    final query = queryIndex == -1 ? '' : url.substring(queryIndex);
    final encodedPath = rawPath.split('/').map((segment) {
      if (segment.isEmpty) {
        return '';
      }
      try {
        return Uri.encodeComponent(Uri.decodeComponent(segment));
      } catch (_) {
        return Uri.encodeComponent(segment);
      }
    }).join('/');
    return '$prefix$encodedPath$query';
  }

  /// Unwrap API proxy URLs like `https://host/webrtc%3A//domain/...` → `webrtc://domain/...`.
  static String? unwrapProxiedStreamUrl(String? url) {
    if (url == null) {
      return null;
    }
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('webrtc://') || trimmed.startsWith('trtc://')) {
      return trimmed;
    }
    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return trimmed;
      }
      final rawPath = uri.path.startsWith('/')
          ? uri.path.substring(1)
          : uri.path;
      if (rawPath.isEmpty) {
        return trimmed;
      }
      final decoded = Uri.decodeComponent(rawPath);
      if (decoded.startsWith('webrtc://') || decoded.startsWith('trtc://')) {
        if (uri.query.isEmpty) {
          return decoded;
        }
        return '$decoded?${uri.query}';
      }
    } catch (_) {}
    return trimmed;
  }
}
