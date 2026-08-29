import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum ChatHistoryOpeningPlaceholderPhase {
  inactive,
  waiting,
  visible,
  dismissing,
  removed,
}

/// Pure policy for the one-shot placeholder shown during an ordinary cold open.
class ChatHistoryOpeningPlaceholderPolicy {
  const ChatHistoryOpeningPlaceholderPolicy._();

  static bool shouldArm({
    required int initialMessageCount,
    required bool initialHistoryLoaded,
    required bool isSearchJump,
    required bool hasLockedEntryUnread,
  }) {
    return initialMessageCount <= 0 &&
        !initialHistoryLoaded &&
        !isSearchJump &&
        !hasLockedEntryUnread;
  }

  static bool shouldShowAfterDelay({
    required int messageCount,
    required bool initialHistoryLoaded,
    required bool revealPainted,
    required bool isSearchJump,
    required bool hasLockedEntryUnread,
  }) {
    return messageCount <= 0 &&
        !initialHistoryLoaded &&
        !revealPainted &&
        !isSearchJump &&
        !hasLockedEntryUnread;
  }
}

/// Keeps delayed callbacks and fade completions scoped to one conversation open.
class ChatHistoryOpeningPlaceholderController {
  int _generation = 0;
  ChatHistoryOpeningPlaceholderPhase _phase =
      ChatHistoryOpeningPlaceholderPhase.inactive;

  int get generation => _generation;
  ChatHistoryOpeningPlaceholderPhase get phase => _phase;
  bool get shouldPaint =>
      _phase == ChatHistoryOpeningPlaceholderPhase.visible ||
      _phase == ChatHistoryOpeningPlaceholderPhase.dismissing;

  int begin({
    required int initialMessageCount,
    required bool initialHistoryLoaded,
    required bool isSearchJump,
    required bool hasLockedEntryUnread,
  }) {
    _generation++;
    _phase = ChatHistoryOpeningPlaceholderPolicy.shouldArm(
      initialMessageCount: initialMessageCount,
      initialHistoryLoaded: initialHistoryLoaded,
      isSearchJump: isSearchJump,
      hasLockedEntryUnread: hasLockedEntryUnread,
    )
        ? ChatHistoryOpeningPlaceholderPhase.waiting
        : ChatHistoryOpeningPlaceholderPhase.inactive;
    return _generation;
  }

  bool showAfterDelay({
    required int generation,
    required int messageCount,
    required bool initialHistoryLoaded,
    required bool revealPainted,
    required bool isSearchJump,
    required bool hasLockedEntryUnread,
  }) {
    if (generation != _generation ||
        _phase != ChatHistoryOpeningPlaceholderPhase.waiting) {
      return false;
    }
    final shouldShow = ChatHistoryOpeningPlaceholderPolicy.shouldShowAfterDelay(
      messageCount: messageCount,
      initialHistoryLoaded: initialHistoryLoaded,
      revealPainted: revealPainted,
      isSearchJump: isSearchJump,
      hasLockedEntryUnread: hasLockedEntryUnread,
    );
    if (!shouldShow) {
      _phase = ChatHistoryOpeningPlaceholderPhase.removed;
      return false;
    }
    _phase = ChatHistoryOpeningPlaceholderPhase.visible;
    return true;
  }

  /// Returns true when a visible placeholder needs a fade-out animation.
  bool beginDismiss(int generation) {
    if (generation != _generation) {
      return false;
    }
    if (_phase == ChatHistoryOpeningPlaceholderPhase.visible) {
      _phase = ChatHistoryOpeningPlaceholderPhase.dismissing;
      return true;
    }
    if (_phase == ChatHistoryOpeningPlaceholderPhase.waiting) {
      _phase = ChatHistoryOpeningPlaceholderPhase.removed;
    }
    return false;
  }

  bool finishDismiss(int generation) {
    if (generation != _generation ||
        _phase != ChatHistoryOpeningPlaceholderPhase.dismissing) {
      return false;
    }
    _phase = ChatHistoryOpeningPlaceholderPhase.removed;
    return true;
  }
}

/// 进页消息区静态气泡骨架；按可用高度裁剪，不随历史长度变化。
class ChatMessageListSkeleton extends StatelessWidget {
  const ChatMessageListSkeleton({
    super.key,
    this.theme,
    this.bubbleColor,
    this.showAvatars = true,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 16),
  });

  final TUITheme? theme;
  final Color? bubbleColor;
  final bool showAvatars;
  final EdgeInsets padding;

  static const List<_SkeletonBubbleSpec> _rows = <_SkeletonBubbleSpec>[
    _SkeletonBubbleSpec(mine: false, widthFactor: 0.42, height: 36),
    _SkeletonBubbleSpec(mine: true, widthFactor: 0.55, height: 36),
    _SkeletonBubbleSpec(mine: false, widthFactor: 0.68, height: 48),
    _SkeletonBubbleSpec(mine: true, widthFactor: 0.38, height: 36),
    _SkeletonBubbleSpec(mine: false, widthFactor: 0.50, height: 36),
    _SkeletonBubbleSpec(mine: true, widthFactor: 0.62, height: 44),
    _SkeletonBubbleSpec(mine: false, widthFactor: 0.34, height: 36),
  ];

  Color _resolveBubbleColor(BuildContext context) {
    if (bubbleColor != null) {
      return bubbleColor!;
    }
    final fromTheme = theme?.weakDividerColor ?? theme?.weakTextColor;
    if (fromTheme != null) {
      return fromTheme.withValues(alpha: 0.22);
    }
    final scheme = Theme.of(context).colorScheme;
    return scheme.onSurface.withValues(alpha: 0.10);
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveBubbleColor(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boundedWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final avatarSpace = showAvatars ? 40.0 : 0.0;
              final availableBubbleWidth = (boundedWidth - avatarSpace)
                  .clamp(0.0, boundedWidth)
                  .toDouble();
              final maxBubbleWidth = availableBubbleWidth * 0.78;
              final rows = _rowsThatFit(constraints.maxHeight);
              if (rows.isEmpty) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < rows.length; index++) ...[
                      _SkeletonBubbleRow(
                        key: ValueKey<String>(
                          'chat_opening_placeholder_row_$index',
                        ),
                        index: index,
                        spec: rows[index],
                        color: color,
                        maxBubbleWidth: maxBubbleWidth,
                        showAvatar: showAvatars,
                      ),
                      if (index != rows.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static List<_SkeletonBubbleSpec> _rowsThatFit(double maxHeight) {
    if (!maxHeight.isFinite) {
      return _rows;
    }
    final result = <_SkeletonBubbleSpec>[];
    var usedHeight = 0.0;
    for (final row in _rows) {
      final nextHeight = row.height + (result.isEmpty ? 0 : 12);
      if (usedHeight + nextHeight > maxHeight) {
        break;
      }
      result.add(row);
      usedHeight += nextHeight;
    }
    return result;
  }
}

class _SkeletonBubbleSpec {
  const _SkeletonBubbleSpec({
    required this.mine,
    required this.widthFactor,
    required this.height,
  });

  final bool mine;
  final double widthFactor;
  final double height;
}

class _SkeletonBubbleRow extends StatelessWidget {
  const _SkeletonBubbleRow({
    super.key,
    required this.index,
    required this.spec,
    required this.color,
    required this.maxBubbleWidth,
    required this.showAvatar,
  });

  final int index;
  final _SkeletonBubbleSpec spec;
  final Color color;
  final double maxBubbleWidth;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final minBubbleWidth = maxBubbleWidth < 72 ? maxBubbleWidth : 72.0;
    final bubble = Container(
      width: (maxBubbleWidth * spec.widthFactor)
          .clamp(minBubbleWidth, maxBubbleWidth),
      height: spec.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
    if (spec.mine) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [bubble],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (showAvatar) ...[
          Container(
            key: ValueKey<String>(
              'chat_opening_placeholder_avatar_$index',
            ),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bubble,
      ],
    );
  }
}
