import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable_plus_plus/flutter_slidable_plus_plus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_slidable.dart';

/// 会话行侧滑：可选懒构建 ActionPane，避免列表滚动时预建全部动作按钮。
Widget lazyConversationSlidable({
  required BuildContext context,
  required Widget child,
  required List<Widget>? Function() buildStartActions,
  required List<Widget> Function() buildEndActions,
  Object groupTag = 'conversation-list',
  bool enabled = true,
}) {
  if (!ConversationPerfFlags.lazyConversationSlidableActions) {
    final webFeel = conversationSlidableUseWebFeel(context);
    final start = buildStartActions();
    return conversationSlidable(
      context: context,
      child: child,
      groupTag: groupTag,
      enabled: enabled,
      startActionPane: start == null
          ? null
          : conversationActionPane(webFeel: webFeel, children: start),
      endActionPane: conversationActionPane(
        webFeel: webFeel,
        children: buildEndActions(),
      ),
    );
  }
  return _LazyConversationSlidable(
    buildStartActions: buildStartActions,
    buildEndActions: buildEndActions,
    groupTag: groupTag,
    enabled: enabled,
    child: child,
  );
}

class _LazyConversationSlidable extends StatefulWidget {
  const _LazyConversationSlidable({
    required this.child,
    required this.buildStartActions,
    required this.buildEndActions,
    required this.groupTag,
    required this.enabled,
  });

  final Widget child;
  final List<Widget>? Function() buildStartActions;
  final List<Widget> Function() buildEndActions;
  final Object groupTag;
  final bool enabled;

  @override
  State<_LazyConversationSlidable> createState() =>
      _LazyConversationSlidableState();
}

class _LazyConversationSlidableState extends State<_LazyConversationSlidable> {
  ActionPane? _startPane;
  ActionPane? _endPane;
  bool _actionsBuilt = false;
  double _accumulatedDx = 0;
  double _accumulatedDy = 0;

  @override
  void didUpdateWidget(covariant _LazyConversationSlidable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级 KeyedSubtree 在 pin/recvOpt 变化时会重建本 State；
    // 若未换 key 但 builder 变了，也丢掉缓存动作文案。
    if (!identical(oldWidget.buildEndActions, widget.buildEndActions) ||
        !identical(oldWidget.buildStartActions, widget.buildStartActions)) {
      _actionsBuilt = false;
      _startPane = null;
      _endPane = null;
    }
  }

  void _resetPointerAccum() {
    _accumulatedDx = 0;
    _accumulatedDy = 0;
  }

  void _ensureActionsBuilt() {
    if (_actionsBuilt || !mounted) {
      return;
    }
    _actionsBuilt = true;
    final webFeel = conversationSlidableUseWebFeel(context);
    final start = widget.buildStartActions();
    setState(() {
      _startPane = start == null
          ? null
          : conversationActionPane(webFeel: webFeel, children: start);
      _endPane = conversationActionPane(
        webFeel: webFeel,
        children: widget.buildEndActions(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final webFeel = conversationSlidableUseWebFeel(context);
    return ClipRect(
      child: applyConversationSlidableTouchSlop(
        child: Listener(
          onPointerDown: (_) => _resetPointerAccum(),
          onPointerCancel: (_) => _resetPointerAccum(),
          onPointerUp: (_) => _resetPointerAccum(),
          onPointerMove: (event) {
            if (_actionsBuilt) {
              return;
            }
            _accumulatedDx += event.delta.dx.abs();
            _accumulatedDy += event.delta.dy.abs();
            if (conversationSlidableShouldArm(
              accumulatedDx: _accumulatedDx,
              accumulatedDy: _accumulatedDy,
            )) {
              _ensureActionsBuilt();
            }
          },
          child: Slidable(
            groupTag: widget.groupTag,
            enabled: widget.enabled,
            closeOnScroll: !webFeel,
            dragStartBehavior: DragStartBehavior.start,
            startActionPane: _startPane,
            endActionPane: _endPane ??
                ActionPane(
                  extentRatio:
                      conversationSlidableExtentRatio(3, webFeel: webFeel),
                  motion: webFeel ? const BehindMotion() : const DrawerMotion(),
                  children: <Widget>[
                    CustomSlidableAction(
                      onPressed: (_) => _ensureActionsBuilt(),
                      backgroundColor: Colors.transparent,
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
