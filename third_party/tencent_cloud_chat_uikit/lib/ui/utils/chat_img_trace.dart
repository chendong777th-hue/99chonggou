/// 聊天图片下载 / 预取诊断。过滤关键字：`[ChatImg]`。
class ChatImgTrace {
  ChatImgTrace._();

  /// 诊断完成后关闭。需要排查图片下载链路时再临时改为 true。
  static const bool enabled = false;

  static void log(String message) {
    if (!enabled) {
      return;
    }
    // ignore: avoid_print
    print(message);
  }
}
