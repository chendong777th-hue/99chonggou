/// 群成员增删结果提示（由业务侧注入 Toast 等）。
class GroupMemberFeedbackBridge {
  GroupMemberFeedbackBridge._();

  static void Function(String message)? onShowMessage;

  static void show(String message) {
    final text = message.trim();
    if (text.isEmpty) {
      return;
    }
    onShowMessage?.call(text);
  }
}
