import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/sangong_ledger_float_prefs.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_game_float_geometry.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 用户资料页可拖拽浮窗：查看三公流水。
///
/// 固定圆形「流」按钮；拖动结束后左右吸边。返回 [Positioned]，需放在 [Stack] 中。
class UserProfileGameLedgerFloatingEntry extends StatefulWidget {
  const UserProfileGameLedgerFloatingEntry({
    super.key,
    required this.theme,
    required this.onOpenLedger,
  });

  final TUITheme theme;
  final VoidCallback onOpenLedger;

  static const Color _accent = Color(0xFF1677FF);
  static const Size _size = Size(58, 58);

  @override
  State<UserProfileGameLedgerFloatingEntry> createState() =>
      _UserProfileGameLedgerFloatingEntryState();
}

class _UserProfileGameLedgerFloatingEntryState
    extends State<UserProfileGameLedgerFloatingEntry> {
  final GlobalKey _panelKey = GlobalKey();

  Offset? _offset;
  Size _childSize = UserProfileGameLedgerFloatingEntry._size;
  bool _dragging = false;
  bool _prefsLoaded = false;
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    unawaited(_restorePrefs());
  }

  Future<void> _restorePrefs() async {
    final saved = await SangongLedgerFloatPrefs.instance.readOffset();
    if (!mounted) {
      return;
    }
    final media = MediaQuery.of(context);
    const childSize = UserProfileGameLedgerFloatingEntry._size;
    final base = saved ??
        defaultGroupGameFloatOffset(
          screenSize: media.size,
          childSize: childSize,
          bottomInset: media.viewPadding.bottom,
        );
    final next = snapGroupGameFloatOffsetToHorizontalEdge(
      offset: base,
      screenSize: media.size,
      childSize: childSize,
      viewPadding: media.viewPadding,
    );
    setState(() {
      _childSize = childSize;
      _offset = next;
      _prefsLoaded = true;
    });
    if (saved == null ||
        (saved.dx - next.dx).abs() > 0.5 ||
        (saved.dy - next.dy).abs() > 0.5) {
      unawaited(SangongLedgerFloatPrefs.instance.writeOffset(next));
    }
  }

  void _measureChildIfNeeded() {
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final size = box.size;
    if ((size.width - _childSize.width).abs() < 0.5 &&
        (size.height - _childSize.height).abs() < 0.5) {
      return;
    }
    final media = MediaQuery.of(context);
    final base = _offset ??
        defaultGroupGameFloatOffset(
          screenSize: media.size,
          childSize: size,
          bottomInset: media.viewPadding.bottom,
        );
    setState(() {
      _childSize = size;
      _offset = snapGroupGameFloatOffsetToHorizontalEdge(
        offset: base,
        screenSize: media.size,
        childSize: size,
        viewPadding: media.viewPadding,
      );
    });
  }

  void _ensureClampedForScreen(Size screenSize, EdgeInsets viewPadding) {
    if (_lastScreenSize == screenSize && _offset != null) {
      return;
    }
    _lastScreenSize = screenSize;
    final base = _offset ??
        defaultGroupGameFloatOffset(
          screenSize: screenSize,
          childSize: _childSize,
          bottomInset: viewPadding.bottom,
        );
    final next = snapGroupGameFloatOffsetToHorizontalEdge(
      offset: base,
      screenSize: screenSize,
      childSize: _childSize,
      viewPadding: viewPadding,
    );
    if (_offset != next) {
      _offset = next;
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragging = true;
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    Size screenSize,
    EdgeInsets padding,
  ) {
    if (!_dragging) {
      return;
    }
    final current = _offset ??
        defaultGroupGameFloatOffset(
          screenSize: screenSize,
          childSize: _childSize,
          bottomInset: padding.bottom,
        );
    setState(() {
      _offset = clampGroupGameFloatOffset(
        offset: current + details.delta,
        screenSize: screenSize,
        childSize: _childSize,
        viewPadding: padding,
      );
    });
  }

  void _snapAndPersist(Size screenSize, EdgeInsets padding) {
    final current = _offset;
    if (current == null) {
      return;
    }
    final snapped = snapGroupGameFloatOffsetToHorizontalEdge(
      offset: current,
      screenSize: screenSize,
      childSize: _childSize,
      viewPadding: padding,
    );
    setState(() {
      _dragging = false;
      _offset = snapped;
    });
    unawaited(SangongLedgerFloatPrefs.instance.writeOffset(snapped));
  }

  void _onPanEnd(DragEndDetails details, Size screenSize, EdgeInsets padding) {
    _snapAndPersist(screenSize, padding);
  }

  void _onPanCancel(Size screenSize, EdgeInsets padding) {
    _snapAndPersist(screenSize, padding);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _ensureClampedForScreen(media.size, media.viewPadding);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measureChildIfNeeded();
      }
    });

    final offset = _offset ??
        defaultGroupGameFloatOffset(
          screenSize: media.size,
          childSize: _childSize,
          bottomInset: media.viewPadding.bottom,
        );

    final i18n = AppI18n.of(context);
    final primary =
        widget.theme.primaryColor ?? UserProfileGameLedgerFloatingEntry._accent;
    final isDark =
        (widget.theme.weakBackgroundColor ?? Colors.white).computeLuminance() <
            0.5;

    return AnimatedPositioned(
      duration: _dragging
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onPanStart: _onPanStart,
        onPanUpdate: (details) =>
            _onPanUpdate(details, media.size, media.viewPadding),
        onPanEnd: (details) =>
            _onPanEnd(details, media.size, media.viewPadding),
        onPanCancel: () => _onPanCancel(media.size, media.viewPadding),
        child: KeyedSubtree(
          key: _panelKey,
          child: Tooltip(
            message: i18n.t(zhHans: '流水', zhHant: '流水', en: 'Ledger'),
            child: Material(
              color: isDark ? const Color(0xFF2A2A2E) : Colors.white,
              shape: const CircleBorder(),
              elevation: _dragging ? 10 : 6,
              shadowColor: isDark ? Colors.black87 : Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _dragging || !_prefsLoaded
                    ? null
                    : widget.onOpenLedger,
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Center(
                    child: Text(
                      i18n.t(zhHans: '流', zhHant: '流', en: 'L'),
                      style: TextStyle(
                        fontSize: 24,
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
