/// 「回到底部」胶囊显隐。
///
/// 不能只看逻辑贴底位（[HistoryMessagePosition.inTwoScreen] 等）：
/// 最后一条还在视口里时，用户会觉得自己已经在底部，按钮却还亮着。
class BackToBottomCapsulePolicy {
  BackToBottomCapsulePolicy._();

  /// 离开底部超过约一屏才点亮。
  static const double showViewportRatio = 1.0;

  /// 隐藏滞后，避免在阈值附近闪烁。
  static const double hideViewportRatio = 0.85;

  static const double bottomEpsilon = 24.0;

  static bool isPhysicallyAtBottom(double distanceFromBottom) {
    return distanceFromBottom <= bottomEpsilon;
  }

  /// [leftBottomByOneScreen]：用户主动离开超过约一屏（含滞后）。
  /// [missingNewerThanViewport]：当前列表贴底，但更新消息还没加载进来。
  static bool shouldShow({
    required bool physicallyAtBottom,
    required bool leftBottomByOneScreen,
    required bool missingNewerThanViewport,
    required bool presentationBottomLocked,
    required bool programmaticScrollToBottom,
  }) {
    if (presentationBottomLocked || programmaticScrollToBottom) {
      return false;
    }
    if (physicallyAtBottom) {
      return missingNewerThanViewport;
    }
    return leftBottomByOneScreen;
  }
}
