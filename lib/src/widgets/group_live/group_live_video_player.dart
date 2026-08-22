import 'dart:async';
import 'dart:io';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:live_flutter_plugin/v2_tx_live_code.dart';
import 'package:live_flutter_plugin/v2_tx_live_def.dart';
import 'package:live_flutter_plugin/v2_tx_live_player.dart';
import 'package:live_flutter_plugin/v2_tx_live_player_observer.dart';
import 'package:live_flutter_plugin/widget/v2_tx_live_video_widget.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_tencent_licence.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_cast_button.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';

/// Max WebRTC start retries before falling back to FLV/HLS.
const int kGroupLiveWebRtcMaxFailures = 2;

/// Wait for first video frame on WebRTC before treating start as success.
const Duration kGroupLiveWebRtcFirstFrameTimeout = Duration(seconds: 8);

BetterPlayerControlsConfiguration groupLiveControlsConfiguration({
  bool compact = false,
}) {
  return BetterPlayerControlsConfiguration(
    showControls: !compact,
    showControlsOnInitialize: false,
    enableFullscreen: !compact,
    enableMute: !compact,
    enablePip: false,
    enablePlayPause: true,
    enableSkips: false,
    enableProgressBar: false,
    enableProgressBarDrag: false,
    enableProgressText: false,
    enableOverflowMenu: false,
    enablePlaybackSpeed: false,
    enableSubtitles: false,
    enableQualities: false,
    enableAudioTracks: false,
    playerTheme: BetterPlayerTheme.material,
    iconsColor: Colors.white,
    textColor: Colors.white,
    liveTextColor: const Color(0xFFFF5252),
  );
}

Future<BetterPlayerController> _createFallbackPlayerController({
  required String url,
  required GroupLivePlaybackMode mode,
  BoxFit fit = BoxFit.contain,
  bool compact = false,
}) async {
  final resolved = MediaUrlResolver.resolve(url) ?? url;
  final headers = resolved.startsWith('http')
      ? MediaUrlResolver.authHeadersFor(resolved)
      : null;
  final String? videoExtension;
  switch (mode) {
    case GroupLivePlaybackMode.flv:
      videoExtension = 'flv';
      break;
    case GroupLivePlaybackMode.hls:
      videoExtension = 'm3u8';
      break;
    case GroupLivePlaybackMode.webrtc:
      videoExtension = null;
      break;
  }
  if (kDebugMode) {
    // ignore: avoid_print
    print(
      '[GroupLive] fallback setup mode=$mode url=$resolved '
      'headers=${headers != null}',
    );
  }
  late final BetterPlayerController controller;
  controller = BetterPlayerController(
    BetterPlayerConfiguration(
      autoPlay: true,
      aspectRatio: 16 / 9,
      fit: fit,
      handleLifecycle: true,
      autoDispose: false,
      expandToFill: true,
      autoDetectFullscreenDeviceOrientation: true,
      autoDetectFullscreenAspectRatio: true,
      controlsConfiguration: groupLiveControlsConfiguration(compact: compact),
      routePageBuilder: compact
          ? (context, animation, secondaryAnimation, provider) {
              return _GroupLiveCompactFullScreenRoute(
                provider: provider,
                onExit: () => controller.exitFullScreen(),
              );
            }
          : null,
    ),
  );

  await controller.setupDataSource(
    BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      resolved,
      liveStream: true,
      headers: headers,
      videoExtension: videoExtension,
    ),
  );
  return controller;
}

class _GroupLiveCompactFullScreenRoute extends StatelessWidget {
  const _GroupLiveCompactFullScreenRoute({
    required this.provider,
    required this.onExit,
  });

  final BetterPlayerControllerProvider provider;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          provider,
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: i18n.t(
                    zhHans: '退出全屏',
                    zhHant: '退出全屏',
                    en: 'Exit fullscreen',
                    ja: '全画面を終了',
                    ko: '전체 화면 종료',
                  ),
                  icon: const Icon(Icons.fullscreen_exit_rounded,
                      color: Colors.white),
                  onPressed: onExit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Group live player: V2TXLivePlayer WebRTC primary, BetterPlayer FLV/HLS fallback.
class GroupLiveVideoPlayer extends StatefulWidget {
  const GroupLiveVideoPlayer({
    super.key,
    required this.playInfo,
    this.compact = false,
    this.fit = BoxFit.contain,
  });

  final GroupLivePlayInfo playInfo;
  final bool compact;
  final BoxFit fit;

  @override
  State<GroupLiveVideoPlayer> createState() => _GroupLiveVideoPlayerState();
}

class _GroupLiveVideoPlayerState extends State<GroupLiveVideoPlayer>
    with WidgetsBindingObserver {
  final GlobalKey _playerKey = GlobalKey();

  V2TXLivePlayer? _tencentPlayer;
  BetterPlayerController? _fallbackController;

  List<GroupLivePlaybackAttempt> _attempts = const [];
  int _attemptIndex = 0;
  int _webrtcFailureCount = 0;
  GroupLivePlaybackMode? _activeMode;
  bool _usingFallback = false;
  bool _muted = false;
  int _volumeBeforeMute = 100;
  bool _isFullScreen = false;
  bool _videoStarted = false;
  Timer? _webrtcStartTimer;
  String? _fatalError;
  String? _pendingWebRtcUrl;
  bool _renderViewReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attempts = _resolveAttempts();
    unawaited(_startPlayback());
  }

  @override
  void didUpdateWidget(covariant GroupLiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playInfo.liveSessionId != widget.playInfo.liveSessionId ||
        oldWidget.playInfo.primaryWebRtcUrl !=
            widget.playInfo.primaryWebRtcUrl ||
        oldWidget.playInfo.fallbackFlvUrl != widget.playInfo.fallbackFlvUrl ||
        oldWidget.playInfo.fallbackHlsUrl != widget.playInfo.fallbackHlsUrl) {
      unawaited(_restartPlayback());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webrtcStartTimer?.cancel();
    _disposeTencentPlayer();
    _disposeFallbackController(force: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_tencentPlayer == null || _usingFallback) {
      return;
    }
    if (state == AppLifecycleState.paused) {
      unawaited(_tencentPlayer?.pauseVideo());
      unawaited(_tencentPlayer?.pauseAudio());
    } else if (state == AppLifecycleState.resumed && !_muted) {
      unawaited(_tencentPlayer?.resumeVideo());
      unawaited(_tencentPlayer?.resumeAudio());
    }
  }

  List<GroupLivePlaybackAttempt> _resolveAttempts() {
    var attempts = widget.playInfo.playbackAttempts;
    if (!_supportsTencentNativePlayer()) {
      attempts = attempts
          .where((item) => item.mode != GroupLivePlaybackMode.webrtc)
          .toList(growable: false);
    } else if (!GroupLiveTencentLicence.hasCredentials ||
        !widget.playInfo.usesTencentWebRtc) {
      attempts = attempts
          .where((item) => item.mode != GroupLivePlaybackMode.webrtc)
          .toList(growable: false);
    }
    // iOS AVPlayer 不支持 FLV，跳过以免无意义失败。
    if (!kIsWeb && Platform.isIOS) {
      attempts = attempts
          .where((item) => item.mode != GroupLivePlaybackMode.flv)
          .toList(growable: false);
    }
    return attempts;
  }

  String _normalizePlaybackUrl(String url, GroupLivePlaybackMode mode) {
    if (mode == GroupLivePlaybackMode.webrtc) {
      return MediaUrlResolver.unwrapProxiedStreamUrl(url) ??
          MediaUrlResolver.resolve(url) ??
          url;
    }
    return MediaUrlResolver.resolve(url) ?? url;
  }

  bool _supportsTencentNativePlayer() =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> _restartPlayback() async {
    _webrtcStartTimer?.cancel();
    _webrtcFailureCount = 0;
    _attemptIndex = 0;
    _videoStarted = false;
    _fatalError = null;
    _renderViewReady = false;
    await _disposeTencentPlayer();
    await _disposeFallbackController(force: true);
    _attempts = _resolveAttempts();
    if (!mounted) return;
    setState(() {
      _activeMode = null;
      _usingFallback = false;
    });
    await _startPlayback();
  }

  Future<void> _startPlayback() async {
    if (_attempts.isEmpty) {
      if (!mounted) return;
      setState(() => _fatalError = 'No playable URL');
      return;
    }
    await _startAttempt(_attempts[_attemptIndex]);
  }

  Future<void> _startAttempt(GroupLivePlaybackAttempt attempt) async {
    _videoStarted = false;
    _fatalError = null;
    if (attempt.mode == GroupLivePlaybackMode.webrtc) {
      await _startWebRtc(attempt.url);
    } else {
      await _startFallback(attempt);
    }
  }

  Future<void> _startWebRtc(String url) async {
    await GroupLiveTencentLicence.ensureConfigured();
    if (!GroupLiveTencentLicence.hasCredentials) {
      await _advanceToNextAttempt();
      return;
    }
    await _disposeFallbackController(force: true);
    _tencentPlayer ??= V2TXLivePlayer();
    _tencentPlayer!.removeListener(_onTencentPlayerEvent);
    _tencentPlayer!.addListener(_onTencentPlayerEvent);

    _pendingWebRtcUrl =
        _normalizePlaybackUrl(url, GroupLivePlaybackMode.webrtc);
    if (!mounted) return;

    setState(() {
      _activeMode = GroupLivePlaybackMode.webrtc;
      _usingFallback = false;
    });

    if (_renderViewReady) {
      await _beginWebRtcPlay();
    }
  }

  Future<void> _beginWebRtcPlay() async {
    final url = _pendingWebRtcUrl?.trim() ?? '';
    final player = _tencentPlayer;
    if (url.isEmpty || player == null) {
      return;
    }

    final code = await player.startLivePlay(url);
    if (!mounted) return;

    if (code != V2TXLIVE_OK) {
      final skipRetry = code == V2TXLIVE_ERROR_INVALID_LICENSE ||
          code == V2TXLIVE_ERROR_NOT_SUPPORTED;
      await _onWebRtcFailed(
        'startLivePlay=$code',
        startCode: code,
        skipRetry: skipRetry,
      );
      return;
    }

    _webrtcStartTimer?.cancel();
    _webrtcStartTimer = Timer(kGroupLiveWebRtcFirstFrameTimeout, () {
      if (!mounted || _videoStarted || _usingFallback) {
        return;
      }
      unawaited(_onWebRtcFailed('first_frame_timeout'));
    });
  }

  Future<void> _onTencentViewCreated(int viewId) async {
    final player = _tencentPlayer;
    if (player == null) return;
    await player.setRenderViewID(viewId);
    await player.setRenderFillMode(_mapFillMode(widget.fit));
    if (_muted) {
      await player.setPlayoutVolume(0);
    } else {
      await player.setPlayoutVolume(_volumeBeforeMute);
    }
    _renderViewReady = true;
    if (_pendingWebRtcUrl != null) {
      await _beginWebRtcPlay();
    }
  }

  V2TXLiveFillMode _mapFillMode(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
      case BoxFit.fill:
        return V2TXLiveFillMode.v2TXLiveFillModeFill;
      case BoxFit.fitWidth:
      case BoxFit.fitHeight:
      case BoxFit.contain:
      case BoxFit.scaleDown:
        return V2TXLiveFillMode.v2TXLiveFillModeFit;
      case BoxFit.none:
        return V2TXLiveFillMode.v2TXLiveFillModeFit;
    }
  }

  void _onTencentPlayerEvent(
    V2TXLivePlayerListenerType type,
    dynamic param,
  ) {
    switch (type) {
      case V2TXLivePlayerListenerType.onVideoPlaying:
        _videoStarted = true;
        _webrtcStartTimer?.cancel();
        break;
      case V2TXLivePlayerListenerType.onConnected:
        if (kDebugMode) {
          // ignore: avoid_print
          print('[GroupLive] WebRTC connected');
        }
        break;
      case V2TXLivePlayerListenerType.onError:
        final code = param is Map ? param['code'] : null;
        unawaited(_onWebRtcFailed('onError=$code'));
        break;
      case V2TXLivePlayerListenerType.onWarning:
        break;
      default:
        break;
    }
  }

  Future<void> _onWebRtcFailed(
    String reason, {
    int? startCode,
    bool skipRetry = false,
  }) async {
    if (_usingFallback || !mounted) return;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[GroupLive] WebRTC failed ($reason) attempt=$_attemptIndex');
    }
    _webrtcFailureCount++;
    await _tencentPlayer?.stopPlay();
    if (skipRetry ||
        startCode == V2TXLIVE_ERROR_INVALID_LICENSE ||
        startCode == V2TXLIVE_ERROR_NOT_SUPPORTED) {
      await _advanceToNextAttempt();
      return;
    }
    if (_webrtcFailureCount < kGroupLiveWebRtcMaxFailures) {
      final url = _attempts[_attemptIndex].url;
      await _startWebRtc(url);
      return;
    }
    await _advanceToNextAttempt();
  }

  Future<void> _advanceToNextAttempt() async {
    _webrtcStartTimer?.cancel();
    await _disposeTencentPlayer();
    while (_attemptIndex + 1 < _attempts.length) {
      _attemptIndex++;
      final next = _attempts[_attemptIndex];
      if (next.mode == GroupLivePlaybackMode.webrtc) {
        continue;
      }
      await _startAttempt(next);
      return;
    }
    if (!mounted) return;
    setState(() => _fatalError = 'Playback failed');
  }

  Future<void> _startFallback(GroupLivePlaybackAttempt attempt) async {
    await _disposeTencentPlayer();
    await _disposeFallbackController(force: true);

    try {
      final controller = await _createFallbackPlayerController(
        url: _normalizePlaybackUrl(attempt.url, attempt.mode),
        mode: attempt.mode,
        fit: widget.fit,
        compact: widget.compact,
      );
      controller.addEventsListener(_onFallbackPlayerEvent);
      if (!mounted) {
        controller.dispose(forceDispose: true);
        return;
      }
      setState(() {
        _fallbackController = controller;
        _activeMode = attempt.mode;
        _usingFallback = true;
        _fatalError = null;
      });
      _fallbackFailureHandled = false;
      controller.setBetterPlayerGlobalKey(_playerKey);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupLive] fallback failed mode=${attempt.mode} error=$e');
      }
      if (_attemptIndex + 1 < _attempts.length) {
        _attemptIndex++;
        await _startAttempt(_attempts[_attemptIndex]);
      } else if (mounted) {
        setState(() => _fatalError = 'Playback failed');
      }
    }
  }

  bool _fallbackFailureHandled = false;

  Future<void> _onFallbackPlaybackFailed(String reason) async {
    if (_fallbackFailureHandled || !mounted || !_usingFallback) {
      return;
    }
    _fallbackFailureHandled = true;
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[GroupLive] fallback playback failed reason=$reason '
        'mode=$_activeMode index=$_attemptIndex',
      );
    }
    await _disposeFallbackController(force: true);
    if (_attemptIndex + 1 < _attempts.length) {
      _attemptIndex++;
      _fallbackFailureHandled = false;
      await _startAttempt(_attempts[_attemptIndex]);
      return;
    }
    if (!mounted) return;
    setState(() => _fatalError = 'Playback failed');
  }

  void _onFallbackPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.exception:
        unawaited(_onFallbackPlaybackFailed('exception'));
        break;
      case BetterPlayerEventType.openFullscreen:
        if (mounted) setState(() => _isFullScreen = true);
        break;
      case BetterPlayerEventType.hideFullscreen:
        if (mounted) setState(() => _isFullScreen = false);
        break;
      default:
        break;
    }
  }

  Future<void> _disposeTencentPlayer() async {
    _webrtcStartTimer?.cancel();
    _pendingWebRtcUrl = null;
    _renderViewReady = false;
    final player = _tencentPlayer;
    _tencentPlayer = null;
    if (player == null) return;
    player.removeListener(_onTencentPlayerEvent);
    await player.stopPlay();
    player.destroy();
  }

  Future<void> _disposeFallbackController({required bool force}) async {
    final controller = _fallbackController;
    _fallbackController = null;
    if (controller == null) return;
    controller.removeEventsListener(_onFallbackPlayerEvent);
    controller.dispose(forceDispose: true);
  }

  Future<void> _toggleMute() async {
    if (_usingFallback) {
      final controller = _fallbackController;
      if (controller == null) return;
      if (_muted) {
        await controller.setVolume(_volumeBeforeMute / 100);
      } else {
        _volumeBeforeMute =
            ((controller.videoPlayerController?.value.volume ?? 1.0) * 100)
                .round();
        if (_volumeBeforeMute <= 0) {
          _volumeBeforeMute = 100;
        }
        await controller.setVolume(0);
      }
    } else {
      final player = _tencentPlayer;
      if (player == null) return;
      if (_muted) {
        await player.setPlayoutVolume(_volumeBeforeMute);
      } else {
        _volumeBeforeMute = 100;
        await player.setPlayoutVolume(0);
      }
    }
    if (!mounted) return;
    setState(() => _muted = !_muted);
  }

  void _toggleFullscreen() {
    if (_usingFallback) {
      final controller = _fallbackController;
      if (controller == null) return;
      if (_isFullScreen) {
        controller.exitFullScreen();
      } else {
        controller.enterFullScreen();
      }
      return;
    }

    if (_activeMode != GroupLivePlaybackMode.webrtc || _tencentPlayer == null) {
      return;
    }

    if (_isFullScreen) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _isFullScreen = true;
      _renderViewReady = false;
    });
    unawaited(
      Navigator.of(context)
          .push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => _GroupLiveWebRtcFullScreenRoute(
            onViewCreated: (viewId) => unawaited(_onTencentViewCreated(viewId)),
            onExit: () => Navigator.of(context).pop(),
            muted: _muted,
            onToggleMute: () => unawaited(_toggleMute()),
          ),
        ),
      )
          .whenComplete(() {
        if (!mounted) return;
        setState(() {
          _isFullScreen = false;
          _renderViewReady = false;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return Center(
        child: Text(
          _fatalError!,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_usingFallback && _fallbackController != null)
          BetterPlayer(
            key: _playerKey,
            controller: _fallbackController!,
          )
        else if (_activeMode == GroupLivePlaybackMode.webrtc && !_isFullScreen)
          V2TXLiveVideoWidget(
            onViewCreated: (viewId) => unawaited(_onTencentViewCreated(viewId)),
          )
        else if (_activeMode == GroupLivePlaybackMode.webrtc && _isFullScreen)
          const ColoredBox(color: Color(0xFF111111))
        else
          const ColoredBox(color: Color(0xFF111111)),
        if (widget.compact)
          Positioned(
            top: 8,
            left: 8,
            child: _CompactToolbar(
              muted: _muted,
              isFullScreen: _isFullScreen,
              onToggleMute: () => unawaited(_toggleMute()),
              onToggleFullscreen: _toggleFullscreen,
            ),
          )
        else
          Positioned(
            top: 8,
            right: 8,
            child: GroupLiveCastButton(
              iconColor: Colors.white,
              iconSize: 22,
            ),
          ),
      ],
    );
  }
}

class _GroupLiveWebRtcFullScreenRoute extends StatelessWidget {
  const _GroupLiveWebRtcFullScreenRoute({
    required this.onViewCreated,
    required this.onExit,
    required this.muted,
    required this.onToggleMute,
  });

  final void Function(int viewId) onViewCreated;
  final VoidCallback onExit;
  final bool muted;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          V2TXLiveVideoWidget(onViewCreated: onViewCreated),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: i18n.t(
                        zhHans: '退出全屏',
                        zhHant: '退出全屏',
                        en: 'Exit fullscreen',
                        ja: '全画面を終了',
                        ko: '전체 화면 종료',
                      ),
                      icon: const Icon(Icons.fullscreen_exit_rounded,
                          color: Colors.white),
                      onPressed: onExit,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: muted
                          ? i18n.t(
                              zhHans: '取消静音',
                              zhHant: '取消靜音',
                              en: 'Unmute',
                              ja: 'ミュート解除',
                              ko: '음소거 해제',
                            )
                          : i18n.t(
                              zhHans: '静音',
                              zhHant: '靜音',
                              en: 'Mute',
                              ja: 'ミュート',
                              ko: '음소거',
                            ),
                      icon: Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                      onPressed: onToggleMute,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactToolbar extends StatelessWidget {
  const _CompactToolbar({
    required this.muted,
    required this.isFullScreen,
    required this.onToggleMute,
    required this.onToggleFullscreen,
  });

  final bool muted;
  final bool isFullScreen;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIcon(
            tooltip: muted
                ? i18n.t(
                    zhHans: '取消静音',
                    zhHant: '取消靜音',
                    en: 'Unmute',
                    ja: 'ミュート解除',
                    ko: '음소거 해제',
                  )
                : i18n.t(
                    zhHans: '静音',
                    zhHant: '靜音',
                    en: 'Mute',
                    ja: 'ミュート',
                    ko: '음소거',
                  ),
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            onTap: onToggleMute,
          ),
          const GroupLiveCastButton(iconSize: 18),
          _ToolbarIcon(
            tooltip: isFullScreen
                ? i18n.t(
                    zhHans: '退出全屏',
                    zhHant: '退出全屏',
                    en: 'Exit fullscreen',
                    ja: '全画面を終了',
                    ko: '전체 화면 종료',
                  )
                : i18n.t(
                    zhHans: '全屏播放',
                    zhHant: '全屏播放',
                    en: 'Fullscreen',
                    ja: '全画面',
                    ko: '전체 화면',
                  ),
            icon: isFullScreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            onTap: onToggleFullscreen,
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
