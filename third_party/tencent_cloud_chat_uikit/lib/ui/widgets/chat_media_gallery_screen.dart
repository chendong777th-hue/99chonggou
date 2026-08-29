import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_scroll_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_gallery_precache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_screen_gallery_close.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gallery_scroll_gate.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tall_image_gesture_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_debug.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_header_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_videoplayer.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_gallery_image_page.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/gestured_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_chrome.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_shell.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_video_progress_bar.dart';

/// 图+视频混滑全屏画廊（微信会话媒体预览）。
class ChatMediaGalleryScreen extends StatefulWidget {
  const ChatMediaGalleryScreen({
    required this.items,
    required this.initialIndex,
    this.sourceMessage,
    this.onOpenMedia,
    this.onClosing,
    /// 会话媒体网格无源 Hero：必须 false，否则零时长入场 + HeroMode
    /// 在 iOS 会留下空飞行层，只剩半透明灰罩看不见图。
    this.enableHero = true,
    Key? key,
  }) : super(key: key);

  final List<ChatMediaPreviewItem> items;
  final int initialIndex;
  final V2TimMessage? sourceMessage;
  final VoidCallback? onOpenMedia;
  final void Function(String? messageID, String heroTag)? onClosing;
  final bool enableHero;

  @override
  State<ChatMediaGalleryScreen> createState() => _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends TIMUIKitState<ChatMediaGalleryScreen>
    with TickerProviderStateMixin {
  final TUIChatGlobalModel _model = serviceLocator<TUIChatGlobalModel>();
  final GlobalKey<ExtendedImageSlidePageState> _slidePageKey =
      GlobalKey<ExtendedImageSlidePageState>();
  final MediaPreviewSlideMetrics _slideMetrics = MediaPreviewSlideMetrics();
  final ValueNotifier<int> _chromeTick = ValueNotifier<int>(0);
  final MediaPreviewSlideDismissController _slideDismissController =
      MediaPreviewSlideDismissController();
  final ValueNotifier<bool> _heroModeEnabled = ValueNotifier<bool>(true);
  final Set<Object> _hiddenHeroTags = <Object>{};

  late ExtendedPageController _pageController;
  late final MediaPreviewEntranceLatch _entranceLatch;
  late int _currentIndex;
  late int _playerPageIndex;
  int _pageControllerEpoch = 0;

  GlobalKey<TIMUIKitVideoPlayerState> _playerKey =
      GlobalKey<TIMUIKitVideoPlayerState>();
  Widget? _cachedPlayerArea;
  bool _closing = false;
  bool _closingFromSlideDismiss = false;
  bool _chromeVisible = true;
  bool _heroOverlayVisible = true;

  /// 首次进场等开播再掀封面；图集翻页落地为 false，首帧就绪即掀。
  bool _holdHeroUntilPlayback = true;
  bool _slidePausedForDrag = false;
  bool _pausedByUser = false;
  bool _isPlaybackActive = false;

  /// 是否已出过画（首帧/开播）。播完后仍为 true，避免封面盾再次盖上。
  bool _hasPresentedVideoFrame = false;
  bool _closeHeroRevealScheduled = false;
  bool _closeHeroRevealed = false;
  bool _galleryScrolling = false;

  /// jumpToPage 会同步抛 ScrollStart；监听里再 jump 会递归到栈溢出。
  bool _galleryPageJumpInFlight = false;
  int? _pendingGalleryJumpIndex;
  int _galleryJumpAttempt = 0;
  static const int _maxGalleryJumpAttempts = 48;
  late final V2TimMessage _tappedMessage;

  int _indexForSourceMessage({int? fallback}) {
    final tapped = widget.sourceMessage ?? _tappedMessage;
    final index = findChatMediaGalleryMessageIndex(
      messagesOldestFirst: _items.map((item) => item.message).toList(),
      target: tapped,
    );
    if (index >= 0) {
      return index;
    }
    if (fallback != null) {
      return fallback.clamp(0, _items.length - 1);
    }
    return widget.initialIndex.clamp(0, _items.length - 1);
  }

  bool _galleryPageMatchesTarget(int target) {
    if (!_pageController.hasClients) {
      return false;
    }
    final page = _pageController.page;
    if (page == null) {
      return false;
    }
    return (page - target).abs() < 0.05;
  }

  void _jumpGalleryPageByOffset(int index) {
    if (!_pageController.hasClients) {
      return;
    }
    final pos = _pageController.position;
    if (!pos.hasViewportDimension || pos.viewportDimension <= 0) {
      return;
    }
    final stride = pos.viewportDimension + kChatMediaGalleryPageSpacing;
    pos.jumpTo(index * stride);
  }
  bool _entranceSettled = false;

  /// 下滑关闭开始时冻结页码，避免惯性翻页导致关页 Hero 飞错气泡。
  int? _dismissGalleryIndex;
  Timer? _playerCommitDebounce;
  final ImagePreviewGalleryPrecache _galleryPrecache =
      ImagePreviewGalleryPrecache();
  final Map<int, ValueNotifier<TallImageGalleryScrollGate>>
      _tallImageGalleryGateByIndex =
      <int, ValueNotifier<TallImageGalleryScrollGate>>{};

  List<ChatMediaPreviewItem> get _items => widget.items;

  ChatMediaPreviewItem get _currentItem => _items[_currentIndex];

  bool get _currentIsVideo => _currentItem.type == ChatMediaPreviewType.video;

  bool get _playerIsVideo =>
      _items[_playerPageIndex].type == ChatMediaPreviewType.video;

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForSourceMessage(fallback: widget.initialIndex);
    _tappedMessage = widget.sourceMessage ?? _items[_currentIndex].message;
    _playerPageIndex = _currentIndex;
    MediaPreviewDebug.log('gallery_open', {
      'count': _items.length,
      'initial': _currentIndex,
      'current': MediaPreviewDebug.itemSummary(_currentItem),
      'items': MediaPreviewDebug.itemsSummary(_items),
      'holdHero': _holdHeroUntilPlayback,
    });
    _pageController = _createGalleryPageController(_currentIndex);
    _entranceLatch = MediaPreviewEntranceLatch(
      onSettled: () {
        if (!mounted || _closing) {
          return;
        }
        setState(() => _entranceSettled = true);
        MediaPreviewDebug.log('gallery_entrance_settled', {
          'playerPage': _playerPageIndex,
          'isVideo': _playerIsVideo,
          'heroVisible': _heroOverlayVisible,
          'holdHero': _holdHeroUntilPlayback,
        });
        if (_playerIsVideo) {
          _playerKey.currentState?.startDeferredPlayback();
        }
        final target = _indexForSourceMessage(fallback: _currentIndex);
        _currentIndex = target;
        _playerPageIndex = target;
        if (!_galleryPageMatchesTarget(target)) {
          _scheduleJumpGalleryToPage(target);
        }
      },
    );
    imagePreviewSlideDismissCallback = (state, details, offset) {
      return _closeFromSlideDismiss(state, details, offset);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) {
        return;
      }
      _entranceLatch.bind(
        mediaPreviewChromeAnimation(context),
        routeDuration: ModalRoute.of(context)?.transitionDuration,
      );
      _hideHero(_currentItem.heroTag);
      if (_playerIsVideo) {
        _playerKey.currentState?.preparePlaybackPipeline();
      }
      _precacheAdjacentGalleryImages(_currentIndex);
    });
  }

  @override
  void didUpdateWidget(covariant ChatMediaGalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged = !identical(oldWidget.items, widget.items) &&
        oldWidget.items != widget.items &&
        widget.items.isNotEmpty;
    final initialChanged = oldWidget.initialIndex != widget.initialIndex;
    if (!itemsChanged && !initialChanged) {
      return;
    }
    if (widget.items.isEmpty) {
      return;
    }
    final nextIndex = _indexForSourceMessage(
      fallback: resolveChatMediaGalleryIndexAfterExpand(
        currentIndex: _currentIndex,
        oldOldestFirst: oldWidget.items.map((item) => item.message).toList(),
        newOldestFirst: widget.items.map((item) => item.message).toList(),
        tappedMessage: widget.sourceMessage ?? _tappedMessage,
        preferredIndex: widget.initialIndex,
      ),
    );
    final oldCount = oldWidget.items.length;
    final newCount = widget.items.length;
    _currentIndex = nextIndex;
    _playerPageIndex = nextIndex;
    if (chatMediaGalleryShouldReplacePageController(
      oldItemCount: oldCount,
      newItemCount: newCount,
    )) {
      _replaceGalleryPageController(nextIndex);
      return;
    }
    _scheduleJumpGalleryToPage(nextIndex);
  }

  ExtendedPageController _createGalleryPageController(int initialPage) {
    final count = _items.length;
    final page = count <= 0 ? 0 : initialPage.clamp(0, count - 1).toInt();
    return ExtendedPageController(
      initialPage: page,
      pageSpacing: kChatMediaGalleryPageSpacing,
      shouldIgnorePointerWhenScrolling: true,
    );
  }

  void _replaceGalleryPageController(int initialPage) {
    final old = _pageController;
    _pageControllerEpoch++;
    final clamped = _items.isEmpty
        ? 0
        : initialPage.clamp(0, _items.length - 1).toInt();
    _currentIndex = clamped;
    _playerPageIndex = clamped;
    _pageController = _createGalleryPageController(clamped);
    MediaPreviewDebug.log('gallery_controller_replace', {
      'to': clamped,
      'count': _items.length,
      'epoch': _pageControllerEpoch,
    });
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      if (!mounted || _closing) {
        return;
      }
      _scheduleJumpGalleryToPage(clamped);
    });
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
    if (target == null || !mounted || _closing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing || _pendingGalleryJumpIndex == null) {
        return;
      }
      if (!_pageController.hasClients || _items.isEmpty) {
        _retryGalleryJump();
        return;
      }
      final clamped =
          _pendingGalleryJumpIndex!.clamp(0, _items.length - 1).toInt();
      if (_galleryPageMatchesTarget(clamped)) {
        _currentIndex = clamped;
        _playerPageIndex = clamped;
        _pendingGalleryJumpIndex = null;
        _galleryJumpAttempt = 0;
        return;
      }
      final pos = _pageController.position;
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
        _pageController.jumpToPage(clamped);
      } finally {
        _galleryPageJumpInFlight = false;
      }
      if (!_galleryPageMatchesTarget(clamped)) {
        _jumpGalleryPageByOffset(clamped);
      }
      if (_galleryPageMatchesTarget(clamped)) {
        _currentIndex = clamped;
        _playerPageIndex = clamped;
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

  @override
  void dispose() {
    _closing = true;
    imagePreviewSlideDismissCallback = null;
    _playerCommitDebounce?.cancel();
    _galleryPrecache.invalidate();
    _evictOpenedPreviewBitmaps();
    _slideDismissController.dispose();
    _slideMetrics.dispose();
    _heroModeEnabled.dispose();
    _entranceLatch.dispose();
    _releaseHiddenHeroes();
    _pageController.dispose();
    _chromeTick.dispose();
    super.dispose();
  }

  void _evictOpenedPreviewBitmaps() {
    if (PlatformUtils().isWeb) {
      return;
    }
    final providers = <ImageProvider?>[];
    for (final item in _items) {
      // 预览大图/视频封面；不驱逐 placeholder（多为气泡 thumb）。
      providers.add(item.imageProvider);
    }
    evictChatPreviewImageProviders(providers);
  }

  void _notifyChrome() {
    if (mounted) {
      _chromeTick.value++;
    }
  }

  void _toggleChrome() {
    if (_closing) {
      return;
    }
    _chromeVisible = !_chromeVisible;
    _notifyChrome();
  }

  void _hideHero(Object tag) {
    if (tag.toString().isEmpty) {
      return;
    }
    if (_hiddenHeroTags.add(tag)) {
      MediaPreviewHeroRegistry.instance.hide(tag);
    }
  }

  void _showHero(Object tag) {
    if (tag.toString().isEmpty) {
      return;
    }
    if (_hiddenHeroTags.remove(tag)) {
      MediaPreviewHeroRegistry.instance.show(tag);
    }
  }

  void _revealHiddenHeroes() {
    if (_hiddenHeroTags.isEmpty) {
      return;
    }
    final tags = Set<Object>.from(_hiddenHeroTags);
    _hiddenHeroTags.clear();
    MediaPreviewHeroRegistry.instance.revealAll(tags);
  }

  /// 下滑关闭延迟恢复气泡，避免退场动画中途闪一下；普通关闭立即恢复。
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
    _revealHiddenHeroes();
  }

  int _readGalleryIndexFromController() {
    if (_pageController.hasClients) {
      final page = _pageController.page;
      if (page != null) {
        return page.round().clamp(0, _items.length - 1);
      }
    }
    return _dismissGalleryIndex ?? _currentIndex;
  }

  bool get _isSlideDismissActive {
    if (_closing && _closingFromSlideDismiss) {
      return true;
    }
    final slideState = _slidePageKey.currentState;
    if (slideState?.isSliding == true) {
      return true;
    }
    if (_slideMetrics.slideOffset.dy > 0.5) {
      return true;
    }
    return false;
  }

  /// 下滑关闭时打断横向翻页，避免与纵向退场抢手势。
  ///
  /// [forceCurrent]：强制回到逻辑页 [_currentIndex]（长图竖向 dismiss / UiKitView
  /// 拆卸后的页码漂移场景）。默认仍按控制器当前 page 就近取整。
  void _interruptGalleryPageScrollIfNeeded({bool forceCurrent = false}) {
    if (_items.length <= 1 || !_pageController.hasClients) {
      return;
    }
    final position = _pageController.position;
    final page = _pageController.page ?? _currentIndex.toDouble();
    final target =
        forceCurrent ? _currentIndex : page.round().clamp(0, _items.length - 1);
    final scrolling = position.isScrollingNotifier.value;
    if (!scrolling && !forceCurrent) {
      return;
    }
    if ((page - target).abs() < 0.001 && !scrolling) {
      return;
    }
    MediaPreviewDebug.log('gallery_scroll_interrupt', {
      'forceCurrent': forceCurrent,
      'scrolling': scrolling,
      'page': page.toStringAsFixed(3),
      'target': target,
      'current': _currentIndex,
    });
    _jumpGalleryToPage(target);
  }

  void _jumpGalleryToPage(int index) {
    _scheduleJumpGalleryToPage(index);
  }

  /// 卸掉 iOS UiKitView（视频页）后 ExtendedPageController.page 会漂移约 1 页。
  /// 在停稳时把控制器校正回 [_currentIndex]，避免下一次轻滑变成跨页跳。
  void _stabilizeGalleryPageOffset({required String reason}) {
    if (_closing || _items.length <= 1 || !_pageController.hasClients) {
      return;
    }
    if (_pageController.position.isScrollingNotifier.value) {
      MediaPreviewDebug.log('page_stabilize_skip', {
        'reason': reason,
        'cause': 'scrolling',
        'current': _currentIndex,
      });
      return;
    }
    final page = _pageController.page;
    if (page == null) {
      return;
    }
    final drift = (page - _currentIndex).abs();
    final pos = _pageController.position;
    final pageFromPixels =
        pos.viewportDimension == 0 ? null : pos.pixels / pos.viewportDimension;
    MediaPreviewDebug.log('page_stabilize_check', {
      'reason': reason,
      'page': page.toStringAsFixed(3),
      'pagePx': pageFromPixels?.toStringAsFixed(3),
      'expected': _currentIndex,
      'initial': widget.initialIndex,
      'drift': drift.toStringAsFixed(3),
    });
    if (drift < 0.08) {
      return;
    }
    // pageSpacing + 平台视图布局时，page 可能瞬时跳回 initialPage；若像素仍停在逻辑页则勿乱跳。
    if (pageFromPixels != null &&
        (page - widget.initialIndex).abs() < 0.05 &&
        _currentIndex != widget.initialIndex &&
        (pageFromPixels - _currentIndex).abs() < 0.2) {
      MediaPreviewDebug.log('page_stabilize_ignore_bogus_initial', {
        'reason': reason,
        'page': page.toStringAsFixed(3),
        'pagePx': pageFromPixels.toStringAsFixed(3),
        'expected': _currentIndex,
      });
      return;
    }
    _jumpGalleryToPage(_currentIndex);
    MediaPreviewDebug.log('page_stabilize_jump', {
      'reason': reason,
      'to': _currentIndex,
      'from': page.toStringAsFixed(3),
      'pagePx': pageFromPixels?.toStringAsFixed(3),
    });
  }

  void _scheduleStabilizeGalleryPageOffset({required String reason}) {
    void run(String tag) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing) {
          return;
        }
        _stabilizeGalleryPageOffset(reason: tag);
      });
    }

    run('${reason}_f1');
    // UiKitView 拆卸常在第二帧才反映到滚动 extent。
    run('${reason}_f2');
    Future<void>.delayed(const Duration(milliseconds: 32), () {
      if (!mounted || _closing) {
        return;
      }
      _stabilizeGalleryPageOffset(reason: '${reason}_d32');
    });
  }

  void _syncHeroVisibility({
    required int previousIndex,
    required int currentIndex,
  }) {
    if (_closing || previousIndex == currentIndex) {
      return;
    }
    if (previousIndex >= 0 && previousIndex < _items.length) {
      _showHero(_items[previousIndex].heroTag);
    }
    if (currentIndex >= 0 && currentIndex < _items.length) {
      _hideHero(_items[currentIndex].heroTag);
    }
  }

  void _revealCloseHero() {
    if (_closeHeroRevealed) {
      return;
    }
    final closeIndex = _readGalleryIndexFromController();
    if (closeIndex < 0 || closeIndex >= _items.length) {
      return;
    }
    _closeHeroRevealed = true;
    final item = _items[closeIndex];
    _showHero(item.heroTag);
    widget.onClosing?.call(item.messageID, item.heroTag.toString());
  }

  void _scheduleCloseHeroReveal() {
    if (_closeHeroRevealed || _closeHeroRevealScheduled) {
      return;
    }
    _closeHeroRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeHeroRevealScheduled = false;
      if (!_closing) {
        return;
      }
      _revealCloseHero();
    });
  }

  bool _canScrollGalleryPage(GestureDetails? details) {
    if (!_entranceLatch.settled) {
      return false;
    }
    final gate = _tallImageGalleryGateByIndex[_currentIndex]?.value ??
        TallImageGalleryScrollGate.initial;
    final isTall = _tallImageGalleryGateByIndex.containsKey(_currentIndex);
    final allow = canScrollMediaPreviewGalleryPage(
      details: details,
      baselineScale: 1.0,
      tallImageGate: isTall ? gate : null,
      tallImageVerticallyScrollable: isTall,
    );
    TallImageGestureDiag.galleryCanScroll(
      allow: allow,
      baselineScale: 1.0,
      gate: isTall ? gate : null,
      isTall: isTall,
      detailsScale: details?.totalScale,
      source: 'media_gallery',
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

  void _onPageChanged(int index) {
    if (_closing) {
      return;
    }
    final next = index.clamp(0, _items.length - 1);
    if (next == _currentIndex) {
      return;
    }
    final previous = _currentIndex;
    _currentIndex = next;
    _chromeVisible = true;
    _notifyChrome();
    final scrolling = _pageController.hasClients &&
        _pageController.position.isScrollingNotifier.value;
    MediaPreviewDebug.log('page_changed', {
      'from': previous,
      'to': next,
      'fromItem': MediaPreviewDebug.itemSummary(_items[previous]),
      'toItem': MediaPreviewDebug.itemSummary(_items[next]),
      'playerPage': _playerPageIndex,
      'scrolling': scrolling,
      'page': _pageController.hasClients
          ? _pageController.page?.toStringAsFixed(2)
          : null,
    });
    _syncHeroVisibility(previousIndex: previous, currentIndex: next);
    if (!scrolling) {
      _scheduleCommitPlayerPage();
    }
    _precacheAdjacentGalleryImages(next);
  }

  void _precacheAdjacentGalleryImages(int index) {
    if (!mounted || _items.length <= 1) {
      return;
    }
    _galleryPrecache.precacheAdjacent(
      context: context,
      centerIndex: index,
      itemCount: _items.length,
      radius: 3,
      resolveProvider: (adjacent) {
        final item = _items[adjacent];
        if (item.type != ChatMediaPreviewType.image) {
          return null;
        }
        final provider = item.imageProvider;
        if (provider == null) {
          return null;
        }
        return ChatMessagePreviewImageResolver.wrapPreviewDecode(
          context: context,
          message: item.message,
          provider: provider,
        );
      },
    );
  }

  void _scheduleCommitPlayerPage() {
    _playerCommitDebounce?.cancel();
    MediaPreviewDebug.log('commit_schedule', {
      'current': _currentIndex,
      'playerPage': _playerPageIndex,
    });
    _playerCommitDebounce = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _closing) {
        MediaPreviewDebug.log(
            'commit_skip', {'reason': 'unmounted_or_closing'});
        return;
      }
      if (_pageController.hasClients &&
          _pageController.position.isScrollingNotifier.value) {
        MediaPreviewDebug.log('commit_skip', {
          'reason': 'still_scrolling',
          'page': _pageController.page?.toStringAsFixed(2),
        });
        return;
      }
      _commitPlayerPage();
    });
  }

  void _commitPlayerPage() {
    if (_closing || !mounted || _playerPageIndex == _currentIndex) {
      MediaPreviewDebug.log('commit_noop', {
        'closing': _closing,
        'mounted': mounted,
        'playerPage': _playerPageIndex,
        'current': _currentIndex,
      });
      return;
    }
    final previousPlayer = _playerPageIndex;
    final leavingWasVideo = _playerIsVideo;
    final enteringVideo =
        _items[_currentIndex].type == ChatMediaPreviewType.video;
    if (leavingWasVideo) {
      _playerKey.currentState?.prepareForRouteClose();
    }
    setState(() {
      _playerPageIndex = _currentIndex;
      // 封面必须留到真正开播：initialized 只代表元数据就绪，此时掀开会闪黑/闪上一页。
      _resetPlayerState(holdHeroUntilPlayback: true);
    });
    MediaPreviewDebug.log('commit_player', {
      'from': previousPlayer,
      'to': _playerPageIndex,
      'toItem': MediaPreviewDebug.itemSummary(_items[_playerPageIndex]),
      'isVideo': _playerIsVideo,
      'holdHero': _holdHeroUntilPlayback,
      'heroVisible': _heroOverlayVisible,
      'leavingVideo': leavingWasVideo,
      'enteringVideo': enteringVideo,
    });
    // 视频播器（UiKitView）挂上/拆下都会让 page 偏移，校正回逻辑页。
    if (leavingWasVideo || enteringVideo) {
      _scheduleStabilizeGalleryPageOffset(
        reason: leavingWasVideo ? 'leave_video' : 'enter_video',
      );
    }
    if (_playerIsVideo) {
      final elem = _items[_playerPageIndex].videoElement;
      if (elem != null) {
        applyVideoPlaybackOrientation(resolveVideoAspectRatio(elem));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing) {
          MediaPreviewDebug.log('commit_start_play_skip', {
            'reason': 'unmounted_or_closing',
          });
          return;
        }
        final hasState = _playerKey.currentState != null;
        MediaPreviewDebug.log('commit_start_play', {
          'hasPlayerState': hasState,
          'playerPage': _playerPageIndex,
        });
        _playerKey.currentState?.preparePlaybackPipeline();
        _playerKey.currentState?.startDeferredPlayback();
        _scheduleStabilizeGalleryPageOffset(reason: 'after_start_play');
      });
    }
  }

  /// [holdHeroUntilPlayback]：封面留到 [onPlaybackStarted] 再撤，避免未出画先露底。
  void _resetPlayerState({bool holdHeroUntilPlayback = true}) {
    _playerKey = GlobalKey<TIMUIKitVideoPlayerState>();
    _cachedPlayerArea = null;
    _heroOverlayVisible = true;
    _holdHeroUntilPlayback = holdHeroUntilPlayback;
    _slidePausedForDrag = false;
    _pausedByUser = false;
    _isPlaybackActive = false;
    _hasPresentedVideoFrame = false;
    MediaPreviewDebug.log('player_reset', {
      'holdHero': _holdHeroUntilPlayback,
      'playerPage': _playerPageIndex,
    });
  }

  void _onPlaybackFinished() {
    if (!mounted || _closing) {
      return;
    }
    MediaPreviewDebug.log('playback_finished_ui_reset', {
      'playerPage': _playerPageIndex,
    });
    setState(() {
      _isPlaybackActive = false;
      _pausedByUser = true;
      _hasPresentedVideoFrame = true;
      _heroOverlayVisible = false;
      _chromeVisible = true;
    });
    _notifyChrome();
  }

  void _onSlidingPage(ExtendedImageSlidePageState state) {
    if (state.isSliding) {
      _dismissGalleryIndex ??= _readGalleryIndexFromController();
      _interruptGalleryPageScrollIfNeeded();
    } else if (!_isSlideDismissActive) {
      _dismissGalleryIndex = null;
    }
    if (_playerIsVideo && state.isSliding && !_slidePausedForDrag) {
      _slidePausedForDrag = true;
      _heroOverlayVisible = false;
      unawaited(_playerKey.currentState?.pausePlayback());
      if (mounted) {
        setState(() {});
      }
    }
    if (_slidePausedForDrag &&
        !state.isSliding &&
        state.offset == Offset.zero &&
        !_closing) {
      _slidePausedForDrag = false;
      if (!_pausedByUser && _playerIsVideo) {
        _playerKey.currentState?.resumePlayback();
        _isPlaybackActive = true;
      }
      if (mounted) {
        setState(() {});
      }
    }
    _slideMetrics.updateFromSlide(state, MediaQuery.sizeOf(context));
  }

  bool _prepareForClose({bool preserveSlideBackdrop = false}) {
    if (_closing || !mounted) {
      return false;
    }
    _closingFromSlideDismiss = preserveSlideBackdrop;
    _closing = true;
    final closeIndex = _readGalleryIndexFromController();
    final closeItem = closeIndex >= 0 && closeIndex < _items.length
        ? _items[closeIndex]
        : _currentItem;
    _heroModeEnabled.value = widget.enableHero &&
        closeItem.type == ChatMediaPreviewType.image &&
        canHeroDismissToTarget(
          heroTag: closeItem.heroTag.toString(),
          targetIsLive:
              MediaPreviewHeroRegistry.instance.isTargetLive(closeItem.heroTag),
        );
    if (_playerIsVideo) {
      _playerKey.currentState?.prepareForRouteClose();
    }
    if (!preserveSlideBackdrop) {
      _slideMetrics.resetBackdrop();
    }
    if (preserveSlideBackdrop) {
      _scheduleCloseHeroReveal();
    } else {
      _revealCloseHero();
    }
    // 下滑关闭禁止 setState，避免重建打断跟手缩放。
    if (!preserveSlideBackdrop) {
      setState(() {});
    }
    return true;
  }

  void _close() {
    _slideDismissController.startMomentumDismiss(
      vsync: this,
      context: context,
      slidePageKey: _slidePageKey,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _closing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismiss,
      releaseOffset: _slideMetrics.slideOffset,
    );
  }

  /// 长图进入竖向关闭手势（含顶部橡皮筋）时立刻钉住图集页，避免同时横滑翻页。
  void _onTallImageDismissGestureStarted() {
    if (_closing) {
      return;
    }
    // 已在两页之间时不要硬钉回：可能是横滑翻页中途的误触竖向。
    if (_pageController.hasClients) {
      final page = _pageController.page;
      if (page != null && (page - page.round()).abs() > 0.12) {
        MediaPreviewDebug.log('tall_dismiss_skip_mid_page', {
          'page': page.toStringAsFixed(3),
          'current': _currentIndex,
        });
        return;
      }
    }
    _interruptGalleryPageScrollIfNeeded(forceCurrent: true);
    _stabilizeGalleryPageOffset(reason: 'tall_dismiss_start');
  }

  /// 长图顶部下拉关闭：微信式缩放淡出（只动画 metrics），保留遮罩后 pop。
  void _closeFromTallImageSlideDismiss(
    Offset releaseOffset,
    ScaleEndDetails? details,
  ) {
    _interruptGalleryPageScrollIfNeeded(forceCurrent: true);
    _slideDismissController.startMetricsMomentumDismiss(
      vsync: this,
      context: context,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _closing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismiss,
      details: details,
      releaseOffset: releaseOffset,
    );
  }

  void _popSlideDismiss() {
    if (!_closing) {
      return;
    }
    _revealCloseHero();
    // 勿在 pop 前 resetBackdrop：会把画面收起而遮罩回到全黑。
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  bool _closeFromSlideDismiss(
    ExtendedImageSlidePageState? state,
    ScaleEndDetails? details,
    Offset releaseOffset,
  ) {
    _slideDismissController.startMomentumDismiss(
      vsync: this,
      context: context,
      slidePageKey: _slidePageKey,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _closing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismiss,
      details: details,
      releaseOffset: releaseOffset,
    );
    // 必须返回 false：true 会让 extended_image 立刻 Navigator.pop 一次，
    // 随后 startMomentumDismiss 的 popRoute 再 pop 一次，把聊天页也关掉。
    return false;
  }

  Future<void> _handleDelete() async {
    final deleteFn = _currentItem.deleteFn;
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
    await deleteFn();
    if (mounted) {
      _close();
    }
  }

  Future<void> _handleDownload() async {
    final item = _currentItem;
    if (item.type == ChatMediaPreviewType.video) {
      final elem = item.videoElement;
      if (elem == null) {
        return;
      }
      await saveChatVideoMessage(
        context: context,
        message: item.message,
        videoElement: elem,
        model: _model,
      );
      return;
    }
    await item.downloadFn?.call();
  }

  void _handleOpenMedia() {
    final openMedia = widget.onOpenMedia;
    if (openMedia == null || _closing) {
      return;
    }
    _close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openMedia();
    });
  }

  Future<void> _togglePlayback() async {
    if (_closing || !_playerIsVideo) {
      return;
    }
    final player = _playerKey.currentState;
    if (player == null || !player.isPlaybackPipelineReady) {
      return;
    }
    final playing = await player.togglePlayback();
    if (!mounted || _closing || playing == null) {
      return;
    }
    setState(() {
      _isPlaybackActive = playing;
      _pausedByUser = !playing;
      _chromeVisible = true;
    });
    _notifyChrome();
  }

  void _handlePreviewTap() {
    if (_closing) {
      return;
    }
    if (_currentIsVideo && _playerPageIndex == _currentIndex) {
      if (_heroOverlayVisible) {
        unawaited(_togglePlayback());
        return;
      }
      final player = _playerKey.currentState;
      if (player != null && player.isPlaybackPipelineReady) {
        unawaited(_togglePlayback());
        return;
      }
    }
    _toggleChrome();
  }

  bool get _shouldShowVideoPlayerOverlay {
    if (_closing || !_playerIsVideo) {
      return false;
    }
    if (_galleryScrolling) {
      return false;
    }
    if (_playerPageIndex != _currentIndex) {
      return false;
    }
    if (_isSlideDismissActive) {
      return false;
    }
    return true;
  }

  /// 播放器层是否保留在树中（可透明）。翻页中途不销毁 UiKitView，只是藏起来。
  bool get _shouldKeepVideoPlayerLayer {
    if (_closing) {
      return false;
    }
    return _playerIsVideo;
  }

  /// 当前已停在视频页、但还没真正出画：顶层盖住封面，挡住 PageView 可能露出的上一页。
  bool get _shouldShowVideoCoverShield {
    if (_closing || _galleryScrolling || _isSlideDismissActive) {
      return false;
    }
    if (!_currentIsVideo) {
      return false;
    }
    // 播完/暂停后不盖盾，否则会把归零后的画面再次挡住。
    return !_hasPresentedVideoFrame;
  }

  Widget _buildVideoCoverShield() {
    final elem = _currentItem.videoElement;
    return ColoredBox(
      color: Colors.black,
      child: elem == null
          ? const SizedBox.shrink()
          : buildMediaPreviewVideoSnapshot(context, elem),
    );
  }

  Widget _buildVideoActivePage() {
    final item = _items[_playerPageIndex];
    final message = item.message;
    _cachedPlayerArea ??= TIMUIKitVideoPlayer(
      key: _playerKey,
      message: message,
      deferInitialization: true,
      preferOnlinePlayback: true,
      isSending: message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING,
      onAspectRatioResolved: (ratio) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_closing) {
            applyVideoPlaybackOrientation(ratio);
          }
        });
      },
      onPlayerInitialized: () {
        MediaPreviewDebug.log('player_initialized', {
          'playerPage': _playerPageIndex,
          'holdHero': _holdHeroUntilPlayback,
          'heroVisible': _heroOverlayVisible,
          'item': MediaPreviewDebug.itemSummary(item),
        });
        // initialized ≠ 首帧；封面由外层 shield / hero 留到 playback_started。
      },
      onInitFailed: () {
        MediaPreviewDebug.log('player_init_failed', {
          'playerPage': _playerPageIndex,
          'item': MediaPreviewDebug.itemSummary(item),
        });
        if (mounted && !_closing) {
          setState(() {
            _heroOverlayVisible = false;
            // 失败也撤盾，避免永远挡住错误态。
            _hasPresentedVideoFrame = true;
          });
        }
      },
      onPlaybackStarted: () {
        MediaPreviewDebug.log('player_playback_started', {
          'playerPage': _playerPageIndex,
          'heroVisible': _heroOverlayVisible,
          'item': MediaPreviewDebug.itemSummary(item),
        });
        // 再等一帧，让平台纹理有机会上屏后再撤封面。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _closing) {
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _closing) {
              return;
            }
            setState(() {
              _heroOverlayVisible = false;
              _isPlaybackActive = true;
              _pausedByUser = false;
              _hasPresentedVideoFrame = true;
            });
            MediaPreviewDebug.log('hero_dismiss', {
              'reason': 'playback_started',
              'playerPage': _playerPageIndex,
            });
          });
        });
      },
      onPlaybackFinished: _onPlaybackFinished,
    );

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        const ColoredBox(color: Colors.black),
        if (_cachedPlayerArea != null)
          Positioned.fill(child: _cachedPlayerArea!),
        if (_pausedByUser && _hasPresentedVideoFrame && !_isPlaybackActive)
          const Center(
            child:
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 64),
          ),
      ],
    );
  }

  Widget _buildVideoSnapshotPage(ChatMediaPreviewItem item) {
    final elem = item.videoElement;
    // 播放器叠在 PageView 外且 IgnorePointer，下滑手势必须落在这一页上；
    // 与 VideoScreen 一样用 SlidePageHandler 把竖直拖动交给 ExtendedImageSlidePage。
    return ExtendedImageSlidePageHandler(
      heroBuilderForSlidingPage: (result) => Material(
        color: Colors.transparent,
        child: result,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handlePreviewTap,
        child: ColoredBox(
          color: Colors.black,
          child: elem == null
              ? const SizedBox.shrink()
              : buildMediaPreviewVideoSnapshot(context, elem),
        ),
      ),
    );
  }

  bool _allowPreviewHeroForIndex(int index) {
    if (!widget.enableHero) {
      return false;
    }
    if (_closing || _closingFromSlideDismiss) {
      return false;
    }
    return index == _currentIndex;
  }

  Widget _buildPage(int index) {
    final item = _items[index];
    switch (item.type) {
      case ChatMediaPreviewType.image:
        return RepaintBoundary(
          child: ChatMediaGalleryImagePage(
            item: item,
            inPageView: _items.length > 1,
            isActive: index == _currentIndex,
            allowHero: _allowPreviewHeroForIndex(index),
            entranceSettled: _entranceSettled || _entranceLatch.settled,
            isGalleryScrolling: _galleryScrolling,
            slidePageKey: _slidePageKey,
            slideMetrics: _slideMetrics,
            galleryScrollGate: _tallImageGalleryGateFor(index),
            onTap: _handlePreviewTap,
            onDismissGestureStarted: _onTallImageDismissGestureStarted,
            onSlideDismiss: (offset, {details}) {
              _closeFromTallImageSlideDismiss(offset, details);
            },
          ),
        );
      case ChatMediaPreviewType.video:
        // 视频页在 PageView 内永远只放封面：真正的 UiKitView 叠在 PageView 外层，
        // 避免平台视图触发布局重算把滚动位置弹回 initialPage（闪屏）。
        return RepaintBoundary(child: _buildVideoSnapshotPage(item));
    }
  }

  Widget _buildGalleryBody(Orientation orientation) {
    final pageView = _items.length <= 1
        ? _buildPage(0)
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) {
                return false;
              }
              // 自身 jumpToPage 触发的滚动通知绝不能再 jump，否则无限递归。
              if (_galleryPageJumpInFlight) {
                return false;
              }
              if (notification is ScrollStartNotification) {
                if (!_galleryScrolling) {
                  MediaPreviewDebug.log('video_overlay_hide', {
                    'reason': 'scroll_start',
                    'playerPage': _playerPageIndex,
                    'current': _currentIndex,
                  });
                  setState(() => _galleryScrolling = true);
                }
                final page =
                    _pageController.hasClients ? _pageController.page : null;
                MediaPreviewDebug.log('gallery_scroll_start', {
                  'current': _currentIndex,
                  'playerPage': _playerPageIndex,
                  'page': page?.toStringAsFixed(2),
                });
                if (page != null && (page - _currentIndex).abs() >= 0.45) {
                  MediaPreviewDebug.log('scroll_start_resync', {
                    'from': page.toStringAsFixed(3),
                    'to': _currentIndex,
                  });
                  _jumpGalleryToPage(_currentIndex);
                }
              } else if (notification is ScrollEndNotification) {
                if (_galleryScrolling) {
                  setState(() => _galleryScrolling = false);
                }
                MediaPreviewDebug.log('gallery_scroll_end', {
                  'current': _currentIndex,
                  'playerPage': _playerPageIndex,
                  'page': _pageController.hasClients
                      ? _pageController.page?.toStringAsFixed(2)
                      : null,
                  'heroVisible': _heroOverlayVisible,
                  'holdHero': _holdHeroUntilPlayback,
                  'coverShield': _currentIsVideo && !_isPlaybackActive,
                });
                // 立刻 commit，让播放器早开始加载；封面盾挡住出画前的底。
                _playerCommitDebounce?.cancel();
                _commitPlayerPage();
                _scheduleStabilizeGalleryPageOffset(reason: 'scroll_end');
              }
              return false;
            },
            child: ExtendedImageGesturePageView.builder(
              key: ValueKey<int>(_pageControllerEpoch),
              controller: _pageController,
              itemCount: _items.length,
              physics: ChatMediaGalleryScrollPhysics.of(context),
              canScrollPage: _canScrollGalleryPage,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _buildPage(index),
            ),
          );

    final showOverlay = _shouldShowVideoPlayerOverlay;
    final keepPlayerLayer = _shouldKeepVideoPlayerLayer;
    final showCoverShield = _shouldShowVideoCoverShield;

    return Stack(
      fit: StackFit.expand,
      children: [
        pageView,
        if (keepPlayerLayer)
          Positioned.fill(
            // 手势交给底下 PageView / 下滑；点击由封面页 GestureDetector 接收。
            // iOS 不能 Offstage：平台视图会被收成 CGRectZero，只出声、画面打洞透出聊天。
            child: IgnorePointer(
              child: Offstage(
                offstage: PlatformUtils().isIOS ? false : !showOverlay,
                child: TickerMode(
                  enabled: showOverlay || PlatformUtils().isIOS,
                  child: _buildVideoActivePage(),
                ),
              ),
            ),
          ),
        // 出画前顶层封面：挡住 PageView 弹跳露出的上一张，也挡住未上屏的黑播放器。
        if (showCoverShield)
          Positioned.fill(
            child: IgnorePointer(
              child: _buildVideoCoverShield(),
            ),
          ),
      ],
    );
  }

  Widget _buildChrome(Animation<double> routeAnimation) {
    return ListenableBuilder(
      listenable: Listenable.merge([_slideMetrics, _chromeTick]),
      builder: (context, _) {
        if (!_chromeVisible || !PlatformUtils().isMobile) {
          return const SizedBox.shrink();
        }
        final item = _currentItem;
        final isVideo = item.type == ChatMediaPreviewType.video;
        final chrome = Stack(
          clipBehavior: Clip.none,
          children: [
            MediaPreviewTopBar(
              title: item.headerTitle ??
                  MediaPreviewHeaderUtils.titleForMessage(item.message),
              subtitle: item.headerSubtitle ??
                  MediaPreviewHeaderUtils.subtitleForMessage(
                    item.message.timestamp,
                  ),
              galleryIndicator: _items.length > 1
                  ? chatMediaGalleryPageLabel(
                      indexOldestFirst: _currentIndex,
                      count: _items.length,
                    )
                  : null,
              onBack: _close,
              onMore: null,
            ),
            MediaPreviewBottomBar(
              onTogglePlayback: isVideo &&
                      _playerPageIndex == _currentIndex &&
                      !_heroOverlayVisible
                  ? _togglePlayback
                  : null,
              isPlaybackActive: isVideo &&
                      _playerPageIndex == _currentIndex &&
                      !_heroOverlayVisible
                  ? _isPlaybackActive
                  : null,
              onShare: item.forwardFn,
              onEdit: item.editFn == null ? null : () => item.editFn!(context),
              onDownload:
                  item.downloadFn == null && !isVideo ? null : _handleDownload,
              onOpenMedia: isVideo && widget.onOpenMedia != null
                  ? _handleOpenMedia
                  : null,
              onDelete: item.deleteFn == null ? null : _handleDelete,
            ),
            if (isVideo && _playerPageIndex == _currentIndex)
              MediaPreviewVideoProgressBar(playerKey: _playerKey),
          ],
        );
        return IgnorePointer(
          ignoring: _slideMetrics.chromeOpacity < 0.96,
          child: Opacity(
            opacity: _slideMetrics.chromeOpacity.clamp(0.0, 1.0),
            child: chrome,
          ),
        );
      },
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return ValueListenableBuilder<bool>(
      valueListenable: _heroModeEnabled,
      builder: (context, heroEnabled, child) {
        return HeroMode(
          // 点视频进混滑：目的页没有对应 Hero，零时长入场再开 HeroMode
          // 会在 iOS 上留下空飞行层，只剩半透明罩、看不见正文和顶栏。
          // 会话媒体网格同样无源 Hero，由 [enableHero] 关闭。
          enabled: heroEnabled && widget.enableHero && !_currentIsVideo,
          child: child!,
        );
      },
      child: MediaPreviewSlideShell(
        slidePageKey: _slidePageKey,
        slideMetrics: _slideMetrics,
        entranceLatch: _entranceLatch,
        opaquePlatformBackdrop:
            _items.any((item) => item.type == ChatMediaPreviewType.video),
        slideType: _currentIsVideo ? SlideType.wholePage : SlideType.onlyImage,
        onSlidingPage: _onSlidingPage,
        slideEndHandler: (
          Offset offset, {
          ExtendedImageSlidePageState? state,
          ScaleEndDetails? details,
        }) {
          final vy = details?.velocity.pixelsPerSecond.dy ?? 0;
          if (mediaPreviewShouldDismissForSlide(offset, vy)) {
            return _closeFromSlideDismiss(state, details, offset);
          }
          return null;
        },
        onClose: () {
          if (!_closing) {
            _close();
          }
        },
        enableEdgeBack: false,
        bodyBuilder: (context, orientation) => _buildGalleryBody(orientation),
        chromeBuilder: _buildChrome,
      ),
    );
  }
}
