/// 活跃会话内存消息窗口策略（DB 无限，内存有限）。
///
/// 与 ImageCache / mediaRoot 生命周期解耦；关闭 [enabled] 可秒回滚旧行为。
class ChatMessageWindowPolicy {
  ChatMessageWindowPolicy._();

  /// 总开关。false 时 [ChatMessageWindow] / setMessageList 闸门不裁剪。
  static bool enabled = true;

  /// trim 后目标长度。
  static const int targetSize = 120;

  /// 超过才 trim（允许 120 + loadBatch 瞬时）。
  static const int softMax = 160;

  /// 连续阅读历史时允许保留的诊断高水位。历史模式内不主动裁剪；真正
  /// 收束发生在回到最新端或页面退出，避免可见窗口边读边移动。
  static const int historyReadSoftMax = 320;

  /// 文档/断言参考；不强制填充。
  static const int softMin = 80;

  /// 与 [HistoryMessageDartConstant.getCount] 对齐。
  static const int loadBatch = 40;

  /// 锚点向更新侧（newest-first 数组头部方向）至少保留。
  static const int keepNewerSide = 40;

  /// 锚点向更旧侧（newest-first 数组尾部方向）至少保留。
  static const int keepOlderSide = 40;
}
