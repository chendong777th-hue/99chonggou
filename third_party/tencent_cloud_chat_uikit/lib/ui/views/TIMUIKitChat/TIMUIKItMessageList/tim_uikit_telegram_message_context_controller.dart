import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
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
      final baseRatio =
          maxPixelRatio == null ? deviceRatio : min(deviceRatio, maxPixelRatio);
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
  static const Duration _minimumOpenDuration = Duration(milliseconds: 320);

  late final AnimationController _presentController;
  late final Animation<double> _presentOpacity;
  late final Animation<double> _presentScale;
  Future<void>? _guardedDismissFuture;
  bool _dismissNotified = false;

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
      CurvedAnimation(parent: _presentController, curve: Curves.easeOutCubic),
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

  void _notifyDismissOnce() {
    if (_dismissNotified) {
      return;
    }
    _dismissNotified = true;
    widget.onDismiss();
  }

  void _dismissFromAction() {
    // Action handlers may immediately present another route (delete/revoke
    // confirmation, forwarding, etc.), so release the overlay synchronously.
    _notifyDismissOnce();
  }

  Future<void> _dismissIfAllowed() {
    return _guardedDismissFuture ??= _runGuardedDismiss();
  }

  Future<void> _runGuardedDismiss() async {
    final elapsed = DateTime.now().difference(widget.openedAt);
    final remaining = _minimumOpenDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (_dismissNotified) {
      return;
    }
    if (mounted &&
        _presentController.status != AnimationStatus.reverse &&
        _presentController.value > 0) {
      final reverseSettled = Completer<void>();
      _presentController
          .reverse()
          .whenCompleteOrCancel(reverseSettled.complete);
      await reverseSettled.future;
    }
    _notifyDismissOnce();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final contentArea = widget.source.contentAreaInScreenSpace;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_dismissIfAllowed());
        }
      },
      child: SizedBox(
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
                    color: Color(
                        0x52000000), // ~32% black, matching WeChat dimming
                  ),
                ),
              ),
            ),
            // The live selected message remains in the chat list below the
            // spotlight scrim; no stale snapshot is painted here.
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
              onClose: _dismissFromAction,
              onDismissBlank: () => unawaited(_dismissIfAllowed()),
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
      ),
    );
  }
}

/// Message long-press entry backed by Flutter's gesture arena.
///
/// Competing tap and scroll recognizers are rejected when the long press wins,
/// so opening the menu cannot also activate the message bubble underneath it.
class TelegramMessageLongPressDetector extends StatelessWidget {
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
    this.duration = const Duration(milliseconds: 500),
    this.moveTolerance = 12,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: duration,
            postAcceptSlopTolerance: moveTolerance,
            debugOwner: this,
          ),
          (recognizer) {
            recognizer.onLongPressStart = (details) {
              HapticFeedback.mediumImpact();
              onLongPressStart?.call(details);
              onLongPress();
            };
          },
        ),
      },
      child: child,
    );
  }
}
