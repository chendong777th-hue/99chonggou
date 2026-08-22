/// 发布版可见的聊天/会话诊断日志。过滤关键字：`[ChatDiag]` 等 tag。
class ChatDiagLog {
  ChatDiagLog._();

  /// 诊断完成后关闭。需要抓会话进页/归档链路时再临时改为 true。
  static const bool enabled = false;

  static void log(
    String tag,
    String event, {
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) {
      return;
    }
    final buffer = StringBuffer('[$tag] event=$event');
    final id = conversationID?.trim() ?? '';
    if (id.isNotEmpty) {
      buffer.write(' conv=$id');
    }
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.write(' ${entry.key}=$value');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }
}
