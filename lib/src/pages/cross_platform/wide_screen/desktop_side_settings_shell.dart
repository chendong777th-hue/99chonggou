import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// Web / 桌面会话右侧「设置」侧栏：贴右全高，从右侧滑入（非居中弹窗）。
class DesktopSideSettingsShell extends StatelessWidget {
  const DesktopSideSettingsShell({
    super.key,
    required this.theme,
    required this.width,
    required this.title,
    required this.onClose,
    required this.child,
    this.visible = true,
  });

  final TUITheme theme;
  final double width;
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final bg = theme.wideBackgroundColor ?? const Color(0xFFFFFFFF);
    final headerBg = theme.appbarBgColor ?? bg;
    final textColor = theme.darkTextColor ?? const Color(0xFF111827);
    final weak = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final line = theme.weakDividerColor ?? const Color(0xFFE8EAED);

    return AnimatedPositioned(
      right: visible ? 0 : -width,
      top: 0,
      bottom: 0,
      width: width,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !visible,
        child: Material(
          color: bg,
          elevation: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                left: BorderSide(color: line.withValues(alpha: 0.9)),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B1220).withValues(alpha: 0.12),
                  offset: const Offset(-6, 0),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(
                      bottom: BorderSide(color: line.withValues(alpha: 0.85)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onClose,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 22,
                              color: weak,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
