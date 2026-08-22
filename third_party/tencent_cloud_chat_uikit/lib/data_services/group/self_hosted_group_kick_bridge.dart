typedef SelfHostedGroupKickResultMessageBuilder = String Function({
  required bool success,
  int? code,
  String? desc,
});

/// 自建群踢人结果文案（由业务侧注入 i18n）。
class SelfHostedGroupKickBridge {
  SelfHostedGroupKickBridge._();

  static SelfHostedGroupKickResultMessageBuilder? _messageBuilder;

  static void configure({
    SelfHostedGroupKickResultMessageBuilder? messageBuilder,
  }) {
    _messageBuilder = messageBuilder;
  }

  static void clear() {
    _messageBuilder = null;
  }

  static String formatMessage({
    required bool success,
    int? code,
    String? desc,
  }) {
    final builder = _messageBuilder;
    if (builder != null) {
      return builder(success: success, code: code, desc: desc);
    }
    if (success) {
      return 'Removed group member';
    }
    final fallback = desc?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return 'Failed to remove group member';
  }
}
