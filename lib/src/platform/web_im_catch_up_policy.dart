/// Web 回前台补拉策略：3s 节流，但打开中的空聊天允许一次会话级补拉。
class WebImCatchUpPolicy {
  WebImCatchUpPolicy._();

  static const Duration minInterval = Duration(seconds: 3);

  static bool isThrottled({
    required DateTime now,
    DateTime? lastCatchUpAt,
    Duration minInterval = WebImCatchUpPolicy.minInterval,
  }) {
    if (lastCatchUpAt == null) {
      return false;
    }
    return now.difference(lastCatchUpAt) < minInterval;
  }

  /// 全量 catchUp（会话列表 + 当前聊天）是否应跳过。
  static bool shouldSkipFullCatchUp({
    required DateTime now,
    DateTime? lastCatchUpAt,
    required bool openConversationEmpty,
    Duration minInterval = WebImCatchUpPolicy.minInterval,
  }) {
    if (!isThrottled(
      now: now,
      lastCatchUpAt: lastCatchUpAt,
      minInterval: minInterval,
    )) {
      return false;
    }
    return !openConversationEmpty;
  }

  /// 节流期内仅补当前打开会话。
  static bool shouldSessionCatchUpWhileThrottled({
    required bool throttled,
    required bool openConversationEmpty,
  }) {
    return throttled && openConversationEmpty;
  }
}
