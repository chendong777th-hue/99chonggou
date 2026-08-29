import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable_plus_plus/flutter_slidable_plus_plus.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// 列表竖滑默认 slop 约 18。侧滑必须更大，短距离竖滑才不会和左右滑抢手势。
const double kConversationSlidableTouchSlop = 36;

/// 累计横向位移达到该值、且明显大于纵向时，才懒建 ActionPane。
const double kConversationSlidableArmDistance = 18;

/// Web / 桌面会话行左右滑手感：更易跟手、更少被竖向微滚打断。
bool conversationSlidableUseWebFeel(BuildContext context) {
  return kIsWeb ||
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
}

bool conversationSlidableShouldArm({
  required double accumulatedDx,
  required double accumulatedDy,
  double armDistance = kConversationSlidableArmDistance,
}) {
  return accumulatedDx >= armDistance && accumulatedDx > accumulatedDy * 1.25;
}

bool conversationSlidableShouldRelease({
  required bool wasTickerActive,
  required bool tickerActive,
  required bool pointerCanceled,
}) =>
    pointerCanceled || (wasTickerActive && !tickerActive);

Widget applyConversationSlidableTouchSlop({required Widget child}) {
  return Builder(
    builder: (context) {
      final mq = MediaQuery.of(context);
      final current = mq.gestureSettings.touchSlop ?? kTouchSlop;
      if (current >= kConversationSlidableTouchSlop - 0.5) {
        return child;
      }
      return MediaQuery(
        data: mq.copyWith(
          gestureSettings: DeviceGestureSettings(
            touchSlop: kConversationSlidableTouchSlop,
          ),
        ),
        child: child,
      );
    },
  );
}

double conversationSlidableExtentRatio(
  int actionCount, {
  required bool webFeel,
}) {
  if (webFeel) {
    // 窄列表上缩短拖动行程，避免鼠标拖很远才露出按钮。
    if (actionCount <= 1) return 0.20;
    if (actionCount == 2) return 0.32;
    return 0.42;
  }
  if (actionCount <= 1) return 0.22;
  if (actionCount == 2) return 0.36;
  return 0.5;
}

ActionPane conversationActionPane({
  required List<Widget> children,
  required bool webFeel,
  double? extentRatio,
}) {
  final extent = extentRatio ??
      conversationSlidableExtentRatio(children.length, webFeel: webFeel);
  return ActionPane(
    extentRatio: extent,
    // BehindMotion 比 DrawerMotion 少一层嵌套变换，Web 跟手更稳。
    motion: webFeel ? const BehindMotion() : const DrawerMotion(),
    openThreshold: webFeel ? (extent * 0.38).clamp(0.08, 0.16) : null,
    closeThreshold: webFeel ? (extent * 0.28).clamp(0.06, 0.12) : null,
    children: children,
  );
}

/// 统一会话列表 [Slidable] 参数；Web 关闭 closeOnScroll，避免触控板微滚把面板关掉。
/// 外层 [ClipRect]：防止左滑行内容画出列表区域、穿进左侧导航栏。
Widget conversationSlidable({
  required BuildContext context,
  required Widget child,
  ActionPane? startActionPane,
  ActionPane? endActionPane,
  Object groupTag = 'conversation-list',
  bool enabled = true,
}) {
  return _ConversationSlidableLifecycle(
    groupTag: groupTag,
    enabled: enabled,
    startActionPane: startActionPane,
    endActionPane: endActionPane,
    child: child,
  );
}

class _ConversationSlidableLifecycle extends StatefulWidget {
  const _ConversationSlidableLifecycle({
    required this.groupTag,
    required this.enabled,
    required this.startActionPane,
    required this.endActionPane,
    required this.child,
  });

  final Object groupTag;
  final bool enabled;
  final ActionPane? startActionPane;
  final ActionPane? endActionPane;
  final Widget child;

  @override
  State<_ConversationSlidableLifecycle> createState() =>
      _ConversationSlidableLifecycleState();
}

class _ConversationSlidableLifecycleState
    extends State<_ConversationSlidableLifecycle>
    with SingleTickerProviderStateMixin {
  late final SlidableController _controller;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    _controller = SlidableController(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (conversationSlidableShouldRelease(
      wasTickerActive: _tickerActive,
      tickerActive: active,
      pointerCanceled: false,
    )) {
      _closeImmediately();
    }
    _tickerActive = active;
  }

  void _closeImmediately() {
    if (_controller.ratio != 0 && !_controller.closing) {
      _controller.close(duration: Duration.zero);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webFeel = conversationSlidableUseWebFeel(context);
    return ClipRect(
      child: applyConversationSlidableTouchSlop(
        child: Listener(
          onPointerCancel: (_) => _closeImmediately(),
          child: Slidable(
            controller: _controller,
            groupTag: widget.groupTag,
            enabled: widget.enabled,
            closeOnScroll: !webFeel,
            dragStartBehavior: DragStartBehavior.start,
            startActionPane: widget.startActionPane,
            endActionPane: widget.endActionPane,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
