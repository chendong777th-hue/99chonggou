import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_plugin_record_plus/const/play_state.dart';
import 'package:flutter_plugin_record_plus/const/response.dart';
import 'package:flutter_plugin_record_plus/index.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_uikit/import_proxy/import_proxy.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_output_route_service.dart';

typedef PlayStateListener = void Function(PlayState playState);
typedef SoundInterruptListener = void Function();
typedef ResponseListener = void Function(RecordResponse recordResponse);

enum VoicePlaybackPhase {
  idle,
  loading,
  playing,
  paused,
  completed,
}

/// 播放与录音 AudioSession（与 TRTC/TUICallKit 共存）：
/// - TRTC 启动后会接管 AudioSession（playAndRecord），播放时不再反复 configure
/// - just_audio 关闭自动 session 激活，由本类按需轻量 setActive
/// - 录音仅在按住说话期间切换 session
class SoundPlayer {
  final ImportProxy importProxy = ImportProxy();
  static final FlutterPluginRecord _recorder = FlutterPluginRecord();
  static SoundInterruptListener? _soundInterruptListener;
  static bool isInit = false;
  static bool _playbackSessionConfigured = false;
  static bool _usingRecordSession = false;
  static final AudioPlayer _audioPlayer = AudioPlayer(
    handleAudioSessionActivation: false,
  );
  static bool _speakerOn = VoiceOutputRouteService.isSpeaker;
  static String? _currentUrl;
  static String? playingMessageId;
  static final Set<String> _activeMessageKeys = {};
  static Set<String> _lastCompletedMessageKeys = {};
  static StreamSubscription<PlayerState>? _playerStateSubscription;
  static StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  static final Set<VoidCallback> _playerStateCallbacks = {};
  static Future<void> _operationQueue = Future<void>.value();
  static VoicePlaybackPhase _playbackPhase = VoicePlaybackPhase.idle;
  static bool _userHoldPaused = false;
  static bool _applyingRouteChange = false;
  static int _routeChangeGeneration = 0;
  static int _cancelGeneration = 0;
  static int _routeReassertGeneration = 0;
  static String? _pendingPlayUrl;

  static VoicePlaybackPhase get currentPhase => _playbackPhase;

  static bool get isPlaying => _audioPlayer.playing;

  static ProcessingState get processingState => _audioPlayer.processingState;

  static Duration? get position => _audioPlayer.position;

  static Stream<Duration> get positionStream => _audioPlayer.positionStream;

  static Duration? get duration => _audioPlayer.duration;

  static Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  static bool get speakerOn => VoiceOutputRouteService.isSpeaker;

  static bool get isVoiceActive =>
      _activeMessageKeys.isNotEmpty &&
      (_playbackPhase == VoicePlaybackPhase.loading ||
          _playbackPhase == VoicePlaybackPhase.playing);

  static Future<T> _runExclusive<T>(Future<T> Function() action) {
    final task = _operationQueue.then((_) => action());
    _operationQueue = task.then((_) => null).catchError((_) => null);
    return task;
  }

  static bool _aborted(int generation) => generation != _cancelGeneration;

  static void _bindActiveMessage(String messageId, {String? altMessageId}) {
    _activeMessageKeys.clear();
    _lastCompletedMessageKeys = {};
    if (messageId.isNotEmpty) {
      _activeMessageKeys.add(messageId);
      playingMessageId = messageId;
    }
    if (altMessageId != null && altMessageId.isNotEmpty) {
      _activeMessageKeys.add(altMessageId);
      playingMessageId ??= altMessageId;
    }
  }

  static void _clearActiveMessage() {
    _activeMessageKeys.clear();
    playingMessageId = null;
    _pendingPlayUrl = null;
  }

  static bool matchesMessage(String messageId, {String? altMessageId}) {
    if (_activeMessageKeys.isEmpty) {
      return false;
    }
    if (messageId.isNotEmpty && _activeMessageKeys.contains(messageId)) {
      return true;
    }
    if (altMessageId != null &&
        altMessageId.isNotEmpty &&
        _activeMessageKeys.contains(altMessageId)) {
      return true;
    }
    return false;
  }

  static bool didJustComplete(String messageId, {String? altMessageId}) {
    if (messageId.isNotEmpty && _lastCompletedMessageKeys.contains(messageId)) {
      return true;
    }
    if (altMessageId != null &&
        altMessageId.isNotEmpty &&
        _lastCompletedMessageKeys.contains(altMessageId)) {
      return true;
    }
    return false;
  }

  static void adoptMessageAlias(String alias) {
    if (alias.isEmpty || _activeMessageKeys.isEmpty) {
      return;
    }
    _activeMessageKeys.add(alias);
    playingMessageId ??= alias;
  }

  static bool isPausedMessage(String messageId, {String? altMessageId}) {
    return matchesMessage(messageId, altMessageId: altMessageId) &&
        (_playbackPhase == VoicePlaybackPhase.paused || _userHoldPaused);
  }

  static bool isLoadingMessage(String messageId, {String? altMessageId}) {
    return matchesMessage(messageId, altMessageId: altMessageId) &&
        _playbackPhase == VoicePlaybackPhase.loading;
  }

  static bool messageShouldAnimate(String messageId, {String? altMessageId}) {
    return matchesMessage(messageId, altMessageId: altMessageId) &&
        (_playbackPhase == VoicePlaybackPhase.playing ||
            _audioPlayer.playing) &&
        !_userHoldPaused;
  }

  /// 与 TRTC 对齐：playAndRecord + voiceChat。
  static AudioSessionConfiguration _sharedVoiceSessionConfig() {
    return VoiceOutputRouteService.voiceChatConfigFor(
      VoiceOutputRouteService.currentRoute,
    );
  }

  static AudioSessionConfiguration _playbackSessionConfig() {
    return VoiceOutputRouteService.playbackConfigFor(
      VoiceOutputRouteService.currentRoute,
    );
  }

  static AudioSessionConfiguration _recordSessionConfig() {
    if (!kIsWeb && Platform.isIOS) {
      final route = VoiceOutputRouteService.currentRoute;
      return AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: route == VoiceOutputRoute.speaker
            ? AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth
            : AVAudioSessionCategoryOptions.allowBluetooth,
        // iOS 语音消息录制不要使用 voiceChat，避免系统语音处理压低录音增益。
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      );
    }
    return _sharedVoiceSessionConfig();
  }

  static Future<void> _ensureInterruptionListener() async {
    if (_interruptionSubscription != null) {
      return;
    }
    final session = await AudioSession.instance;
    _interruptionSubscription = session.interruptionEventStream.listen((event) {
      if (!event.begin) {
        return;
      }
      if (_applyingRouteChange) {
        return;
      }
      if (event.type == AudioInterruptionType.pause ||
          event.type == AudioInterruptionType.duck) {
        unawaited(pause());
      }
    });
  }

  static Listenable get outputRouteListenable =>
      VoiceOutputRouteService.routeNotifier;

  static Future<void> _applyOutputRoute({
    bool forRecording = false,
    bool configureSession = false,
  }) async {
    await VoiceOutputRouteService.applyCurrentRoute(
      configureSession: configureSession,
      forRecording: forRecording,
      activate: false,
    );
    _speakerOn = VoiceOutputRouteService.isSpeaker;
  }

  /// 仅在首次播放或录音结束后配置 session；播放/暂停切换时不触碰 session。
  /// [force] 为 true 时强制重配：避免提示音等把 session 改成 notification 后，
  /// 静音模式下语音仍走旧 session 导致无声。
  static Future<void> ensurePlaybackReady({bool force = false}) async {
    await _ensureInterruptionListener();

    if (_usingRecordSession) {
      _usingRecordSession = false;
      _playbackSessionConfigured = false;
    }

    if (_playbackSessionConfigured && !force) {
      return;
    }

    final session = await AudioSession.instance;
    try {
      await session.configure(_playbackSessionConfig());
      _playbackSessionConfigured = true;
      await _applyOutputRoute();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: configure playback session failed ($e)');
      }
      // 配置失败不要锁死，下次播放继续重试。
      _playbackSessionConfigured = false;
      return;
    }

    if (_audioPlayer.playing) {
      return;
    }
    try {
      await session.setActive(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: activate playback session failed ($e)');
      }
    }
  }

  /// 其它模块改写了 AudioSession 后调用，确保下次语音播放重新配置。
  static void invalidatePlaybackSession() {
    _playbackSessionConfigured = false;
  }

  static Future<void> _ensureRecordSession() async {
    final session = await AudioSession.instance;
    try {
      await session.configure(_recordSessionConfig());
      _usingRecordSession = true;
      _playbackSessionConfigured = false;
      await _applyOutputRoute(forRecording: true);
      await session.setActive(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: configure record session failed ($e)');
      }
    }
  }

  /// 进入语音模式后提前配置录音会话，避免按住说话时主线程卡顿。
  static Future<void> prepareRecordSession() async {
    if (kIsWeb) {
      return;
    }
    try {
      await initSoundPlayer();
      if (!isInit) {
        return;
      }
      await _ensureRecordSession();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: prepare record session failed ($e)');
      }
    }
  }

  static Future<bool> hasMicrophonePermission() async {
    if (kIsWeb) {
      return false;
    }
    final status = await Permission.microphone.status;
    return status.isGranted || status.isLimited;
  }

  static Future<void> initSoundPlayer() async {
    if (!isInit) {
      try {
        _recorder.init();
        isInit = true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SoundPlayer: recorder init failed ($e)');
        }
        isInit = false;
      }
    }
  }

  static AudioSource _audioSourceForUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return AudioSource.uri(Uri.parse(url));
    }
    return AudioSource.file(url);
  }

  static bool _isRemoteUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  static bool _hasReadySource() {
    return _currentUrl != null &&
        _audioPlayer.processingState != ProcessingState.idle;
  }

  static bool _shouldPauseForTap(String messageId, {String? altMessageId}) {
    if (!matchesMessage(messageId, altMessageId: altMessageId)) {
      return false;
    }
    return _playbackPhase == VoicePlaybackPhase.playing ||
        _playbackPhase == VoicePlaybackPhase.loading ||
        _audioPlayer.playing;
  }

  static bool _shouldResumeForTap(String messageId, {String? altMessageId}) {
    return matchesMessage(messageId, altMessageId: altMessageId) &&
        (_playbackPhase == VoicePlaybackPhase.paused ||
            (_userHoldPaused && _hasReadySource()));
  }

  static Future<void> handleBubbleTap({
    required String messageId,
    String? altMessageId,
    required Future<String?> Function() resolveUrl,
  }) async {
    final sameAtTap = matchesMessage(messageId, altMessageId: altMessageId);

    // 同一条语音：播放中/加载中点击，立即暂停，不排队等待下载或 setSource。
    if (sameAtTap &&
        _shouldPauseForTap(messageId, altMessageId: altMessageId)) {
      _cancelGeneration++;
      await _pauseInternal(incrementCancel: false);
      return;
    }

    // 同一条语音：暂停后点击，优先从当前位置续播；如果当时还没拿到地址，再重新取地址播放。
    if (sameAtTap &&
        _shouldResumeForTap(messageId, altMessageId: altMessageId)) {
      final generation = ++_cancelGeneration;
      _userHoldPaused = false;
      _bindActiveMessage(messageId, altMessageId: altMessageId);
      if (_hasReadySource()) {
        await _runExclusive(
            () => _resumeInternal(requestGeneration: generation));
        return;
      }
      _setPhase(VoicePlaybackPhase.loading);
      final url = _pendingPlayUrl ?? await resolveUrl();
      if (_aborted(generation)) {
        return;
      }
      if (url == null || url.isEmpty) {
        await _stopInternal(resetCancel: false);
        return;
      }
      await _runExclusive(() => _playInternal(
            url: url,
            messageId: messageId,
            altMessageId: altMessageId,
            requestGeneration: generation,
          ));
      return;
    }

    // 切换到另一条语音：先让旧请求失效并停掉当前声音，再异步取新地址。
    // 地址解析不进入队列，避免 A 正在下载时点击 B，要等 A 超时才有反应。
    final generation = ++_cancelGeneration;
    _userHoldPaused = false;
    _bindActiveMessage(messageId, altMessageId: altMessageId);
    _setPhase(VoicePlaybackPhase.loading);
    await _stopPlaybackOnly();

    final url = await resolveUrl();
    if (_aborted(generation) ||
        !matchesMessage(messageId, altMessageId: altMessageId)) {
      return;
    }
    if (url == null || url.isEmpty) {
      await _stopInternal(resetCancel: false);
      return;
    }

    await _runExclusive(() => _playInternal(
          url: url,
          messageId: messageId,
          altMessageId: altMessageId,
          requestGeneration: generation,
        ));
  }

  static void _storePendingPlay(
    String? url,
    String messageId,
    String? altMessageId,
  ) {
    _pendingPlayUrl = url;
  }

  static Future<void> _resumeOrRestart({
    required String messageId,
    String? altMessageId,
    required Future<String?> Function() resolveUrl,
  }) async {
    _userHoldPaused = false;
    if (_hasReadySource() &&
        matchesMessage(messageId, altMessageId: altMessageId)) {
      await _resumeInternal();
      return;
    }
    final url = _pendingPlayUrl ??
        (matchesMessage(messageId, altMessageId: altMessageId)
            ? await resolveUrl()
            : null);
    if (url == null || url.isEmpty) {
      await _stopInternal(resetCancel: false);
      return;
    }
    await _playInternal(
      url: url,
      messageId: messageId,
      altMessageId: altMessageId,
    );
  }

  static Future<void> play({
    required String url,
    required String messageId,
    String? altMessageId,
  }) {
    return _runExclusive(() async {
      await _playInternal(
        url: url,
        messageId: messageId,
        altMessageId: altMessageId,
      );
    });
  }

  static Future<void> restart({
    required String url,
    required String messageId,
    String? altMessageId,
  }) {
    return _runExclusive(() async {
      _cancelGeneration++;
      _userHoldPaused = false;
      await _playInternal(
        url: url,
        messageId: messageId,
        altMessageId: altMessageId,
      );
    });
  }

  static Future<void> _activateSessionIfNeeded() async {
    if (_audioPlayer.playing) {
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: setActive failed ($e)');
      }
    }
  }

  static Future<void> _playInternal({
    required String url,
    required String messageId,
    String? altMessageId,
    int? requestGeneration,
  }) async {
    final generation = requestGeneration ?? _cancelGeneration;
    await ensurePlaybackReady(force: true);
    if (_aborted(generation)) {
      return;
    }
    if (_userHoldPaused &&
        matchesMessage(messageId, altMessageId: altMessageId)) {
      _storePendingPlay(url, messageId, altMessageId);
      return;
    }

    if (_soundInterruptListener != null) {
      _soundInterruptListener!();
    }

    if (_activeMessageKeys.isNotEmpty &&
        !matchesMessage(messageId, altMessageId: altMessageId)) {
      await _stopInternal(resetCancel: false);
    }
    if (_aborted(generation)) {
      return;
    }

    _userHoldPaused = false;
    _bindActiveMessage(messageId, altMessageId: altMessageId);
    _pendingPlayUrl = url;
    _setPhase(VoicePlaybackPhase.loading);

    final isRemote = _isRemoteUrl(url);
    try {
      if (_currentUrl != url) {
        await _audioPlayer.setAudioSource(
          isRemote
              // ignore: experimental_member_use
              ? LockCachingAudioSource(Uri.parse(url))
              : _audioSourceForUrl(url),
          preload: !isRemote,
        );
        _currentUrl = url;
      } else {
        await _audioPlayer.seek(Duration.zero);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: set audio source failed ($e)');
      }
      await _stopInternal(resetCancel: false);
      return;
    }

    if (_aborted(generation) || _userHoldPaused) {
      if (_userHoldPaused) {
        _setPhase(VoicePlaybackPhase.paused);
      }
      return;
    }

    try {
      await _activateSessionIfNeeded();
      // setAudioSource / AudioSession 激活可能覆盖当前输出端口。
      // 必须按当前用户选择重配 session（听筒 playAndRecord / 扬声器 playback），
      // 否则连播下一条会回到听筒默认口。
      await _applyOutputRoute(configureSession: true);
      if (_aborted(generation) || _userHoldPaused) {
        return;
      }
      unawaited(_audioPlayer.play().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('SoundPlayer: play failed ($e)');
        }
      }));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: play failed ($e)');
      }
      await _stopInternal(resetCancel: false);
      return;
    }

    if (_aborted(generation) || _userHoldPaused) {
      if (_userHoldPaused) {
        await _audioPlayer.pause();
        _setPhase(VoicePlaybackPhase.paused);
      }
      return;
    }
    _setPhase(VoicePlaybackPhase.playing);
  }

  static Future<void> pause() {
    return _pauseInternal();
  }

  static Future<void> _pauseInternal({bool incrementCancel = true}) async {
    final shouldPause = _playbackPhase == VoicePlaybackPhase.playing ||
        _playbackPhase == VoicePlaybackPhase.loading ||
        _audioPlayer.playing;
    if (!shouldPause) {
      return;
    }
    if (_activeMessageKeys.isEmpty && _audioPlayer.playing) {
      _playbackPhase = VoicePlaybackPhase.playing;
    }
    if (incrementCancel) {
      _cancelGeneration++;
    }
    _userHoldPaused = true;
    _setPhase(VoicePlaybackPhase.paused);
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else if (_hasReadySource()) {
        await _audioPlayer.pause();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: pause failed ($e)');
      }
    }
    _setPhase(VoicePlaybackPhase.paused);
  }

  static Future<void> resume() {
    return _runExclusive(() => _resumeInternal());
  }

  static Future<void> _resumeInternal({int? requestGeneration}) async {
    if (_activeMessageKeys.isEmpty ||
        _playbackPhase != VoicePlaybackPhase.paused) {
      return;
    }
    if (!_hasReadySource()) {
      return;
    }
    final generation = requestGeneration ?? _cancelGeneration;
    _userHoldPaused = false;
    await ensurePlaybackReady(force: true);
    if (_aborted(generation)) {
      return;
    }
    try {
      final currentPosition = _audioPlayer.position;
      if (currentPosition > const Duration(seconds: 1)) {
        await _audioPlayer.seek(currentPosition - const Duration(seconds: 1));
      }
      await _activateSessionIfNeeded();
      await _applyOutputRoute();
      if (_aborted(generation) || _userHoldPaused) {
        return;
      }
      unawaited(_audioPlayer.play().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('SoundPlayer: resume failed ($e)');
        }
      }));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: resume failed ($e)');
      }
      await _stopInternal(resetCancel: false);
      return;
    }
    if (_aborted(generation) || _userHoldPaused) {
      return;
    }
    _setPhase(VoicePlaybackPhase.playing);
  }

  static Future<void> stop() {
    return _stopInternal(resetCancel: true);
  }

  static Future<void> _stopPlaybackOnly() async {
    _currentUrl = null;
    try {
      if (_audioPlayer.playing ||
          _audioPlayer.processingState != ProcessingState.idle) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: stop current playback failed ($e)');
      }
    }
  }

  static Future<void> _stopInternal({required bool resetCancel}) async {
    if (resetCancel) {
      _cancelGeneration++;
    }
    _userHoldPaused = false;
    _clearActiveMessage();
    _currentUrl = null;
    _setPhase(VoicePlaybackPhase.idle);
    try {
      await _audioPlayer.stop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: stop failed ($e)');
      }
    }
  }

  static void _setPhase(VoicePlaybackPhase phase) {
    if (_playbackPhase == phase) {
      return;
    }
    _playbackPhase = phase;
    _notifyPlayerState();
  }

  static void _onPlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      // 切到下一条时旧源仍可能再报 completed；加载中忽略，避免跳过当前条。
      if (_playbackPhase == VoicePlaybackPhase.loading ||
          _playbackPhase == VoicePlaybackPhase.completed ||
          _playbackPhase == VoicePlaybackPhase.idle) {
        return;
      }
      _userHoldPaused = false;
      _lastCompletedMessageKeys = Set<String>.from(_activeMessageKeys);
      _clearActiveMessage();
      _currentUrl = null;
      _playbackPhase = VoicePlaybackPhase.completed;
      _notifyPlayerState();
      return;
    }
    if (_userHoldPaused) {
      if (_playbackPhase != VoicePlaybackPhase.paused) {
        _playbackPhase = VoicePlaybackPhase.paused;
        _notifyPlayerState();
      }
      return;
    }
    if (_activeMessageKeys.isEmpty) {
      return;
    }
    if (state.playing) {
      _reassertRouteAfterPlaybackStarted();
      _setPhase(VoicePlaybackPhase.playing);
    } else if (state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering) {
      _setPhase(VoicePlaybackPhase.loading);
    } else if (_playbackPhase == VoicePlaybackPhase.playing &&
        !state.playing &&
        state.processingState == ProcessingState.ready) {
      _setPhase(VoicePlaybackPhase.paused);
    }
  }

  /// AVPlayer/ExoPlayer 在真正进入 playing 时可能再次接管系统输出端口。
  /// 立即校准一次，并在启动稳定后复核一次；两次都读取当前用户选择，
  /// 因此不会把播放期间刚切换的路由改回旧值。
  static void _reassertRouteAfterPlaybackStarted() {
    final generation = ++_routeReassertGeneration;
    unawaited(_applyOutputRoute());
    Future<void>.delayed(const Duration(milliseconds: 160), () async {
      if (generation != _routeReassertGeneration || !_audioPlayer.playing) {
        return;
      }
      await _applyOutputRoute();
    });
  }

  static void addPlayerStateCallback(VoidCallback callback) {
    _playerStateCallbacks.add(callback);
    _playerStateSubscription ??=
        _audioPlayer.playerStateStream.listen(_onPlayerStateChanged);
  }

  static void removePlayerStateCallback(VoidCallback callback) {
    _playerStateCallbacks.remove(callback);
    if (_playerStateCallbacks.isEmpty) {
      _playerStateSubscription?.cancel();
      _playerStateSubscription = null;
    }
  }

  static void _notifyPlayerState() {
    for (final callback in Set<VoidCallback>.from(_playerStateCallbacks)) {
      callback();
    }
  }

  static Future<bool> setSpeakerOn(bool enabled) {
    return _runExclusive(() => _setSpeakerOnInternal(enabled));
  }

  static Future<bool> _setSpeakerOnInternal(bool enabled) async {
    final targetRoute =
        enabled ? VoiceOutputRoute.speaker : VoiceOutputRoute.earpiece;
    if (speakerOn == enabled &&
        !_playbackSessionConfigured &&
        !_usingRecordSession) {
      return true;
    }

    final livePlayback = _playbackPhase == VoicePlaybackPhase.playing ||
        _playbackPhase == VoicePlaybackPhase.loading ||
        _audioPlayer.playing;
    final resumeAfter = livePlayback && !_userHoldPaused;
    final position = _audioPlayer.position;

    _applyingRouteChange = true;
    final applyGen = ++_routeChangeGeneration;
    _routeReassertGeneration++;
    try {
      if (livePlayback) {
        try {
          if (_audioPlayer.playing) {
            await _audioPlayer.pause();
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('SoundPlayer: pause for route switch failed ($e)');
          }
        }
      }

      final success = await VoiceOutputRouteService.setRoute(
        targetRoute,
        configureSession: true,
        forRecording: _usingRecordSession,
        activate: true,
        forceApply: true,
      );
      if (!success) {
        return false;
      }

      _speakerOn = enabled;
      _playbackSessionConfigured = !_usingRecordSession;

      if (resumeAfter && _activeMessageKeys.isNotEmpty) {
        try {
          if (position > Duration.zero) {
            await _audioPlayer.seek(position);
          }
          await _applyOutputRoute(
            configureSession: true,
            forRecording: _usingRecordSession,
          );
          _setPhase(VoicePlaybackPhase.playing);
          unawaited(_audioPlayer.play().catchError((Object e) {
            if (kDebugMode) {
              debugPrint('SoundPlayer: resume after route switch failed ($e)');
            }
          }));
          _reassertRouteAfterPlaybackStarted();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('SoundPlayer: resume after route switch failed ($e)');
          }
        }
      }
      _notifyPlayerState();
      return true;
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (applyGen == _routeChangeGeneration) {
          _applyingRouteChange = false;
        }
      });
    }
  }

  static Future<bool> toggleSpeaker() async {
    return setSpeakerOn(!speakerOn);
  }

  static void dispose() {
    _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    _audioPlayer.dispose();
    _recorder.dispose();
  }

  static StreamSubscription<PlayerState> playStateListener(
          {required void Function(PlayerState)? listener}) =>
      _audioPlayer.playerStateStream.listen(listener);

  static setSoundInterruptListener(SoundInterruptListener listener) {
    _soundInterruptListener = listener;
  }

  static removeSoundInterruptListener() {
    _soundInterruptListener = null;
  }

  static StreamSubscription<RecordResponse> responseListener(
          ResponseListener listener) =>
      _recorder.response.listen(listener);

  static StreamSubscription<RecordResponse> responseFromAmplitudeListener(
          ResponseListener listener) =>
      _recorder.responseFromAmplitude.listen(listener);

  static Future<bool> startRecord() async {
    try {
      if (!await hasMicrophonePermission()) {
        if (kDebugMode) {
          debugPrint('SoundPlayer: skip startRecord — microphone not granted');
        }
        return false;
      }
      await initSoundPlayer();
      if (!isInit) {
        return false;
      }
      if (_activeMessageKeys.isNotEmpty || _audioPlayer.playing) {
        await _stopInternal(resetCancel: true);
      }
      if (!_usingRecordSession) {
        await _ensureRecordSession();
      }
      _recorder.start();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: start record failed ($e)');
      }
      return false;
    }
  }

  static Future<void> stopRecord() async {
    try {
      _recorder.stop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: stop record failed ($e)');
      }
    }
    unawaited(prepareForPlaybackAfterRecord());
  }

  static Future<String?> copyRecordingToUniquePath(String sourcePath) async {
    if (kIsWeb || sourcePath.isEmpty) {
      return sourcePath;
    }
    try {
      final source = File(sourcePath);
      if (!source.existsSync()) {
        return sourcePath;
      }
      final dir = await getTemporaryDirectory();
      final voiceDir = Directory('${dir.path}/voice_outgoing');
      if (!voiceDir.existsSync()) {
        await voiceDir.create(recursive: true);
      }
      final destPath =
          '${voiceDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await source.copy(destPath);
      return destPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: copy recording failed ($e)');
      }
      return sourcePath;
    }
  }

  static Future<void> prepareForPlaybackAfterRecord() async {
    if (kIsWeb) {
      return;
    }
    try {
      await ensurePlaybackReady(force: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundPlayer: prepare playback after record failed ($e)');
      }
    }
  }
}
