import 'dart:convert';

/// Isolate / `compute` 入口：批量解码会话表行的 `raw_json`。
/// 只使用可 Send 的 Map/基本类型；不碰 `V2TimConversation`。

/// 将 SQLite 行转为主 isolate 可组装的 payload。
///
/// 每项包含列字段副本，以及可选的 `decoded`（`raw_json` 解析后的 Map）。
List<Map<String, dynamic>> decodeConversationRowsForIsolate(
  List<Map<String, Object?>> rows,
) {
  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    out.add(_decodeOneRow(row));
  }
  return out;
}

Map<String, dynamic> _decodeOneRow(Map<String, Object?> row) {
  final payload = <String, dynamic>{
    'conversation_id': row['conversation_id']?.toString() ?? '',
    'conv_type': _asInt(row['conv_type']),
    'user_id': row['user_id']?.toString() ?? '',
    'group_id': row['group_id']?.toString() ?? '',
    'show_name': row['show_name']?.toString() ?? '',
    'face_url': row['face_url']?.toString() ?? '',
    'unread_count': _asInt(row['unread_count']),
    'recv_opt': _asInt(row['recv_opt']),
    'group_type': row['group_type']?.toString() ?? '',
    'is_pinned': _asInt(row['is_pinned']),
    'order_key': _asInt(row['order_key']),
    'active_time': _asInt(row['active_time']),
    'read_cleared_at': _asInt(row['read_cleared_at']),
    'local_draft_text': row['local_draft_text']?.toString() ?? '',
    'local_draft_updated_at': _asInt(row['local_draft_updated_at']),
    'decoded': null,
  };

  final raw = row['raw_json']?.toString() ?? '';
  if (raw.isEmpty) {
    return payload;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      payload['decoded'] = Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    payload['decoded'] = null;
  }
  return payload;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}
