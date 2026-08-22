import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_select_emoji.dart';

/// 表情条沿用浅色毛玻璃；操作菜单对齐微信深色横向面板。
const Color _kTelegramMenuBackgroundColor = Color(0xE6F2F2F7);
const Color _kWeChatActionMenuBackgroundColor = Color(0xE64C4C4C);

/// Resolved layout for Telegram-style mobile context menu.
class TelegramMobileContextMenuLayout {
  final double menuTop;
  final double? menuMaxHeight;
  final double? menuLeft;
  final double? menuRight;
  final double? reactionTop;
  final double reactionLeft;
  final bool menuBelowBubble;

  const TelegramMobileContextMenuLayout({
    required this.menuTop,
    required this.menuMaxHeight,
    required this.menuLeft,
    required this.menuRight,
    required this.reactionTop,
    required this.reactionLeft,
    required this.menuBelowBubble,
  });
}

/// Telegram-style placement:
/// - Reactions sit above the bubble top (or above the menu when flipped).
/// - Menu prefers below the bubble; flips above when bottom space is tight.
/// - The whole stack shifts vertically to stay inside [safeTop, safeBottom].
TelegramMobileContextMenuLayout resolveTelegramMobileContextMenuLayout({
  required Rect bubbleAnchor,
  required bool isSelf,
  required double screenWidth,
  required double safeTop,
  required double safeBottom,
  required double menuWidth,
  required double menuHeight,
  required bool showReactionBar,
  double reactionBarHeight = TIMUIKitMessageTooltipState.mobileTelegramReactionBarHeight,
  double gap = 8,
  double edgePadding = 8,
}) {
  final reactionBlock = showReactionBar ? reactionBarHeight + gap : 0.0;

  final spaceBelowMenu = safeBottom - bubbleAnchor.bottom - gap;
  final spaceAboveMenu = bubbleAnchor.top - safeTop - gap;
  final roomBelow = spaceBelowMenu >= menuHeight;
  final roomAbove = spaceAboveMenu >= menuHeight + reactionBlock;

  late final bool menuBelowBubble;
  if (roomBelow && !roomAbove) {
    menuBelowBubble = true;
  } else if (roomAbove && !roomBelow) {
    menuBelowBubble = false;
  } else if (roomBelow && roomAbove) {
    menuBelowBubble = spaceBelowMenu >= spaceAboveMenu;
  } else {
    menuBelowBubble = spaceBelowMenu >= spaceAboveMenu;
  }

  double menuTop;
  double? reactionTop;

  if (menuBelowBubble) {
    menuTop = bubbleAnchor.bottom + gap;
    reactionTop = showReactionBar
        ? bubbleAnchor.top - reactionBarHeight - gap
        : null;
  } else {
    menuTop = bubbleAnchor.top - gap - menuHeight;
    reactionTop =
        showReactionBar ? menuTop - reactionBarHeight - gap : null;
  }

  if (!menuBelowBubble) {
    final maxMenuBottom = bubbleAnchor.top - gap;
    if (menuTop + menuHeight > maxMenuBottom) {
      menuTop = maxMenuBottom - menuHeight;
    }
    if (showReactionBar && reactionTop != null) {
      reactionTop = menuTop - reactionBarHeight - gap;
      if (reactionTop < safeTop) {
        reactionTop = safeTop;
        menuTop = reactionTop + reactionBarHeight + gap;
      }
    }
    if (menuTop < safeTop) {
      menuTop = safeTop;
      if (showReactionBar) {
        reactionTop = max(safeTop, menuTop - reactionBarHeight - gap);
      }
    }
  } else {
    final stackTop = reactionTop ?? menuTop;
    final stackBottom = menuTop + menuHeight;
    var shift = 0.0;
    if (stackTop < safeTop) {
      shift = safeTop - stackTop;
    } else if (stackBottom > safeBottom) {
      shift = safeBottom - stackBottom;
    }

    menuTop += shift;
    if (reactionTop != null) {
      reactionTop += shift;
    }
  }

  double? menuMaxHeight;
  if (!menuBelowBubble) {
    final maxMenuBottom = bubbleAnchor.top - gap;
    if (menuTop + menuHeight > maxMenuBottom) {
      menuTop = max(safeTop, maxMenuBottom - menuHeight);
    }
    if (menuTop + menuHeight > maxMenuBottom) {
      menuMaxHeight = max(120, maxMenuBottom - menuTop);
    }
  } else {
    if (menuTop < safeTop) {
      menuTop = safeTop;
    }
    final availableMenuHeight = safeBottom - menuTop;
    if (availableMenuHeight < menuHeight) {
      menuMaxHeight = max(120, availableMenuHeight);
    }
  }

  if (reactionTop != null) {
    reactionTop = max(safeTop, reactionTop);
    if (reactionTop + reactionBarHeight > menuTop - gap) {
      reactionTop = max(safeTop, menuTop - reactionBarHeight - gap);
    }
  }

  final menuLeft = isSelf
      ? null
      : bubbleAnchor.left.clamp(edgePadding, screenWidth - menuWidth - edgePadding);
  final menuRight = isSelf
      ? (screenWidth - bubbleAnchor.right)
          .clamp(edgePadding, screenWidth - menuWidth - edgePadding)
      : null;
  final reactionLeft =
      bubbleAnchor.left.clamp(edgePadding, screenWidth - menuWidth - edgePadding);

  return TelegramMobileContextMenuLayout(
    menuTop: menuTop,
    menuMaxHeight: menuMaxHeight,
    menuLeft: menuLeft,
    menuRight: menuRight,
    reactionTop: reactionTop,
    reactionLeft: reactionLeft,
    menuBelowBubble: menuBelowBubble,
  );
}

/// Telegram-style mobile long-press menu: quick reactions + action sheet.
class MobileTelegramMessageContextMenu extends StatefulWidget {
  final Rect anchorRect;
  final bool isSelf;
  final V2TimMessage message;
  final TUIChatSeparateViewModel model;
  final ToolTipsConfig? toolTipsConfig;
  final int estimatedMenuItemCount;
  final double safeTop;
  final double safeBottom;
  final bool allowAtUserWhenReply;
  final bool showQuickReactionBar;
  final Function(String? userId, String? nickName)? onLongPressForOthersHeadPortrait;
  final Function(String? userId, String? nickName)? onAtUserWhenReply;
  final V2TimGroupMemberFullInfo? groupMemberInfo;
  final bool iSUseDefaultHoverBar;
  final VoidCallback onClose;
  final ValueChanged<int> onSelectSticker;

  /// When non-null, super-long-text mode: the full bubble snapshot scrolls
  /// together with the action menu below it (reaction bar stays pinned on top).
  final ui.Image? scrollableBubbleImage;
  final double? longPressGlobalY;
  final Rect? fullContentRect;
  final Animation<double>? presentOpacity;
  final Animation<double>? presentScale;

  const MobileTelegramMessageContextMenu({
    super.key,
    required this.anchorRect,
    required this.isSelf,
    required this.message,
    required this.model,
    required this.onClose,
    required this.onSelectSticker,
    required this.safeTop,
    required this.safeBottom,
    this.toolTipsConfig,
    this.estimatedMenuItemCount = 8,
    this.allowAtUserWhenReply = true,
    this.showQuickReactionBar = true,
    this.onLongPressForOthersHeadPortrait,
    this.onAtUserWhenReply,
    this.groupMemberInfo,
    this.iSUseDefaultHoverBar = false,
    this.scrollableBubbleImage,
    this.longPressGlobalY,
    this.fullContentRect,
    this.presentOpacity,
    this.presentScale,
  });

  @override
  State<MobileTelegramMessageContextMenu> createState() =>
      _MobileTelegramMessageContextMenuState();
}

class _MobileTelegramMessageContextMenuState
    extends State<MobileTelegramMessageContextMenu> {
  final GlobalKey _menuMeasureKey = GlobalKey();
  final GlobalKey _reactionMeasureKey = GlobalKey();
  double? _measuredMenuHeight;
  double? _measuredReactionHeight;
  ScrollController? _comboScrollController;

  @override
  void initState() {
    super.initState();
    if (widget.scrollableBubbleImage != null) {
      _comboScrollController = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealInitialScroll());
    }
    WidgetsBinding.instance.addPostFrameCallback(_remeasure);
  }

  void _revealInitialScroll() {
    if (!mounted) {
      return;
    }
    final controller = _comboScrollController;
    if (controller == null || !controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealInitialScroll());
      return;
    }

    const gap = 8.0;
    final reactionBarHeight =
        TIMUIKitMessageTooltipState.mobileTelegramReactionBarHeight;
    final showReaction = widget.showQuickReactionBar;
    final reactionBlock = showReaction ? reactionBarHeight + gap : 0.0;
    final scrollTop = widget.safeTop + reactionBlock;
    final scrollBottom = widget.safeBottom;
    final viewportHeight = max(0.0, scrollBottom - scrollTop);

    final image = widget.scrollableBubbleImage!;
    final bubbleWidth = widget.anchorRect.width;
    final bubbleHeight = image.width > 0
        ? bubbleWidth * image.height / image.width
        : widget.anchorRect.height;
    final menuHeight = _measuredMenuHeight ??
        TIMUIKitMessageTooltipState.estimateTelegramActionMenuHeight(
          widget.estimatedMenuItemCount,
        );
    final totalContentHeight = bubbleHeight + gap + menuHeight + gap;
    final maxScroll = max(0.0, totalContentHeight - viewportHeight);

    double targetOffset = maxScroll;
    final pressY = widget.longPressGlobalY;
    final fullRect = widget.fullContentRect;
    if (pressY != null && fullRect != null && fullRect.height > 0) {
      final pressOffsetInBubble =
          (pressY - fullRect.top).clamp(0.0, bubbleHeight);
      final menuReserve = menuHeight + gap * 2;
      final visibleForBubble = max(0.0, viewportHeight - menuReserve);
      final centeredOffset = pressOffsetInBubble - visibleForBubble * 0.35;
      final menuVisibleOffset =
          max(0.0, bubbleHeight + gap + menuHeight - viewportHeight);
      targetOffset = centeredOffset;
      if (targetOffset < menuVisibleOffset) {
        targetOffset = menuVisibleOffset;
      }
      if (targetOffset > maxScroll) {
        targetOffset = maxScroll;
      }
    }

    if ((controller.offset - targetOffset).abs() > 0.5) {
      controller.jumpTo(targetOffset);
    }
  }

  final DateTime _openedAt = DateTime.now();

  void _dismissOnBlankTap() {
    // Mirror the controller's open guard so the long-press release doesn't
    // immediately close the freshly opened menu.
    if (DateTime.now().difference(_openedAt) <
        const Duration(milliseconds: 320)) {
      return;
    }
    widget.onClose();
  }

  @override
  void dispose() {
    _comboScrollController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MobileTelegramMessageContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorRect != widget.anchorRect ||
        oldWidget.estimatedMenuItemCount != widget.estimatedMenuItemCount) {
      WidgetsBinding.instance.addPostFrameCallback(_remeasure);
    }
  }

  void _remeasure(_) {
    if (!mounted) {
      return;
    }
    final menuBox =
        _menuMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    final reactionBox =
        _reactionMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    final menuHeight = menuBox?.hasSize == true ? menuBox!.size.height : null;
    final reactionHeight =
        reactionBox?.hasSize == true ? reactionBox!.size.height : null;

    final menuChanged = menuHeight != null &&
        (_measuredMenuHeight == null ||
            (menuHeight - _measuredMenuHeight!).abs() > 0.5);
    final reactionChanged = reactionHeight != null &&
        (_measuredReactionHeight == null ||
            (reactionHeight - _measuredReactionHeight!).abs() > 0.5);

    if (menuChanged || reactionChanged) {
      setState(() {
        _measuredMenuHeight = menuHeight ?? _measuredMenuHeight;
        _measuredReactionHeight = reactionHeight ?? _measuredReactionHeight;
      });
      if (widget.scrollableBubbleImage != null && menuChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealInitialScroll());
      }
      WidgetsBinding.instance.addPostFrameCallback(_remeasure);
    }
  }

  void _handleClose() {
    widget.onClose();
  }

  TIMUIKitMessageTooltip _buildTooltip({
    required TelegramMobileTooltipLayout layout,
    double? menuMaxHeight,
  }) {
    return TIMUIKitMessageTooltip(
      model: widget.model,
      message: widget.message,
      allowAtUserWhenReply: widget.allowAtUserWhenReply,
      onLongPressForOthersHeadPortrait: widget.onLongPressForOthersHeadPortrait,
      onAtUserWhenReply: widget.onAtUserWhenReply,
      groupMemberInfo: widget.groupMemberInfo,
      iSUseDefaultHoverBar: widget.iSUseDefaultHoverBar,
      toolTipsConfig: widget.toolTipsConfig,
      isUseMessageReaction: widget.showQuickReactionBar,
      isShowMoreSticker: false,
      selectEmojiPanelPosition: SelectEmojiPanelPosition.up,
      onCloseTooltip: _handleClose,
      onSelectSticker: (value) {
        widget.onSelectSticker(value);
        _handleClose();
      },
      mobileLayout: layout,
      mobileMenuMaxHeight: menuMaxHeight,
    );
  }

  Widget _applyPresent(Widget child) {
    final opacity = widget.presentOpacity;
    final scale = widget.presentScale;
    if (opacity == null || scale == null) {
      return child;
    }
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }

  /// iOS-Notes-style super-long layout: reaction bar pinned at the top, and the
  /// full bubble snapshot + action menu share a single vertical scroll view so
  /// the whole thing (bubble *and* menu) scrolls together.
  Widget _buildScrollableSuperLong(BuildContext context) {
    final media = MediaQuery.of(context);
    final anchor = widget.anchorRect;
    final image = widget.scrollableBubbleImage!;
    final screenWidth = media.size.width;
    const gap = 8.0;
    final reactionBarHeight =
        TIMUIKitMessageTooltipState.mobileTelegramReactionBarHeight;
    final showReaction = widget.showQuickReactionBar;
    final reactionBlock = showReaction ? reactionBarHeight + gap : 0.0;

    final scrollTop = widget.safeTop + reactionBlock;
    final scrollBottom = widget.safeBottom;

    final bubbleWidth = anchor.width;
    final naturalHeight = image.width > 0
        ? bubbleWidth * image.height / image.width
        : anchor.height;

    final menuWidth =
        TIMUIKitMessageTooltipState.mobileTelegramMenuWidth(context);

    final leftInset = anchor.left.clamp(0.0, screenWidth).toDouble();
    final rightInset =
        (screenWidth - anchor.right).clamp(0.0, screenWidth).toDouble();
    final reactionLeft =
        anchor.left.clamp(8.0, max(8.0, screenWidth - menuWidth - 8.0)).toDouble();

    final bubble = Padding(
      padding: EdgeInsets.only(left: leftInset, right: rightInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: bubbleWidth,
          height: naturalHeight,
          child: RawImage(
            image: image,
            width: bubbleWidth,
            height: naturalHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );

    final menu = Padding(
      padding: EdgeInsets.only(
        left: widget.isSelf ? 0 : leftInset,
        right: widget.isSelf ? rightInset : 0,
      ),
      child: Align(
        alignment: widget.isSelf ? Alignment.centerRight : Alignment.centerLeft,
        // Absorb taps on the menu card so its background doesn't trigger the
        // blank-area dismiss; the rows keep handling their own taps.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: SizedBox(
            width: menuWidth,
            child: _FrostedTooltipShell(
              borderRadius: BorderRadius.circular(12),
              padding: EdgeInsets.zero,
              // 操作菜单：微信深色横向网格（全屏已 blur，此处不再叠第二层）。
              backgroundColor: _kWeChatActionMenuBackgroundColor,
              useBackdropBlur: false,
              child: _buildTooltip(
                layout: TelegramMobileTooltipLayout.actionMenuOnly,
              ),
            ),
          ),
        ),
      ),
    );

    final scrollViewportHeight = max(0.0, scrollBottom - scrollTop);
    final scrollColumn = SingleChildScrollView(
      controller: _comboScrollController,
      physics: const BouncingScrollPhysics(),
      // Opaque tap layer behind the content: tapping any blank area (inside the
      // otherwise tap-absorbing scroll view) closes the menu, while taps on the
      // menu rows are handled by the rows themselves.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissOnBlankTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: scrollViewportHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bubble,
              const SizedBox(height: gap),
              menu,
              const SizedBox(height: gap),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      width: media.size.width,
      height: media.size.height,
      child: ChangeNotifierProvider.value(
        value: widget.model,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: scrollTop,
              height: max(0.0, scrollBottom - scrollTop),
              child: _applyPresent(scrollColumn),
            ),
            if (showReaction)
              Positioned(
                left: reactionLeft,
                top: widget.safeTop,
                child: _applyPresent(
                  _FrostedTooltipShell(
                    borderRadius: BorderRadius.circular(24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    // 与操作菜单一致：不再叠 live BackdropFilter。
                    useBackdropBlur: false,
                    child: _buildTooltip(
                      layout: TelegramMobileTooltipLayout.reactionBarOnly,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scrollableBubbleImage != null) {
      return _buildScrollableSuperLong(context);
    }

    final media = MediaQuery.of(context);
    final anchor = widget.anchorRect;

    final menuWidth =
        TIMUIKitMessageTooltipState.mobileTelegramMenuWidth(context);
    final estimatedMenuHeight =
        TIMUIKitMessageTooltipState.estimateTelegramActionMenuHeight(
      widget.estimatedMenuItemCount,
    );
    final menuHeight = _measuredMenuHeight ?? estimatedMenuHeight;
    final reactionBarHeight =
        _measuredReactionHeight ??
            TIMUIKitMessageTooltipState.mobileTelegramReactionBarHeight;

    final layout = resolveTelegramMobileContextMenuLayout(
      bubbleAnchor: anchor,
      isSelf: widget.isSelf,
      screenWidth: media.size.width,
      safeTop: widget.safeTop,
      safeBottom: widget.safeBottom,
      menuWidth: menuWidth,
      menuHeight: menuHeight,
      showReactionBar: widget.showQuickReactionBar,
      reactionBarHeight: reactionBarHeight,
    );

    final needsScroll = layout.menuMaxHeight != null &&
        layout.menuMaxHeight! < menuHeight - 1;

    return SizedBox(
      width: media.size.width,
      height: media.size.height,
      child: ChangeNotifierProvider.value(
        value: widget.model,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.showQuickReactionBar && layout.reactionTop != null)
              Positioned(
                left: layout.reactionLeft,
                top: layout.reactionTop,
                child: KeyedSubtree(
                  key: _reactionMeasureKey,
                  child: _FrostedTooltipShell(
                    borderRadius: BorderRadius.circular(24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    // 与操作菜单一致：不再叠 live BackdropFilter。
                    useBackdropBlur: false,
                    child: _buildTooltip(
                      layout: TelegramMobileTooltipLayout.reactionBarOnly,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: layout.menuLeft,
              right: layout.menuRight,
              top: layout.menuTop,
              child: KeyedSubtree(
                key: _menuMeasureKey,
                child: _FrostedTooltipShell(
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.zero,
                  // 操作菜单：微信深色横向网格（全屏已 blur，此处不再叠第二层）。
                  backgroundColor: _kWeChatActionMenuBackgroundColor,
                  useBackdropBlur: false,
                  child: _buildTooltip(
                    layout: TelegramMobileTooltipLayout.actionMenuOnly,
                    menuMaxHeight:
                        needsScroll ? layout.menuMaxHeight : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrostedTooltipShell extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool useBackdropBlur;

  const _FrostedTooltipShell({
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.useBackdropBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final shell = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? _kTelegramMenuBackgroundColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: useBackdropBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: shell,
            )
          : shell,
    );
  }
}
