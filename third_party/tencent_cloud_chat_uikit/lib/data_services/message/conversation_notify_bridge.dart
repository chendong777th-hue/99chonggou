typedef ConversationMuteSyncedReporter = Future<void> Function({
  required String chatType,
  required String peerId,
  required bool muted,
});

/// App 侧在 IM 免打扰设置成功后上报服务端 Push 策略。
class ConversationNotifyBridge {
  ConversationNotifyBridge._();

  static ConversationMuteSyncedReporter? onMuteSynced;

  static void configure({ConversationMuteSyncedReporter? reporter}) {
    onMuteSynced = reporter;
  }
}
