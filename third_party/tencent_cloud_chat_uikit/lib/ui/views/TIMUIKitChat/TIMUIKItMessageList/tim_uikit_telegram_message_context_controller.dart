import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_mobile_telegram_message_menu.dart';

/// Mirrors Telegram `ContextExtractedContentSource` + `contentAreaInScreenSpace`.
class TelegramMessageContextSource {
  final Rect extractedContentRect;
  final Rect layoutAnchorRect;
  final Rect contentAreaInScreenSpace;
  final bool isSelf;

  /// When non-null, the extracted snapshot is the *full* message bubble and the
  /// extraction window ([extractedContentRect]) is only a viewport into it.
  /// Used for super-long text so the whole message can be scrolled/read inside
  /// the context menu instead of being cropped to a middle slice.
  final Rect? scrollableFullContentRect;

  /// Global Y of the long-press point; used to scroll super-long previews.
  final double? longPressGlobalY;

  const TelegramMessageContextSource({
    required this.extractedContentRect,
    required this.layoutAnchorRect,
    required this.contentAreaInScreenSpace,
    required this.isSelf,
    this.scrollableFullContentRect,
    this.longPressGlobalY,
  });
}

/// Telegram `ContextController`: blur backdrop + extracted bubble + actions.
class TelegramMessageContextController extends StatefulWidget {
  final TelegramMessageContextSource source;
  final ui.Image? extractedSnapshot;
  final V2TimMessage message;
  final TUIChatSeparateViewModel model;
  final ToolTipsConfig? toolTipsConfig;
  final int estimatedMenuItemCount;
  final bool showQuickReactionBar;
  final bool allowAtUserWhenReply;
  final Function(String? userId, String? nickName)?
      onLongPressForOthersHeadPortrait;
  final Function(String? userId, String? nickName)? onAtUserWhenReply;
  final V2TimGroupMemberFullInfo? groupMemberInfo;
  final bool iSUseDefaultHoverBar;
  final VoidCallback onDismiss;
  final ValueChanged<int> onSelectSticker;
  final DateTime openedAt;

  const TelegramMessageContextController({
    super.key,
    required this.source,
    required this.extractedSnapshot,
    required this.message,
    required this.model,
    required this.onDismiss,
    required this.onSelectSticker,
    required this.openedAt,
    this.toolTipsConfig,
    this.estimatedMenuItemCount = 8,
    this.showQuickReactionBar = true,
    this.allowAtUserWhenReply = true,
    this.onLongPressForOthersHeadPortrait,
    this.onAtUserWhenReply,
    this.groupMemberInfo,
    this.iSUseDefaultHoverBar = false,
  });

  /// Soft cap for long-press menu captures. Device DPR is often 3×; menu
  /// extract does not need full framebuffer sharpness.
  static const double menuCaptureMaxPixelRatio = 2.0;

  static Future<ui.Image?> captureSnapshot(
    GlobalKey boundaryKey,
    BuildContext context, {
    Rect? cropInScreenSpace,
    double? maxPixelRatio,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      return null;
    }
    try {
      final deviceRatio = MediaQuery.devicePixelRatioOf(context);
      final baseRatio = maxPixelRatio == null
          ? deviceRatio
          : min(deviceRatio, maxPixelRatio);
      // Clamp the capture resolution so a very tall bubble never exceeds the
      // GPU max texture size (commonly 4096px). Exceeding it makes toImage
      // throw and yields a blank snapshot.
      const maxTextureDimension = 4096.0;
      final size = boundary.size;
      final longestSide = max(size.width, size.height);
      final ratio = longestSide * baseRatio > maxTextureDimension
          ? max(1.0, maxTextureDimension / longestSide)
          : baseRatio;
      final fullImage = await boundary.toImage(pixelRatio: ratio);
      if (cropInScreenSpace == null) {
        return fullImage;
      }

      final fullRect = boundary.localToGlobal(Offset.zero) & boundary.size;
      final crop = cropInScreenSpace.intersect(fullRect);
      if (crop.width <= 1 || crop.height <= 1) {
        return fullImage;
      }

      final srcLeft = (crop.left - fullRect.left) * ratio;
      final srcTop = (crop.top - fullRect.top) * ratio;
      final srcWidth = crop.width * ratio;
      final srcHeight = crop.height * ratio;
      final dstWidth = srcWidth.round();
      final dstHeight = srcHeight.round();
      if (dstWidth <= 0 || dstHeight <= 0) {
        return fullImage;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        fullImage,
        Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight),
        Rect.fromLTWH(0, 0, srcWidth, srcHeight),
        Paint(),
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(dstWidth, dstHeight);
      fullImage.dispose();
      return cropped;
    } catch (_) {
      return null;
    }
  }

  @override
  State<TelegramMessageContextController> createState() =>
      _TelegramMessageContextControllerState();
}

class _TelegramMessageContextControllerState
    extends State<TelegramMessageContextController>
    with SingleTickerProviderStateMixin {
  late final AnimationController _presentController;
  late final Animation<double> _presentOpacity;
  late final Animation<double> _presentScale;

  @override
  void initState() {
    super.initState();
    _presentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _presentOpacity = CurvedAnimation(
      parent: _presentController,
      curve: Curves.easeOutCubic,
    );
    _presentScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _presentController, curve: Curves.easeOutBack),
    );
    _presentController.forward();
  }

  @override
  void dispose() {
    _presentController.dispose();
    super.dispose();
  }

  /// Super-long text mode: the bubble snapshot scrolls together with the action
  /// menu inside [MobileTelegramMessageContextMenu], so the controller does not
  /// render a separate extracted bubble.
  bool get _scrollableMode => widget.source.scrollableFullContentRect != null;

  Future<void> _dismissIfAllowed() async {
    if (DateTime.now().difference(widget.openedAt) <
        const Duration(milliseconds: 320)) {
      return;
    }
    if (_presentController.status == AnimationStatus.reverse ||
        _presentController.value <= 0) {
      widget.onDismiss();
      return;
    }
    await _presentController.reverse();
    if (!mounted) {
      return;
    }
    widget.onDismiss();
  }

  Widget _buildExtractedMessageRow(Rect extracted, Rect contentArea) {
    final rowTop = extracted.top.clamp(contentArea.top, contentArea.bottom);
    final rowBottom =
        extracted.bottom.clamp(contentArea.top, contentArea.bottom);
    final rowHeight = max(0.0, rowBottom - rowTop);
    return Positioned(
      left: contentArea.left,
      top: rowTop,
      width: contentArea.width,
      height: rowHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_dismissIfAllowed()),
        // Clip so a tall bubble that extends above safeTop cannot paint into
        // the chat AppBar / status bar.
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: extracted.left - contentArea.left,
                top: extracted.top - rowTop,
                width: extracted.width,
                height: extracted.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // The extracted snapshot has no independent action. Let a tap
                  // on the selected image return to the chat instead of
                  // swallowing the event in this inner recognizer.
                  onTap: () => unawaited(_dismissIfAllowed()),
                  child: FadeTransition(
                    opacity: _presentOpacity,
                    child: ScaleTransition(
                      scale: _presentScale,
                      alignment: Alignment.center,
                      child: RawImage(
                        image: widget.extractedSnapshot,
                        width: extracted.width,
                        height: extracted.height,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final extracted = widget.source.extractedContentRect;
    final contentArea = widget.source.contentAreaInScreenSpace;

    return SizedBox(
      width: media.size.width,
      height: media.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _presentOpacity,
              child: GestureDetector(
                onTap: () => unawaited(_dismissIfAllowed()),
                behavior: HitTestBehavior.opaque,
                // Solid scrim: avoid live GPU blur filters on the menu path.
                child: const ColoredBox(
                  color: Color(0x61000000), // ~38% black
                ),
              ),
            ),
          ),
          if (widget.extractedSnapshot != null && !_scrollableMode)
            _buildExtractedMessageRow(extracted, contentArea),
          MobileTelegramMessageContextMenu(
            anchorRect: widget.source.layoutAnchorRect,
            isSelf: widget.source.isSelf,
            message: widget.message,
            model: widget.model,
            toolTipsConfig: widget.toolTipsConfig,
            estimatedMenuItemCount: widget.estimatedMenuItemCount,
            safeTop: contentArea.top + 6,
            safeBottom: contentArea.bottom - 6,
            showQuickReactionBar: widget.showQuickReactionBar,
            allowAtUserWhenReply: widget.allowAtUserWhenReply,
            onLongPressForOthersHeadPortrait:
                widget.onLongPressForOthersHeadPortrait,
            onAtUserWhenReply: widget.onAtUserWhenReply,
            groupMemberInfo: widget.groupMemberInfo,
            iSUseDefaultHoverBar: widget.iSUseDefaultHoverBar,
            onClose: widget.onDismiss,
            onSelectSticker: widget.onSelectSticker,
            scrollableBubbleImage:
                _scrollableMode ? widget.extractedSnapshot : null,
            longPressGlobalY: widget.source.longPressGlobalY,
            fullContentRect: widget.source.scrollableFullContentRect,
            presentOpacity: _presentOpacity,
            presentScale: _presentScale,
          ),
        ],
      ),
    );
  }
}

/// Telegram-style long-press recognizer (450ms, ~12px move tolerance).
class TelegramMessageLongPressDetector extends StatefulWidget {
  final Widget child;
  final ValueChanged<LongPressStartDetails>? onLongPressStart;
  final VoidCallback onLongPress;
  final Duration duration;
  final double moveTolerance;

  const TelegramMessageLongPressDetector({
    super.key,
    required this.child,
    required this.onLongPress,
    this.onLongPressStart,
    this.duration = const Duration(milliseconds: 450),
    this.moveTolerance = 12,
  });

  @override
  State<TelegramMessageLongPressDetector> createState() =>
      _TelegramMessageLongPressDetectorState();
}

class _TelegramMessageLongPressDetectorState
    extends State<TelegramMessageLongPressDetector> {
  Offset? _downPosition;
  Timer? _timer;
  bool _triggered = false;
  bool _suppressChildGestures = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancelPending() {
    _timer?.cancel();
    _timer = null;
    _downPosition = null;
    _triggered = false;
    _suppressChildGestures = false;
  }

  void _releaseChildGestureSuppression() {
    if (!_suppressChildGestures) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) {
        return;
      }
      if (serviceLocator<TUIChatGlobalModel>()
          .isMessageContextMenuOverlayOpen) {
        _releaseChildGestureSuppression();
        return;
      }
      setState(() {
        _suppressChildGestures = false;
        _triggered = false;
      });
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _cancelPending();
    _downPosition = event.position;
    _timer = Timer(widget.duration, () {
      if (!mounted || _downPosition == null || _triggered) {
        return;
      }
      _triggered = true;
      _suppressChildGestures = true;
      setState(() {});
      final position = _downPosition!;
      HapticFeedback.mediumImpact();
      widget.onLongPressStart?.call(
        LongPressStartDetails(globalPosition: position),
      );
      widget.onLongPress();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _downPosition;
    if (origin == null || _triggered) {
      return;
    }
    if ((event.position - origin).distance > widget.moveTolerance) {
      _cancelPending();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_suppressChildGestures) {
      _timer?.cancel();
      _timer = null;
      _downPosition = null;
      _releaseChildGestureSuppression();
      return;
    }
    _cancelPending();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) {
        if (_suppressChildGestures) {
          _timer?.cancel();
          _timer = null;
          _downPosition = null;
          _releaseChildGestureSuppression();
          return;
        }
        _cancelPending();
      },
      child: IgnorePointer(
        ignoring: _suppressChildGestures,
        child: widget.child,
      ),
    );
  }
}
