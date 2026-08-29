import 'dart:async';
import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/gestured_image.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/image_preview_edit_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_gallery_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_hero.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_screen_gallery_close.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gesture_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_gallery_precache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_scroll_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_chrome.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_shell.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_preview_center_loading_indicator.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_preview_original_fan_reveal.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/tall_image_scroll_preview.dart';

typedef DoubleClickAnimationListener = void Function();

typedef ImagePreviewClosingCallback = void Function(
  String? messageID,
  String heroTag,
);

class ImageScreen extends StatefulWidget {
  const ImageScreen({
    required this.imageProvider,
    required this.heroTag,
    this.downloadFn,
    this.editFn,
    this.sendFn,
    this.headerTitle,
    this.headerSubtitle,
    this.forwardFn,
    this.deleteFn,
    this.onOpenMedia,
    this.onClosing,
    this.messageID,
    this.galleryItems,
    this.initialIndex = 0,
    this.downloadOnly = false,
    this.sourceMessage,
    this.placeholderImageProvider,
    this.forceGalleryMode = false,
    /// 聊天消息默认 true；头像 / 群头像 / 朋友圈传 false，避免长图贴宽拉满。
    this.fitTallImagesToScreenWidth = true,
    /// 会话媒体网格等无源 Hero 的入口必须 false：零时长入场 + HeroMode
    /// 会在 iOS 留下空飞行层，只剩半透明灰罩看不见图。
    this.enableHero = true,
    Key? key,
  }) : super(key: key);

  final ImageProvider? imageProvider;
  final ImageProvider? placeholderImageProvider;
  final String heroTag;
  final String? messageID;
  final Future<void> Function()? downloadFn;
  final Future<void> Function(BuildContext previewContext)? editFn;
  final Future<void> Function(BuildContext previewContext)? sendFn;
  final String? headerTitle;
  final String? headerSubtitle;
  final Future<void> Function()? forwardFn;
  final Future<void> Function()? deleteFn;

  /// 会话图集入口。全屏看图底部不展示该按钮，字段保留以免调用方改签名。
  final VoidCallback? onOpenMedia;
  final ImagePreviewClosingCallback? onClosing;
  final List<ImageGalleryItem>? galleryItems;
  final int initialIndex;
  final bool downloadOnly;
  final V2TimMessage? sourceMessage;
  final bool forceGalleryMode;
  final bool fitTallImagesToScreenWidth;
  final bool enableHero;

  bool get _useGallery {
    if (forceGalleryMode) {
      return galleryItems?.isNotEmpty ?? false;
    }
    return (galleryItems?.length ?? 0) > 1;
  }

  @override
  State<StatefulWidget> createState() {
    return _ImageScreenState();
  }
}

class _ImageScreenState extends TIMUIKitState<ImageScreen>
    with TickerProviderStateMixin {
  Animation<double>? _doubleClickAnimation;
  late DoubleClickAnimationListener _doubleClickAnimationListener;
  late AnimationController _doubleClickAnimationController;
  final Set<Object> _hiddenHeroTags = <Object>{};
  List<double> doubleTapScales = <double>[1.0, 2.0];
  double fittedScale = 1.0;
  double initialScale = 1.0;
  bool isLoading = false;
  bool _isClosing = false;
  bool _chromeVisible = true;

  /// 顶栏/底栏独立刷新，避免翻页 setState 牵动整页（含 PageView 缓存判定）。
  final ValueNotifier<int> _chromeTick = ValueNotifier<int>(0);
  final MediaPreviewSlideMetrics _slideMetrics = MediaPreviewSlideMetrics();
  late final MediaPreviewEntranceLatch _entranceLatch;

  late ExtendedPageController _galleryPageController;
  Widget? _cachedSlideBody;
  Orientation? _cachedSlideBodyOrientation;
  late int _currentGalleryIndex;
  int _pageControllerEpoch = 0;
  int? _dismissGalleryIndex;
  bool _closingFromSlideDismiss = false;
  bool _closeHeroRevealed = false;
  bool _closeHeroRevealScheduled = false;
  final MediaPreviewSlideDismissController _slideDismissController =
      MediaPreviewSlideDismissController();
  late final ValueNotifier<bool> _heroModeEnabled;
  final Map<int, GlobalKey<ExtendedImageGestureState>> _gestureKeys = {};
  final Map<int, ImageProvider> _refreshedProviders = <int, ImageProvider>{};
  final Map<int, ImagePreviewDisplayConfig> _loadedDisplayByIndex =
      <int, ImagePreviewDisplayConfig>{};
  // Lock the Hero flight displaySize per index: the display config can
  // change subtly after ORIGIN decode (decoded pixels vs metadata), which
  // would make the dismiss Hero land at a different rect than the entrance
  // Hero started from. Freeze the box size on first build so entrance and
  // dismiss use the same geometry.
  final Map<int, Size> _heroLockedBoxSizeByIndex = <int, Size>{};
  final Map<int, ValueNotifier<TallImageGalleryScrollGate>>
      _tallImageGalleryGateByIndex =
      <int, ValueNotifier<TallImageGalleryScrollGate>>{};
  final Set<int> _lowResolutionRefreshInFlight = <int>{};
  final Set<int> _lowResolutionRefreshAttempted = <int>{};
  final Map<int, ImageProvider> _originalRevealProviders =
      <int, ImageProvider>{};
  final Map<int, AnimationController> _originalFanControllers =
      <int, AnimationController>{};
  final Set<int> _originalFanRevealCompleted = <int>{};
  static const Duration _originalFanRevealDuration =
      Duration(milliseconds: 620);

  /// 图集滚动中：推迟原图升级 / 预缓存 / Hero 之外的重活，避免高频连滑卡顿。
  bool _galleryScrolling = false;
  bool _galleryScrollNotifierBound = false;
  bool _galleryPageJumpInFlight = false;
  int? _pendingGalleryJumpIndex;
  int _galleryJumpAttempt = 0;
  static const int _maxGalleryJumpAttempts = 48;

  int _indexForSourceMessage({int? fallback}) {
    final tapped = widget.sourceMessage;
    if (tapped == null || _items.isEmpty) {
      if (fallback != null) {
        return fallback.clamp(0, _items.length - 1);
      }
      return widget.initialIndex.clamp(0, _items.length - 1);
    }
    for (var i = 0; i < _items.length; i++) {
      final message = _items[i].sourceMessage;
      if (message != null && isSameChatMediaMessage(message, tapped)) {
        return i;
      }
    }
    if (fallback != null) {
      return fallback.clamp(0, _items.length - 1);
    }
    return widget.initialIndex.clamp(0, _items.length - 1);
  }

  bool _galleryPageMatchesTarget(int target) {
    if (!_galleryPageController.hasClients) {
      return false;
    }
    final page = _galleryPageController.page;
    if (page == null) {
      return false;
    }
    return (page - target).abs() < 0.05;
  }

  void _jumpGalleryPageByOffset(int index) {
    if (!_galleryPageController.hasClients) {
      return;
    }
    final pos = _galleryPageController.position;
    if (!pos.hasViewportDimension || pos.viewportDimension <= 0) {
      return;
    }
    final stride = pos.viewportDimension + kChatMediaGalleryPageSpacing;
    pos.jumpTo(index * stride);
  }
  final ImagePreviewGalleryPrecache _galleryPrecache =
      ImagePreviewGalleryPrecache();
  int? _pendingOriginalRefreshIndex;
  Timer? _galleryIdleWorkTimer;
  static const int _galleryCacheRadius = 3;
  static const Duration _galleryIdleWorkDelay = Duration(milliseconds: 48);

  AnimationController _fanControllerForIndex(int index) {
    return _originalFanControllers.putIfAbsent(
      index,
      () => AnimationController(
        vsync: this,
        duration: _originalFanRevealDuration,
      ),
    );
  }

  void _disposeFanControllerForIndex(int index) {
    final controller = _originalFanControllers.remove(index);
    controller?.dispose();
  }

  void _completeOriginalUpgrade({
    required int index,
    required ImageProvider originalProvider,
  }) {
    _originalFanRevealCompleted.add(index);
    _originalRevealProviders.remove(index);
    _disposeFanControllerForIndex(index);
    _refreshedProviders[index] = originalProvider;
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

  Future<void> _playOriginalFanReveal({
    required int index,
    required ImageProvider originalProvider,
    required ImagePreviewDisplayConfig display,
  }) async {
    if (!mounted || _isClosing || _isSlideDismissActive) {
      return;
    }
    if (widget._useGallery && index != _currentGalleryIndex) {
      return;
    }
    // 连滑中不做扇形升级动画，等停稳再补，避免中途 setState 卡顿。
    if (widget._useGallery && _isGalleryActivelyScrolling) {
      _pendingOriginalRefreshIndex = index;
      return;
    }
    try {
      await _precachePreviewImage(originalProvider);
    } catch (_) {
      // 原图预解码失败时保留当前已显示的大图/占位，绝不能换成坏 provider（会全屏灰）。
      if (mounted &&
          !_isClosing &&
          !_isSlideDismissActive) {
        _lowResolutionRefreshAttempted.add(index);
      }
      return;
    }

    if (!mounted ||
        _isClosing ||
        _isSlideDismissActive ||
        _originalFanRevealCompleted.contains(index)) {
      return;
    }
    if (widget._useGallery && index != _currentGalleryIndex) {
      return;
    }
    if (widget._useGallery && _isGalleryActivelyScrolling) {
      _pendingOriginalRefreshIndex = index;
      return;
    }

    final controller = _fanControllerForIndex(index);
    controller.stop();
    controller.value = 0;
    setState(() {
      _originalRevealProviders[index] = originalProvider;
    });
    try {
      await controller.forward(from: 0);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    if (widget._useGallery &&
        (index != _currentGalleryIndex || _isGalleryActivelyScrolling)) {
      _originalRevealProviders.remove(index);
      return;
    }
    setState(() {
      _completeOriginalUpgrade(
        index: index,
        originalProvider: originalProvider,
      );
    });
  }

  GlobalKey<ExtendedImageSlidePageState> slidePageKey =
      GlobalKey<ExtendedImageSlidePageState>();
  GlobalKey<ExtendedImageGestureState> extendedImageGestureKey =
      GlobalKey<ExtendedImageGestureState>();

  final Map<int, int> _previewRotationTurns = <int, int>{};

  bool get _showWebPreviewTools => PlatformUtils().isWeb;

  bool get _showPreviewChrome =>
      PlatformUtils().isMobile || PlatformUtils().isWeb;

  int get _activePreviewIndex => widget._useGallery ? _currentGalleryIndex : 0;

  ExtendedImageGestureState? _activeGestureState() {
    if (widget._useGallery) {
      return _gestureKeyForIndex(_activePreviewIndex).currentState;
    }
    return extendedImageGestureKey.currentState;
  }

  void _zoomPreview({required double factor}) {
    final state = _activeGestureState();
    if (state == null) {
      return;
    }
    final config = state.imageGestureConfig;
    final minScale = config?.minScale ?? 1.0;
    final maxScale = config?.maxScale ?? 4.0;
    final current = state.gestureDetails?.totalScale ?? minScale;
    final target = (current * factor).clamp(minScale, maxScale);
    state.handleDoubleTap(scale: target);
  }

  void _rotatePreview() {
    setState(() {
      final index = _activePreviewIndex;
      _previewRotationTurns[index] =
          ((_previewRotationTurns[index] ?? 0) + 1) % 4;
    });
  }

  void _resetPreviewView() {
    _activeGestureState()?.reset();
    setState(() {
      _previewRotationTurns[_activePreviewIndex] = 0;
    });
  }

  void _handleWebPointerSignal(PointerSignalEvent event) {
    if (!_showWebPreviewTools || event is! PointerScrollEvent) {
      return;
    }
    final delta = event.scrollDelta.dy;
    if (delta == 0) {
      return;
    }
    _zoomPreview(factor: delta < 0 ? 1.12 : 0.88);
  }

  List<ImageGalleryItem> get _items {
    if (widget._useGallery) {
      return widget.galleryItems!;
    }
    return [
      ImageGalleryItem(
        imageProvider: widget.imageProvider,
        placeholderImageProvider: widget.placeholderImageProvider,
        heroTag: widget.heroTag,
        messageID: widget.messageID,
        sourceMessage: widget.sourceMessage,
        downloadFn: widget.downloadFn,
        editFn: widget.editFn,
        sendFn: widget.sendFn,
        forwardFn: widget.forwardFn,
        deleteFn: widget.deleteFn,
        headerTitle: widget.headerTitle,
        headerSubtitle: widget.headerSubtitle,
      ),
    ];
  }

  ImageGalleryItem get _currentItem => _items[_currentGalleryIndex];

  int _readGalleryIndexFromController() {
    if (widget._useGallery && _galleryPageController.hasClients) {
      final page = _galleryPageController.page;
      if (page != null) {
        return page.round().clamp(0, _items.length - 1);
      }
    }
    return _dismissGalleryIndex ?? _resolveGalleryIndex();
  }

  int get _closeGalleryIndex => _readGalleryIndexFromController();

  int _resolveGalleryIndex() {
    return resolveMediaPreviewGalleryIndex(
      useGallery: widget._useGallery,
      currentIndex: _currentGalleryIndex,
      itemCount: _items.length,
      page: _galleryPageController.hasClients
          ? _galleryPageController.page
          : null,
    );
  }

  /// 当前页保持 Hero，关闭才能飞回对应气泡；入场结束后也不拆掉。
  bool _allowPreviewHeroForIndex(int index) {
    if (!widget.enableHero) {
      return false;
    }
    if (_isClosing || _closingFromSlideDismiss) {
      return false;
    }
    if (!widget._useGallery) {
      return true;
    }
    return index == _currentGalleryIndex;
  }

  bool get _isGalleryActivelyScrolling {
    if (_galleryScrolling) {
      return true;
    }
    if (!widget._useGallery || !_galleryPageController.hasClients) {
      return false;
    }
    return _galleryPageController.position.isScrollingNotifier.value;
  }

  /// 适配缩放可翻页；长图放大后仅左右贴边可横滑（微信式）。
  bool _canScrollGalleryPage(GestureDetails? details) {
    if (!_entranceLatch.settled) {
      return false;
    }
    final baseline = doubleTapScales.isNotEmpty ? doubleTapScales.first : 1.0;
    final display = _loadedDisplayByIndex[_currentGalleryIndex];
    final gate = _tallImageGalleryGateByIndex[_currentGalleryIndex]?.value ??
        TallImageGalleryScrollGate.initial;
    final isTall = display?.verticallyScrollable == true;
    final allow = canScrollMediaPreviewGalleryPage(
      details: details,
      baselineScale: baseline,
      tallImageGate: isTall ? gate : null,
      tallImageVerticallyScrollable: isTall,
    );
    TallImageGestureDiag.galleryCanScroll(
      allow: allow,
      baselineScale: baseline,
      gate: isTall ? gate : null,
      isTall: isTall,
      detailsScale: details?.totalScale,
      source: 'image_screen',
    );
    return allow;
  }

  ValueNotifier<TallImageGalleryScrollGate> _tallImageGalleryGateFor(
      int index) {
    return _tallImageGalleryGateByIndex.putIfAbsent(
      index,
      () => ValueNotifier<TallImageGalleryScrollGate>(
        TallImageGalleryScrollGate.initial,
      ),
    );
  }

  void _bindGalleryScrollNotifier() {
    if (!widget._useGallery ||
        _galleryScrollNotifierBound ||
        !_galleryPageController.hasClients) {
      return;
    }
    _galleryPageController.position.isScrollingNotifier
        .addListener(_onGalleryScrollingNotifier);
    _galleryScrollNotifierBound = true;
  }

  void _unbindGalleryScrollNotifier() {
    if (!_galleryScrollNotifierBound) {
      return;
    }
    _galleryScrollNotifierBound = false;
    if (!_galleryPageController.hasClients) {
      return;
    }
    _galleryPageController.position.isScrollingNotifier
        .removeListener(_onGalleryScrollingNotifier);
  }

  void _onGalleryScrollingNotifier() {
    if (!mounted || _isClosing || !widget._useGallery) {
      return;
    }
    if (!_galleryPageController.hasClients) {
      return;
    }
    final scrolling = _galleryPageController.position.isScrollingNotifier.value;
    if (scrolling) {
      _galleryScrolling = true;
      _galleryIdleWorkTimer?.cancel();
      return;
    }
    _galleryScrolling = false;
    _scheduleGalleryIdleWork();
  }

  void _scheduleGalleryIdleWork() {
    _galleryIdleWorkTimer?.cancel();
    _galleryIdleWorkTimer = Timer(_galleryIdleWorkDelay, () {
      if (!mounted || _isClosing || _isGalleryActivelyScrolling) {
        return;
      }
      _runGalleryIdleWork();
    });
  }

  void _runGalleryIdleWork() {
    if (!mounted || _isClosing || !widget._useGallery) {
      return;
    }
    final index = _currentGalleryIndex;
    _pruneDistantGalleryCaches(index);
    _precacheAdjacentGalleryImages(index);
    final pending = _pendingOriginalRefreshIndex;
    if (pending != null && pending == index && pending < _items.length) {
      _pendingOriginalRefreshIndex = null;
      _scheduleOriginalRefreshIfNeeded(
        index: pending,
        item: _items[pending],
      );
    }
  }

  /// 多图连滑时丢掉远离当前页的手势 Key / 扇形动画，控制内存与重建成本。
  void _pruneDistantGalleryCaches(int center) {
    bool far(int i) => (i - center).abs() > _galleryCacheRadius;

    final staleKeys = _gestureKeys.keys.where(far).toList(growable: false);
    for (final i in staleKeys) {
      _gestureKeys.remove(i);
    }

    final staleFans =
        _originalFanControllers.keys.where(far).toList(growable: false);
    for (final i in staleFans) {
      _originalRevealProviders.remove(i);
      _disposeFanControllerForIndex(i);
    }

    if (_loadedDisplayByIndex.length > 24) {
      _loadedDisplayByIndex.removeWhere((i, _) => far(i));
      _heroLockedBoxSizeByIndex.removeWhere((i, _) => far(i));
    }
  }

  void _resetDismissGalleryIndex() {
    if (_isSlideDismissActive) {
      return;
    }
    _dismissGalleryIndex = null;
  }

  bool get _isSlideDismissActive {
    if (_isClosing && _closingFromSlideDismiss) {
      return true;
    }
    final slideState = slidePageKey.currentState;
    if (slideState?.isSliding == true) {
      return true;
    }
    if (_slideMetrics.slideOffset.dy > 0.5) {
      return true;
    }
    return false;
  }

  void _interruptGalleryPageScrollIfNeeded({bool forceCurrent = false}) {
    if (!widget._useGallery || !_galleryPageController.hasClients) {
      return;
    }
    final position = _galleryPageController.position;
    final page = _galleryPageController.page ?? _currentGalleryIndex.toDouble();
    final target = forceCurrent
        ? _currentGalleryIndex
        : page.round().clamp(0, _items.length - 1);
    final scrolling = position.isScrollingNotifier.value;
    if (!scrolling && !forceCurrent) {
      return;
    }
    if ((page - target).abs() < 0.001 && !scrolling) {
      return;
    }
    _jumpGalleryToPage(target);
  }

  void _jumpGalleryToPage(int index) {
    _scheduleJumpGalleryToPage(index);
  }

  void _scheduleJumpGalleryToPage(int index) {
    if (_items.isEmpty) {
      return;
    }
    _pendingGalleryJumpIndex = index.clamp(0, _items.length - 1).toInt();
    _galleryJumpAttempt = 0;
    _runGalleryJumpAttempt();
  }

  void _runGalleryJumpAttempt() {
    final target = _pendingGalleryJumpIndex;
    if (target == null || !mounted || _isClosing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isClosing || _pendingGalleryJumpIndex == null) {
        return;
      }
      if (!_galleryPageController.hasClients || _items.isEmpty) {
        _retryGalleryJump();
        return;
      }
      final clamped =
          _pendingGalleryJumpIndex!.clamp(0, _items.length - 1).toInt();
      if (_galleryPageMatchesTarget(clamped)) {
        _currentGalleryIndex = clamped;
        _pendingGalleryJumpIndex = null;
        _galleryJumpAttempt = 0;
        return;
      }
      final pos = _galleryPageController.position;
      if (pos.hasViewportDimension &&
          pos.viewportDimension > 0 &&
          clamped > 0) {
        final reachableMaxPage =
            (pos.maxScrollExtent / pos.viewportDimension).round();
        if (chatMediaGalleryMustDeferPageJump(
          targetIndex: clamped,
          attachedChildCount: reachableMaxPage + 1,
        )) {
          _retryGalleryJump();
          return;
        }
      }
      if (_galleryPageJumpInFlight) {
        _retryGalleryJump();
        return;
      }
      _galleryPageJumpInFlight = true;
      try {
        _galleryPageController.jumpToPage(clamped);
      } finally {
        _galleryPageJumpInFlight = false;
      }
      if (!_galleryPageMatchesTarget(clamped)) {
        _jumpGalleryPageByOffset(clamped);
      }
      if (_galleryPageMatchesTarget(clamped)) {
        _currentGalleryIndex = clamped;
        _pendingGalleryJumpIndex = null;
        _galleryJumpAttempt = 0;
        return;
      }
      _retryGalleryJump();
    });
  }

  void _retryGalleryJump() {
    _galleryJumpAttempt++;
    if (_galleryJumpAttempt >= _maxGalleryJumpAttempts) {
      _pendingGalleryJumpIndex = null;
      return;
    }
    _runGalleryJumpAttempt();
  }

  int _resolveGalleryIndexAfterItemsChange({
    required List<ImageGalleryItem>? oldItems,
    required List<ImageGalleryItem> newItems,
    required int currentIndex,
  }) {
    final newMessages = chatMediaGalleryMessagesFromImageItems(newItems);
    final oldMessages = oldItems == null
        ? const <V2TimMessage>[]
        : chatMediaGalleryMessagesFromImageItems(oldItems);
    return resolveChatMediaGalleryIndexAfterExpand(
      currentIndex: currentIndex,
      oldOldestFirst: oldMessages,
      newOldestFirst: newMessages,
      tappedMessage: widget.sourceMessage,
      preferredIndex: widget.initialIndex,
    );
  }

  GlobalKey<ExtendedImageGestureState> _gestureKeyForIndex(int index) {
    return _gestureKeys.putIfAbsent(
      index,
      () => GlobalKey<ExtendedImageGestureState>(),
    );
  }

  void _hideHero(Object tag) {
    final tagText = tag.toString();
    if (tagText.isEmpty) {
      return;
    }
    if (_hiddenHeroTags.add(tag)) {
      MediaPreviewHeroRegistry.instance.hide(tag);
    }
  }

  void _showHero(Object tag) {
    final tagText = tag.toString();
    if (tagText.isEmpty) {
      return;
    }
    if (_hiddenHeroTags.remove(tag)) {
      MediaPreviewHeroRegistry.instance.show(tag);
    }
  }

  void _syncGalleryHeroVisibility({
    required int previousIndex,
    required int currentIndex,
  }) {
    if (!widget._useGallery || _isClosing) {
      return;
    }
    // 入场黑遮罩未铺满前，只藏当前图，避免翻页时提前 show 上一张在半透明层下闪烁。
    if (!_entranceLatch.settled) {
      if (currentIndex >= 0 && currentIndex < _items.length) {
        _hideHero(_heroTagForItem(_items[currentIndex]));
      }
      return;
    }
    // 与 Telegram galleryHiddenMedia 一致：仅当前居中图隐藏，翻页时恢复上一张、隐藏新当前。
    // 入场结束后遮罩全黑，非当前缩略图恢复可见也不会透出。
    if (previousIndex != currentIndex &&
        previousIndex >= 0 &&
        previousIndex < _items.length) {
      _showHero(_heroTagForItem(_items[previousIndex]));
    }
    if (currentIndex >= 0 && currentIndex < _items.length) {
      _hideHero(_heroTagForItem(_items[currentIndex]));
    }
  }

  void _hideInitialGalleryHero() {
    if (!widget._useGallery) {
      return;
    }
    final index = _currentGalleryIndex.clamp(0, _items.length - 1);
    _hideHero(_heroTagForItem(_items[index]));
  }

  void _revealCloseHero() {
    if (_closeHeroRevealed) {
      return;
    }
    final closeIndex = _closeGalleryIndex;
    if (closeIndex >= 0 && closeIndex < _items.length) {
      _closeHeroRevealed = true;
      final item = _items[closeIndex];
      _showHero(_heroTagForItem(item));
      widget.onClosing?.call(item.messageID, item.heroTag);
    }
  }

  void _scheduleCloseHeroReveal() {
    if (_closeHeroRevealed || _closeHeroRevealScheduled) {
      return;
    }
    _closeHeroRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeHeroRevealScheduled = false;
      if (!_isClosing) {
        return;
      }
      _revealCloseHero();
    });
  }

  void _revealHiddenHeroesNow() {
    if (_hiddenHeroTags.isEmpty) {
      return;
    }
    final tags = Set<Object>.from(_hiddenHeroTags);
    _hiddenHeroTags.clear();
    MediaPreviewHeroRegistry.instance.revealAll(tags);
  }

  void _releaseHiddenHeroes() {
    if (_closingFromSlideDismiss) {
      final tags = Set<Object>.from(_hiddenHeroTags);
      _hiddenHeroTags.clear();
      MediaPreviewHeroRegistry.instance.scheduleRevealAll(
        tags,
        delay: const Duration(milliseconds: 180),
      );
      return;
    }
    _revealHiddenHeroesNow();
  }

  Object _heroTagForItem(ImageGalleryItem item) => item.heroTag;

  void _toggleChromeVisibility() {
    if (_isClosing) {
      return;
    }
    _chromeVisible = !_chromeVisible;
    _chromeTick.value++;
  }

  void _handleOuterImageTap(int index) {
    // 长图组件用原始 Pointer 事件立即处理单击；外层 GestureDetector 会在
    // 双击判定窗口结束后再次收到同一次点击。这里跳过第二次切换，避免工具栏
    // 先隐藏、约 300ms 后又自动出现。
    if (_loadedDisplayByIndex[index]?.verticallyScrollable == true) {
      return;
    }
    _toggleChromeVisibility();
  }

  void _notifyChromeChanged() {
    if (!mounted) {
      return;
    }
    _chromeTick.value++;
  }

  /// 预解码相邻页，减少滑入时才开始解码的卡顿。
  void _precacheAdjacentGalleryImages(int index) {
    if (!widget._useGallery || !mounted) {
      return;
    }
    _galleryPrecache.precacheAdjacent(
      context: context,
      centerIndex: index,
      itemCount: _items.length,
      radius: _galleryCacheRadius,
      resolveProvider: (adjacent) {
        final provider = _resolveImageProvider(
          _items[adjacent],
          adjacent,
        );
        return provider;
      },
    );
  }

  String get _headerTitle =>
      _currentItem.headerTitle ?? widget.headerTitle ?? TIM_t('您');

  String get _headerSubtitle =>
      _currentItem.headerSubtitle ?? widget.headerSubtitle ?? '';

  String? get _galleryIndicator {
    if (!widget._useGallery || _items.length <= 1) {
      return null;
    }
    return chatMediaGalleryPageLabel(
      indexOldestFirst: _currentGalleryIndex,
      count: _items.length,
    );
  }

  Future<void> _handleDelete() async {
    final deleteFn = _currentItem.deleteFn ?? widget.deleteFn;
    if (deleteFn == null) {
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(TIM_t('删除')),
        content: Text(TIM_t('确定删除这条消息吗？')),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(TIM_t('取消')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(TIM_t('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runOverlayAction(deleteFn);
    if (mounted) {
      close();
    }
  }

  void _showMoreMenu() {
    final item = _currentItem;
    showMediaPreviewMoreSheet(
      context: context,
      onDownload: item.downloadFn ?? widget.downloadFn,
      onEdit: item.editFn == null
          ? null
          : () => _runOverlayAction(() => item.editFn!(context)),
      onForward: item.forwardFn ?? widget.forwardFn,
      onDelete: item.deleteFn ?? widget.deleteFn,
    );
  }

  void _invalidateSlideBodyCache() {
    _cachedSlideBody = null;
  }

  void _onSlidingPage(ExtendedImageSlidePageState state) {
    if (state.isSliding) {
      _dismissGalleryIndex ??= _readGalleryIndexFromController();
      _interruptGalleryPageScrollIfNeeded();
    }
    _slideMetrics.updateFromSlide(state, MediaQuery.sizeOf(context));
  }

  Widget _buildBodyWithSlideOffset(Orientation orientation) {
    if (_cachedSlideBody == null ||
        _cachedSlideBodyOrientation != orientation) {
      _cachedSlideBodyOrientation = orientation;
      _cachedSlideBody = RepaintBoundary(child: _buildImageBody(orientation));
    }
    // 位移仅由 GesturedImage + SlideType.onlyImage 处理，避免整页重复 transform 导致顿挫。
    return _cachedSlideBody!;
  }

  bool _prepareForClose({bool preserveSlideBackdrop = false}) {
    if (_isClosing || !mounted) {
      return false;
    }
    _closingFromSlideDismiss = preserveSlideBackdrop;
    _isClosing = true;
    final closeIndex = _closeGalleryIndex;
    final closeItem = closeIndex >= 0 && closeIndex < _items.length
        ? _items[closeIndex]
        : _currentItem;
    final closeHeroTag = _heroTagForItem(closeItem);
    _heroModeEnabled.value = widget.enableHero &&
        canHeroDismissToTarget(
          heroTag: closeHeroTag.toString(),
          targetIsLive:
              MediaPreviewHeroRegistry.instance.isTargetLive(closeHeroTag),
        );
    if (!preserveSlideBackdrop) {
      _slideMetrics.resetBackdrop();
    }
    if (preserveSlideBackdrop) {
      _scheduleCloseHeroReveal();
    } else {
      _revealCloseHero();
    }
    // 下滑关闭禁止 setState，避免重建打断跟手缩放。
    // 普通关闭（非下滑）再刷新以关掉 HeroMode。
    if (!preserveSlideBackdrop) {
      setState(() {});
    }
    return true;
  }

  void _popSlideDismissRoute() {
    if (!_isClosing) {
      return;
    }
    _revealCloseHero();
    // 勿在 pop 前调用 popPage/resetBackdrop：会把图片收起而遮罩回到 1.0 全黑。
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _scheduleSlideDismissMomentumPop(
    ExtendedImageSlidePageState? state,
    ScaleEndDetails? details,
    Offset releaseOffset,
  ) {
    _slideDismissController.startMomentumDismiss(
      vsync: this,
      context: context,
      slidePageKey: slidePageKey,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _isClosing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismissRoute,
      details: details,
      releaseOffset: releaseOffset,
    );
  }

  void close() {
    _slideDismissController.startMomentumDismiss(
      vsync: this,
      context: context,
      slidePageKey: slidePageKey,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _isClosing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismissRoute,
      releaseOffset: _slideMetrics.slideOffset,
    );
  }

  /// 下滑关闭：微信式缩放淡出后 pop。
  bool closeFromSlideDismiss(
    ExtendedImageSlidePageState? state,
    ScaleEndDetails? details,
    Offset releaseOffset,
  ) {
    _scheduleSlideDismissMomentumPop(state, details, releaseOffset);
    return true;
  }

  /// 长图顶部下拉关闭：微信式缩放淡出（只动画 metrics），保留遮罩后 pop。
  void closeFromTallImageSlideDismiss(
    Offset releaseOffset,
    ScaleEndDetails? details,
  ) {
    _interruptGalleryPageScrollIfNeeded(forceCurrent: true);
    _slideDismissController.startMetricsMomentumDismiss(
      vsync: this,
      context: context,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _isClosing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismissRoute,
      details: details,
      releaseOffset: releaseOffset,
    );
  }

  @override
  void initState() {
    super.initState();
    _heroModeEnabled = ValueNotifier<bool>(widget.enableHero);
    _entranceLatch = MediaPreviewEntranceLatch(
      onSettled: () {
        // Chrome 已随 animation completed 到 1。不要重建 body / 拆 Hero，落地会闪。
        if (widget._useGallery) {
          final target = _indexForSourceMessage(fallback: _currentGalleryIndex);
          _currentGalleryIndex = target;
          if (!_galleryPageMatchesTarget(target)) {
            _scheduleJumpGalleryToPage(target);
          }
        }
      },
    );
    imagePreviewTapToCloseCallback = _toggleChromeVisibility;
    imagePreviewSlideDismissCallback = (state, details, offset) {
      return closeFromSlideDismiss(state, details, offset);
    };
    _currentGalleryIndex = widget._useGallery
        ? _indexForSourceMessage(fallback: widget.initialIndex)
        : 0;
    _galleryPageController = _createGalleryPageController(_currentGalleryIndex);
    _doubleClickAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bindGalleryScrollNotifier();
      _slideMetrics.resetBackdrop();
      if (widget._useGallery) {
        if (widget.enableHero) {
          _hideInitialGalleryHero();
        }
        _precacheAdjacentGalleryImages(_currentGalleryIndex);
      } else if (widget.enableHero) {
        _hideHero(_heroTagForItem(_currentItem));
      }
      _entranceLatch.bind(
        mediaPreviewChromeAnimation(context),
        routeDuration: ModalRoute.of(context)?.transitionDuration,
      );
      if (widget._useGallery) {
        // 入场后再绑一次，确保 PageView attach 后能监听到 scrolling。
        _bindGalleryScrollNotifier();
      }
      Future<void>.delayed(mediaPreviewBackdropDuration, () {
        if (!mounted) {
          return;
        }
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      });
    });
  }

  @override
  void didUpdateWidget(covariant ImageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItems = oldWidget.galleryItems;
    final newItems = widget.galleryItems;
    final itemsChanged = !identical(oldItems, newItems) &&
        oldItems != newItems &&
        newItems != null &&
        newItems.isNotEmpty;
    final initialChanged = oldWidget.initialIndex != widget.initialIndex;
    if (!itemsChanged && !initialChanged) {
      return;
    }
    if (newItems == null || newItems.isEmpty) {
      return;
    }
    final oldIndex = _currentGalleryIndex;
    final mappedIndex = _resolveGalleryIndexAfterItemsChange(
      oldItems: oldItems,
      newItems: newItems,
      currentIndex: oldIndex,
    );
    final nextIndex = _indexForSourceMessage(fallback: mappedIndex);
    final countChanged = (oldItems?.length ?? 0) != newItems.length;
    _currentGalleryIndex = nextIndex;
    if (nextIndex != oldIndex || countChanged) {
      _invalidateSlideBodyCache();
      _pruneDistantGalleryCaches(nextIndex);
    }
    if (chatMediaGalleryShouldReplacePageController(
      oldItemCount: oldItems?.length ?? 0,
      newItemCount: newItems.length,
    )) {
      _replaceGalleryPageController(nextIndex);
      return;
    }
    _scheduleJumpGalleryToPage(nextIndex);
  }

  ExtendedPageController _createGalleryPageController(int initialPage) {
    final count = widget._useGallery ? (widget.galleryItems?.length ?? 0) : 1;
    final page = count <= 0 ? 0 : initialPage.clamp(0, count - 1).toInt();
    return ExtendedPageController(
      initialPage: page,
      pageSpacing: kChatMediaGalleryPageSpacing,
      shouldIgnorePointerWhenScrolling: true,
    );
  }

  void _replaceGalleryPageController(int initialPage) {
    _unbindGalleryScrollNotifier();
    final old = _galleryPageController;
    _pageControllerEpoch++;
    final clamped = _items.isEmpty
        ? 0
        : initialPage.clamp(0, _items.length - 1).toInt();
    _currentGalleryIndex = clamped;
    _galleryPageController = _createGalleryPageController(clamped);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      if (!mounted || _isClosing) {
        return;
      }
      _bindGalleryScrollNotifier();
      _scheduleJumpGalleryToPage(clamped);
    });
  }

  @override
  void dispose() {
    if (imagePreviewTapToCloseCallback == _toggleChromeVisibility) {
      imagePreviewTapToCloseCallback = null;
    }
    if (imagePreviewSlideDismissCallback != null) {
      imagePreviewSlideDismissCallback = null;
    }
    _galleryIdleWorkTimer?.cancel();
    _galleryPrecache.invalidate();
    _evictOpenedPreviewBitmaps();
    _unbindGalleryScrollNotifier();
    _slideMetrics.dispose();
    _heroModeEnabled.dispose();
    _entranceLatch.dispose();
    _resetDismissGalleryIndex();
    _slideDismissController.dispose();
    for (final controller in _originalFanControllers.values) {
      controller.dispose();
    }
    _originalFanControllers.clear();
    _releaseHiddenHeroes();
    _doubleClickAnimationController.dispose();
    _galleryPageController.dispose();
    _chromeTick.dispose();
    super.dispose();
  }

  /// 只驱逐本页打开过的预览大图/原图位图，保留气泡 thumb。
  void _evictOpenedPreviewBitmaps() {
    if (PlatformUtils().isWeb) {
      return;
    }
    final providers = <ImageProvider?>[
      ..._refreshedProviders.values,
      ..._originalRevealProviders.values,
      widget.imageProvider,
    ];
    final items = widget.galleryItems;
    if (items != null) {
      for (final item in items) {
        providers.add(item.imageProvider);
      }
    }
    evictChatPreviewImageProviders(providers);
  }

  void _onDoubleTap(ExtendedImageGestureState state) {
    final Offset? pointerDownPosition = state.pointerDownPosition;
    final double? begin = state.gestureDetails!.totalScale;
    double end;

    _doubleClickAnimation?.removeListener(_doubleClickAnimationListener);
    _doubleClickAnimationController.stop();
    _doubleClickAnimationController.reset();

    if (begin == doubleTapScales[0]) {
      end = doubleTapScales[1];
    } else {
      end = doubleTapScales[0];
    }

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

  ImageProvider? _resolveImageProvider(
    ImageGalleryItem item,
    int index, {
    bool preferFullResolution = false,
  }) {
    final messageId = item.messageID?.trim();
    if (messageId != null && messageId.isNotEmpty) {
      final edited = ImagePreviewEditStore.instance.peek(messageId);
      if (edited != null && edited.existsSync()) {
        return FileImage(edited);
      }
    }
    final primary = _refreshedProviders[index] ?? item.imageProvider;
    if (primary == null) {
      return null;
    }
    // 始终加载大图/原图；加载中由 LoadingLayer 铺气泡底图，避免入场后再切换造成黑屏。
    return ChatMessagePreviewImageResolver.wrapPreviewDecode(
      context: context,
      message: item.sourceMessage ?? widget.sourceMessage,
      provider: primary,
      preferFullResolution: preferFullResolution,
    );
  }

  ImageProvider? _placeholderForItem(ImageGalleryItem item) {
    final existing = item.placeholderImageProvider;
    if (existing != null) {
      return existing;
    }
    final message = item.sourceMessage ?? widget.sourceMessage;
    if (message == null ||
        message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return null;
    }
    return ChatMessagePreviewImageResolver.resolvePlaceholder(message);
  }

  Widget _buildLoadingPlaceholder(ImageGalleryItem item, int index) {
    final placeholder = _placeholderForItem(item);
    final screenSize = MediaQuery.sizeOf(context);
    final display = _loadedDisplayByIndex[index] ??
        imagePreviewDisplayConfigResolved(
          sourceMessage: item.sourceMessage ?? widget.sourceMessage,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
        );
    return ImagePreviewLoadingLayer(
      placeholder: placeholder,
      fit: imagePreviewPaintFit(
        display,
        fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
      ),
      alignment: display.alignment,
      showSpinner: _entranceLatch.settled,
    );
  }

  void _scheduleOriginalRefreshIfNeeded({
    required int index,
    required ImageGalleryItem item,
    int? loadedImageWidth,
    int? loadedImageHeight,
  }) {
    if (_isClosing || _isSlideDismissActive) {
      return;
    }
    if (widget._useGallery && index != _currentGalleryIndex) {
      return;
    }
    if (widget._useGallery && _isGalleryActivelyScrolling) {
      _pendingOriginalRefreshIndex = index;
      return;
    }
    if (_lowResolutionRefreshAttempted.contains(index) ||
        _lowResolutionRefreshInFlight.contains(index) ||
        _originalFanRevealCompleted.contains(index) ||
        _originalRevealProviders.containsKey(index)) {
      return;
    }
    final message = item.sourceMessage ?? widget.sourceMessage;
    if (message == null ||
        message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return;
    }
    final currentProvider = _refreshedProviders[index] ?? item.imageProvider;
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
      _lowResolutionRefreshAttempted.add(index);
      return;
    }

    Future<void> runRefresh() async {
      if (!mounted ||
          _isClosing ||
          _isSlideDismissActive ||
          _lowResolutionRefreshAttempted.contains(index) ||
          _lowResolutionRefreshInFlight.contains(index) ||
          _originalFanRevealCompleted.contains(index)) {
        return;
      }
      if (widget._useGallery && index != _currentGalleryIndex) {
        return;
      }
      _lowResolutionRefreshInFlight.add(index);
      try {
        final originalProvider =
            await ChatMessagePreviewImageResolver.refreshOriginal(message);
        if (!mounted ||
            _isClosing ||
            _isSlideDismissActive ||
            originalProvider == null) {
          // 升原图失败：标记已尝试，避免空转；继续展示当前 BIG。
          if (mounted && !_isClosing && !_isSlideDismissActive) {
            _lowResolutionRefreshAttempted.add(index);
          }
          return;
        }
        if (ChatMessagePreviewImageResolver.isSameImageProvider(
          originalProvider,
          currentProvider,
        )) {
          _lowResolutionRefreshAttempted.add(index);
          return;
        }
        _lowResolutionRefreshAttempted.add(index);
        final display = _loadedDisplayByIndex[index] ??
            imagePreviewDisplayConfigForItem(
              sourceMessage: message,
              screenWidth: MediaQuery.sizeOf(context).width,
              screenHeight: MediaQuery.sizeOf(context).height,
              fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
            );
        if (display.verticallyScrollable) {
          if (!mounted || _isClosing || _isSlideDismissActive) {
            return;
          }
          if (widget._useGallery &&
              (index != _currentGalleryIndex || _isGalleryActivelyScrolling)) {
            _pendingOriginalRefreshIndex = index;
            return;
          }
          try {
            await _precachePreviewImage(originalProvider);
          } catch (_) {
            if (mounted && !_isClosing && !_isSlideDismissActive) {
              _lowResolutionRefreshAttempted.add(index);
            }
            return;
          }
          if (!mounted || _isClosing || _isSlideDismissActive) {
            return;
          }
          setState(() {
            _completeOriginalUpgrade(
              index: index,
              originalProvider: originalProvider,
            );
          });
          return;
        }
        await _playOriginalFanReveal(
          index: index,
          originalProvider: originalProvider,
          display: display,
        );
      } finally {
        if (mounted) {
          if (_isClosing || _isSlideDismissActive) {
            _lowResolutionRefreshInFlight.remove(index);
          } else {
            setState(() {
              _lowResolutionRefreshInFlight.remove(index);
            });
          }
        }
      }
    }

    if (_entranceLatch.settled) {
      unawaited(runRefresh());
      return;
    }
    Future<void>.delayed(mediaPreviewBackdropDuration, () {
      if (mounted) {
        unawaited(runRefresh());
      }
    });
  }

  Widget _buildExtendedImage({
    required ImageGalleryItem item,
    required int index,
    required bool inPageView,
    required Orientation orientation,
  }) {
    final gestureKey = widget._useGallery
        ? _gestureKeyForIndex(index)
        : extendedImageGestureKey;
    final activeIndex = _isClosing ? _closeGalleryIndex : _currentGalleryIndex;
    final onActivePage = !widget._useGallery || index == activeIndex;
    final useHero = !_isClosing &&
        !_closingFromSlideDismiss &&
        item.heroTag.isNotEmpty &&
        onActivePage &&
        _allowPreviewHeroForIndex(index);
    final imageProvider = _resolveImageProvider(item, index);
    if (imageProvider == null) {
      return Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
      );
    }

    final screenSize = MediaQuery.sizeOf(context);
    final display = _loadedDisplayByIndex[index] ??
        imagePreviewDisplayConfigResolved(
          sourceMessage: item.sourceMessage ?? widget.sourceMessage,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
        );
    final computedBoxSize = imagePreviewBoxSizeFor(
      display: display,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
    );
    // Freeze the Hero flight box size on first build. ORIGIN decode can
    // shift the aspect ratio by a few pixels, which would otherwise make
    // the dismiss Hero land at a slightly different rect than the entrance
    // Hero started from (visible "jump" on close).
    final heroBoxSize = _heroLockedBoxSizeByIndex.putIfAbsent(
      index,
      () => computedBoxSize,
    );
    // The displayed image still uses the live box size (so ORIGIN upgrades
    // render crisply); only the Hero flight geometry is locked.
    final boxSize = computedBoxSize;
    final imageFit = imagePreviewPaintFit(
      display,
      fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
    );

    Widget image = ExtendedImage(
      key: ValueKey<String>(
        'preview_${item.messageID ?? '$index'}_'
        '${ImagePreviewEditStore.instance.revision.value}',
      ),
      image: imageProvider,
      width: boxSize.width,
      height: boxSize.height,
      fit: imageFit,
      alignment: display.alignment,
      gaplessPlayback: true,
      enableLoadState: true,
      extendedImageGestureKey: gestureKey,
      enableSlideOutPage: true,
      // 默认 Clip.antiAlias 会把放大后的图片裁回 boxSize 矩形内，
      // 导致放大无法超出初始显示尺寸。none 让绘制自然溢出框外。
      clipBehavior: Clip.none,
      initGestureConfigHandler: (state) {
        final screenSize = MediaQuery.sizeOf(context);
        final info = state.extendedImageInfo;
        final display = imagePreviewDisplayConfigResolved(
          sourceMessage: item.sourceMessage ?? widget.sourceMessage,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          decodedWidth: info?.image.width ?? 0,
          decodedHeight: info?.image.height ?? 0,
          fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
        );
        final maxScale = imagePreviewMaxScale(
          imageWidth: display.imageWidth,
          imageHeight: display.imageHeight,
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          fit: display.fit,
        );
        return buildImagePreviewGestureConfig(
          inPageView: inPageView,
          display: display,
          maxScale: maxScale,
        );
      },
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return _buildLoadingPlaceholder(item, index);
          case LoadState.completed:
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;
            final imgHeight = state.extendedImageInfo?.image.height ?? 1;
            final imgWidth = state.extendedImageInfo?.image.width ?? 0;
            final builtDisplay = _loadedDisplayByIndex[index] ??
                imagePreviewDisplayConfigResolved(
                  sourceMessage: item.sourceMessage ?? widget.sourceMessage,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
                );
            final display = imagePreviewDisplayConfigResolved(
              sourceMessage: item.sourceMessage ?? widget.sourceMessage,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              decodedWidth: imgWidth,
              decodedHeight: imgHeight,
              fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
            );
            final doubleTapTarget = imagePreviewDoubleTapScale(
              imageWidth: display.imageWidth,
              imageHeight: display.imageHeight,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              display: display,
            );
            final panScale = imagePreviewInitialScale(
              verticallyScrollable: display.verticallyScrollable,
            );
            fittedScale = doubleTapTarget;
            doubleTapScales = [panScale, doubleTapTarget];
            _loadedDisplayByIndex[index] = display;
            // 仅在元数据宽高比与解码不一致（EXIF 等）时重建，避免解码后二次跳位置。
            if (!builtDisplay.layoutEquals(display)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _isClosing) {
                  return;
                }
                setState(() {});
              });
            }
            _scheduleOriginalRefreshIfNeeded(
              index: index,
              item: item,
              loadedImageWidth: imgWidth,
              loadedImageHeight: imgHeight,
            );
            // extended_image 在约 1x 时无法可靠纵滑长图，可纵滑内容仍走专用组件。
            if (display.verticallyScrollable) {
              final maxScale = imagePreviewMaxScale(
                imageWidth: display.imageWidth,
                imageHeight: display.imageHeight,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                fit: display.fit,
              );
              return SizedBox.expand(
                child: TallImageScrollPreview(
                  extendedImageState: state,
                  maxScale: maxScale,
                  doubleTapTarget: doubleTapTarget,
                  slidePageKey: slidePageKey,
                  slideMetrics: _slideMetrics,
                  displayMode: display.mode,
                  inPageView: inPageView,
                  galleryScrollGate: _tallImageGalleryGateFor(index),
                  onTap: _toggleChromeVisibility,
                  onDismissGestureStarted: () {
                    _interruptGalleryPageScrollIfNeeded(forceCurrent: true);
                  },
                  onSlideDismiss: (offset, {details}) {
                    closeFromTallImageSlideDismiss(offset, details);
                  },
                ),
              );
            }
            return GesturedImage(state, key: gestureKey);
          case LoadState.failed:
            return Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image,
                  color: Colors.white54, size: 48),
            );
        }
      },
      onDoubleTap: _onDoubleTap,
      mode: ExtendedImageMode.gesture,
    );

    if (useHero && item.heroTag.isNotEmpty) {
      image = HeroWidget(
        tag: item.heroTag,
        slidePagekey: slidePageKey,
        animateCornerRadius: true,
        cornerRadius: 10,
        child: image,
      );
    }

    final revealProvider = _originalRevealProviders[index];
    final fanController = _originalFanControllers[index];
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
      // Hero flight uses the locked box size so entrance and dismiss use
      // the same geometry (prevents a close-time "jump" from ORIGIN decode
      // shifting the aspect ratio by a few pixels).
      displaySize: heroBoxSize,
      alignment: display.alignment,
      child: ImagePreviewDisplayBox(
        displaySize: boxSize,
        alignment: display.alignment,
        child: image,
      ),
    );
    final rotationTurns = _previewRotationTurns[index] ?? 0;
    if (rotationTurns != 0) {
      image = Transform.rotate(
        angle: rotationTurns * math.pi / 2,
        child: image,
      );
    }
    return image;
  }

  Widget _buildGalleryItem({
    required ImageGalleryItem item,
    required int index,
    required bool inPageView,
    required Orientation orientation,
  }) {
    return _buildExtendedImage(
      item: item,
      index: index,
      inPageView: inPageView,
      orientation: orientation,
    );
  }

  Widget _buildGalleryView(Orientation orientation) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) {
          return false;
        }
        if (_galleryPageJumpInFlight) {
          return false;
        }
        if (notification is ScrollStartNotification) {
          _galleryScrolling = true;
          _galleryIdleWorkTimer?.cancel();
          final page = _galleryPageController.hasClients
              ? _galleryPageController.page
              : null;
          if (page != null && (page - _currentGalleryIndex).abs() >= 0.45) {
            _jumpGalleryToPage(_currentGalleryIndex);
          }
        } else if (notification is ScrollEndNotification) {
          _galleryScrolling = false;
          _scheduleGalleryIdleWork();
        }
        return false;
      },
      child: ExtendedImageGesturePageView.builder(
        key: ValueKey<int>(_pageControllerEpoch),
        controller: _galleryPageController,
        itemCount: _items.length,
        scrollDirection: Axis.horizontal,
        physics: ChatMediaGalleryScrollPhysics.of(context),
        canScrollPage: _canScrollGalleryPage,
        onPageChanged: (index) {
          final sliding = _isSlideDismissActive;
          if (!sliding) {
            _resetDismissGalleryIndex();
            _slideMetrics.resetBackdrop();
          }
          final previousIndex = _currentGalleryIndex;
          if (index == previousIndex) {
            return;
          }
          // 离开页重置缩放，避免连滑回来仍停在放大态抢手势。
          _doubleClickAnimationController.stop();
          _doubleClickAnimationController.reset();
          _gestureKeyForIndex(previousIndex).currentState?.reset();
          if (!sliding) {
            _gestureKeyForIndex(index).currentState?.reset();
          }
          final pendingFan = _originalFanControllers[previousIndex];
          if (pendingFan != null && pendingFan.isAnimating) {
            pendingFan.stop();
            _originalRevealProviders.remove(previousIndex);
          }
          // 只改字段 + 刷新顶栏，避免 setState 打断翻页 ballistic。
          _currentGalleryIndex = index;
          fittedScale = 1.0;
          doubleTapScales = [1.0, 2.0];
          _chromeVisible = true;
          _notifyChromeChanged();
          // 预缓存放到停稳后的 idle work，连滑时不刷解码队列。
          if (!_isGalleryActivelyScrolling) {
            _precacheAdjacentGalleryImages(index);
          }
          if (!sliding) {
            _syncGalleryHeroVisibility(
              previousIndex: previousIndex,
              currentIndex: index,
            );
          }
        },
        itemBuilder: (context, index) {
          final item = _items[index];
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () => _handleOuterImageTap(index),
              behavior: HitTestBehavior.deferToChild,
              child: SizedBox.expand(
                child: _buildGalleryItem(
                  item: item,
                  index: index,
                  inPageView: true,
                  orientation: orientation,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageBody(Orientation orientation) {
    if (widget._useGallery) {
      return _buildGalleryView(orientation);
    }
    final item = _items.first;
    return GestureDetector(
      onTap: () => _handleOuterImageTap(0),
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox.expand(
        child: _buildGalleryItem(
          item: item,
          index: 0,
          inPageView: false,
          orientation: orientation,
        ),
      ),
    );
  }

  Widget _buildPreviewChrome(Animation<double> routeAnimation) {
    return ListenableBuilder(
      listenable: Listenable.merge([_slideMetrics, _chromeTick]),
      builder: (context, _) {
        if (!_chromeVisible || !_showPreviewChrome) {
          return const SizedBox.shrink();
        }
        final item = _currentItem;
        final downloadFn = item.downloadFn ?? widget.downloadFn;
        final forwardFn = item.forwardFn ?? widget.forwardFn;
        final editFn = item.editFn;
        final deleteFn = item.deleteFn ?? widget.deleteFn;
        final hasMore = !_showWebPreviewTools &&
            !widget.downloadOnly &&
            (downloadFn != null ||
                editFn != null ||
                forwardFn != null ||
                deleteFn != null);

        final chrome = Stack(
          clipBehavior: Clip.none,
          children: [
            MediaPreviewTopBar(
              title: _headerTitle,
              subtitle: _headerSubtitle,
              galleryIndicator: _galleryIndicator,
              onBack: close,
              onMore: hasMore ? _showMoreMenu : null,
            ),
            MediaPreviewBottomBar(
              downloadOnly: widget.downloadOnly,
              showPreviewTools: _showWebPreviewTools,
              onZoomOut: _showWebPreviewTools
                  ? () => _zoomPreview(factor: 0.85)
                  : null,
              onZoomIn: _showWebPreviewTools
                  ? () => _zoomPreview(factor: 1.15)
                  : null,
              onRotate: _showWebPreviewTools ? _rotatePreview : null,
              onResetView: _showWebPreviewTools ? _resetPreviewView : null,
              onShare:
                  forwardFn == null ? null : () => _runOverlayAction(forwardFn),
              onEdit: editFn == null
                  ? null
                  : () => _runOverlayAction(() => editFn(context)),
              onDownload: downloadFn == null
                  ? null
                  : () => _runOverlayAction(downloadFn),
              onDelete: deleteFn == null ? null : _handleDelete,
            ),
          ],
        );
        final routeOpacity = _entranceLatch.settled
            ? 1.0
            : _entranceLatch.chromeOpacity(routeAnimation).value;
        final opacity = routeOpacity * _slideMetrics.chromeOpacity;
        return IgnorePointer(
          ignoring: opacity < 0.96,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: chrome,
          ),
        );
      },
    );
  }

  Future<void> _runOverlayAction(Future<void> Function() action) async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return ImagePreviewFitPolicyScope(
      fitTallImagesToScreenWidth: widget.fitTallImagesToScreenWidth,
      child: ValueListenableBuilder<bool>(
        valueListenable: _heroModeEnabled,
        builder: (context, heroEnabled, child) {
          return HeroMode(
            enabled: heroEnabled && widget.enableHero,
            child: child!,
          );
        },
        child: ValueListenableBuilder<int>(
          valueListenable: ImagePreviewEditStore.instance.revision,
          builder: (context, _, __) {
            return MediaPreviewSlideShell(
              slidePageKey: slidePageKey,
              slideMetrics: _slideMetrics,
              entranceLatch: _entranceLatch,
              // 无源 Hero（会话媒体网格）必须实心黑底，半透明会透出浅灰网格。
              opaquePlatformBackdrop: !widget.enableHero,
              onSlidingPage: _onSlidingPage,
              slideEndHandler: (
                Offset offset, {
                ExtendedImageSlidePageState? state,
                ScaleEndDetails? details,
              }) {
                final vy = details?.velocity.pixelsPerSecond.dy ?? 0;
                if (mediaPreviewShouldDismissForSlide(offset, vy)) {
                  closeFromSlideDismiss(state, details, offset);
                  return false;
                }
                return null;
              },
              onClose: () {
                if (_isClosing) {
                  return;
                }
                close();
              },
              enableEdgeBack: false,
              bodyBuilder: (context, orientation) {
                final body = _buildBodyWithSlideOffset(orientation);
                if (!_showWebPreviewTools) {
                  return body;
                }
                return Listener(
                  onPointerSignal: _handleWebPointerSignal,
                  child: body,
                );
              },
              chromeBuilder: _buildPreviewChrome,
              overlayChildren: [
                if (isLoading)
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: const BoxDecoration(
                      color: Color(0xB22b2b2b),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      size: 35,
                      color: Colors.white,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
