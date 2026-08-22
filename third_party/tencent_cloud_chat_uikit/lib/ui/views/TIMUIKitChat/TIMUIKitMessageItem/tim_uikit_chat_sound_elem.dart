import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_jump_highlight.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/voice_auto_play_order.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/voice_waveform_extractor.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/models/link_preview_content.dart';
import 'TIMUIKitMessageReaction/tim_uikit_message_reaction_show_panel.dart';

abstract final class _ChatUiTokens {
  static const Color surfaceAltLight = Color(0xFFF1F3F5);
  static const double s2 = 4;
  static const double rMd = 12;
}

class TIMUIKitSoundElem extends StatefulWidget {
  final V2TimMessage message;
  final V2TimSoundElem soundElem;
  final String msgID;
  final bool isFromSelf;
  final int? localCustomInt;
  final bool isShowJump;
  final VoidCallback? clearJump;
  final TextStyle? fontStyle;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? textPadding;
  final bool? isShowMessageReaction;
  final TUIChatSeparateViewModel chatModel;

  const TIMUIKitSoundElem({
    Key? key,
    required this.soundElem,
    required this.msgID,
    required this.isFromSelf,
    this.isShowJump = false,
    this.clearJump,
    this.localCustomInt,
    this.fontStyle,
    this.borderRadius,
    this.backgroundColor,
    this.textPadding,
    required this.message,
    this.isShowMessageReaction,
    required this.chatModel,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitSoundElemState();
}

class _TIMUIKitSoundElemState extends TIMUIKitState<TIMUIKitSoundElem> {
  static const Color _voicePlayButtonColor = Color(0xFF4A5866);
  static const double _voiceWaveformWidth = 48;
  static const int _voiceWaveformBarCount = 11;
  static const List<double> _voiceDesignFallbackBars = [
    0.32,
    0.48,
    0.62,
    0.78,
    0.92,
    1.0,
    0.92,
    0.78,
    0.62,
    0.48,
    0.32,
  ];

  bool isShowJumpState = false;
  Timer? _jumpHighlightTimer;
  bool isShining = false;
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  final MessageService _messageService = serviceLocator<MessageService>();
  late V2TimSoundElem stateElement = widget.message.soundElem!;
  bool? _lastIsCurrent;
  bool? _lastIconAnimating;
  bool? _lastIsPaused;
  bool? _lastIsPlaybackLoading;
  bool? _lastDrivesPlaybackUi;
  int? _lastUploadProgress;
  bool _iconRefreshScheduled = false;
  bool _optimisticLoading = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackPeakPosition = Duration.zero;
  Duration? _loadedAudioDuration;
  int? _probedFileDurationMs;
  int? _calibratedTotalMs;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  List<double>? _waveformBars;
  String? _waveformSourceKey;
  int _waveformLoadGeneration = 0;

  String get _playbackMessageId {
    if (widget.msgID.isNotEmpty) {
      return widget.msgID;
    }
    return widget.message.id ?? '';
  }

  String? get _clientMessageId {
    final id = widget.message.id;
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  bool _matchesEngine() {
    return SoundPlayer.matchesMessage(
      _playbackMessageId,
      altMessageId: _clientMessageId,
    );
  }

  String? _resolveLocalPathIfExists() {
    if (PlatformUtils().isWeb) {
      return null;
    }
    final playbackId = _playbackMessageId;
    final candidates = <String?>[
      if (playbackId.isNotEmpty) globalModel.getFileMessageLocation(playbackId),
      globalModel.getFileMessageLocation(widget.message.id),
      stateElement.path,
      stateElement.localUrl,
      widget.message.soundElem?.path,
      widget.message.soundElem?.localUrl,
    ];
    for (final raw in candidates) {
      final path = TencentUtils.checkString(raw);
      if (path != null && File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  String? _resolveRemoteUrl() {
    final remote =
        stateElement.url?.trim() ?? widget.message.soundElem?.url?.trim();
    if (remote != null && remote.isNotEmpty) {
      return remote;
    }
    return null;
  }

  Future<String?> _resolvePlaybackUrlForTap() async {
    final local = _resolveLocalPathIfExists();
    if (local != null) {
      return local;
    }
    final remote = _resolveRemoteUrl();
    if (remote != null && remote.isNotEmpty) {
      if (!PlatformUtils().isWeb) {
        final cached = await _downloadRemoteSoundToCache(remote);
        if (cached != null) {
          return cached;
        }
      }
      return remote;
    }
    if (!PlatformUtils().isWeb) {
      try {
        final waitBudget = widget.isFromSelf &&
                widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING
            ? const Duration(seconds: 2)
            : const Duration(milliseconds: 400);
        final downloaded = await _ensureLocalPath().timeout(
          waitBudget,
          onTimeout: () => _resolveLocalPathIfExists(),
        );
        if (downloaded != null) {
          return downloaded;
        }
      } catch (_) {
        final cached = _resolveLocalPathIfExists();
        if (cached != null) {
          return cached;
        }
      }
    }
    return remote;
  }

  Future<String?>? _ensureLocalPathFuture;
  Future<String?>? _remoteDownloadFuture;

  String _guessSoundExtension(String url, String? contentType) {
    final lower = url.toLowerCase();
    if (lower.contains('.amr')) return '.amr';
    if (lower.contains('.aac')) return '.aac';
    if (lower.contains('.m4a')) return '.m4a';
    if (lower.contains('.mp3')) return '.mp3';
    if (lower.contains('.wav')) return '.wav';
    if (contentType != null) {
      final ct = contentType.toLowerCase();
      if (ct.contains('amr')) return '.amr';
      if (ct.contains('mpeg')) return '.mp3';
      if (ct.contains('mp4') || ct.contains('m4a')) return '.m4a';
    }
    return '.amr';
  }

  Future<String?> _downloadRemoteSoundToCache(String remoteUrl) {
    return _remoteDownloadFuture ??=
        _downloadRemoteSoundToCacheImpl(remoteUrl).whenComplete(() {
      _remoteDownloadFuture = null;
    });
  }

  Future<String?> _downloadRemoteSoundToCacheImpl(String remoteUrl) async {
    final existing = _resolveLocalPathIfExists();
    if (existing != null) {
      return existing;
    }
    try {
      final response = await http.get(Uri.parse(remoteUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[ArchiveSound] download failed HTTP ${response.statusCode} url=$remoteUrl',
        );
        return null;
      }
      final dir = await getTemporaryDirectory();
      final uuid = TencentUtils.checkString(stateElement.UUID) ??
          TencentUtils.checkString(widget.message.soundElem?.UUID);
      final ext = _guessSoundExtension(
        remoteUrl,
        response.headers['content-type'],
      );
      final msgId = _playbackMessageId.isNotEmpty
          ? _playbackMessageId
          : (widget.message.id ?? 'voice');
      final fileName = uuid != null && uuid.isNotEmpty
          ? 'sound_$uuid$ext'
          : '${msgId}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final savePath = '${dir.path}/$fileName';
      await File(savePath).writeAsBytes(response.bodyBytes);
      globalModel.setFileMessageLocation(msgId, savePath);
      final clientId = _clientMessageId;
      if (clientId != null && clientId.isNotEmpty) {
        globalModel.setFileMessageLocation(clientId, savePath);
      }
      debugPrint('[ArchiveSound] cached local path=$savePath');
      return savePath;
    } catch (e) {
      debugPrint('[ArchiveSound] download error $e url=$remoteUrl');
      return null;
    }
  }

  Future<String?> _ensureLocalPath() {
    return _ensureLocalPathFuture ??= _ensureLocalPathImpl().whenComplete(() {
      _ensureLocalPathFuture = null;
    });
  }

  Future<String?> _ensureLocalPathImpl() async {
    final existing = _resolveLocalPathIfExists();
    if (existing != null) {
      return existing;
    }
    final remote = _resolveRemoteUrl();
    if (remote != null && remote.isNotEmpty) {
      return _downloadRemoteSoundToCache(remote);
    }
    final msgID = widget.msgID;
    if (msgID.isEmpty) {
      return null;
    }

    unawaited(_messageService.downloadMessage(
      msgID: msgID,
      messageType: 4,
      imageType: 0,
      isSnapshot: false,
      reportError: false,
    ));

    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      final path = _resolveLocalPathIfExists();
      if (path != null) {
        return path;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await _refreshSoundElemFromSdk();
    return _resolveLocalPathIfExists();
  }

  Future<void> _refreshSoundElemFromSdk() async {
    if (widget.msgID.isEmpty) {
      return;
    }
    final messages =
        await _messageService.findMessages(messageIDList: [widget.msgID]);
    final sound = messages?.firstOrNull?.soundElem;
    if (sound != null && mounted) {
      widget.message.soundElem = sound;
      _safeSetState(() => stateElement = sound, force: true);
    }
  }

  int _lastHandledRowRevision = -1;

  void _onRowRevisionUpdate(int rowRevision) {
    if (rowRevision == _lastHandledRowRevision) {
      return;
    }
    _lastHandledRowRevision = rowRevision;
    if (!mounted) {
      return;
    }
    final shouldRefresh = _resolveLocalPathIfExists() != null ||
        _uploadProgress != _lastUploadProgress;
    if (shouldRefresh) {
      unawaited(_loadWaveformBarsIfNeeded(force: true));
      _safeSetState(() {}, force: true);
    }
  }

  String get _waveformCacheKey {
    final playbackId = _playbackMessageId;
    if (playbackId.isNotEmpty) {
      return playbackId;
    }
    return widget.message.id ?? 'voice';
  }

  List<double> _fallbackWaveformBars(int durationSec) {
    final generated = VoiceWaveformExtractor.generateFallback(
      _waveformCacheKey,
      durationSec: max(1, durationSec),
    );
    return _normalizeWaveformBars(generated);
  }

  List<double> _waveformBarsForMessage(int durationSec) {
    return _normalizeWaveformBars(
      _waveformBars ?? _fallbackWaveformBars(durationSec),
    );
  }

  List<double> _normalizeWaveformBars(List<double> bars) {
    if (bars.isEmpty) {
      return List<double>.from(_voiceDesignFallbackBars);
    }
    if (bars.length == _voiceWaveformBarCount) {
      return bars;
    }
    final result = <double>[];
    for (var i = 0; i < _voiceWaveformBarCount; i++) {
      final index = (i / (_voiceWaveformBarCount - 1)) * (bars.length - 1);
      final lower = index.floor();
      final upper = index.ceil();
      final weight = index - lower;
      final lowerValue = bars[lower.clamp(0, bars.length - 1)];
      final upperValue = bars[upper.clamp(0, bars.length - 1)];
      result.add(lowerValue + (upperValue - lowerValue) * weight);
    }
    return result;
  }

  Color _resolvePlayIconColor({
    required Color bubbleColor,
    required TUITheme theme,
  }) {
    if (widget.isFromSelf) {
      return bubbleColor;
    }
    return theme.primaryColor ?? const Color(0xFF1E90FF);
  }

  Future<void> _loadWaveformBarsIfNeeded({bool force = false}) async {
    final cacheKey = _waveformCacheKey;
    final localPath = _resolveLocalPathIfExists();
    final sourceKey =
        '$cacheKey|${localPath ?? ''}|${stateElement.duration ?? 0}';
    if (!force &&
        _waveformSourceKey == sourceKey &&
        _waveformBars != null &&
        _waveformBars!.isNotEmpty) {
      return;
    }

    final generation = ++_waveformLoadGeneration;
    final durationSec = max(1, stateElement.duration ?? 1);
    final waveformData = await VoiceWaveformExtractor.load(
      cacheKey: cacheKey,
      localPath: localPath,
      fallbackSeed: cacheKey,
      durationSec: durationSec,
    );
    if (!mounted || generation != _waveformLoadGeneration) {
      return;
    }
    _waveformSourceKey = sourceKey;
    _waveformBars = waveformData.bars;
    if (waveformData.durationMs != null && waveformData.durationMs! > 0) {
      _probedFileDurationMs = waveformData.durationMs;
    }
    _safeSetState(() {}, force: true);
  }

  void _resetPlaybackMetrics() {
    _playbackPosition = Duration.zero;
    _playbackPeakPosition = Duration.zero;
    _calibratedTotalMs = null;
    _loadedAudioDuration = null;
  }

  int _playerDurationMs() {
    final playerMs = SoundPlayer.duration?.inMilliseconds ?? 0;
    if (playerMs > 0) {
      return playerMs;
    }
    final loadedMs = _loadedAudioDuration?.inMilliseconds ?? 0;
    return loadedMs > 0 ? loadedMs : 0;
  }

  int _totalDurationMs(int messageDurationSec) {
    final messageMs = max(1, messageDurationSec) * 1000;
    final playerMs = _playerDurationMs();
    final fileMs = _probedFileDurationMs ?? 0;
    final peakMs = _playbackPeakPosition.inMilliseconds;
    final calibratedMs = _calibratedTotalMs ?? 0;

    if (calibratedMs > 0) {
      return calibratedMs;
    }

    if (_isCurrent) {
      if (fileMs > 0) {
        return fileMs;
      }
      if (playerMs > 0) {
        return playerMs;
      }
      if (peakMs > 0) {
        return max(max(peakMs, _playbackPosition.inMilliseconds), 1);
      }
    }

    if (fileMs > 0) {
      return fileMs;
    }
    return messageMs;
  }

  void _calibrateTotalFromPlayback({bool completed = false}) {
    final peakMs = max(
      _playbackPeakPosition.inMilliseconds,
      _playbackPosition.inMilliseconds,
    );
    if (peakMs <= 0) {
      return;
    }

    final playerMs = _playerDurationMs();
    final fileMs = _probedFileDurationMs ?? 0;
    var resolved = peakMs;

    if (completed) {
      if (peakMs > 0 && (playerMs <= 0 || peakMs + 180 < playerMs)) {
        resolved = peakMs;
      } else if (playerMs > 0) {
        resolved = playerMs;
      } else if (fileMs > 0) {
        resolved = fileMs;
      }
    } else if (playerMs > 0 && playerMs <= peakMs + 180) {
      resolved = playerMs;
    } else if (fileMs > 0 && fileMs <= peakMs + 180) {
      resolved = fileMs;
    }

    _calibratedTotalMs = max(resolved, 1);
  }

  Future<void> _markVoiceReadIfNeeded() async {
    if (widget.isFromSelf) {
      return;
    }
    final alreadyRead =
        widget.message.localCustomInt == HistoryMessageDartConstant.read ||
            widget.localCustomInt == HistoryMessageDartConstant.read;
    if (alreadyRead) {
      return;
    }

    // 先改当前消息对象，列表侧红点立刻消失；再持久化到 SDK / 全局列表。
    widget.message.localCustomInt = HistoryMessageDartConstant.read;
    if (mounted) {
      _safeSetState(() {}, force: true);
    }

    final msgId = widget.msgID.trim().isNotEmpty
        ? widget.msgID.trim()
        : _playbackMessageId.trim();
    if (msgId.isEmpty) {
      return;
    }
    await globalModel.setLocalCustomInt(
      msgId,
      HistoryMessageDartConstant.read,
      widget.chatModel.conversationID,
    );
  }

  int get _uploadProgress {
    final byMsgId = widget.msgID.isNotEmpty
        ? globalModel.getMessageProgress(widget.msgID)
        : 0;
    final byId = widget.message.id != null && widget.message.id!.isNotEmpty
        ? globalModel.getMessageProgress(widget.message.id)
        : 0;
    return max(byMsgId, byId);
  }

  bool get _isSendingUpload =>
      widget.isFromSelf &&
      (widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING ||
          (_uploadProgress > 0 && _uploadProgress < 100));

  bool get _isPlaybackLoading =>
      _optimisticLoading ||
      SoundPlayer.isLoadingMessage(
        _playbackMessageId,
        altMessageId: _clientMessageId,
      );

  bool get _isCurrent =>
      _matchesEngine() ||
      widget.chatModel.currentPlayedMsgId == _playbackMessageId ||
      widget.chatModel.currentPlayedMsgId == (_clientMessageId ?? '');

  bool get _iconAnimating => SoundPlayer.messageShouldAnimate(
        _playbackMessageId,
        altMessageId: _clientMessageId,
      );

  bool get _isPaused => SoundPlayer.isPausedMessage(
        _playbackMessageId,
        altMessageId: _clientMessageId,
      );

  bool get _playerActive {
    final phase = SoundPlayer.currentPhase;
    return phase == VoicePlaybackPhase.playing ||
        phase == VoicePlaybackPhase.loading ||
        phase == VoicePlaybackPhase.paused ||
        SoundPlayer.isPlaying;
  }

  bool get _drivesPlaybackUi => shouldDriveVoicePlaybackUi(
        isCurrent: _isCurrent,
        engineMatches: _matchesEngine(),
        isAnimating: _iconAnimating,
        isPaused: _isPaused,
        playerActive: _playerActive,
      );

  void _syncPositionFromPlayer() {
    final position = SoundPlayer.position ?? Duration.zero;
    _playbackPosition = position;
    _playbackPeakPosition = Duration(
      milliseconds: max(
        _playbackPeakPosition.inMilliseconds,
        position.inMilliseconds,
      ),
    );
    final duration = SoundPlayer.duration;
    if (duration != null && duration.inMilliseconds > 0) {
      _loadedAudioDuration = duration;
    }
  }

  bool _voiceVisualStateChanged() {
    final current = _isCurrent;
    final animating = _iconAnimating;
    final paused = _isPaused;
    final loading = _isPlaybackLoading;
    final driving = _drivesPlaybackUi;
    final uploadProgress = _uploadProgress;
    final changed = _lastIsCurrent != current ||
        _lastIconAnimating != animating ||
        _lastIsPaused != paused ||
        _lastIsPlaybackLoading != loading ||
        _lastDrivesPlaybackUi != driving ||
        _lastUploadProgress != uploadProgress;
    _lastIsCurrent = current;
    _lastIconAnimating = animating;
    _lastIsPaused = paused;
    _lastIsPlaybackLoading = loading;
    _lastDrivesPlaybackUi = driving;
    _lastUploadProgress = uploadProgress;
    return changed;
  }

  void _safeSetState(VoidCallback fn, {bool force = false}) {
    if (!mounted) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      if (mounted) {
        setState(fn);
      }
      return;
    }
    if (!force && _iconRefreshScheduled) {
      return;
    }
    _iconRefreshScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _iconRefreshScheduled = false;
      if (mounted) {
        setState(fn);
      }
    });
  }

  void _refreshIconState({bool force = false}) {
    if (!mounted) {
      return;
    }
    if (!force && !_voiceVisualStateChanged()) {
      return;
    }
    _safeSetState(() {}, force: force);
  }

  /// 点击：播放中/加载中 → 暂停；暂停 → 续播；否则从头播。
  Future<void> _onBubbleTap() async {
    final msgId = _playbackMessageId;
    if (msgId.isEmpty) {
      return;
    }

    unawaited(_markVoiceReadIfNeeded());
    final clientId = _clientMessageId;

    final willPause = _matchesEngine() &&
        (SoundPlayer.currentPhase == VoicePlaybackPhase.playing ||
            SoundPlayer.currentPhase == VoicePlaybackPhase.loading ||
            SoundPlayer.isPlaying);
    if (willPause) {
      widget.chatModel.disableVoiceAutoPlayChain();
    } else {
      widget.chatModel.enableVoiceAutoPlayChain();
    }

    widget.chatModel.currentPlayedMsgId = msgId;
    _resetPlaybackMetrics();
    _optimisticLoading = true;
    _refreshIconState(force: true);

    try {
      await SoundPlayer.handleBubbleTap(
        messageId: msgId,
        altMessageId: clientId,
        resolveUrl: _resolvePlaybackUrlForTap,
      );
    } finally {
      if (mounted) {
        _optimisticLoading = false;
      }
    }

    if (!mounted) {
      return;
    }
    if (!SoundPlayer.matchesMessage(msgId, altMessageId: clientId) &&
        SoundPlayer.currentPhase != VoicePlaybackPhase.loading) {
      widget.chatModel.currentPlayedMsgId = '';
    }
    if (SoundPlayer.currentPhase == VoicePlaybackPhase.idle &&
        !SoundPlayer.matchesMessage(msgId, altMessageId: clientId)) {
      unawaited(downloadMessageDetailAndSave());
    }
    _refreshIconState(force: true);
  }

  Future<void> _onResumeTap() async {
    final msgId = _playbackMessageId;
    if (msgId.isEmpty) {
      return;
    }
    final clientId = _clientMessageId;
    if (!SoundPlayer.isPausedMessage(msgId, altMessageId: clientId)) {
      return;
    }
    widget.chatModel.enableVoiceAutoPlayChain();
    widget.chatModel.currentPlayedMsgId = msgId;
    await SoundPlayer.handleBubbleTap(
      messageId: msgId,
      altMessageId: clientId,
      resolveUrl: _resolvePlaybackUrlForTap,
    );
    if (!mounted) {
      return;
    }
    _refreshIconState(force: true);
  }

  bool _tracksCurrentPlayback() {
    final playbackId = _playbackMessageId;
    final clientId = _clientMessageId;
    return _matchesEngine() ||
        widget.chatModel.currentPlayedMsgId == playbackId ||
        (clientId != null && widget.chatModel.currentPlayedMsgId == clientId);
  }

  Future<void> _handleVoicePlaybackCompleted(String completedId) async {
    _calibrateTotalFromPlayback(completed: true);
    _playbackPosition = Duration(
      milliseconds: _calibratedTotalMs ?? _playbackPeakPosition.inMilliseconds,
    );
    _refreshIconState(force: true);

    final chainWasEnabled = widget.chatModel.voiceAutoPlayChainEnabled;
    if (chainWasEnabled) {
      await widget.chatModel.tryAutoPlayNextVoice(completedId);
    }

    if (!mounted) {
      return;
    }

    final chainedToNext = chainWasEnabled &&
        widget.chatModel.voiceAutoPlayChainEnabled &&
        widget.chatModel.currentPlayedMsgId.isNotEmpty &&
        widget.chatModel.currentPlayedMsgId != completedId;

    if (!chainedToNext) {
      if (widget.chatModel.currentPlayedMsgId == completedId) {
        widget.chatModel.currentPlayedMsgId = '';
      }
      _resetPlaybackMetrics();
      _refreshIconState(force: true);
    }
  }

  Widget _buildPlayButton({
    required Color buttonColor,
    required Color iconColor,
    required double size,
    required bool isPlaying,
    required bool isLoading,
  }) {
    if (isLoading) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: const BoxDecoration(
            color: _voicePlayButtonColor,
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(size * 0.22),
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: iconColor,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _voicePlayButtonColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: iconColor,
        size: size * 0.62,
      ),
    );
  }

  static const _innerGap = 2.0;
  static const _playButtonGap = 6.0;

  double _labelSlotWidth(TextStyle style) {
    final samples = ['99"', '0"'];
    var maxWidth = 20.0;
    for (final sample in samples) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(minWidth: 0, maxWidth: double.infinity);
      maxWidth = max(maxWidth, painter.width);
    }
    return maxWidth;
  }

  double _waveformAreaWidth(int durationSec, double fontScale) {
    return max(40.0, _voiceWaveformWidth * fontScale.clamp(0.95, 1.15));
  }

  double _playbackProgress(int durationSec) {
    if (!_drivesPlaybackUi) {
      return 0;
    }
    if (SoundPlayer.currentPhase == VoicePlaybackPhase.completed &&
        _matchesEngine()) {
      return 1.0;
    }
    final totalMs = _totalDurationMs(durationSec);
    if (totalMs <= 0) {
      return 0;
    }
    final posMs = _playbackPosition.inMilliseconds;
    if (posMs + 80 >= totalMs) {
      return 1.0;
    }
    return (posMs / totalMs).clamp(0.0, 1.0);
  }

  int _remainingSeconds(int? seconds) {
    if (_isCurrent &&
        SoundPlayer.currentPhase == VoicePlaybackPhase.completed &&
        _matchesEngine()) {
      return 0;
    }
    final totalMs = _totalDurationMs(max(1, seconds ?? 1));
    final posMs = _playbackPosition.inMilliseconds.clamp(0, totalMs);
    if (posMs + 80 >= totalMs) {
      return 0;
    }
    return max(0, ((totalMs - posMs) / 1000.0).ceil());
  }

  String _voiceStatusLabel(int? seconds) {
    if (_drivesPlaybackUi) {
      return _formatDurationLabel(_remainingSeconds(seconds));
    }
    return _formatDurationLabel(seconds);
  }

  double _voiceContentHeight(
      TextStyle labelTextStyle, double fallbackLineHeight) {
    final fontSize = labelTextStyle.fontSize ?? 16.0;
    final lineHeight = labelTextStyle.height ?? fallbackLineHeight;
    return fontSize * lineHeight;
  }

  double _resolveMinContentWidth({
    required TextStyle labelTextStyle,
    required int durationSec,
    required double playButtonSize,
    required double fontScale,
  }) {
    final labelSlot = _labelSlotWidth(labelTextStyle);
    final waveformWidth = _waveformAreaWidth(durationSec, fontScale);
    return labelSlot +
        _innerGap +
        waveformWidth +
        _playButtonGap +
        playButtonSize;
  }

  Widget _buildVoiceRow({
    required int durationSec,
    required String durationLabel,
    required TextStyle labelTextStyle,
    required TextStyle timeTextStyle,
    required String timeText,
    required Color accentColor,
    required Color playIconColor,
    required double contentHeight,
    required double playButtonSize,
    required double fontScale,
    required double minContentWidth,
  }) {
    final waveformHeight = contentHeight * 0.88;
    final waveformWidth = _waveformAreaWidth(durationSec, fontScale);
    final labelSlotWidth = _labelSlotWidth(labelTextStyle);
    final isPlaying = _drivesPlaybackUi &&
        !_isPaused &&
        SoundPlayer.currentPhase != VoicePlaybackPhase.loading;
    final waveform = ClipRect(
      child: _VoiceWaveform(
        bars: _waveformBarsForMessage(durationSec),
        progress: _playbackProgress(durationSec),
        barColor: accentColor,
        lineColor: accentColor.withValues(alpha: 0.5),
        width: waveformWidth,
        height: waveformHeight,
      ),
    );
    final playButton = _buildPlayButton(
      buttonColor: _voicePlayButtonColor,
      iconColor: playIconColor,
      size: playButtonSize,
      isPlaying: isPlaying,
      isLoading: _isPlaybackLoading,
    );
    final label = IgnorePointer(
      child: Text(
        durationLabel,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: labelTextStyle,
      ),
    );
    final time = IgnorePointer(
      child: Text(
        timeText,
        maxLines: 1,
        style: timeTextStyle,
      ),
    );
    const metaGap = SizedBox(width: 4);
    final pinnedLabel = SizedBox(
      width: labelSlotWidth,
      child: Align(
        alignment:
            widget.isFromSelf ? Alignment.centerLeft : Alignment.centerRight,
        child: label,
      ),
    );
    final pinnedWaveform = SizedBox(
      width: waveformWidth,
      height: waveformHeight,
      child: waveform,
    );
    final pinnedButton = SizedBox(
      width: playButtonSize,
      height: playButtonSize,
      child: playButton,
    );
    final voiceContent = SizedBox(
      height: contentHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widget.isFromSelf
            ? <Widget>[
                pinnedLabel,
                const SizedBox(width: _innerGap),
                pinnedWaveform,
                const SizedBox(width: _playButtonGap),
                pinnedButton,
              ]
            : <Widget>[
                pinnedButton,
                const SizedBox(width: _playButtonGap),
                pinnedWaveform,
                const SizedBox(width: _innerGap),
                pinnedLabel,
              ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: minContentWidth,
          child: Align(
            alignment: widget.isFromSelf
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: voiceContent,
          ),
        ),
        metaGap,
        time,
      ],
    );
  }

  Future<void> downloadMessageDetailAndSave() async {
    final msgID = widget.message.msgID;
    if (msgID == null || msgID.isEmpty) {
      return;
    }
    if (widget.isFromSelf &&
        widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return;
    }
    if (widget.message.soundElem!.url == null ||
        widget.message.soundElem!.url == '') {
      final response = await _messageService.getMessageOnlineUrl(
        msgID: msgID,
        reportError: false,
      );
      if (response.data != null) {
        widget.message.soundElem = response.data!.soundElem;
        Future.delayed(const Duration(microseconds: 10), () {
          if (mounted) {
            _safeSetState(() => stateElement = response.data!.soundElem!,
                force: true);
          }
        });
      }
    }
    if (!PlatformUtils().isWeb && _resolveLocalPathIfExists() == null) {
      final remote = _resolveRemoteUrl();
      if (remote != null && remote.isNotEmpty) {
        unawaited(_downloadRemoteSoundToCache(remote).then((path) {
          if (path != null && mounted) {
            unawaited(_loadWaveformBarsIfNeeded(force: true));
            _safeSetState(() {}, force: true);
          }
        }));
      } else {
        unawaited(_messageService.downloadMessage(
          msgID: msgID,
          messageType: 4,
          imageType: 0,
          isSnapshot: false,
          reportError: false,
        ));
      }
    }
    unawaited(_loadWaveformBarsIfNeeded(force: true));
  }

  @override
  void initState() {
    super.initState();

    unawaited(downloadMessageDetailAndSave());
    unawaited(_loadWaveformBarsIfNeeded());

    SoundPlayer.addPlayerStateCallback(_onPlayerStateChanged);
    _positionSubscription = SoundPlayer.positionStream.listen(_onPositionTick);
    _durationSubscription = SoundPlayer.durationStream.listen(_onDurationTick);
    widget.chatModel.addListener(_onChatModelChanged);
    if (_isCurrent || _matchesEngine()) {
      _syncPositionFromPlayer();
    }
  }

  @override
  void didUpdateWidget(covariant TIMUIKitSoundElem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = oldWidget.soundElem.url?.trim() ?? '';
    final newUrl = widget.soundElem.url?.trim() ?? '';
    if (oldUrl.isEmpty && newUrl.isNotEmpty) {
      unawaited(downloadMessageDetailAndSave());
    }
    if (!_matchesEngine()) {
      return;
    }
    if (widget.msgID.isNotEmpty && widget.msgID != oldWidget.msgID) {
      SoundPlayer.adoptMessageAlias(widget.msgID);
    }
    final clientId = _clientMessageId;
    if (clientId != null && clientId != oldWidget.message.id) {
      SoundPlayer.adoptMessageAlias(clientId);
    }
  }

  void _onPositionTick(Duration position) {
    if (!mounted) {
      return;
    }
    if (!_isCurrent && !_drivesPlaybackUi) {
      if (_playbackPosition != Duration.zero ||
          _playbackPeakPosition != Duration.zero) {
        _safeSetState(() {
          _playbackPosition = Duration.zero;
          _playbackPeakPosition = Duration.zero;
        });
      }
      return;
    }

    final peakMs =
        max(_playbackPeakPosition.inMilliseconds, position.inMilliseconds);
    final changed = _playbackPosition != position ||
        _playbackPeakPosition.inMilliseconds != peakMs;
    if (!changed) {
      return;
    }

    _playbackPosition = position;
    _playbackPeakPosition = Duration(milliseconds: peakMs);
    _safeSetState(() {}, force: true);
  }

  void _onDurationTick(Duration? duration) {
    if (!mounted || duration == null || duration.inMilliseconds <= 0) {
      return;
    }
    if (!_isCurrent && !_drivesPlaybackUi) {
      return;
    }
    if (_loadedAudioDuration != duration) {
      _safeSetState(() => _loadedAudioDuration = duration, force: true);
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted) {
      return;
    }
    final playbackId = _playbackMessageId;
    if (!_tracksCurrentPlayback()) {
      return;
    }

    if (SoundPlayer.currentPhase == VoicePlaybackPhase.completed) {
      if (!SoundPlayer.didJustComplete(
        playbackId,
        altMessageId: _clientMessageId,
      )) {
        if (_drivesPlaybackUi) {
          _syncPositionFromPlayer();
          _refreshIconState(force: true);
        }
        return;
      }
      unawaited(_handleVoicePlaybackCompleted(playbackId));
      return;
    }

    if (_matchesEngine() || _drivesPlaybackUi) {
      if (SoundPlayer.currentPhase == VoicePlaybackPhase.idle) {
        if (_matchesEngine()) {
          widget.chatModel.currentPlayedMsgId = '';
        }
        _resetPlaybackMetrics();
      } else if (SoundPlayer.currentPhase == VoicePlaybackPhase.playing ||
          SoundPlayer.currentPhase == VoicePlaybackPhase.paused ||
          SoundPlayer.currentPhase == VoicePlaybackPhase.loading) {
        _syncPositionFromPlayer();
      }
      _refreshIconState(force: true);
      return;
    }
    _refreshIconState();
  }

  void _onChatModelChanged() {
    if (!mounted) {
      return;
    }
    if (_isCurrent) {
      if (_matchesEngine() || _playerActive) {
        _syncPositionFromPlayer();
      }
      _refreshIconState(force: true);
      return;
    }
    if (_playbackPosition != Duration.zero ||
        _playbackPeakPosition != Duration.zero) {
      _resetPlaybackMetrics();
    }
    _refreshIconState();
  }

  @override
  void dispose() {
    _jumpHighlightTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    widget.chatModel.removeListener(_onChatModelChanged);
    // 行级刷新会重建语音气泡，停止播放交给聊天页生命周期处理。
    SoundPlayer.removePlayerStateCallback(_onPlayerStateChanged);
    super.dispose();
  }

  String _formatDurationLabel(int? seconds) {
    final total = max(1, seconds ?? 0);
    return '$total"';
  }

  Widget _buildVoiceToTextPanel({
    required LocalCustomDataModel localCustomData,
    required Color bubbleColor,
    required BorderRadius borderRadius,
    required TUITheme theme,
    required bool isDesktopScreen,
    required double bodyFontSize,
    required double compactTextHeight,
  }) {
    final voiceToText = TencentUtils.checkString(localCustomData.voiceToText);
    final isLoading = localCustomData.voiceToTextStatus == 'loading';
    if (!isLoading && voiceToText == null) {
      return const SizedBox.shrink();
    }

    final bodyTextStyle = MessageBubbleTextColor.bodyTextStyle(
      theme: theme,
      backgroundColor: bubbleColor,
      fontStyle: widget.fontStyle,
      fontSize: bodyFontSize,
      lineHeight: compactTextHeight,
    );

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: widget.textPadding ??
          EdgeInsets.symmetric(
            horizontal: isDesktopScreen ? 14 : 12,
            vertical: isDesktopScreen ? 10 : 9,
          ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: widget.borderRadius ?? borderRadius,
      ),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: bodyTextStyle.color?.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '转文字中…',
                  style: bodyTextStyle.copyWith(
                    fontSize: (bodyTextStyle.fontSize ?? bodyFontSize) - 1,
                    color: bodyTextStyle.color?.withValues(alpha: 0.72),
                  ),
                ),
              ],
            )
          else
            Text(
              voiceToText!,
              softWrap: true,
              style: bodyTextStyle,
            ),
          if (!isLoading) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  Icons.text_fields_rounded,
                  color: bodyTextStyle.color?.withValues(alpha: 0.45) ??
                      const Color(0x72282c34),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '转文字完成',
                  style: TextStyle(
                    color: bodyTextStyle.color?.withValues(alpha: 0.45) ??
                        const Color(0x72282c34),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showJumpColor() {
    _jumpHighlightTimer = MessageJumpHighlight.play(
      mounted: () => mounted,
      getIsShining: () => isShining,
      setIsShining: (value) => isShining = value,
      setState: (fn) => _safeSetState(fn, force: true),
      applyHighlight: (highlighted, {border}) {
        isShowJumpState = highlighted;
      },
      clearJump: () => widget.clearJump?.call(),
      shouldRun: () =>
          (widget.chatModel.jumpMsgID == widget.message.msgID) ||
          !(widget.message.msgID?.isNotEmpty ?? false),
      previousTimer: _jumpHighlightTimer,
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final convId = widget.chatModel.conversationID;
    final msgKey = ChatUiStateStore.messageKeyOf(widget.message);
    final rowRevision = context.select<ChatUiStateStore, int>(
      (store) => store.rowRevision(convId, msgKey),
    );
    _onRowRevisionUpdate(rowRevision);

    final theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    final defaultStyle = widget.isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ??
            theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor ??
            _ChatUiTokens.surfaceAltLight);

    final borderRadius = widget.borderRadius ??
        (widget.isFromSelf
            ? const BorderRadius.only(
                topLeft: Radius.circular(_ChatUiTokens.rMd),
                topRight: Radius.circular(_ChatUiTokens.s2),
                bottomLeft: Radius.circular(_ChatUiTokens.rMd),
                bottomRight: Radius.circular(_ChatUiTokens.rMd),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(_ChatUiTokens.s2),
                topRight: Radius.circular(_ChatUiTokens.rMd),
                bottomLeft: Radius.circular(_ChatUiTokens.rMd),
                bottomRight: Radius.circular(_ChatUiTokens.rMd),
              ));
    final bubbleColor = isShowJumpState
        ? kMessageJumpHighlightColor
        : (widget.backgroundColor ?? defaultStyle);
    final configuredTextHeight = widget.chatModel.chatConfig.textHeight;
    final compactTextHeight = configuredTextHeight <= 0
        ? 1.20
        : configuredTextHeight.clamp(1.16, 1.22).toDouble();
    const bodyFontSize = 16.0;
    final labelTextStyle = MessageBubbleTextColor.bodyTextStyle(
      theme: theme,
      backgroundColor: bubbleColor,
      fontStyle: widget.fontStyle,
      fontSize: bodyFontSize,
      lineHeight: compactTextHeight,
    ).copyWith(
      fontFeatures: const [
        FontFeature.tabularFigures(),
      ],
    );
    final accentColor =
        labelTextStyle.color ?? theme.darkTextColor ?? Colors.black;
    final playIconColor = _resolvePlayIconColor(
      bubbleColor: bubbleColor,
      theme: theme,
    );

    if (widget.isShowJump) {
      if (!isShining) {
        Future.delayed(Duration.zero, _showJumpColor);
      } else if ((widget.chatModel.jumpMsgID == widget.message.msgID) &&
          (widget.message.msgID?.isNotEmpty ?? false)) {
        widget.clearJump?.call();
      }
    }

    final durationSec = stateElement.duration ?? 0;
    final textScaler = MediaQuery.textScalerOf(context);
    final fontScale =
        textScaler.scale(labelTextStyle.fontSize ?? bodyFontSize) /
            (labelTextStyle.fontSize ?? bodyFontSize);
    final durationLabel = _voiceStatusLabel(durationSec);
    final contentHeight =
        _voiceContentHeight(labelTextStyle, compactTextHeight);
    final playButtonSize = contentHeight;
    final voicePadding = widget.textPadding ??
        MessageBubbleTextColor.messageBubblePadding;
    final minContentWidth = _resolveMinContentWidth(
      labelTextStyle: labelTextStyle,
      durationSec: durationSec,
      playButtonSize: playButtonSize,
      fontScale: fontScale,
    );
    final timeText = TimeAgo().getTimeForBubble(widget.message.timestamp ?? 0);
    final timeTextStyle = TextStyle(
      fontSize: 11,
      height: 1,
      color: MessageBubbleTextColor.metaText(
        theme: theme,
        backgroundColor: bubbleColor,
        overrideColor: widget.fontStyle?.color,
      ),
    );
    final localCustomData = LocalCustomDataModel.fromMap(
      json.decode(
          TencentUtils.checkString(widget.message.localCustomData) ?? '{}'),
    );

    final bubbleBody = Column(
      crossAxisAlignment:
          widget.isFromSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVoiceRow(
          durationSec: durationSec,
          durationLabel: durationLabel,
          labelTextStyle: labelTextStyle,
          timeTextStyle: timeTextStyle,
          timeText: timeText,
          accentColor: accentColor,
          playIconColor: playIconColor,
          contentHeight: contentHeight,
          playButtonSize: playButtonSize,
          fontScale: fontScale,
          minContentWidth: minContentWidth,
        ),
        if (widget.isShowMessageReaction ?? true)
          TIMUIKitMessageReactionShowPanel(
            message: widget.message,
          ),
      ],
    );

    return Column(
      crossAxisAlignment:
          widget.isFromSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _onBubbleTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IntrinsicWidth(
                child: Container(
                  padding: voicePadding,
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    border: MessageBubbleTextColor.othersBubbleBorder(
                      isFromSelf: widget.isFromSelf,
                      bubbleBackground: bubbleColor,
                    ),
                  ),
                  child: bubbleBody,
                ),
              ),
              if (_isSendingUpload &&
                  _uploadProgress > 0 &&
                  _uploadProgress < 100)
                Positioned(
                  right: widget.isFromSelf ? 6 : null,
                  left: widget.isFromSelf ? null : 6,
                  top: 6,
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      value: _uploadProgress / 100,
                      strokeWidth: 1.5,
                      color: accentColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildVoiceToTextPanel(
          localCustomData: localCustomData,
          bubbleColor: bubbleColor,
          borderRadius: borderRadius,
          theme: theme,
          isDesktopScreen: isDesktopScreen,
          bodyFontSize: bodyFontSize,
          compactTextHeight: compactTextHeight,
        ),
      ],
    );
  }
}

/// 语音气泡竖条波形 + 播放进度线。
class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({
    required this.bars,
    required this.progress,
    required this.barColor,
    required this.lineColor,
    required this.width,
    required this.height,
  });

  final List<double> bars;
  final double progress;
  final Color barColor;
  final Color lineColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _VoiceWaveformPainter(
          bars: bars,
          progress: progress,
          barColor: barColor,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  _VoiceWaveformPainter({
    required this.bars,
    required this.progress,
    required this.barColor,
    required this.lineColor,
  });

  final List<double> bars;
  final double progress;
  final Color barColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const barGap = 1.8;
    final barCount = bars.length;
    final barWidth =
        max(1.2, (size.width - barGap * (barCount - 1)) / barCount);
    final centerY = size.height / 2;
    final barPaint = Paint()..color = barColor;

    for (var i = 0; i < barCount; i++) {
      final barHeight = max(2.0, bars[i] * size.height);
      final x = i * (barWidth + barGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, barPaint);
    }

    final lineX =
        (progress.clamp(0.0, 1.0) * size.width).clamp(0.0, size.width);
    if (progress <= 0) {
      return;
    }
    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.barColor != barColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.bars != bars;
  }
}
