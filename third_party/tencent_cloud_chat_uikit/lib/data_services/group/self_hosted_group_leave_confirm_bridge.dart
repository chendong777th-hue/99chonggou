typedef SelfHostedGroupLeaveConfirmHandler = Future<bool> Function({
  required bool dismiss,
});

/// 退群/解散确认弹窗（由业务侧注入 AppDialog 等统一组件）。
class SelfHostedGroupLeaveConfirmBridge {
  SelfHostedGroupLeaveConfirmBridge._();

  static SelfHostedGroupLeaveConfirmHandler? _handler;

  static void configure({
    SelfHostedGroupLeaveConfirmHandler? handler,
  }) {
    _handler = handler;
  }

  static void clear() {
    _handler = null;
  }

  static Future<bool> confirm({required bool dismiss}) async {
    final handler = _handler;
    if (handler != null) {
      return handler(dismiss: dismiss);
    }
    return false;
  }
}
