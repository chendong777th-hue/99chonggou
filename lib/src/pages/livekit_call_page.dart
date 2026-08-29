import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/route_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_page_paint_gate.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ui_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_video_layer.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_voip_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

/// LiveKit C2C call UI modeled after TUICallKit SingleCallWidget layout:
/// avatar backdrop, hint text, function bar, video big/small window swap.
class LiveKitCallPage extends StatefulWidget {
  const LiveKitCallPage({
    super.key,
    this.peerDisplayName,
    this.peerFaceUrl,
  });

  final String? peerDisplayName;
  final String? peerFaceUrl;

  @override
  State<LiveKitCallPage> createState() => _LiveKitCallPageState();
}

class _LiveKitCallPageState extends State<LiveKitCallPage> with RouteAware {
  final _session = LiveKitCallSession.instance;

  Timer? _tickTimer;
  bool _chromeHidden = false;
  bool _localIsBig = true;
  bool _calleeLayoutApplied = false;
  bool _closing = false;

  /// Drop video + network backdrop before Navigator.pop so exit isn't
  /// fighting LiveKit texture dispose / Image decode (hangup stutter).
  bool _exiting = false;

  /// Full-bleed peer face is deferred until enter fade + stagger settles.
  bool _allowHeavyBg = false;
  Timer? _heavyBgTimer;
  LiveKitCallPagePaintSnapshot? _lastPaint;
  final ValueNotifier<int> _durationTick = ValueNotifier<int>(0);
  double _smallTop = 128;
  double _smallRight = 20;
  String _resolvedFaceUrl = '';
  String _resolvedName = '';

  static const Color _bgSolid = Color(0xFF2D2D2D);
  static const Color _bgScrim = Color.fromRGBO(45, 45, 45, 0.9);
  static const Color _tipColor = Colors.white;
  static const String _assetDir = 'assets/call_ui';

  /// PiP size must be pinned on [Positioned] — see [_buildSmallVideo].
  static const double _pipWidth = 110;
  static const double _pipHeight = 216;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    LiveKitCallNavigator.notifyCallRoutePushed();
  }

  @override
  void didPopNext() {
    LiveKitCallNavigator.notifyCallRouteUncovered();
  }

  @override
  void didPushNext() {
    LiveKitCallNavigator.notifyCallRouteCovered();
  }

  @override
  void didPop() {
    LiveKitCallNavigator.notifyCallRoutePopped();
  }

  @override
  void initState() {
    super.initState();
    // Heal RouteAware missed didPush — subscribe happens after push already fired.
    LiveKitCallNavigator.notifyCallPageMounted();
    liveKitCallUiLog(
      'LiveKitCallPage.initState phase=${_session.phase} '
      'role=${_session.role} video=${_session.isVideo} '
      'callId=${_session.callId}',
    );
    _session.addListener(_onSession);
    LiveKitCallSystemUi.instance.systemPipActive
        .addListener(_onSystemPipChanged);
    _resolvedFaceUrl = widget.peerFaceUrl?.trim() ?? '';
    _resolvedName = widget.peerDisplayName?.trim() ?? '';
    unawaited(_resolvePeerProfile());
    unawaited(LiveKitCallSystemUi.instance.setPipContentReady(true));
    _scheduleHeavyBg();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_session.phase == LiveKitCallPhase.connected) {
        _durationTick.value++;
      }
    });
    // Guard: CallKit 接听可能在挂断之后才 push 本页；监听注册前 idle
    // 通知已发过，必须在此自检，否则僵尸页会留在栈上。
    _exitIfSessionAlreadyEnded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitIfSessionAlreadyEnded();
      if (mounted) {
        liveKitCallUiLog(
          'LiveKitCallPage.firstFrame phase=${_session.phase} '
          'routeCurrent=${ModalRoute.of(context)?.isCurrent} '
          'routeName=${ModalRoute.of(context)?.settings.name}',
        );
      }
    });
  }

  void _exitIfSessionAlreadyEnded() {
    if (!mounted || _closing) return;
    if (_session.phase == LiveKitCallPhase.idle ||
        _session.phase == LiveKitCallPhase.ended) {
      _exitCallPage();
    }
  }

  void _scheduleHeavyBg() {
    _heavyBgTimer?.cancel();
    // Solid chrome first; decode peer face after enter fade + video settle gap.
    final delay = liveKitCallHeavyBgDelay(
      isVideo: _session.isVideo,
      enterTransition: LiveKitCallNavigator.enterTransitionDuration,
    );
    _heavyBgTimer = Timer(delay, () {
      if (!mounted || _exiting || _allowHeavyBg) return;
      setState(() => _allowHeavyBg = true);
    });
  }

  void _onSystemPipChanged() {
    if (!mounted) return;
    // Hide chrome while system PiP snapshots / shows the Activity.
    if (LiveKitCallSystemUi.instance.systemPipActive.value &&
        _session.isVideo) {
      setState(() => _chromeHidden = true);
    } else {
      setState(() {});
    }
  }

  Future<void> _resolvePeerProfile() async {
    final peerId = _peerId;
    if (peerId.isEmpty) return;
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getUsersInfo(userIDList: <String>[peerId]);
      final info = res.data?.isNotEmpty == true ? res.data!.first : null;
      if (!mounted || info == null) return;
      final nick = (info.nickName ?? '').trim();
      final face = UserAvatarHelper.pickBest(imFaceUrl: info.faceUrl);
      if (nick.isNotEmpty) {
        DisplayNameStore.instance.setC2C(peerId, nick);
      }
      setState(() {
        if (_resolvedName.isEmpty && nick.isNotEmpty) {
          _resolvedName = nick;
        }
        if (_resolvedFaceUrl.isEmpty && face.isNotEmpty) {
          _resolvedFaceUrl = face;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    liveKitCallUiLog(
      'LiveKitCallPage.dispose phase=${_session.phase} closing=$_closing',
    );
    appRouteObserver.unsubscribe(this);
    LiveKitCallNavigator.notifyCallPageDisposed();
    _tickTimer?.cancel();
    _heavyBgTimer?.cancel();
    _durationTick.dispose();
    _session.removeListener(_onSession);
    LiveKitCallSystemUi.instance.systemPipActive
        .removeListener(_onSystemPipChanged);
    unawaited(LiveKitCallSystemUi.instance.setPipContentReady(false));
    super.dispose();
  }

  void _onSession() {
    if (!mounted || _closing) return;
    liveKitCallUiLog(
      'LiveKitCallPage.onSession phase=${_session.phase} '
      'video=${_session.isVideo} room=${_session.room != null}',
    );
    if (!_calleeLayoutApplied &&
        _session.role == AppCallRole.callee &&
        (_session.phase == LiveKitCallPhase.ringingIn ||
            _session.phase == LiveKitCallPhase.connecting ||
            _session.phase == LiveKitCallPhase.connected)) {
      _calleeLayoutApplied = true;
      _localIsBig = false;
    }
    if (_session.phase == LiveKitCallPhase.idle ||
        _session.phase == LiveKitCallPhase.ended) {
      liveKitCallUiLog('LiveKitCallPage.onSession → exit (idle/ended)');
      _exitCallPage();
      return;
    }
    final next = LiveKitCallPagePaintSnapshot.fromSession(_session);
    if (!LiveKitCallPagePaintSnapshot.shouldRebuild(
      previous: _lastPaint,
      next: next,
    )) {
      return;
    }
    _lastPaint = next;
    setState(() {});
  }

  /// Blank video + network bg → next frame pop. Keeps exit light.
  void _exitCallPage({VoidCallback? thenEndSession}) {
    if (_closing) return;
    liveKitCallUiLog(
      'LiveKitCallPage._exitCallPage phase=${_session.phase} '
      'exiting=$_exiting',
    );
    _closing = true;
    _heavyBgTimer?.cancel();
    _allowHeavyBg = false;
    _session.removeListener(_onSession);
    _tickTimer?.cancel();
    void popNow() {
      if (!mounted) {
        thenEndSession?.call();
        return;
      }
      final route = ModalRoute.of(context);
      if (route?.settings.name == LiveKitCallNavigator.routeName &&
          route?.isCurrent == true) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
        }
      }
      thenEndSession?.call();
    }

    if (!_exiting) {
      setState(() => _exiting = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => popNow());
    } else {
      popNow();
    }
  }

  String get _peerId => _session.peerUserId;

  String get _peerName {
    if (_resolvedName.isNotEmpty) return _resolvedName;
    final override = widget.peerDisplayName?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final fromStore = DisplayNameStore.instance.c2c(_peerId)?.trim() ?? '';
    if (fromStore.isNotEmpty) return fromStore;
    return _peerId;
  }

  String get _peerFaceUrl {
    if (_resolvedFaceUrl.isNotEmpty) return _resolvedFaceUrl;
    return widget.peerFaceUrl?.trim() ?? '';
  }

  bool get _isWaiting =>
      _session.phase == LiveKitCallPhase.ringingOut ||
      _session.phase == LiveKitCallPhase.ringingIn ||
      _session.phase == LiveKitCallPhase.connecting;

  bool get _isIncomingWaiting => _session.phase == LiveKitCallPhase.ringingIn;

  bool get _isConnected => _session.phase == LiveKitCallPhase.connected;

  bool get _shouldShowVideoLayer => shouldShowLiveKitVideoLayer(
        isVideo: _session.isVideo,
        phase: _session.phase,
        role: _session.role,
        hasRoom: _session.room != null,
      );

  bool get _showUserInfo {
    // Video layer active: hide center avatar block (video fills screen).
    if (_shouldShowVideoLayer) return false;
    return true;
  }

  String _hintText(AppI18n i18n) {
    if (_session.phase == LiveKitCallPhase.connecting) {
      return i18n.t(
        zhHans: '连接中…',
        zhHant: '連線中…',
        en: 'Connecting…',
        ja: '接続中…',
        ko: '연결 중…',
      );
    }
    if (_isIncomingWaiting) {
      return _session.isVideo
          ? i18n.t(
              zhHans: '邀请你视频通话',
              zhHant: '邀請你視訊通話',
              en: 'Invites you to a video call',
              ja: 'ビデオ通話に招待されています',
              ko: '영상 통화 초대',
            )
          : i18n.t(
              zhHans: '邀请你语音通话',
              zhHant: '邀請你語音通話',
              en: 'Invites you to a voice call',
              ja: '音声通話に招待されています',
              ko: '음성 통화 초대',
            );
    }
    if (_session.phase == LiveKitCallPhase.ringingOut) {
      return i18n.t(
        zhHans: '等待接听…',
        zhHant: '等待接聽…',
        en: 'Waiting for answer…',
        ja: '応答待ち…',
        ko: '응답 대기 중…',
      );
    }
    return '';
  }

  String _durationLabel() {
    final started = _session.connectedAt;
    if (started == null) return '';
    final sec = DateTime.now().difference(started).inSeconds;
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onHangupOrCancel() {
    if (_closing) return;
    if (kDebugMode) {
      debugPrint(
        'LiveKitCallPage: hangup/cancel tap phase=${_session.phase} '
        'callId=${_session.callId}',
      );
    }
    unawaited(
      LiveKitVoipBridge.instance.dismissSystemCallKitForSession(
        callId: _session.callId,
      ),
    );
    // Pop first (after blanking video), then end the session — so disconnect
    // / chat bubble work never overlaps the exit transition.
    final phase = _session.phase;
    _exitCallPage(
      thenEndSession: () {
        switch (phase) {
          case LiveKitCallPhase.ringingIn:
            unawaited(_session.rejectIncoming());
            break;
          case LiveKitCallPhase.ringingOut:
          case LiveKitCallPhase.connecting:
            unawaited(_session.cancelOutgoing());
            break;
          case LiveKitCallPhase.connected:
          case LiveKitCallPhase.ended:
          case LiveKitCallPhase.idle:
            unawaited(_session.hangup());
            break;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final size = MediaQuery.sizeOf(context);
    final inSystemPip = LiveKitCallSystemUi.instance.systemPipActive.value;
    final showChrome =
        !inSystemPip && (!_chromeHidden || !_session.isVideo || !_isConnected);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_minimize());
      },
      child: Scaffold(
        body: Container(
          color: _backgroundColor,
          child: Stack(
            alignment: Alignment.topLeft,
            fit: StackFit.expand,
            children: [
              if (!inSystemPip && !_exiting) _buildBackground(),
              if (!_exiting && _shouldShowVideoLayer) _buildBigVideo(),
              if (!_exiting && _shouldShowVideoLayer && showChrome)
                _buildSmallVideo(size),
              if (!_exiting && showChrome) _buildMinimizeButton(),
              if (!_exiting && showChrome) _buildTimer(size),
              if (!_exiting && showChrome && _showUserInfo)
                _buildUserInfo(size),
              if (!_exiting && showChrome) _buildHint(size, i18n),
              if (!_exiting && showChrome) _buildFunctions(size, i18n),
            ],
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor =>
      _session.isVideo ? const Color(0xFF444444) : const Color(0xFFF2F2F2);

  Future<void> _minimize() {
    return DesktopCallFloatService.instance.minimize(
      peerDisplayName: _peerName,
      peerFaceUrl: _peerFaceUrl,
    );
  }

  Widget _buildMinimizeButton() {
    // Match TUICallKit SingleCallWidget floating_button (left:12, top:52).
    return Positioned(
      left: 12,
      top: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_minimize()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Image.asset('$_assetDir/floating_button.png'),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    // Solid placeholder during enter fade / missing URL — no decode race.
    if (!_allowHeavyBg) {
      return const ColoredBox(color: _bgSolid);
    }
    final face = _peerFaceUrl;
    final resolved = UserAvatarHelper.resolveDisplayUrl(face);
    final headers =
        resolved == null ? null : UserAvatarHelper.httpHeadersFor(resolved);
    final cacheSize = liveKitCallHeavyBgMemCachePx(
      MediaQuery.sizeOf(context).shortestSide,
    );
    // Background must not compete for taps with control buttons.
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _bgSolid),
          if (resolved != null && resolved.isNotEmpty)
            CachedNetworkImage(
              imageUrl: resolved,
              cacheKey: resolved,
              httpHeaders: headers,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: cacheSize,
              memCacheHeight: cacheSize,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          const ColoredBox(color: _bgScrim),
        ],
      ),
    );
  }

  Widget _buildTimer(Size size) {
    return Positioned(
      left: 0,
      top: 66,
      width: size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isConnected)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: ValueListenableBuilder<int>(
                valueListenable: _durationTick,
                builder: (_, __, ___) => Text(
                  _durationLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(Size size) {
    return Positioned(
      top: size.height / 4,
      width: size.width,
      child: IgnorePointer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppUserAvatar(
              faceUrl: _peerFaceUrl,
              showName: _peerName,
              size: 110,
            ),
            const SizedBox(height: 20),
            Text(
              _peerName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHint(Size size, AppI18n i18n) {
    final text = _hintText(i18n);
    if (text.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: size.height * 2 / 3,
      width: size.width,
      child: IgnorePointer(
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _tipColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFunctions(Size size, AppI18n i18n) {
    // Match TUICallKit: left:0, bottom:50, full width.
    return Positioned(
      left: 0,
      bottom: 50,
      width: size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_buildFunctionBar(i18n)],
      ),
    );
  }

  Widget _buildFunctionBar(AppI18n i18n) {
    if (_isIncomingWaiting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _extendBtn(
            img: '$_assetDir/hangup.png',
            tips: i18n.t(
              zhHans: '挂断',
              zhHant: '掛斷',
              en: 'Decline',
              ja: '拒否',
              ko: '거절',
            ),
            onTap: _onHangupOrCancel,
          ),
          _extendBtn(
            img: '$_assetDir/dialing.png',
            tips: i18n.t(
              zhHans: '接听',
              zhHant: '接聽',
              en: 'Accept',
              ja: '応答',
              ko: '응답',
            ),
            onTap: () => unawaited(LiveKitVoipBridge.instance.acceptFromUi()),
          ),
        ],
      );
    }

    if (_session.isVideo) {
      if (_isWaiting) {
        // Video caller waiting: switch cam | hangup | camera
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _extendBtn(
              img: '$_assetDir/switch_camera_group.png',
              tips: i18n.t(
                zhHans: '翻转镜头',
                zhHant: '翻轉鏡頭',
                en: 'Flip',
                ja: 'カメラ切替',
                ko: '카메라 전환',
              ),
              onTap: () => unawaited(_session.switchCamera()),
            ),
            _extendBtn(
              img: '$_assetDir/hangup.png',
              tips: i18n.t(
                zhHans: '挂断',
                zhHant: '掛斷',
                en: 'Hang up',
                ja: '終了',
                ko: '종료',
              ),
              onTap: _onHangupOrCancel,
            ),
            _extendBtn(
              img: _session.camEnabled
                  ? '$_assetDir/camera_on.png'
                  : '$_assetDir/camera_off.png',
              tips: _session.camEnabled
                  ? i18n.t(
                      zhHans: '摄像头已开',
                      zhHant: '攝像頭已開',
                      en: 'Camera on',
                      ja: 'カメラオン',
                      ko: '카메라 켜짐',
                    )
                  : i18n.t(
                      zhHans: '摄像头已关',
                      zhHant: '攝像頭已關',
                      en: 'Camera off',
                      ja: 'カメラオフ',
                      ko: '카메라 꺼짐',
                    ),
              onTap: () =>
                  unawaited(_session.setCameraEnabled(!_session.camEnabled)),
            ),
          ],
        );
      }

      // Video accepted: two rows like TUICallKit SingleFunctionWidget
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _micBtn(i18n),
              _speakerBtn(i18n),
              _cameraBtn(i18n),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 100),
              _extendBtn(
                img: '$_assetDir/hangup.png',
                tips: i18n.t(
                  zhHans: '挂断',
                  zhHant: '掛斷',
                  en: 'Hang up',
                  ja: '終了',
                  ko: '종료',
                ),
                onTap: _onHangupOrCancel,
              ),
              _session.camEnabled
                  ? _extendBtn(
                      img: '$_assetDir/switch_camera.png',
                      tips: '',
                      imgHeight: 28,
                      imgOffsetX: -16,
                      // Visual stays 28px; enlarge hit target so flip isn't finicky.
                      minTapWidth: 100,
                      minTapHeight: 60,
                      onTap: () => unawaited(_session.switchCamera()),
                    )
                  : const SizedBox(width: 100),
            ],
          ),
        ],
      );
    }

    // Audio: mute | hangup | speaker
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _micBtn(i18n),
        _extendBtn(
          img: '$_assetDir/hangup.png',
          tips: i18n.t(
            zhHans: '挂断',
            zhHant: '掛斷',
            en: 'Hang up',
            ja: '終了',
            ko: '종료',
          ),
          onTap: _onHangupOrCancel,
        ),
        _speakerBtn(i18n),
      ],
    );
  }

  Widget _micBtn(AppI18n i18n) {
    final muted = !_session.micEnabled;
    return _extendBtn(
      img: muted ? '$_assetDir/mute_on.png' : '$_assetDir/mute.png',
      tips: muted
          ? i18n.t(
              zhHans: '麦克风已关',
              zhHant: '麥克風已關',
              en: 'Mic off',
              ja: 'マイクオフ',
              ko: '마이크 꺼짐',
            )
          : i18n.t(
              zhHans: '麦克风已开',
              zhHant: '麥克風已開',
              en: 'Mic on',
              ja: 'マイクオン',
              ko: '마이크 켜짐',
            ),
      onTap: () =>
          unawaited(_session.setMicrophoneEnabled(!_session.micEnabled)),
    );
  }

  Widget _speakerBtn(AppI18n i18n) {
    return _extendBtn(
      img: _session.speakerOn
          ? '$_assetDir/handsfree_on.png'
          : '$_assetDir/handsfree.png',
      tips: _session.speakerOn
          ? i18n.t(
              zhHans: '扬声器已开',
              zhHant: '揚聲器已開',
              en: 'Speaker on',
              ja: 'スピーカーオン',
              ko: '스피커 켜짐',
            )
          : i18n.t(
              zhHans: '扬声器已关',
              zhHant: '揚聲器已關',
              en: 'Speaker off',
              ja: 'スピーカーオフ',
              ko: '스피커 꺼짐',
            ),
      onTap: () => unawaited(_session.setSpeakerphoneOn(!_session.speakerOn)),
    );
  }

  Widget _cameraBtn(AppI18n i18n) {
    return _extendBtn(
      img: _session.camEnabled
          ? '$_assetDir/camera_on.png'
          : '$_assetDir/camera_off.png',
      tips: _session.camEnabled
          ? i18n.t(
              zhHans: '摄像头已开',
              zhHant: '攝像頭已開',
              en: 'Camera on',
              ja: 'カメラオン',
              ko: '카메라 켜짐',
            )
          : i18n.t(
              zhHans: '摄像头已关',
              zhHant: '攝像頭已關',
              en: 'Camera off',
              ja: 'カメラオフ',
              ko: '카메라 꺼짐',
            ),
      onTap: () => unawaited(_session.setCameraEnabled(!_session.camEnabled)),
    );
  }

  /// Geometry matches TUICallKit [ExtendButton]: img 60×60, tip slot 100×15 + top 10.
  Widget _extendBtn({
    required String img,
    required String tips,
    required VoidCallback onTap,
    double imgHeight = 60,
    double imgOffsetX = 0,
    double? minTapWidth,
    double? minTapHeight,
  }) {
    final column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(imgOffsetX, 0),
          child: SizedBox(
            height: imgHeight,
            width: imgHeight,
            child: Image.asset(img),
          ),
        ),
        Container(
          width: 100,
          height: 15,
          margin: const EdgeInsets.only(top: 10),
          alignment: Alignment.center,
          child: Text(
            tips,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _tipColor),
          ),
        ),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: (minTapWidth != null || minTapHeight != null)
          ? SizedBox(
              width: minTapWidth,
              height: minTapHeight,
              child: Center(child: column),
            )
          : column,
    );
  }

  Widget _buildBigVideo() {
    final local = _session.localVideoTrack;
    final remote = _session.remoteVideoTrack;
    final inSystemPip = LiveKitCallSystemUi.instance.systemPipActive.value;
    // Connected or media already publishing — prefer remote on fullscreen.
    final showLocalBig =
        inSystemPip ? (remote == null && local != null) : _localIsBig;
    final track = showLocalBig ? local : remote;
    final mirror = showLocalBig;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_isConnected) {
            setState(() => _chromeHidden = !_chromeHidden);
          }
        },
        child: ColoredBox(
          color: Colors.black54,
          child: track != null
              ? IgnorePointer(
                  child: VideoTrackRenderer(
                    track,
                    fit: VideoViewFit.cover,
                    renderMode: VideoRenderMode.texture,
                    mirrorMode: mirror
                        ? VideoViewMirrorMode.mirror
                        : VideoViewMirrorMode.off,
                  ),
                )
              : IgnorePointer(
                  child: Center(
                    child: AppUserAvatar(
                      faceUrl: _peerFaceUrl,
                      showName: _peerName,
                      size: 80,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSmallVideo(Size size) {
    final local = _session.localVideoTrack;
    final remote = _session.remoteVideoTrack;
    final showRemoteSmall = _localIsBig;
    final track = showRemoteSmall ? remote : local;
    final mirror = !showRemoteSmall;

    // Match TUICallKit geometry. Critically: pin BOTH width and height on
    // Positioned. flutter_webrtc's RTCVideoView sizes itself to
    // constraints.maxWidth × constraints.maxHeight; with only top/right set,
    // maxHeight ≈ screen height and the pip becomes a full-height grey strip.
    return Positioned(
      top: _smallTop - 40,
      right: _smallRight,
      width: _pipWidth,
      height: _pipHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _localIsBig = !_localIsBig),
        onPanUpdate: (details) {
          setState(() {
            _smallRight -= details.delta.dx;
            _smallTop += details.delta.dy;
            if (_smallTop < 100) _smallTop = 100;
            final limit = size.height - _pipHeight;
            if (_smallTop > limit) _smallTop = limit;
            if (_smallRight < 0) _smallRight = 0;
            if (_smallRight > size.width - _pipWidth) {
              _smallRight = size.width - _pipWidth;
            }
          });
        },
        child: ClipRect(
          child: ColoredBox(
            color: Colors.black54,
            child: track != null
                ? IgnorePointer(
                    child: VideoTrackRenderer(
                      track,
                      fit: VideoViewFit.cover,
                      renderMode: VideoRenderMode.texture,
                      mirrorMode: mirror
                          ? VideoViewMirrorMode.mirror
                          : VideoViewMirrorMode.off,
                    ),
                  )
                : IgnorePointer(
                    child: Center(
                      child: AppUserAvatar(
                        faceUrl: showRemoteSmall
                            ? _peerFaceUrl
                            : UserAvatarHelper.currentSelfFaceUrl(),
                        showName: showRemoteSmall ? _peerName : '',
                        size: 80,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
