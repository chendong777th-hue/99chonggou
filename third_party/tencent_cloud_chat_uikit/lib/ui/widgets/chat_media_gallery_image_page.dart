import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/image_preview_edit_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/gestured_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_hero.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_preview_center_loading_indicator.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_preview_original_fan_reveal.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/tall_image_scroll_preview.dart';

typedef DoubleClickAnimationListener = void Function();

/// 混滑画廊单页图片：对齐 [ImageScreen] 的 Hero 入场、占位→原图扇形升级、长图竖滑。
class ChatMediaGalleryImagePage extends StatefulWidget {
  const ChatMediaGalleryImagePage({
    super.key,
    required this.item,
    required this.inPageView,
    required this.isActive,
    required this.allowHero,
    required this.entranceSettled,
    required this.isGalleryScrolling,
    required this.slidePageKey,
    required this.slideMetrics,
    required this.onTap,
    this.onSlideDismiss,
    this.onDismissGestureStarted,
    this.galleryScrollGate,
  });

  final ChatMediaPreviewItem item;
  final bool inPageView;
  final bool isActive;
  final bool allowHero;
  final bool entranceSettled;
  final bool isGalleryScrolling;
  final GlobalKey<ExtendedImageSlidePageState> slidePageKey;
  final MediaPreviewSlideMetrics slideMetrics;
  final VoidCallback onTap;
  final TallImageSlideDismissCallback? onSlideDismiss;
  /// 长图进入竖向关闭手势时通知图集钉住当前页。
  final VoidCallback? onDismissGestureStarted;
  final ValueNotifier<TallImageGalleryScrollGate>? galleryScrollGate;

  @override
  State<ChatMediaGalleryImagePage> createState() =>
      _ChatMediaGalleryImagePageState();
}

class _ChatMediaGalleryImagePageState extends State<ChatMediaGalleryImagePage>
    with TickerProviderStateMixin {
  final GlobalKey<ExtendedImageGestureState> _gestureKey =
      GlobalKey<ExtendedImageGestureState>();
  Animation<double>? _doubleClickAnimation;
  late DoubleClickAnimationListener _doubleClickAnimationListener;
  late AnimationController _doubleClickAnimationController;
  List<double> _doubleTapScales = <double>[1.0, 2.0];

  ImageProvider? _refreshedProvider;
  ImageProvider? _originalRevealProvider;
  AnimationController? _fanController;
  ImagePreviewDisplayConfig? _loadedDisplay;
  bool _originalFanRevealCompleted = false;
  bool _lowResolutionRefreshAttempted = false;
  bool _lowResolutionRefreshInFlight = false;
  bool _pendingOriginalRefresh = false;

  static const Duration _originalFanRevealDuration =
      Duration(milliseconds: 620);

  @override
  void initState() {
    super.initState();
    _doubleClickAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ChatMediaGalleryImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive = !oldWidget.isActive && widget.isActive;
    final scrollSettled =
        oldWidget.isGalleryScrolling && !widget.isGalleryScrolling;
    if (widget.isActive &&
        !widget.isGalleryScrolling &&
        (becameActive || scrollSettled || _pendingOriginalRefresh)) {
      _scheduleOriginalRefreshIfNeeded();
    }
    if (oldWidget.isActive && !widget.isActive) {
      _fanController?.stop();
      if (_originalRevealProvider != null) {
        setState(() => _originalRevealProvider = null);
      }
    }
  }

  @override
  void dispose() {
    _fanController?.dispose();
    _doubleClickAnimationController.dispose();
    super.dispose();
  }

  AnimationController _ensureFanController() {
    return _fanController ??= AnimationController(
      vsync: this,
      duration: _originalFanRevealDuration,
    );
  }

  void _completeOriginalUpgrade(ImageProvider originalProvider) {
    _originalFanRevealCompleted = true;
    _originalRevealProvider = null;
    _fanController?.dispose();
    _fanController = null;
    _refreshedProvider = originalProvider;
  }

  Future<void> _precachePreviewImage(ImageProvider provider) async {
    final config = createLocalImageConfiguration(context);
    final stream = provider.resolve(config);
    final completer = Completer<void>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, sync) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    await completer.future;
  }

  ImageProvider? _resolveImageProvider({bool preferFullResolution = false}) {
    final messageId = widget.item.messageID?.trim();
    if (messageId != null && messageId.isNotEmpty) {
      final edited = ImagePreviewEditStore.instance.peek(messageId);
      if (edited != null && edited.existsSync()) {
        return FileImage(edited);
      }
    }
    final primary = _refreshedProvider ?? widget.item.imageProvider;
    if (primary == null) {
      return null;
    }
    // 始终加载大图/原图；加载中由 LoadingLayer 铺气泡底图。
    return ChatMessagePreviewImageResolver.wrapPreviewDecode(
      context: context,
      message: widget.item.message,
      provider: primary,
      preferFullResolution: preferFullResolution,
    );
  }

  ImageProvider? _placeholderForItem() {
    final existing = widget.item.placeholderImageProvider;
    if (existing != null) {
      return existing;
    }
    if (widget.item.message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return null;
    }
    return ChatMessagePreviewImageResolver.resolvePlaceholder(
      widget.item.message,
    );
  }

  Future<void> _playOriginalFanReveal({
    required ImageProvider originalProvider,
    required ImagePreviewDisplayConfig display,
  }) async {
    if (!mounted || !widget.isActive) {
      return;
    }
    if (widget.isGalleryScrolling) {
      _pendingOriginalRefresh = true;
      return;
    }
    try {
      await _precachePreviewImage(originalProvider);
    } catch (_) {
      // 原图预解码失败时保留当前已显示的大图，避免换成坏 provider 导致全屏灰。
      if (mounted) {
        _lowResolutionRefreshAttempted = true;
      }
      return;
    }

    if (!mounted ||
        _originalFanRevealCompleted ||
        !widget.isActive ||
        widget.isGalleryScrolling) {
      if (widget.isGalleryScrolling || !widget.isActive) {
        _pendingOriginalRefresh = true;
      }
      return;
    }

    final controller = _ensureFanController();
    controller.stop();
    controller.value = 0;
    setState(() => _originalRevealProvider = originalProvider);
    try {
      await controller.forward(from: 0);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    if (!widget.isActive || widget.isGalleryScrolling) {
      setState(() => _originalRevealProvider = null);
      return;
    }
    setState(() => _completeOriginalUpgrade(originalProvider));
  }

  void _scheduleOriginalRefreshIfNeeded({
    int? loadedImageWidth,
    int? loadedImageHeight,
  }) {
    if (!widget.isActive) {
      return;
    }
    if (widget.isGalleryScrolling) {
      _pendingOriginalRefresh = true;
      return;
    }
    if (_lowResolutionRefreshAttempted ||
        _lowResolutionRefreshInFlight ||
        _originalFanRevealCompleted ||
        _originalRevealProvider != null) {
      return;
    }
    final message = widget.item.message;
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return;
    }
    final currentProvider = _refreshedProvider ?? widget.item.imageProvider;
    var needsUpgrade = ChatMessagePreviewImageResolver.shouldUpgradeToOriginal(
      message,
      currentProvider,
    );
    if (!needsUpgrade &&
        loadedImageWidth != null &&
        loadedImageHeight != null &&
        loadedImageWidth > 0 &&
        loadedImageHeight > 0) {
      needsUpgrade = isImagePreviewResolutionTooLow(
        imageWidth: loadedImageWidth,
        imageHeight: loadedImageHeight,
        context: context,
      );
    }
    if (!needsUpgrade) {
      _lowResolutionRefreshAttempted = true;
      _pendingOriginalRefresh = false;
      return;
    }

    Future<void> runRefresh() async {
      if (!mounted ||
          !widget.isActive ||
          _lowResolutionRefreshAttempted ||
          _lowResolutionRefreshInFlight ||
          _originalFanRevealCompleted) {
        return;
      }
      _lowResolutionRefreshInFlight = true;
      _pendingOriginalRefresh = false;
      try {
        final originalProvider =
            await ChatMessagePreviewImageResolver.refreshOriginal(message);
        if (!mounted || originalProvider == null) {
          if (mounted) {
            _lowResolutionRefreshAttempted = true;
          }
          return;
        }
        if (ChatMessagePreviewImageResolver.isSameImageProvider(
          originalProvider,
          currentProvider,
        )) {
          _lowResolutionRefreshAttempted = true;
          return;
        }
        _lowResolutionRefreshAttempted = true;
        final display = _loadedDisplay ??
            imagePreviewDisplayConfigForItem(
              sourceMessage: message,
              screenWidth: MediaQuery.sizeOf(context).width,
              screenHeight: MediaQuery.sizeOf(context).height,
            );
        if (display.verticallyScrollable) {
          if (!mounted || !widget.isActive || widget.isGalleryScrolling) {
            _pendingOriginalRefresh = true;
            return;
          }
          try {
            await _precachePreviewImage(originalProvider);
          } catch (_) {
            if (mounted) {
              _lowResolutionRefreshAttempted = true;
            }
            return;
          }
          if (!mounted || !widget.isActive) {
            return;
          }
          setState(() => _completeOriginalUpgrade(originalProvider));
          return;
        }
        await _playOriginalFanReveal(
          originalProvider: originalProvider,
          display: display,
        );
      } finally {
        if (mounted) {
          _lowResolutionRefreshInFlight = false;
        }
      }
    }

    if (widget.entranceSettled) {
      unawaited(runRefresh());
      return;
    }
    Future<void>.delayed(mediaPreviewBackdropDuration, () {
      if (mounted) {
        unawaited(runRefresh());
      }
    });
  }

  void _onDoubleTap(ExtendedImageGestureState state) {
    final pointerDownPosition = state.pointerDownPosition;
    final begin = state.gestureDetails!.totalScale;
    final end = begin == _doubleTapScales[0]
        ? _doubleTapScales[1]
        : _doubleTapScales[0];

    _doubleClickAnimation?.removeListener(_doubleClickAnimationListener);
    _doubleClickAnimationController
      ..stop()
      ..reset();

    _doubleClickAnimationListener = () {
      state.handleDoubleTap(
        scale: _doubleClickAnimation!.value,
        doubleTapPosition: pointerDownPosition,
      );
    };
    _doubleClickAnimation = _doubleClickAnimationController.drive(
      Tween<double>(begin: begin, end: end),
    );
    _doubleClickAnimation!.addListener(_doubleClickAnimationListener);
    _doubleClickAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ImagePreviewEditStore.instance.revision,
      builder: (context, revision, _) {
        return _buildBody(context, revision);
      },
    );
  }

  Widget _buildBody(BuildContext context, int revision) {
    final imageProvider = _resolveImageProvider();
    if (imageProvider == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      );
    }

    final screenSize = MediaQuery.sizeOf(context);
    final display = _loadedDisplay ??
        imagePreviewDisplayConfigResolved(
          sourceMessage: widget.item.message,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
        );
    final boxSize = imagePreviewBoxSizeFor(
      display: display,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
    );
    final imageFit = imagePreviewPaintFit(display);

    Widget image = ExtendedImage(
      key: ValueKey<String>(
        'mixed_preview_${widget.item.messageID ?? widget.item.heroTag}_$revision'
        '_${_refreshedProvider != null}',
      ),
      image: imageProvider,
      width: boxSize.width,
      height: boxSize.height,
      fit: imageFit,
      alignment: display.alignment,
      gaplessPlayback: true,
      enableLoadState: true,
      extendedImageGestureKey: _gestureKey,
      enableSlideOutPage: true,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (state) {
        final info = state.extendedImageInfo;
        final resolved = imagePreviewDisplayConfigResolved(
          sourceMessage: widget.item.message,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          decodedWidth: info?.image.width ?? 0,
          decodedHeight: info?.image.height ?? 0,
        );
        final maxScale = imagePreviewMaxScale(
          imageWidth: resolved.imageWidth,
          imageHeight: resolved.imageHeight,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          fit: resolved.fit,
        );
        return buildImagePreviewGestureConfig(
          inPageView: widget.inPageView,
          display: resolved,
          maxScale: maxScale,
        );
      },
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return ImagePreviewLoadingLayer(
              placeholder: _placeholderForItem(),
              fit: imagePreviewPaintFit(display),
              alignment: display.alignment,
              showSpinner: widget.entranceSettled,
            );
          case LoadState.completed:
            final imgHeight = state.extendedImageInfo?.image.height ?? 1;
            final imgWidth = state.extendedImageInfo?.image.width ?? 1;
            final builtDisplay = _loadedDisplay ??
                imagePreviewDisplayConfigResolved(
                  sourceMessage: widget.item.message,
                  screenWidth: screenSize.width,
                  screenHeight: screenSize.height,
                );
            final resolved = imagePreviewDisplayConfigResolved(
              sourceMessage: widget.item.message,
              screenWidth: screenSize.width,
              screenHeight: screenSize.height,
              decodedWidth: imgWidth,
              decodedHeight: imgHeight,
            );
            final doubleTapTarget = imagePreviewDoubleTapScale(
              imageWidth: resolved.imageWidth,
              imageHeight: resolved.imageHeight,
              screenWidth: screenSize.width,
              screenHeight: screenSize.height,
              display: resolved,
            );
            final panScale = imagePreviewInitialScale(
              verticallyScrollable: resolved.verticallyScrollable,
            );
            _doubleTapScales = [panScale, doubleTapTarget];
            _loadedDisplay = resolved;
            if (!builtDisplay.layoutEquals(resolved)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {});
              });
            }
            _scheduleOriginalRefreshIfNeeded(
              loadedImageWidth: imgWidth,
              loadedImageHeight: imgHeight,
            );
            // extended_image 在约 1x 时无法可靠纵滑长图，可纵滑内容仍走专用组件。
            if (resolved.verticallyScrollable) {
              final maxScale = imagePreviewMaxScale(
                imageWidth: resolved.imageWidth,
                imageHeight: resolved.imageHeight,
                screenWidth: screenSize.width,
                screenHeight: screenSize.height,
                fit: resolved.fit,
              );
              return SizedBox.expand(
                child: TallImageScrollPreview(
                  extendedImageState: state,
                  maxScale: maxScale,
                  doubleTapTarget: doubleTapTarget,
                  slidePageKey: widget.slidePageKey,
                  slideMetrics: widget.slideMetrics,
                  displayMode: resolved.mode,
                  inPageView: widget.inPageView,
                  galleryScrollGate: widget.galleryScrollGate,
                  onTap: widget.onTap,
                  onDismissGestureStarted: widget.onDismissGestureStarted,
                  onSlideDismiss: widget.onSlideDismiss,
                ),
              );
            }
            return GesturedImage(state, key: _gestureKey);
          case LoadState.failed:
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
            );
        }
      },
      onDoubleTap: _onDoubleTap,
    );

    if (widget.allowHero && widget.item.heroTag.toString().isNotEmpty) {
      image = HeroWidget(
        tag: widget.item.heroTag,
        slidePagekey: widget.slidePageKey,
        child: image,
      );
    }

    final revealProvider = _originalRevealProvider;
    final fanController = _fanController;
    if (revealProvider != null && fanController != null) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned.fill(
            child: IgnorePointer(
              child: ImagePreviewOriginalFanReveal(
                imageProvider: revealProvider,
                display: display,
                progress: CurvedAnimation(
                  parent: fanController,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          ),
        ],
      );
    }

    image = MediaPreviewHeroLayout(
      displaySize: boxSize,
      alignment: display.alignment,
      child: ImagePreviewDisplayBox(
        displaySize: boxSize,
        alignment: display.alignment,
        child: image,
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox.expand(child: image),
    );
  }
}
