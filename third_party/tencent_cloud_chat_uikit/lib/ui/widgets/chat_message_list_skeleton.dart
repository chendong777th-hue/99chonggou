import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 进页消息区静态气泡骨架（固定条数，不随历史长度变化）。
class ChatMessageListSkeleton extends StatelessWidget {
  const ChatMessageListSkeleton({
    super.key,
    this.theme,
    this.bubbleColor,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 16),
  });

  final TUITheme? theme;
  final Color? bubbleColor;
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
    return IgnorePointer(
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxBubbleWidth = constraints.maxWidth * 0.78;
            return Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in _rows) ...[
                    _SkeletonBubbleRow(
                      spec: row,
                      color: color,
                      maxBubbleWidth: maxBubbleWidth,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
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
    required this.spec,
    required this.color,
    required this.maxBubbleWidth,
  });

  final _SkeletonBubbleSpec spec;
  final Color color;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      width: (maxBubbleWidth * spec.widthFactor).clamp(72.0, maxBubbleWidth),
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
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        bubble,
      ],
    );
  }
}
