import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'chat_jitter_diag.dart';

/// 把一次性任务推迟到所在子树的 [TickerMode] 打开之后再执行。
///
/// 聊天页在进场转场期间用 `TickerMode(enabled: false)` 包裹内容，转场结束
/// 后才打开。媒体气泡（图片/视频）如果在 `initState` 里立刻发起在线信息
/// 回填并 `setState`，正好落在转场动画中间，会造成气泡尺寸/内容中途变化
/// （进入聊天页头像和图片视频气泡抖动的来源之一）。挂上本 mixin 后用
/// [runWhenTickerEnabled] 调度，可保证任务在转场结束后才跑；若子树没有被
/// TickerMode 关闭（例如非转场场景），任务立即执行，行为不变。
mixin TickerSettledTaskMixin<T extends StatefulWidget> on State<T> {
  ValueListenable<bool>? _tickerSettledNotifier;
  VoidCallback? _tickerSettledListener;

  /// TickerMode 已打开则立即执行 [task]；否则等它打开后执行一次。
  /// 重复调用会覆盖上一个尚未执行的任务。
  void runWhenTickerEnabled(VoidCallback task, {String? debugLabel}) {
    if (!mounted) {
      return;
    }
    final notifier = TickerMode.getNotifier(context);
    if (notifier.value) {
      ChatJitterDiag.logTickerTask(
        widget: debugLabel ?? runtimeType.toString(),
        tickerEnabled: true,
        deferred: false,
      );
      task();
      return;
    }
    ChatJitterDiag.logTickerTask(
      widget: debugLabel ?? runtimeType.toString(),
      tickerEnabled: false,
      deferred: true,
    );
    _clearTickerSettledListener();
    _tickerSettledNotifier = notifier;
    _tickerSettledListener = () {
      if (!(_tickerSettledNotifier?.value ?? true)) {
        return;
      }
      _clearTickerSettledListener();
      if (mounted) {
        ChatJitterDiag.logTickerTask(
          widget: debugLabel ?? runtimeType.toString(),
          tickerEnabled: true,
          deferred: false,
        );
        task();
      }
    };
    notifier.addListener(_tickerSettledListener!);
  }

  void _clearTickerSettledListener() {
    final listener = _tickerSettledListener;
    final notifier = _tickerSettledNotifier;
    if (listener != null && notifier != null) {
      notifier.removeListener(listener);
    }
    _tickerSettledListener = null;
    _tickerSettledNotifier = null;
  }

  @override
  void dispose() {
    _clearTickerSettledListener();
    super.dispose();
  }
}

/// 不依赖 [TickerSettledTaskMixin] 时，用 [context] 所在子树调度一次性任务。
void scheduleWhenTickerEnabled(
  BuildContext context,
  VoidCallback task, {
  String? debugLabel,
}) {
  final notifier = TickerMode.getNotifier(context);
  if (notifier.value) {
    ChatJitterDiag.logTickerTask(
      widget: debugLabel ?? 'scheduleWhenTickerEnabled',
      tickerEnabled: true,
      deferred: false,
    );
    task();
    return;
  }
  ChatJitterDiag.logTickerTask(
    widget: debugLabel ?? 'scheduleWhenTickerEnabled',
    tickerEnabled: false,
    deferred: true,
  );
  late VoidCallback listener;
  listener = () {
    if (!notifier.value) {
      return;
    }
    notifier.removeListener(listener);
    ChatJitterDiag.logTickerTask(
      widget: debugLabel ?? 'scheduleWhenTickerEnabled',
      tickerEnabled: true,
      deferred: false,
    );
    task();
  };
  notifier.addListener(listener);
}
