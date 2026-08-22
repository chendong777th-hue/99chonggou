typedef SelfHostedGroupLeaveResultMessageBuilder = String Function({
  required bool dismiss,
  int? code,
  String? desc,
});

/// 自建群退群/解散结果文案（由业务侧注入 i18n）。
class SelfHostedGroupLeaveBridge {
  SelfHostedGroupLeaveBridge._();

  static SelfHostedGroupLeaveResultMessageBuilder? _messageBuilder;

  static void configure({
    SelfHostedGroupLeaveResultMessageBuilder? messageBuilder,
  }) {
    _messageBuilder = messageBuilder;
  }

  static void clear() {
    _messageBuilder = null;
  }

  static String formatMessage({
    required bool dismiss,
    int? code,
    String? desc,
  }) {
    final builder = _messageBuilder;
    if (builder != null) {
      return builder(dismiss: dismiss, code: code, desc: desc);
    }
    final fallback = desc?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return dismiss ? 'Failed to dismiss the group' : 'Failed to leave the group';
  }
}
