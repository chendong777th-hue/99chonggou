import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:awesome_video_player/awesome_video_player.dart' as avp;
import 'package:video_player/video_player.dart' as vp;
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_online_url.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_online_url.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_debug.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_slide_frame_capture.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';

/// 竖屏视频锁定竖屏；横屏视频允许随系统自动旋转（含竖屏↔横屏）。
void applyVideoPlaybackOrientation(double aspectRatio) {
  if (isLandscapeVideo(aspectRatio)) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}

bool isLandscapeVideo(double aspectRatio) => aspectRatio > 1.0;

class TIMUIKitVideoPlayer extends StatefulWidget {
  final V2TimMessage message;
  final bool isSending;
  final bool preferOnlinePlayback;
  final ValueChanged<double>? onAspectRatioResolved;
  final VoidCallback? onPlaybackStarted;
  /// 播到结尾：内部会 pause + seek(0)，再回调以便外层把按钮改回「播放」、进度归零。
  final VoidCallback? onPlaybackFinished;
  final VoidCallback? onPlayerInitialized;
  /// 初始化彻底失败时回调（与 [onPlayerInitialized] 区分：成功初始化但尚未出帧不算失败）。
  final VoidCallback? onInitFailed;
  final bool deferInitialization;

  const TIMUIKitVideoPlayer({
    super.key,
    required this.message,
    required this.isSending,
    this.preferOnlinePlayback = false,
    this.onAspectRatioResolved,
    this.onPlaybackStarted,
    this.onPlaybackFinished,
    this.onPlayerInitialized,
    this.onInitFailed,
    this.deferInitialization = false,
  });

  @override
  State<StatefulWidget> createState() => TIMUIKitVideoPlayerState();
}

enum CurrentVideoType {
  online,
  local,
}

class CurrentVideoInfo {
  final String path;
  final CurrentVideoType type;
  final double aspectRatio;

  CurrentVideoInfo({
    required this.path,
    required this.type,
    required this.aspectRatio,
  });
}

class TIMUIKitVideoPlayerState extends State<TIMUIKitVideoPlayer> {
  final String _tag = "TencentCloudChatMessageVideoPlayer";
  final TUIChatGlobalModel _globalModel = serviceLocator<TUIChatGlobalModel>();

  /// 超过该大小的视频优先等本地下载完成，避免大文件在线流式播放卡顿或失败。
  static const int _largeVideoPreferLocalBytes = 20 * 1024 * 1024;

  avp.BetterPlayerController? _controller;
  /// iOS 全屏走 Navigator + UiKitView 会合成失败（有声无画、灰幕透出聊天）。
  /// 官方 video_player 默认 Texture，可随路由合成；Android 仍用 BetterPlayer Texture。
  vp.VideoPlayerController? _iosTextureController;
  dynamic _playbackControllerForListener;
  VoidCallback? _controllerListener;
  bool _initFailed = false;
  bool _initializing = false;
  bool _waitingForLocalDownload = false;
  int _downloadProgress = 0;
  bool _disposed = false;
  bool _routeClosing = false;
  double _videoAspectRatio = 9 / 16;
  CurrentVideoType? _activeSourceType;
  String? _activeLocalVideoPath;
  String? _activeRemoteVideoUrl;
  Duration? _lastTrackedCapturePosition;
  bool _retryingWithOnline = false;
  bool _playbackStartedNotified = false;
  bool _playbackFinishedHandling = false;
  /// 播完后拦住自动续播，直到用户显式点播放。
  bool _holdAfterFinished = false;
  bool _deferredPlaybackPending = false;
  final GlobalKey _frameCaptureKey = GlobalKey();
  Size? _displayedVideoSize;
  ui.Image? _cachedSlideFrame;
  bool _slideFrameCaptureInFlight = false;
  DateTime? _lastSlideFrameCaptureAt;
  static const Duration _slideFrameCaptureInterval = Duration(milliseconds: 500);
  int _lastHandledRowRevision = -1;

  void _onRowRevisionUpdate(int rowRevision) {
    if (rowRevision == _lastHandledRowRevision) {
      return;
    }
    _lastHandledRowRevision = rowRevision;
    if (_disposed || _routeClosing || _hasActiveController) {
      return;
    }
    final elem = widget.message.videoElem;
    final msgID = widget.message.msgID;
    if (elem == null) {
      return;
    }

    if (_waitingForLocalDownload) {
      final progress = _globalModel.getMessageProgress(msgID ?? '');
      if (progress != _downloadProgress) {
        _safeSetState(() => _downloadProgress = progress);
      }
    }

    final localPath = _resolveReadyLocalVideoPath(elem, msgID);
    if (localPath != null && (_waitingForLocalDownload || _initFailed)) {
      unawaited(_retryInitializeWithLocal());
    }
  }

  Size? get displayedVideoSize => _displayedVideoSize;

  ui.Image? get cachedSlideFrame => _cachedSlideFrame;

  String? get activeLocalVideoPath => _activeLocalVideoPath;

  String? get activeRemoteVideoUrl => _activeRemoteVideoUrl;

  bool get _useIosTexturePlayer => !kIsWeb && Platform.isIOS;

  bool get _hasActiveController =>
      _useIosTexturePlayer ? _iosTextureController != null : _controller != null;

  dynamic get _activePlaybackController => _useIosTexturePlayer
      ? _iosTextureController
      : _controller?.videoPlayerController;

  Duration get playbackPosition =>
      _activePlaybackController?.value.position ?? Duration.zero;

  bool get _isPlayerInitialized {
    if (_useIosTexturePlayer) {
      return _iosTextureController?.value.isInitialized ?? false;
    }
    return _controller?.videoPlayerController?.value.initialized ?? false;
  }

  bool get _isPlayerPlaying =>
      _activePlaybackController?.value.isPlaying == true;

  String get _debugMsgId {
    final id = widget.message.msgID ?? widget.message.id?.toString() ?? '-';
    if (id.length <= 12) {
      return id;
    }
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  void preparePlaybackPipeline() {
    MediaPreviewDebug.log('player_prepare', {
      'msg': _debugMsgId,
      'defer': widget.deferInitialization,
      'preferOnline': widget.preferOnlinePlayback,
      'initialized': _isPlayerInitialized,
      'initializing': _initializing,
      'hasController': _hasActiveController,
    });
    _beginInitialize();
  }

  bool get isPlaybackPipelineReady {
    if (_disposed || _routeClosing) {
      return false;
    }
    return _isPlayerInitialized;
  }

  bool get isPlaying => !_disposed && !_routeClosing && _isPlayerPlaying;

  Future<void> startDeferredPlayback() async {
    if (_disposed || _routeClosing) {
      MediaPreviewDebug.log('player_start_deferred_skip', {
        'msg': _debugMsgId,
        'disposed': _disposed,
        'routeClosing': _routeClosing,
      });
      return;
    }
    // 播完复位后禁止自动再开播，只响应用户点击。
    if (_holdAfterFinished) {
      MediaPreviewDebug.log('player_start_deferred_skip', {
        'msg': _debugMsgId,
        'reason': 'hold_after_finished',
      });
      return;
    }
    MediaPreviewDebug.log('player_start_deferred', {
      'msg': _debugMsgId,
      'initialized': _isPlayerInitialized,
      'playing': _isPlayerPlaying,
      'hasController': _hasActiveController,
      'pending': _deferredPlaybackPending,
    });
    if (_hasActiveController && _isPlayerInitialized) {
      _deferredPlaybackPending = false;
      if (!_isPlayerPlaying) {
        await _playActive();
      }
      widget.onPlayerInitialized?.call();
      _notifyPlaybackStarted();
      return;
    }
    _deferredPlaybackPending = true;
    _beginInitialize();
  }

  Future<void> _completeDeferredPlaybackIfNeeded() async {
    if (!_deferredPlaybackPending || _disposed || _routeClosing) {
      return;
    }
    if (_holdAfterFinished) {
      _deferredPlaybackPending = false;
      return;
    }
    if (!_hasActiveController || !_isPlayerInitialized) {
      MediaPreviewDebug.log('player_complete_deferred_wait', {
        'msg': _debugMsgId,
        'hasController': _hasActiveController,
        'initialized': _isPlayerInitialized,
      });
      return;
    }
    _deferredPlaybackPending = false;
    try {
      MediaPreviewDebug.log('player_complete_deferred_play', {
        'msg': _debugMsgId,
        'wasPlaying': _isPlayerPlaying,
      });
      if (!_isPlayerPlaying) {
        await _playActive();
      }
      widget.onPlayerInitialized?.call();
      _notifyPlaybackStarted();
    } catch (e) {
      debugPrint('Deferred playback start error: $e');
      MediaPreviewDebug.log('player_complete_deferred_error', {
        'msg': _debugMsgId,
        'error': '$e',
      });
      widget.onInitFailed?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    final elem = widget.message.videoElem;
    if (elem != null) {
      _videoAspectRatio = resolveVideoAspectRatio(elem);
    }
    if (!widget.deferInitialization) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _beginInitialize();
      });
    }
  }

  void resumePlayback() {
    if (_disposed || _routeClosing) {
      return;
    }
    _holdAfterFinished = false;
    if (_hasActiveController &&
        _isPlayerInitialized &&
        !_isPlayerPlaying) {
      unawaited(_playActive());
      return;
    }
    if (!_hasActiveController) {
      _beginInitialize();
    }
  }

  Future<void> _playActive() async {
    if (_useIosTexturePlayer) {
      await _iosTextureController?.play();
      return;
    }
    await _controller?.play();
  }

  Future<void> _pauseActive() async {
    if (_useIosTexturePlayer) {
      await _iosTextureController?.pause();
      return;
    }
    await _controller?.pause();
    try {
      await _controller?.videoPlayerController?.pause();
    } catch (_) {}
  }

  Future<void> _seekActive(Duration position) async {
    if (_useIosTexturePlayer) {
      await _iosTextureController?.seekTo(position);
      return;
    }
    await _controller?.seekTo(position);
  }

  Future<bool?> togglePlayback() async {
    if (_disposed || _routeClosing || !_isPlayerInitialized) {
      return null;
    }
    if (!_hasActiveController) {
      return null;
    }
    if (_isPlayerPlaying) {
      _holdAfterFinished = false;
      await _pauseActive();
      return false;
    }
    _holdAfterFinished = false;
    await _playActive();
    _notifyPlaybackStarted();
    return true;
  }

  dynamic get playbackController => _activePlaybackController;

  Future<void> seekPlaybackTo(Duration position) async {
    if (_disposed || _routeClosing) {
      return;
    }
    await _seekActive(position);
    if (!_disposed && !_routeClosing) {
      unawaited(refreshSlideCaptureFrame());
    }
  }

  void _notifyPlaybackStarted() {
    if (_playbackStartedNotified || _disposed || _routeClosing) {
      return;
    }
    _playbackStartedNotified = true;
    _playbackFinishedHandling = false;
    MediaPreviewDebug.log('player_notify_playback_started', {
      'msg': _debugMsgId,
      'source': _activeSourceType?.name,
    });
    widget.onPlaybackStarted?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && !_routeClosing) {
        unawaited(refreshSlideCaptureFrame());
      }
    });
  }

  Future<void> _handlePlaybackFinished() async {
    if (_disposed || _routeClosing || _playbackFinishedHandling) {
      return;
    }
    _playbackFinishedHandling = true;
    _playbackStartedNotified = false;
    _holdAfterFinished = true;
    MediaPreviewDebug.log('player_event_finished', {'msg': _debugMsgId});
    try {
      if (_hasActiveController) {
        // iOS 上 finished 后 seek 可能把播放态再次点着，pause→seek→再 pause 卡住。
        await _pauseActive();
        await _seekActive(Duration.zero);
        await _pauseActive();
      }
    } catch (e) {
      MediaPreviewDebug.log('player_finished_reset_error', {
        'msg': _debugMsgId,
        'error': '$e',
      });
    }
    if (_disposed || _routeClosing) {
      return;
    }
    // 再确认一帧后仍暂停，杜绝异步 play 回潮。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _routeClosing || !_holdAfterFinished) {
        return;
      }
      unawaited(() async {
        try {
          await _pauseActive();
        } catch (_) {}
      }());
    });
    widget.onPlaybackFinished?.call();
    if (mounted) {
      setState(() {});
    }
  }

  void _beginInitialize() {
    if (_disposed ||
        _hasActiveController ||
        _initializing ||
        (_initFailed && !_waitingForLocalDownload)) {
      MediaPreviewDebug.log('player_begin_init_skip', {
        'msg': _debugMsgId,
        'disposed': _disposed,
        'hasController': _hasActiveController,
        'initializing': _initializing,
        'initFailed': _initFailed,
        'waitingDownload': _waitingForLocalDownload,
      });
      return;
    }
    MediaPreviewDebug.log('player_begin_init', {'msg': _debugMsgId});
    _initializing = true;
    _initializePlayer();
  }

  void _detachControllerListener() {
    final listener = _controllerListener;
    final playbackController = _playbackControllerForListener;
    if (listener != null && playbackController != null) {
      playbackController.removeListener(listener);
    }
    _controllerListener = null;
    _playbackControllerForListener = null;
  }

  Future<void> _disposeController() async {
    _detachControllerListener();
    final iosController = _iosTextureController;
    _iosTextureController = null;
    if (iosController != null) {
      try {
        await iosController.dispose();
      } catch (_) {}
    }
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.dispose(forceDispose: true);
      } catch (_) {}
    }
  }

  void _attachControllerListener() {
    _detachControllerListener();
    final playbackController = _activePlaybackController;
    if (playbackController == null) {
      return;
    }
    void onTick() {
      if (_disposed || _routeClosing || !mounted) {
        return;
      }
      final value = playbackController.value;
      final position = value.position;
      if (_lastTrackedCapturePosition != null) {
        final jumpMs =
            (position - _lastTrackedCapturePosition!).inMilliseconds.abs();
        if (jumpMs >= 800 && !_slideFrameCaptureInFlight) {
          unawaited(refreshSlideCaptureFrame());
        }
      }
      _lastTrackedCapturePosition = position;
      if (value.isPlaying) {
        _maybeRefreshSlideCaptureFrameThrottled();
      }
      // 部分机型 finished 事件不可靠：贴结尾且已停止时兜底复位（阈值从严，避免中段暂停误触）。
      final duration = value.duration;
      if (!_playbackFinishedHandling &&
          !value.isPlaying &&
          duration != null &&
          duration > const Duration(milliseconds: 500) &&
          position > Duration.zero &&
          position >= duration - const Duration(milliseconds: 80)) {
        unawaited(_handlePlaybackFinished());
      }
      if (value.hasError) {
        if (_activeSourceType == CurrentVideoType.local && !_retryingWithOnline) {
          unawaited(_retryWithOnlineUrl());
        } else if (!_initFailed) {
          _markInitFailed();
        }
      }
    }

    _controllerListener = onTick;
    _playbackControllerForListener = playbackController;
    playbackController.addListener(onTick);
  }

  Future<void> _retryInitializeWithLocal() async {
    if (_disposed || _routeClosing || _hasActiveController || _initializing) {
      return;
    }
    _initFailed = false;
    _waitingForLocalDownload = false;
    _initializing = true;
    await _initializePlayer();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _disposed || _routeClosing) {
      return;
    }
    void apply() {
      if (mounted && !_disposed && !_routeClosing) {
        setState(fn);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      Future<void>.delayed(Duration.zero, apply);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration.zero, apply);
    });
  }

  void _markInitFailed() {
    if (_disposed || _routeClosing || _initFailed) {
      return;
    }
    MediaPreviewDebug.log('player_mark_init_failed', {
      'msg': _debugMsgId,
      'source': _activeSourceType?.name,
      'local': _activeLocalVideoPath,
      'remote': _activeRemoteVideoUrl,
    });
    _safeSetState(() => _initFailed = true);
    widget.onInitFailed?.call();
  }

  void _notifyAspectRatio(double aspectRatio) {
    if (!aspectRatio.isFinite || aspectRatio <= 0) {
      return;
    }
    _videoAspectRatio = aspectRatio;
    final callback = widget.onAspectRatioResolved;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed && !_routeClosing) {
        callback(aspectRatio);
      }
    });
  }

  Size _fitVideoSize(BoxConstraints constraints, double aspectRatio) {
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;
    if (maxW <= 0 || maxH <= 0) {
      return Size.zero;
    }
    final safeAspect = aspectRatio.isFinite && aspectRatio > 0.1 ? aspectRatio : 9 / 16;
    if (maxW / maxH > safeAspect) {
      final height = maxH;
      return Size(height * safeAspect, height);
    }
    final width = maxW;
    return Size(width, width / safeAspect);
  }

  Future<void> _initializePlayer() async {
    try {
      final info = await getMessageInfo();
      if (!mounted || _disposed || _routeClosing) {
        MediaPreviewDebug.log('player_init_aborted', {
          'msg': _debugMsgId,
          'reason': 'unmounted',
        });
        return;
      }
      if (info == null) {
        final elem = widget.message.videoElem;
        final msgID = widget.message.msgID;
        if (elem != null && _shouldWaitForLocalDownload(elem, msgID)) {
          _waitingForLocalDownload = true;
          _downloadProgress = _globalModel.getMessageProgress(msgID ?? '');
          MediaPreviewDebug.log('player_wait_download', {
            'msg': _debugMsgId,
            'progress': _downloadProgress,
          });
          widget.onPlayerInitialized?.call();
          _safeSetState(() {});
          return;
        }
        MediaPreviewDebug.log('player_no_source', {'msg': _debugMsgId});
        _markInitFailed();
        return;
      }
      MediaPreviewDebug.log('player_source_resolved', {
        'msg': _debugMsgId,
        'type': info.type.name,
        'path': info.path.length > 80
            ? '${info.path.substring(0, 40)}…${info.path.substring(info.path.length - 20)}'
            : info.path,
        'ar': info.aspectRatio.toStringAsFixed(3),
      });
      _waitingForLocalDownload = false;
      await _mountPlayer(info);
    } catch (e) {
      debugPrint("Video initialization error: $e");
      MediaPreviewDebug.log('player_init_exception', {
        'msg': _debugMsgId,
        'error': '$e',
      });
      if (mounted && !_disposed && !_routeClosing) {
        _markInitFailed();
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _mountIosTexturePlayer(CurrentVideoInfo info) async {
    if (!mounted || _disposed || _routeClosing) {
      return;
    }

    late final vp.VideoPlayerController controller;
    if (info.type == CurrentVideoType.online) {
      final resolvedUrl = resolveChatMediaNetworkUrl(info.path);
      _activeLocalVideoPath = null;
      _activeRemoteVideoUrl = resolvedUrl;
      final uri = Uri.tryParse(resolvedUrl);
      if (uri == null || !uri.hasScheme) {
        MediaPreviewDebug.log('player_ios_texture_bad_url', {
          'msg': _debugMsgId,
          'url': resolvedUrl,
        });
        _markInitFailed();
        return;
      }
      controller = vp.VideoPlayerController.networkUrl(
        uri,
        httpHeaders:
            chatMediaNetworkHeaders(resolvedUrl) ?? const <String, String>{},
        videoPlayerOptions: vp.VideoPlayerOptions(mixWithOthers: true),
        viewType: vp.VideoViewType.textureView,
      );
    } else {
      _activeLocalVideoPath = info.path;
      _activeRemoteVideoUrl = null;
      controller = vp.VideoPlayerController.file(
        File(info.path),
        videoPlayerOptions: vp.VideoPlayerOptions(mixWithOthers: true),
        viewType: vp.VideoViewType.textureView,
      );
    }

    MediaPreviewDebug.log('player_mount_ios_texture', {
      'msg': _debugMsgId,
      'type': info.type.name,
      'defer': widget.deferInitialization,
    });
    debugPrint(
      '$_tag ios_texture mount type=${info.type.name} defer=${widget.deferInitialization} msg=$_debugMsgId',
    );

    _iosTextureController = controller;
    _attachControllerListener();
    if (mounted && !_disposed && !_routeClosing) {
      setState(() {});
    }

    try {
      await controller.initialize();
      if (!mounted || _disposed || _routeClosing) {
        try {
          await controller.dispose();
        } catch (_) {}
        if (identical(_iosTextureController, controller)) {
          _iosTextureController = null;
        }
        return;
      }
      if (controller.value.hasError) {
        throw StateError(
          controller.value.errorDescription ?? 'ios texture init error',
        );
      }
      await controller.setLooping(false);
      final rawAspect = controller.value.aspectRatio;
      debugPrint(
        '$_tag ios_texture initialized ar=${rawAspect.toStringAsFixed(3)} '
        'size=${controller.value.size} duration=${controller.value.duration} msg=$_debugMsgId',
      );
      if (rawAspect.isFinite && rawAspect > 0.1) {
        _notifyAspectRatio(rawAspect);
      }
      if (mounted && !_disposed && !_routeClosing) {
        setState(() {});
      }
      widget.onPlayerInitialized?.call();
      if (widget.deferInitialization) {
        await _completeDeferredPlaybackIfNeeded();
        return;
      }
      await controller.play();
      _notifyPlaybackStarted();
    } catch (e) {
      debugPrint('$_tag ios_texture init error: $e msg=$_debugMsgId');
      MediaPreviewDebug.log('player_ios_texture_init_error', {
        'msg': _debugMsgId,
        'error': '$e',
      });
      _detachControllerListener();
      try {
        await controller.dispose();
      } catch (_) {}
      if (identical(_iosTextureController, controller)) {
        _iosTextureController = null;
      }
      if (!mounted || _disposed || _routeClosing) {
        return;
      }
      if (info.type == CurrentVideoType.local && !_retryingWithOnline) {
        await _retryWithOnlineUrl();
      } else {
        _markInitFailed();
      }
    }
  }

  Future<void> _mountPlayer(CurrentVideoInfo info) async {
    if (!mounted || _disposed || _routeClosing) {
      return;
    }

    MediaPreviewDebug.log('player_mount', {
      'msg': _debugMsgId,
      'type': info.type.name,
      'defer': widget.deferInitialization,
      'autoPlay': !widget.deferInitialization,
    });
    _notifyAspectRatio(info.aspectRatio);
    _activeSourceType = info.type;
    await _disposeController();
    if (_useIosTexturePlayer) {
      await _mountIosTexturePlayer(info);
      return;
    }

    final avp.BetterPlayerDataSource dataSource;
    if (info.type == CurrentVideoType.online) {
      final resolvedUrl = resolveChatMediaNetworkUrl(info.path);
      _activeLocalVideoPath = null;
      _activeRemoteVideoUrl = resolvedUrl;
      dataSource = avp.BetterPlayerDataSource(
        avp.BetterPlayerDataSourceType.network,
        resolvedUrl,
        headers: chatMediaNetworkHeaders(resolvedUrl),
      );
    } else {
      _activeLocalVideoPath = info.path;
      _activeRemoteVideoUrl = null;
      dataSource = avp.BetterPlayerDataSource(
        avp.BetterPlayerDataSourceType.file,
        info.path,
      );
    }

    final controller = avp.BetterPlayerController(
      avp.BetterPlayerConfiguration(
        aspectRatio: info.aspectRatio,
        autoPlay: !widget.deferInitialization,
        looping: false,
        autoDispose: false,
        fit: BoxFit.contain,
        controlsConfiguration: const avp.BetterPlayerControlsConfiguration(
          showControls: false,
          showControlsOnInitialize: false,
          enableFullscreen: false,
          enableMute: false,
          enableProgressText: false,
          enableProgressBar: false,
          enableProgressBarDrag: false,
          enablePlayPause: false,
          enableSkips: false,
          enableOverflowMenu: false,
          enablePlaybackSpeed: false,
          enableSubtitles: false,
          enableQualities: false,
          enablePip: false,
          enableRetry: false,
        ),
      ),
    );
    var initializedNotified = false;
    controller.addEventsListener((event) {
      if (_disposed || _routeClosing || !mounted) {
        return;
      }
      switch (event.betterPlayerEventType) {
        case avp.BetterPlayerEventType.initialized:
          if (initializedNotified) {
            return;
          }
          initializedNotified = true;
          final rawAspect = controller.videoPlayerController?.value.aspectRatio;
          MediaPreviewDebug.log('player_event_initialized', {
            'msg': _debugMsgId,
            'ar': rawAspect?.toStringAsFixed(3),
            'defer': widget.deferInitialization,
            'pendingPlay': _deferredPlaybackPending,
          });
          if (rawAspect != null && rawAspect.isFinite && rawAspect > 0.1) {
            _notifyAspectRatio(rawAspect);
          }
          _attachControllerListener();
          if (mounted && !_disposed && !_routeClosing) {
            setState(() {});
          }
          widget.onPlayerInitialized?.call();
          if (widget.deferInitialization) {
            unawaited(_completeDeferredPlaybackIfNeeded());
          } else {
            _notifyPlaybackStarted();
          }
          break;
        case avp.BetterPlayerEventType.play:
          MediaPreviewDebug.log('player_event_play', {
            'msg': _debugMsgId,
            'holdAfterFinished': _holdAfterFinished,
          });
          // 播完复位后若底层又自动 play，立刻按住。
          if (_holdAfterFinished) {
            unawaited(() async {
              try {
                await controller.pause();
                await controller.videoPlayerController?.pause();
              } catch (_) {}
            }());
            return;
          }
          _notifyPlaybackStarted();
          break;
        case avp.BetterPlayerEventType.finished:
          unawaited(_handlePlaybackFinished());
          break;
        case avp.BetterPlayerEventType.exception:
          MediaPreviewDebug.log('player_event_exception', {
            'msg': _debugMsgId,
            'source': _activeSourceType?.name,
            'retrying': _retryingWithOnline,
          });
          if (_activeSourceType == CurrentVideoType.local && !_retryingWithOnline) {
            unawaited(_retryWithOnlineUrl());
          } else if (!_initFailed) {
            _markInitFailed();
          }
          break;
        default:
          break;
      }
    });

    try {
      _controller = controller;
      if (mounted && !_disposed && !_routeClosing) {
        setState(() {});
      }
      await controller.setupDataSource(dataSource);
      if (!mounted || _disposed || _routeClosing) {
        controller.dispose(forceDispose: true);
        return;
      }
      final rawAspect = controller.videoPlayerController?.value.aspectRatio;
      if (rawAspect != null && rawAspect.isFinite && rawAspect > 0.1) {
        _notifyAspectRatio(rawAspect);
      }
      _attachControllerListener();
      if (mounted && !_disposed && !_routeClosing) {
        setState(() {});
      }
      if (widget.deferInitialization) {
        await _completeDeferredPlaybackIfNeeded();
        return;
      }
    } catch (e) {
      debugPrint('Video init error: $e');
      controller.dispose(forceDispose: true);
      if (identical(_controller, controller)) {
        _controller = null;
      }
      if (!mounted || _disposed || _routeClosing) {
        return;
      }
      if (info.type == CurrentVideoType.local && !_retryingWithOnline) {
        await _retryWithOnlineUrl();
      } else {
        _markInitFailed();
      }
    }
  }

  Future<void> _retryWithOnlineUrl() async {
    if (_disposed || _routeClosing || _retryingWithOnline) {
      return;
    }
    _retryingWithOnline = true;
    try {
      final onlineUrl = await _resolveOnlineVideoUrl(widget.message.videoElem!);
      if (onlineUrl == null || !mounted || _disposed || _routeClosing) {
        _markInitFailed();
        return;
      }

      _initFailed = false;
      await _disposeController();
      _safeSetState(() {});

      if (!mounted || _disposed || _routeClosing) {
        return;
      }

      final elem = widget.message.videoElem!;
      await _mountPlayer(
        CurrentVideoInfo(
          path: onlineUrl,
          type: CurrentVideoType.online,
          aspectRatio: resolveVideoAspectRatio(elem),
        ),
      );
    } catch (e) {
      debugPrint("Video online retry error: $e");
      if (mounted && !_disposed && !_routeClosing) {
        _markInitFailed();
      }
    } finally {
      _retryingWithOnline = false;
    }
  }

  Future<void> pausePlayback() async {
    if (_disposed || _routeClosing) {
      return;
    }
    try {
      await _pauseActive();
    } catch (_) {}
  }

  Future<ui.Image?> captureCurrentFrameImage({required double pixelRatio}) async {
    if (_disposed || _routeClosing || !_isPlayerInitialized) {
      return null;
    }
    final boundary = _frameCaptureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return null;
    }
    if (boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      return boundary.toImage(pixelRatio: pixelRatio);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Video frame capture failed: $e');
      }
      return null;
    }
  }

  Future<void> refreshSlideCaptureFrame({double? pixelRatio}) async {
    if (_disposed || _routeClosing || !_canRenderPlayer || _slideFrameCaptureInFlight) {
      return;
    }
    _slideFrameCaptureInFlight = true;
    try {
      final dpr = pixelRatio ??
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final frame = await MediaPreviewSlideFrameCapture.capture(
        MediaPreviewSlideFrameRequest(
          frameCaptureKey: _frameCaptureKey,
          localVideoPath: _activeLocalVideoPath,
          remoteVideoUrl: _activeRemoteVideoUrl,
          position: playbackPosition,
          targetSize: _displayedVideoSize,
          pixelRatio: dpr,
        ),
      );
      if (frame == null || _disposed || _routeClosing) {
        frame?.dispose();
        return;
      }
      _cachedSlideFrame?.dispose();
      _cachedSlideFrame = frame;
      _lastSlideFrameCaptureAt = DateTime.now();
      _lastTrackedCapturePosition = playbackPosition;
    } finally {
      _slideFrameCaptureInFlight = false;
    }
  }

  ui.Image? borrowSlideFrameForDrag({required double pixelRatio}) {
    final cached = _cachedSlideFrame;
    if (cached != null) {
      return cached;
    }
    unawaited(refreshSlideCaptureFrame(pixelRatio: pixelRatio));
    return null;
  }

  void _maybeRefreshSlideCaptureFrameThrottled() {
    if (_disposed || _routeClosing || !_canRenderPlayer || _slideFrameCaptureInFlight) {
      return;
    }
    final lastAt = _lastSlideFrameCaptureAt;
    if (lastAt != null &&
        DateTime.now().difference(lastAt) < _slideFrameCaptureInterval) {
      return;
    }
    unawaited(refreshSlideCaptureFrame());
  }

  bool get _canRenderPlayer {
    if (_disposed || !_isPlayerInitialized) {
      return false;
    }
    if (_useIosTexturePlayer) {
      return _iosTextureController != null;
    }
    return _controller != null;
  }

  void prepareForRouteClose() {
    if (_disposed || _routeClosing) {
      return;
    }
    _routeClosing = true;
    pausePlayback();
    _detachControllerListener();
  }

  @override
  void dispose() {
    _routeClosing = true;
    _disposed = true;
    _detachControllerListener();
    _cachedSlideFrame?.dispose();
    _cachedSlideFrame = null;
    final iosController = _iosTextureController;
    _iosTextureController = null;
    if (iosController != null) {
      try {
        iosController.dispose();
      } catch (_) {}
    }
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.dispose(forceDispose: true);
      } catch (_) {}
    }
    super.dispose();
  }

  bool _isDownloadInProgress(V2TimVideoElem elem, String? msgID) {
    if (msgID != null && msgID.isNotEmpty) {
      final progress = _globalModel.getMessageProgress(msgID);
      if (progress > 0 && progress < 100) {
        return true;
      }
    }
    final expectedSize = elem.videoSize;
    if (expectedSize == null || expectedSize <= 0) {
      return false;
    }
    final candidates = <String?>[
      if (msgID != null && msgID.isNotEmpty)
        _globalModel.getFileMessageLocation(msgID),
      elem.videoPath,
      elem.localVideoUrl,
    ];
    for (final raw in candidates) {
      final path = TencentUtils.checkString(raw);
      if (path == null) {
        continue;
      }
      try {
        final file = File(path);
        if (!file.existsSync()) {
          continue;
        }
        final actualSize = file.lengthSync();
        if (actualSize > 0 && actualSize < expectedSize) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  bool _shouldWaitForLocalDownload(V2TimVideoElem elem, String? msgID) {
    final size = elem.videoSize ?? 0;
    if (size >= _largeVideoPreferLocalBytes) {
      return true;
    }
    return _isDownloadInProgress(elem, msgID);
  }

  bool _isLocalVideoPlayable(String path, V2TimVideoElem elem, String? msgID) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return false;
      }
      final actualSize = file.lengthSync();
      if (actualSize <= 0) {
        return false;
      }
      final expectedSize = elem.videoSize;
      if (expectedSize != null && expectedSize > 0 && actualSize < expectedSize) {
        return false;
      }
      if (msgID != null && msgID.isNotEmpty) {
        final progress = _globalModel.getMessageProgress(msgID);
        if (progress > 0 && progress < 100) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveOnlineVideoUrl(V2TimVideoElem elem) async {
    final videoUrl = TencentUtils.checkString(elem.videoUrl);
    if (videoUrl != null) {
      return resolveChatMediaNetworkUrl(videoUrl);
    }

    if (!kIsWeb && TencentUtils.checkString(widget.message.msgID) != null) {
      final V2TimValueCallback<V2TimMessageOnlineUrl> urlres = await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .getMessageOnlineUrl(msgID: widget.message.msgID!);
      if (urlres.data?.videoElem != null) {
        final merged = mergeVideoElemKeepingLocalPreview(
          elem,
          urlres.data!.videoElem!,
        );
        final onlineUrl = TencentUtils.checkString(merged.videoUrl);
        if (onlineUrl != null) {
          widget.message.videoElem = merged;
          return resolveChatMediaNetworkUrl(onlineUrl);
        }
      }
    }
    return null;
  }

  void _requestVideoDownload() {
    final msgID = widget.message.msgID;
    if (msgID == null || msgID.isEmpty || kIsWeb) {
      return;
    }
    TencentImSDKPlugin.v2TIMManager.getMessageManager().downloadMessage(
      msgID: msgID,
      messageType: 5,
      imageType: 0,
      isSnapshot: false,
    );
  }

  String? _resolveReadyLocalVideoPath(V2TimVideoElem elem, String? msgID) {
    final candidates = <String?>[
      if (msgID != null && msgID.isNotEmpty)
        serviceLocator<TUIChatGlobalModel>().getFileMessageLocation(msgID),
      elem.videoPath,
      elem.localVideoUrl,
    ];
    for (final raw in candidates) {
      final path = TencentUtils.checkString(raw);
      if (path != null && _isLocalVideoPlayable(path, elem, msgID)) {
        return path;
      }
    }
    return null;
  }

  Future<CurrentVideoInfo?> getMessageInfo() async {
    if (widget.message.elemType != MessageElemType.V2TIM_ELEM_TYPE_VIDEO) {
      console("The component received a non-video message parameter. please check");
      return null;
    }

    final elem = widget.message.videoElem!;
    final aspectRatio = resolveVideoAspectRatio(elem);
    final msgID = widget.message.msgID;

    if (widget.isSending) {
      final sendingPath = elem.videoPath ?? "";
      if (sendingPath.isNotEmpty &&
          !kIsWeb &&
          _isLocalVideoPlayable(sendingPath, elem, msgID)) {
        console("view sending message video path");
        return CurrentVideoInfo(path: sendingPath, type: CurrentVideoType.local, aspectRatio: aspectRatio);
      }
    }

    final localPath = _resolveReadyLocalVideoPath(elem, msgID);
    if (localPath != null) {
      console("video: local url exists");
      return CurrentVideoInfo(path: localPath, type: CurrentVideoType.local, aspectRatio: aspectRatio);
    }

    if (widget.preferOnlinePlayback) {
      final onlineUrl = await _resolveOnlineVideoUrl(elem);
      if (onlineUrl != null) {
        console("video: prefer online url $onlineUrl");
        return CurrentVideoInfo(
          path: onlineUrl,
          type: CurrentVideoType.online,
          aspectRatio: resolveVideoAspectRatio(widget.message.videoElem!),
        );
      }
    }

    _requestVideoDownload();

    if (!widget.preferOnlinePlayback && _shouldWaitForLocalDownload(elem, msgID)) {
      console("video: waiting for local download");
      return null;
    }

    final onlineUrl = await _resolveOnlineVideoUrl(elem);
    if (onlineUrl != null) {
      console("video: online url $onlineUrl");
      return CurrentVideoInfo(
        path: onlineUrl,
        type: CurrentVideoType.online,
        aspectRatio: resolveVideoAspectRatio(widget.message.videoElem!),
      );
    }

    console("has no view video source. please check");
    return null;
  }

  Widget _buildPlayerSurface() {
    if (_useIosTexturePlayer) {
      final controller = _iosTextureController;
      if (controller == null) {
        return const ColoredBox(color: Colors.black);
      }
      return vp.VideoPlayer(controller);
    }
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(color: Colors.black);
    }
    return avp.BetterPlayer(controller: controller);
  }

  Widget _buildVideoContent(BoxConstraints constraints) {
    final videoSize = _fitVideoSize(constraints, _videoAspectRatio);
    if (videoSize == Size.zero) {
      return const ColoredBox(color: Colors.black);
    }
    _displayedVideoSize = videoSize;

    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_canRenderPlayer)
          Center(
            child: SizedBox(
              width: videoSize.width,
              height: videoSize.height,
              // 播放画面不参与命中，手势交给外层预览（翻页/下滑/边缘返回）。
              child: IgnorePointer(
                child: RepaintBoundary(
                  key: _frameCaptureKey,
                  child: _buildPlayerSurface(),
                ),
              ),
            ),
          )
        else if (_waitingForLocalDownload)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  _downloadProgress > 0
                      ? '下载中 $_downloadProgress%'
                      : '正在下载视频...',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          )
        else if (!_initFailed)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        if (_initFailed)
          const Center(
            child: Text(
              '视频加载失败',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
      ],
    );
  }

  console(String log) {
    if (kDebugMode) {
      print("$_tag, $log");
    }
  }

  @override
  Widget build(BuildContext context) {
    final convId = ChatUiStateStore.conversationIDOf(widget.message) ?? '';
    if (convId.isNotEmpty) {
      final msgKey = ChatUiStateStore.messageKeyOf(widget.message);
      // 全屏预览经 Navigator 推出后常不在聊天页 Provider 子树内；
      // select 抛错会导致整棵播放器挂掉并灰屏。
      try {
        final rowRevision = context.select<ChatUiStateStore, int>(
          (store) => store.rowRevision(convId, msgKey),
        );
        _onRowRevisionUpdate(rowRevision);
      } on ProviderNotFoundException {
        final rowRevision =
            serviceLocator<ChatUiStateStore>().rowRevision(convId, msgKey);
        _onRowRevisionUpdate(rowRevision);
      }
    }

    if (widget.message.hasRiskContent == true) {
      return const Center(
        child: Text(
          "Risk Video",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: _buildVideoContent(constraints),
        );
      },
    );
  }
}
