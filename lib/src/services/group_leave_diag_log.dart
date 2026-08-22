import 'package:tencent_cloud_chat_demo/src/services/chat_diag_log.dart';

/// 退群/解散诊断日志（发布版可见，便于 Xcode/Logcat 过滤 `GroupLeave`）。
class GroupLeaveDiagLog {
  GroupLeaveDiagLog._();

  static const String tag = 'GroupLeave';

  static void log(
    String event, {
    String? groupId,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final id = groupId?.trim() ?? '';
    ChatDiagLog.log(
      tag,
      event,
      conversationID: id.isEmpty ? null : 'group_$id',
      extras: extras,
    );
  }
}
