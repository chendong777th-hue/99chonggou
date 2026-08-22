import 'package:flutter/material.dart';

/// 群聊头部导航下方的公告跑马灯。
///
/// 文本超出可视宽度时无缝循环滚动；未超出则静态左对齐显示。
class GroupNoticeMarquee extends StatefulWidget {
  const GroupNoticeMarquee({
    super.key,
    required this.text,
    this.onTap,
    this.onClose,
    this.label = '群公告：',
    this.backgroundColor = const Color(0xFFFFF7E3),
    this.textColor = const Color(0xFF8A6417),
    this.velocity = 42.0,
  });

  /// 公告内容（会自动去除首尾空白并把换行折叠为空格）。
  final String text;

  /// 点击文本区时的回调（一般用于展开完整公告）。
  final VoidCallback? onTap;

  /// 点击右侧关闭按钮时的回调；为 null 时不显示关闭按钮。
  final VoidCallback? onClose;

  /// 公告正文前的固定标签，如「群公告：」。
  final String label;

  final Color backgroundColor;
  final Color textColor;

  /// 滚动速度，单位：逻辑像素/秒。
  final double velocity;

  @override
  State<GroupNoticeMarquee> createState() => _GroupNoticeMarqueeState();
}

class _GroupNoticeMarqueeState extends State<GroupNoticeMarquee>
    with SingleTickerProviderStateMixin {
  static const double _gap = 56;
  static const double _height = 20;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _normalizedText =>
      widget.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _syncAnimation(bool shouldScroll, Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!shouldScroll) {
        if (_controller.isAnimating) {
          _controller.stop();
        }
        return;
      }
      if (_controller.duration != duration) {
        _controller.duration = duration;
        _controller
          ..reset()
          ..repeat();
      } else if (!_controller.isAnimating) {
        _controller
          ..reset()
          ..repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _normalizedText;
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final textStyle = TextStyle(
      color: widget.textColor,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w500,
    );
    final labelStyle = textStyle.copyWith(fontWeight: FontWeight.w600);

    return Material(
      color: widget.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: Row(
                  children: [
                    Text(widget.label, style: labelStyle),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: _height,
                        child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final painter = TextPainter(
                        text: TextSpan(text: text, style: textStyle),
                        maxLines: 1,
                        textDirection: Directionality.of(context),
                      )..layout();
                      final textWidth = painter.width;
                      final shouldScroll =
                          maxWidth > 0 && textWidth > maxWidth + 0.5;

                      if (!shouldScroll) {
                        _syncAnimation(false, Duration.zero);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle,
                          ),
                        );
                      }

                      final loopWidth = textWidth + _gap;
                      final durationMs = (loopWidth / widget.velocity * 1000)
                          .round()
                          .clamp(2500, 60000);
                      _syncAnimation(
                        true,
                        Duration(milliseconds: durationMs),
                      );

                      final line = Text(
                        text,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: textStyle,
                      );

                      return ClipRect(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(-_controller.value * loopWidth, 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              line,
                              const SizedBox(width: _gap),
                              line,
                            ],
                          ),
                        ),
                      );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onClose != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: widget.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
