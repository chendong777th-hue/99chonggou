typedef SelfHostedGroupLeaveDiagHandler = void Function(
  String event, {
  String? groupId,
  Map<String, Object?> extras,
});

/// 退群/解散诊断日志桥（由业务侧注入，UIKit 不依赖 lib）。
class SelfHostedGroupLeaveDiagBridge {
  SelfHostedGroupLeaveDiagBridge._();

  static SelfHostedGroupLeaveDiagHandler? _handler;

  static void configure({
    SelfHostedGroupLeaveDiagHandler? handler,
  }) {
    _handler = handler;
  }

  static void clear() {
    _handler = null;
  }

  static void log(
    String event, {
    String? groupId,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final handler = _handler;
    if (handler != null) {
      handler(event, groupId: groupId, extras: extras);
      return;
    }
    final buffer = StringBuffer('[GroupLeave] event=$event');
    final id = groupId?.trim() ?? '';
    if (id.isNotEmpty) {
      buffer.write(' conv=group_$id');
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
