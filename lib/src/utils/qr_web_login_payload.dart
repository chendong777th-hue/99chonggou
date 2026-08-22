import 'dart:convert';

/// Web 扫码登录二维码载荷解析（契约 v1）。
///
/// 载荷格式：`{"type":"web_login","sessionId":"<id>","v":1}`
class QrWebLoginPayload {
  const QrWebLoginPayload({
    required this.sessionId,
    this.version = 1,
  });

  final String sessionId;
  final int version;

  static const typeValue = 'web_login';

  static QrWebLoginPayload? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      final type = decoded['type']?.toString().trim() ?? '';
      if (type != typeValue) {
        return null;
      }
      final sessionId = decoded['sessionId']?.toString().trim() ??
          decoded['session_id']?.toString().trim() ??
          '';
      if (sessionId.isEmpty) {
        return null;
      }
      final versionRaw = decoded['v'] ?? decoded['version'];
      final version = versionRaw is num
          ? versionRaw.toInt()
          : int.tryParse(versionRaw?.toString() ?? '') ?? 1;
      return QrWebLoginPayload(sessionId: sessionId, version: version);
    } catch (_) {
      return null;
    }
  }

  String encode() {
    return jsonEncode(<String, dynamic>{
      'type': typeValue,
      'sessionId': sessionId,
      'v': version,
    });
  }
}
