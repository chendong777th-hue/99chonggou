import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// Viewport insert / row-reveal / continuous list-push transient state.
class ChatListViewportInsertController {
  static const continuousViewportPushBasePixelsPerSecond = 500.0;
  static const continuousViewportPushMaxPixelsPerSecond = 920.0;
  static const continuousViewportPushSpeedRampRows = 4;
  /// 排队新行量齐真实高度的 post-frame 重试上限。
  /// 4 帧对 3+ 张异步解码图经常量不齐，CVP 会放弃贴底。
  static const continuousViewportPushMeasureMaxAttempts = 8;
  static const continuousViewportPushInitialLayoutSuppressMs = 120;
  static const viewportInsertSettleMs = 480;
  static const mediaSettleMs = 400;

  AnimationController? rowRevealController;
  Animation<double>? rowRevealAnimation;
  final Map<String, V2TimMessage> activeRowRevealMessages =
      <String, V2TimMessage>{};
  final Map<String, V2TimMessage> queuedViewportInsertMessages =
      <String, V2TimMessage>{};
  final Map<String, double> rowRevealFullExtentByKey = <String, double>{};
  Ticker? continuousViewportPushTicker;
  Duration? continuousViewportPushLastElapsed;
  bool continuousViewportPushActive = false;
  bool continuousViewportPushIntegrationScheduled = false;
  int continuousViewportPushIntegrationGeneration = 0;
  final List<double> continuousViewportPushRemainingRowExtents = <double>[];
  final Map<String, int> continuousViewportPushInitialLayoutUntilMsByKey =
      <String, int>{};
  int continuousViewportPushDiagTransaction = 0;
  int continuousViewportPushDiagFrame = 0;
  double? continuousViewportPushLastCommandedPixels;
  int rowRevealGeneration = 0;
  bool viewportInsertSlideActive = false;
  int viewportInsertSlideGeneration = 0;
  bool suppressRowRevealStatus = false;
  int viewportInsertSettleUntilMs = 0;
  final Map<String, int> mediaSettleUntilMsByKey = <String, int>{};

  bool isViewportInsertSettling([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now < viewportInsertSettleUntilMs;
  }

  void beginViewportInsertSettle({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    viewportInsertSettleUntilMs = now + viewportInsertSettleMs;
  }

  int viewportInsertSettleRemainingMs([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final remaining = viewportInsertSettleUntilMs - now;
    return remaining > 0 ? remaining : 0;
  }

  /// Snap reveal controller to completed and finish enter animations.
  List<V2TimMessage> takeArmedRevealMessages() {
    if (activeRowRevealMessages.isEmpty) {
      return const <V2TimMessage>[];
    }
    final messages = List<V2TimMessage>.from(activeRowRevealMessages.values);
    activeRowRevealMessages.clear();
    return messages;
  }

  void snapRevealControllerComplete() {
    suppressRowRevealStatus = true;
    rowRevealController?.value = 1;
    suppressRowRevealStatus = false;
  }

  void startContinuousViewportPushTicker() {
    final ticker = continuousViewportPushTicker;
    if (ticker == null || ticker.isActive) {
      return;
    }
    continuousViewportPushLastElapsed = Duration.zero;
    ticker.start();
  }

  double continuousViewportPushSpeedPxPerSec() {
    final pendingRows = continuousViewportPushRemainingRowExtents.length +
        queuedViewportInsertMessages.length;
    if (pendingRows <= 1) {
      return continuousViewportPushBasePixelsPerSecond;
    }
    final t = ((pendingRows - 1) / (continuousViewportPushSpeedRampRows - 1))
        .clamp(0.0, 1.0);
    return continuousViewportPushBasePixelsPerSecond +
        (continuousViewportPushMaxPixelsPerSecond -
                continuousViewportPushBasePixelsPerSecond) *
            t;
  }

  void consumeContinuousViewportPushTravel(double travel) {
    var remaining = travel;
    while (remaining > 0.5 &&
        continuousViewportPushRemainingRowExtents.isNotEmpty) {
      final head = continuousViewportPushRemainingRowExtents.first;
      if (remaining + 0.5 >= head) {
        remaining -= head;
        continuousViewportPushRemainingRowExtents.removeAt(0);
      } else {
        continuousViewportPushRemainingRowExtents[0] = head - remaining;
        remaining = 0;
      }
    }
  }

  void beginMediaSettleForKeys(Iterable<String> keys, {int? holdMs, int? nowMs}) {
    final until = (nowMs ?? DateTime.now().millisecondsSinceEpoch) +
        (holdMs ?? mediaSettleMs);
    for (final key in keys) {
      mediaSettleUntilMsByKey[key] = until;
    }
  }

  bool isMediaSettlingForKey(String key, [int? nowMs]) {
    final until = mediaSettleUntilMsByKey[key];
    if (until == null) {
      return false;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (now >= until) {
      mediaSettleUntilMsByKey.remove(key);
      return false;
    }
    return true;
  }

  bool hasAnyMediaSettling([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    mediaSettleUntilMsByKey.removeWhere((_, until) => now >= until);
    return mediaSettleUntilMsByKey.isNotEmpty;
  }
}
