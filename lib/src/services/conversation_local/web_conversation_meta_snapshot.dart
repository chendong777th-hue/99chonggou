class WebConversationMetaSnapshot {
  const WebConversationMetaSnapshot({
    this.historyClearedAtMs = const <String, int>{},
    this.readClearedAtMs = const <String, int>{},
    this.readClearedLastMsgId = const <String, String>{},
  });

  final Map<String, int> historyClearedAtMs;
  final Map<String, int> readClearedAtMs;
  final Map<String, String> readClearedLastMsgId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'historyClearedAtMs': historyClearedAtMs,
        'readClearedAtMs': readClearedAtMs,
        'readClearedLastMsgId': readClearedLastMsgId,
      };

  factory WebConversationMetaSnapshot.fromJson(Map<String, dynamic> json) {
    return WebConversationMetaSnapshot(
      historyClearedAtMs: _intMap(json['historyClearedAtMs']),
      readClearedAtMs: _intMap(json['readClearedAtMs']),
      readClearedLastMsgId: _stringMap(json['readClearedLastMsgId']),
    );
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }
    final out = <String, int>{};
    raw.forEach((key, value) {
      if (value is num) {
        out[key.toString()] = value.toInt();
      }
    });
    return out;
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final out = <String, String>{};
    raw.forEach((key, value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        out[key.toString()] = text;
      }
    });
    return out;
  }
}
