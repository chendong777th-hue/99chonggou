import 'dart:async';
import 'dart:io' show Platform;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_scroll_physics.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_debug.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_header_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_videoplayer.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_hero.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_chrome.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_shell.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_video_progress_bar.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({
    required this.message,
    required this.heroTag,
    required this.videoElement,
    this.preferOnlinePlayback = false,
    this.forwardFn,
    this.deleteFn,
    this.onOpenMedia,
    this.galleryItems,
    this.initialIndex = 0,
    Key? key,
  }) : super(key: key);

  final V2TimMessage message;
  final dynamic heroTag;
  final V2TimVideoElem videoElement;
  final bool preferOnlinePlayback;
  final Future<void> Function()? forwardFn;
  final Future<void> Function()? deleteFn;
  final VoidCallback? onOpenMedia;
  final List<ChatMediaPreviewItem>? galleryItems;
  final int initialIndex;

  bool get _useGallery => (galleryItems?.length ?? 0) > 1;

  @override
  State<StatefulWidget> createState() => _VideoScreenState();
}

class _VideoScreenState extends TIMUIKitState<VideoScreen>
    with TickerProviderStateMixin {
  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  final GlobalKey<ExtendedImageSlidePageState> _slidePageKey =
      GlobalKey<ExtendedImageSlidePageState>();
  GlobalKey<TIMUIKitVideoPlayerState> _playerKey =
      GlobalKey<TIMUIKitVideoPlayerState>();
  final MediaPreviewSlideMetrics _slideMetrics = MediaPreviewSlideMetrics();
  bool _closing = false;
  bool _heroOverlayVisible = true;

  /// 首次进场等开播再掀封面；图集翻页落地为 false。
  bool _holdHeroUntilPlayback = true;
  bool _chromeVisible = true;
  Timer? _chromeAutoHideTimer;
  static const Duration _chromeAutoHideDelay = Duration(seconds: 3);
  final ValueNotifier<int> _chromeTick = ValueNotifier<int>(0);
  bool _slidePausedForDrag = false;
  bool _pausedByUser = false;
  bool _isPlaybackActive = false;
  bool _playbackRequested = false;
  final Set<Object> _hiddenHeroTags = <Object>{};
  bool _closeHeroRevealScheduled = false;
  final MediaPreviewSlideDismissController _slideDismissController =
      MediaPreviewSlideDismissController();
  final ValueNotifier<bool> _heroModeEnabled = ValueNotifier<bool>(true);
  late final MediaPreviewEntranceLatch _entranceLatch;
  late PageController _galleryPageController;
  late int _currentIndex;
  int _pageControllerEpoch = 0;

  /// 播放器所在页：翻页 ballistic 结束再切换，避免中途 setState 卡顿。
  late int _playerPageIndex;
  Widget? _cachedPlayerArea;

  List<ChatMediaPreviewItem> get _items {
    if (widget.galleryItems?.isNotEmpty == true) {
      return widget.galleryItems!;
    }
    return [
      ChatMediaPreviewItem(
        message: widget.message,
        type: ChatMediaPreviewType.video,
        heroTag: widget.heroTag,
        messageID: widget.message.msgID ?? widget.message.id?.toString(),
        videoElement: widget.videoElement,
        forwardFn: widget.forwardFn,
        deleteFn: widget.deleteFn,
      ),
    ];
  }

  ChatMediaPreviewItem get _currentItem => _items[_currentIndex];
  ChatMediaPreviewItem get _playerItem => _items[_playerPageIndex];
  V2TimMessage get _currentMessage => _currentItem.message;
  V2TimMessage get _playerMessage => _playerItem.message;
  V2TimVideoElem get _currentVideoElement =>
      _currentItem.videoElement ?? widget.videoElement;
  V2TimVideoElem get _playerVideoElement =>
      _playerItem.videoElement ?? widget.videoElement;
  Object get _currentHeroTag => _currentItem.heroTag;
  bool get _shouldBuildPlayer => widget._useGallery || _playbackRequested;

  void _markPlaybackActive() {
    if (!mounted || _closing) {
      return;
    }
    setState(() {
      _isPlaybackActive = true;
      _pausedByUser = false;
    });
    _startChromeAutoHideTimer();
  }

  void _markPlaybackPaused() {
    if (!mounted || _closing) {
      return;
    }
    setState(() {
      _isPlaybackActive = false;
      _pausedByUser = true;
      _chromeVisible = true;
    });
    _cancelChromeAutoHideTimer();
  }

  void _showHero(Object tag) {
    if (_hiddenHeroTags.remove(tag)) {
      MediaPreviewHeroRegistry.instance.show(tag);
    } else {
      MediaPreviewHeroRegistry.instance.revealAll({tag});
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

  void _scheduleCurrentHeroReveal() {
    if (_closeHeroRevealScheduled) {
      return;
    }
    _closeHeroRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeHeroRevealScheduled = false;
      if (!_closing) {
        return;
      }
      _showHero(_currentHeroTag);
    });
  }

  void _onSlidingPage(ExtendedImageSlidePageState state) {
    if (state.isSliding && !_slidePausedForDrag) {
      _slidePausedForDrag = true;
      if (_heroOverlayVisible) {
        _heroOverlayVisible = false;
      }
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
      if (!_pausedByUser) {
        _playerKey.currentState?.resumePlayback();
        if (mounted) {
          setState(() => _isPlaybackActive = true);
        }
      }
      if (mounted) {
        setState(() {});
      }
    }
    _slideMetrics.updateFromSlide(state, MediaQuery.sizeOf(context));
  }

  @override
  initState() {
    super.initState();
    _currentIndex = widget._useGallery
        ? widget.initialIndex.clamp(0, widget.galleryItems!.length - 1)
        : 0;
    _playerPageIndex = _currentIndex;
    _playbackRequested = true;
    MediaPreviewDebug.log('video_screen_open', {
      'useGallery': widget._useGallery,
      'count': _items.length,
      'initial': _currentIndex,
      'items': MediaPreviewDebug.itemsSummary(_items),
      'holdHero': _holdHeroUntilPlayback,
    });
    _galleryPageController = PageController(initialPage: _currentIndex);
    _entranceLatch = MediaPreviewEntranceLatch(
      onSettled: () {
        if (!mounted || _closing) {
          return;
        }
        MediaPreviewDebug.log('video_screen_entrance_settled', {
          'playerPage': _playerPageIndex,
          'heroVisible': _heroOverlayVisible,
          'holdHero': _holdHeroUntilPlayback,
        });
        _onPreviewTransitionEnd();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) {
        return;
      }
      _entranceLatch.bind(
        mediaPreviewChromeAnimation(context),
        routeDuration: ModalRoute.of(context)?.transitionDuration,
      );
      applyVideoPlaybackOrientation(
        resolveVideoAspectRatio(_currentVideoElement),
      );
      if (_shouldBuildPlayer) {
        _playerKey.currentState?.preparePlaybackPipeline();
      }
    });
  }

  @override
  void didUpdateWidget(covariant VideoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItems = oldWidget.galleryItems;
    final newItems = widget.galleryItems;
    if (identical(oldItems, newItems) ||
        oldItems == newItems ||
        newItems == null ||
        newItems.isEmpty) {
      return;
    }
    final nextIndex = retainChatMediaGalleryIndex(
      currentIndex: _currentIndex,
      oldOldestFirst: [
        for (final item in oldItems ?? const <ChatMediaPreviewItem>[])
          item.message,
      ],
      newOldestFirst: [for (final item in newItems) item.message],
    );
    _currentIndex = nextIndex;
    _playerPageIndex = nextIndex;
    if (chatMediaGalleryShouldReplacePageController(
      oldItemCount: oldItems?.length ?? 0,
      newItemCount: newItems.length,
    )) {
      _replaceGalleryPageController(nextIndex);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) {
        return;
      }
      if (_galleryPageController.hasClients &&
          _galleryPageController.page?.round() != nextIndex) {
        _galleryPageController.jumpToPage(nextIndex);
      }
    });
  }

  void _replaceGalleryPageController(int initialPage) {
    final old = _galleryPageController;
    _pageControllerEpoch++;
    final count = _items.length;
    final page = count <= 0 ? 0 : initialPage.clamp(0, count - 1).toInt();
    _galleryPageController = PageController(initialPage: page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      if (!mounted || _closing) {
        return;
      }
      if (_galleryPageController.hasClients &&
          _galleryPageController.page?.round() != page) {
        _galleryPageController.jumpToPage(page);
      }
    });
  }

  void _onPreviewTransitionEnd() {
    if (_shouldBuildPlayer) {
      // 入场结束只触发播放；Hero 封面留到首帧/开播后再撤，避免灰屏。
      MediaPreviewDebug.log('video_screen_start_play', {
        'playerPage': _playerPageIndex,
        'hasPlayerState': _playerKey.currentState != null,
      });
      _playerKey.currentState?.startDeferredPlayback();
    }
  }

  void _dismissHeroOverlay() {
    if (!mounted || _closing || !_heroOverlayVisible) {
      return;
    }
    MediaPreviewDebug.log('video_screen_hero_dismiss', {
      'playerPage': _playerPageIndex,
      'holdHero': _holdHeroUntilPlayback,
    });
    setState(() => _heroOverlayVisible = false);
  }

  Widget _buildHeroSnapshot() =>
      buildMediaPreviewVideoSnapshot(context, _playerVideoElement);

  void _resetPlayerForCurrentItem({bool holdHeroUntilPlayback = true}) {
    _playerKey = GlobalKey<TIMUIKitVideoPlayerState>();
    _cachedPlayerArea = null;
    _heroOverlayVisible = true;
    _holdHeroUntilPlayback = holdHeroUntilPlayback;
    _slidePausedForDrag = false;
    _pausedByUser = false;
    _isPlaybackActive = false;
    _playbackRequested = true;
  }

  Timer? _playerCommitDebounce;
  static const Duration _playerCommitDebounceDelay = Duration(milliseconds: 50);

  void _notifyChromeChanged() {
    if (!mounted) {
      return;
    }
    _chromeTick.value++;
  }

  /// Chrome 自动隐藏：播放中 3 秒无操作自动隐藏 top/bottom bar，
  /// 点击画面恢复。与 Telegram 行为一致。
  void _startChromeAutoHideTimer() {
    _chromeAutoHideTimer?.cancel();
    if (!_chromeVisible || _closing) {
      return;
    }
    // 暂停时不再自动隐藏——用户需要看到操作栏。
    if (!_isPlaybackActive && _pausedByUser) {
      return;
    }
    _chromeAutoHideTimer = Timer(_chromeAutoHideDelay, () {
      if (!mounted || _closing || !_chromeVisible) {
        return;
      }
      // Hero 封面仍在或播放器未就绪时不隐藏。
      if (!_shouldBuildPlayer || _heroOverlayVisible) {
        return;
      }
      _chromeVisible = false;
      _notifyChromeChanged();
    });
  }

  void _cancelChromeAutoHideTimer() {
    _chromeAutoHideTimer?.cancel();
    _chromeAutoHideTimer = null;
  }

  void _onGalleryPageChanged(int index) {
    if (_closing) {
      return;
    }
    final next = index.clamp(0, _items.length - 1);
    if (next == _currentIndex) {
      return;
    }
    final previous = _currentIndex;
    // 先只更新逻辑页与顶栏，播放器等滚动停稳再切，避免翻页中途重建卡顿。
    _currentIndex = next;
    _chromeVisible = true;
    _cancelChromeAutoHideTimer();
    _startChromeAutoHideTimer();
    _notifyChromeChanged();
    final scrolling = _galleryPageController.hasClients &&
        _galleryPageController.position.isScrollingNotifier.value;
    MediaPreviewDebug.log('video_screen_page_changed', {
      'from': previous,
      'to': next,
      'fromItem': MediaPreviewDebug.itemSummary(_items[previous]),
      'toItem': MediaPreviewDebug.itemSummary(_items[next]),
      'playerPage': _playerPageIndex,
      'scrolling': scrolling,
    });
    if (!scrolling) {
      _scheduleCommitPlayerPage();
    }
  }

  void _onGalleryScrollEnd() {
    if (_closing) {
      return;
    }
    MediaPreviewDebug.log('video_screen_scroll_end', {
      'current': _currentIndex,
      'playerPage': _playerPageIndex,
    });
    _scheduleCommitPlayerPage();
  }

  void _scheduleCommitPlayerPage() {
    _playerCommitDebounce?.cancel();
    MediaPreviewDebug.log('video_screen_commit_schedule', {
      'current': _currentIndex,
      'playerPage': _playerPageIndex,
    });
    _playerCommitDebounce = Timer(_playerCommitDebounceDelay, () {
      if (!mounted || _closing) {
        return;
      }
      if (_galleryPageController.hasClients &&
          _galleryPageController.position.isScrollingNotifier.value) {
        MediaPreviewDebug.log('video_screen_commit_skip', {
          'reason': 'still_scrolling',
        });
        return;
      }
      _commitPlayerPage();
    });
  }

  void _commitPlayerPage() {
    if (_closing || !mounted) {
      return;
    }
    if (_playerPageIndex == _currentIndex) {
      MediaPreviewDebug.log('video_screen_commit_noop', {
        'playerPage': _playerPageIndex,
        'current': _currentIndex,
      });
      return;
    }
    final previousPlayer = _playerPageIndex;
    _playerKey.currentState?.prepareForRouteClose();
    setState(() {
      _playerPageIndex = _currentIndex;
      // 封面留到真正开播，避免 initialized 时掀开露出黑屏/上一页。
      _resetPlayerForCurrentItem(holdHeroUntilPlayback: true);
    });
    MediaPreviewDebug.log('video_screen_commit_player', {
      'from': previousPlayer,
      'to': _playerPageIndex,
      'toItem': MediaPreviewDebug.itemSummary(_items[_playerPageIndex]),
      'holdHero': _holdHeroUntilPlayback,
    });
    // 普通 PageView 也会因平台视图拆卸漂移，停稳后钉回逻辑页。
    void stabilize(String reason) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _closing ||
            !_galleryPageController.hasClients ||
            _galleryPageController.position.isScrollingNotifier.value) {
          return;
        }
        final page = _galleryPageController.page;
        if (page == null || (page - _currentIndex).abs() < 0.08) {
          return;
        }
        MediaPreviewDebug.log('video_screen_page_stabilize', {
          'reason': reason,
          'from': page.toStringAsFixed(3),
          'to': _currentIndex,
        });
        _galleryPageController.jumpToPage(_currentIndex);
      });
    }

    stabilize('commit_f1');
    stabilize('commit_f2');
    applyVideoPlaybackOrientation(resolveVideoAspectRatio(_playerVideoElement));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) {
        return;
      }
      MediaPreviewDebug.log('video_screen_commit_start_play', {
        'hasPlayerState': _playerKey.currentState != null,
        'playerPage': _playerPageIndex,
      });
      _playerKey.currentState?.preparePlaybackPipeline();
      _playerKey.currentState?.startDeferredPlayback();
      stabilize('after_start_play');
    });
  }

  Widget _buildSlideBody(Orientation orientation) {
    if (_shouldBuildPlayer) {
      _cachedPlayerArea ??= TIMUIKitVideoPlayer(
        key: _playerKey,
        message: _playerMessage,
        deferInitialization: true,
        preferOnlinePlayback: true,
        isSending:
            _playerMessage.status == MessageStatus.V2TIM_MSG_STATUS_SENDING,
        onAspectRatioResolved: _onAspectRatioResolved,
        onPlayerInitialized: () {
          MediaPreviewDebug.log('video_screen_player_initialized', {
            'playerPage': _playerPageIndex,
            'holdHero': _holdHeroUntilPlayback,
            'heroVisible': _heroOverlayVisible,
            'item': MediaPreviewDebug.itemSummary(_playerItem),
          });
          // 翻页落地：解码就绪即可掀封面。
          if (!_holdHeroUntilPlayback) {
            _dismissHeroOverlay();
          }
        },
        onInitFailed: () {
          MediaPreviewDebug.log('video_screen_player_init_failed', {
            'playerPage': _playerPageIndex,
            'item': MediaPreviewDebug.itemSummary(_playerItem),
          });
          _dismissHeroOverlay();
        },
        onPlaybackStarted: () {
          MediaPreviewDebug.log('video_screen_playback_started', {
            'playerPage': _playerPageIndex,
            'heroVisible': _heroOverlayVisible,
            'item': MediaPreviewDebug.itemSummary(_playerItem),
          });
          // 等一帧让平台纹理有机会上屏，再撤封面。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _closing) {
              return;
            }
            _dismissHeroOverlay();
            _markPlaybackActive();
          });
        },
        onPlaybackFinished: () {
          MediaPreviewDebug.log('video_screen_playback_finished', {
            'playerPage': _playerPageIndex,
            'item': MediaPreviewDebug.itemSummary(_playerItem),
          });
          _dismissHeroOverlay();
          _markPlaybackPaused();
        },
      );
    }

    return ExtendedImageSlidePageHandler(
      heroBuilderForSlidingPage: (result) => Material(
        color: Colors.transparent,
        child: result,
      ),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            const ColoredBox(color: Colors.black),
            if (_cachedPlayerArea != null)
              Positioned.fill(child: _cachedPlayerArea!),
            if (_heroOverlayVisible)
              Positioned.fill(
                child: IgnorePointer(
                  child: HeroMode(
                    enabled: true,
                    child: HeroWidget(
                      tag: _currentHeroTag,
                      slidePagekey: _slidePageKey,
                      slideType: SlideType.wholePage,
                      child: Material(
                        color: Colors.transparent,
                        child: _buildHeroSnapshot(),
                      ),
                    ),
                  ),
                ),
              ),
            if (!_shouldBuildPlayer)
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            if (_pausedByUser && !_heroOverlayVisible)
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            if (!_heroOverlayVisible && _shouldBuildPlayer)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayback,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryBody(Orientation orientation) {
    if (!widget._useGallery) {
      return _buildSlideBody(orientation);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && notification.depth == 0) {
          _onGalleryScrollEnd();
        }
        return false;
      },
      child: PageView.builder(
        key: ValueKey<int>(_pageControllerEpoch),
        controller: _galleryPageController,
        itemCount: _items.length,
        physics: ChatMediaGalleryScrollPhysics.of(context),
        allowImplicitScrolling: true,
        onPageChanged: _onGalleryPageChanged,
        itemBuilder: (context, index) {
          // 普通 PageView 无 pageSpacing：左右各半缝，滑到一半中间露出黑间隔。
          final page = Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kChatMediaGalleryPageSpacing / 2,
            ),
            child: index == _playerPageIndex
                ? _buildSlideBody(orientation)
                : ColoredBox(
                    color: Colors.black,
                    child: buildMediaPreviewVideoSnapshot(
                      context,
                      _items[index].videoElement ?? widget.videoElement,
                    ),
                  ),
          );
          return RepaintBoundary(child: page);
        },
      ),
    );
  }

  void _onAspectRatioResolved(double aspectRatio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) {
        applyVideoPlaybackOrientation(aspectRatio);
      }
    });
  }

  bool _prepareForClose({bool preserveSlideBackdrop = false}) {
    if (_closing) {
      return false;
    }
    if (!mounted) {
      return false;
    }
    _closing = true;
    _heroModeEnabled.value = false;
    _slidePausedForDrag = false;
    _playerKey.currentState?.prepareForRouteClose();
    if (!preserveSlideBackdrop) {
      _slideMetrics.resetBackdrop();
    } else {
      _scheduleCurrentHeroReveal();
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
      popRoute: _popSlideDismissRoute,
      releaseOffset: _slideMetrics.slideOffset,
    );
  }

  void _popSlideDismissRoute() {
    if (!_closing) {
      return;
    }
    _showHero(_currentHeroTag);
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
      slidePageKey: _slidePageKey,
      metrics: _slideMetrics,
      isMounted: () => mounted,
      isClosing: () => _closing,
      prepareForClose: () => _prepareForClose(preserveSlideBackdrop: true),
      popRoute: _popSlideDismissRoute,
      details: details,
      releaseOffset: releaseOffset,
    );
  }

  bool _closeFromSlideDismiss(
    ExtendedImageSlidePageState? state,
    ScaleEndDetails? details,
    Offset releaseOffset,
  ) {
    _scheduleSlideDismissMomentumPop(state, details, releaseOffset);
    return false;
  }

  void _toggleChromeVisibility() {
    if (_closing) {
      return;
    }
    _chromeVisible = !_chromeVisible;
    _notifyChromeChanged();
    if (_chromeVisible) {
      _startChromeAutoHideTimer();
    } else {
      _cancelChromeAutoHideTimer();
    }
  }

  void _handlePreviewTap() {
    if (_closing) {
      return;
    }
    if (!_shouldBuildPlayer || _heroOverlayVisible) {
      unawaited(_togglePlayback());
      return;
    }
    final player = _playerKey.currentState;
    if (player != null && player.isPlaybackPipelineReady) {
      unawaited(_togglePlayback());
      return;
    }
    _toggleChromeVisibility();
  }

  Future<void> _togglePlayback() async {
    if (_closing) {
      return;
    }
    if (!_shouldBuildPlayer) {
      setState(() {
        _playbackRequested = true;
        _cachedPlayerArea = null;
        _pausedByUser = false;
        _isPlaybackActive = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing) {
          return;
        }
        _playerKey.currentState?.preparePlaybackPipeline();
        _playerKey.currentState?.startDeferredPlayback();
      });
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
    if (playing) {
      _markPlaybackActive();
    } else {
      _markPlaybackPaused();
    }
  }

  Future<void> _showVideoActionMenu() async {
    final currentSpeed = _playerKey.currentState?.playbackSpeed ?? 1.0;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.download_rounded, color: Colors.white),
                title: Text(TIM_t('保存视频'),
                    style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'save'),
              ),
              const Divider(height: 1, color: Colors.white24),
              // 倍速控制
              for (final speed in <double>[1.0, 1.5, 2.0])
                ListTile(
                  leading: Icon(
                    speed == 1.0
                        ? Icons.play_arrow_rounded
                        : Icons.fast_forward_rounded,
                    color: currentSpeed == speed
                        ? const Color(0xFF4FACFE)
                        : Colors.white70,
                  ),
                  title: Text(
                    speed == 1.0 ? '正常速度' : '${speed}x 倍速',
                    style: TextStyle(
                      color: currentSpeed == speed
                          ? const Color(0xFF4FACFE)
                          : Colors.white,
                    ),
                  ),
                  trailing: currentSpeed == speed
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF4FACFE), size: 20)
                      : null,
                  onTap: () => Navigator.pop(ctx, 'speed_$speed'),
                ),
              // PiP 选项（仅 Android 支持 AVP PiP）
              if (Platform.isAndroid)
                ListTile(
                  leading: const Icon(Icons.picture_in_picture_rounded,
                      color: Colors.white),
                  title: const Text('画中画',
                      style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'pip'),
                ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white70),
                title: Text(TIM_t('取消'),
                    style: const TextStyle(color: Colors.white70)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
    if (action == 'save') {
      await _saveVideo();
    } else if (action == 'pip') {
      final ok = await _playerKey.currentState?.enablePictureInPicture();
      if (ok == true && mounted) {
        // PiP 启动后关闭全屏预览，让视频在小窗继续播放。
        _close();
      }
    } else if (action != null && action.startsWith('speed_')) {
      final speedStr = action.substring(6);
      final speed = double.tryParse(speedStr);
      if (speed != null) {
        await _playerKey.currentState?.setPlaybackSpeed(speed);
        _startChromeAutoHideTimer();
      }
    }
  }

  Future<void> _saveVideo() {
    return saveChatVideoMessage(
      context: context,
      message: _currentMessage,
      videoElement: _currentVideoElement,
      model: model,
    );
  }

  @override
  void dispose() {
    _closing = true;
    _chromeAutoHideTimer?.cancel();
    _playerCommitDebounce?.cancel();
    _slideDismissController.dispose();
    _heroModeEnabled.dispose();
    _slideMetrics.dispose();
    _entranceLatch.dispose();
    _revealHiddenHeroes();
    _galleryPageController.dispose();
    _chromeTick.dispose();
    super.dispose();
  }

  Widget _buildPreviewChrome(Animation<double> routeAnimation) {
    return ListenableBuilder(
      listenable: Listenable.merge([_slideMetrics, _chromeTick]),
      builder: (context, _) {
        if (!_chromeVisible || !PlatformUtils().isMobile) {
          return const SizedBox.shrink();
        }
        final chrome = Stack(
          clipBehavior: Clip.none,
          children: [
            MediaPreviewTopBar(
              title: MediaPreviewHeaderUtils.titleForMessage(_currentMessage),
              subtitle: MediaPreviewHeaderUtils.subtitleForMessage(
                _currentMessage.timestamp,
              ),
              onBack: _close,
              onMore: _showMoreMenu,
            ),
            MediaPreviewBottomBar(
              onTogglePlayback: _shouldBuildPlayer && !_heroOverlayVisible
                  ? _togglePlayback
                  : null,
              isPlaybackActive: _shouldBuildPlayer && !_heroOverlayVisible
                  ? _isPlaybackActive
                  : null,
              onShare: _currentItem.forwardFn ?? widget.forwardFn,
              onEdit: null,
              onDownload: _saveVideo,
              // 视频全屏预览不提供图集入口；图集仍可从图片预览进入。
              onOpenMedia: null,
              onDelete: (_currentItem.deleteFn ?? widget.deleteFn) == null
                  ? null
                  : _handleDelete,
            ),
            MediaPreviewVideoProgressBar(playerKey: _playerKey),
          ],
        );
        return IgnorePointer(
          ignoring: _slideMetrics.chromeOpacity < 0.96,
          child: AnimatedOpacity(
            opacity: _slideMetrics.chromeOpacity,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: chrome,
          ),
        );
      },
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return HeroMode(
      enabled: false,
      child: MediaPreviewSlideShell(
        slidePageKey: _slidePageKey,
        slideMetrics: _slideMetrics,
        entranceLatch: _entranceLatch,
        opaquePlatformBackdrop: true,
        slideType: SlideType.wholePage,
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
          if (_closing) {
            return;
          }
          _close();
        },
        bodyBuilder: (context, orientation) => GestureDetector(
          onTap: _handlePreviewTap,
          onLongPress: _showVideoActionMenu,
          behavior: HitTestBehavior.translucent,
          child: _buildGalleryBody(orientation),
        ),
        chromeBuilder: _buildPreviewChrome,
      ),
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
    await deleteFn();
    if (mounted) {
      _close();
    }
  }

  void _showMoreMenu() {
    showMediaPreviewMoreSheet(
      context: context,
      onDownload: _saveVideo,
      onForward: widget.forwardFn,
      onDelete: widget.deleteFn,
    );
  }
}
