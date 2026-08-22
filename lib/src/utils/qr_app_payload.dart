import 'dart:convert';

/// 个人 / 群二维码载荷。
///
/// 新格式为官网落地 URL（外置扫码可打开下载页），查询参数携带业务字段：
/// `https://example.com/?type=user&id=...&name=...&from=qr`
///
/// 旧格式仍为 JSON：`{"type":"user|group","id":"...","name":"..."}`，App 内扫码双轨兼容。
enum QrAppPayloadType { user, group }

class QrAppPayload {
  const QrAppPayload({
    required this.type,
    required this.id,
    this.name = '',
  });

  final QrAppPayloadType type;
  final String id;
  final String name;

  String get typeValue =>
      type == QrAppPayloadType.user ? 'user' : 'group';

  /// 将官网 / 下载地址与业务字段合成可扫码字符串。
  ///
  /// [baseUrl] 为空或无法解析为 http(s) 时回退到旧 JSON，保证 App 内仍可用。
  static String encode({
    required String baseUrl,
    required QrAppPayloadType type,
    required String id,
    String name = '',
  }) {
    final trimmedId = id.trim();
    final trimmedName = name.trim();
    final typeValue =
        type == QrAppPayloadType.user ? 'user' : 'group';

    final jsonFallback = jsonEncode(<String, dynamic>{
      'type': typeValue,
      'id': trimmedId,
      'name': trimmedName,
    });

    final trimmedBase = baseUrl.trim();
    if (trimmedBase.isEmpty || trimmedId.isEmpty) {
      return jsonFallback;
    }

    final uri = Uri.tryParse(trimmedBase);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return jsonFallback;
    }

    final params = <String, String>{
      ...uri.queryParameters,
      'type': typeValue,
      'id': trimmedId,
      'from': 'qr',
    };
    if (trimmedName.isNotEmpty) {
      params['name'] = trimmedName;
    }

    return uri.replace(queryParameters: params).toString();
  }

  static QrAppPayload? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final fromJson = _tryParseJson(trimmed);
    if (fromJson != null) {
      return fromJson;
    }
    return _tryParseUri(trimmed);
  }

  static QrAppPayload? _tryParseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return _fromTypeAndId(
        type: decoded['type']?.toString(),
        id: decoded['id']?.toString(),
        name: decoded['name']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static QrAppPayload? _tryParseUri(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    final params = uri.queryParameters;
    return _fromTypeAndId(
      type: params['type'],
      id: params['id'],
      name: params['name'],
    );
  }

  static QrAppPayload? _fromTypeAndId({
    required String? type,
    required String? id,
    String? name,
  }) {
    final trimmedType = type?.trim() ?? '';
    final trimmedId = id?.trim() ?? '';
    if (trimmedId.isEmpty) {
      return null;
    }
    if (trimmedType == 'user') {
      return QrAppPayload(
        type: QrAppPayloadType.user,
        id: trimmedId,
        name: name?.trim() ?? '',
      );
    }
    if (trimmedType == 'group') {
      return QrAppPayload(
        type: QrAppPayloadType.group,
        id: trimmedId,
        name: name?.trim() ?? '',
      );
    }
    return null;
  }
}
