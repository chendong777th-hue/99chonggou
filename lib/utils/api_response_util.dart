/// 兼容后端多种 JSON 包装（如 `{ "data": ... }`、`{ "items": [...] }`）。
dynamic unwrapApiPayload(dynamic raw) {
  var current = raw;
  for (var depth = 0; depth < 4; depth++) {
    if (current is! Map) {
      break;
    }
    final map = Map<String, dynamic>.from(current);
    if (map['data'] != null) {
      current = map['data'];
      continue;
    }
    if (map['result'] != null) {
      current = map['result'];
      continue;
    }
    if (map['payload'] != null) {
      current = map['payload'];
      continue;
    }
    break;
  }
  return current;
}

List<dynamic> extractApiList(dynamic raw, {List<String> listKeys = const []}) {
  final payload = unwrapApiPayload(raw);
  if (payload is List) {
    return payload;
  }
  if (payload is! Map) {
    return const [];
  }
  final map = Map<String, dynamic>.from(payload);
  final keys = [
    ...listKeys,
    'items',
    'list',
    'records',
    'content',
    'favorites',
    'packs',
    'data',
  ];
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value;
    }
  }
  return const [];
}
