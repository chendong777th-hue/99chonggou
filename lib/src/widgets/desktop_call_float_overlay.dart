import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';

/// In-app LiveKit call float — layout matches TUICallKit SingleCallFloatWindowView.
///
/// Audio: 72×72 white card, green dial icon + timer.
/// Video: 110×196, local preview while waiting, remote when available.
class DesktopCallFloatOverlay extends StatefulWidget {
  final Widget child;

  const DesktopCallFloatOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DesktopCallFloatOverlay> createState() =>
      _DesktopCallFloatOverlayState();
}

class _DesktopCallFloatOverlayState extends State<DesktopCallFloatOverlay> {
  final _service = DesktopCallFloatService.instance;
  Timer? _tickTimer;

  static const Color _audioGreen = Color(0xFF1CB056);
  static const Color _videoUnavailableBg = Color(0xFF3C3C3C);

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    LiveKitCallSession.instance.addListener(_onServiceChanged);
    unawaited(_service.ensureAttached());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_service.visible && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _service.removeListener(_onServiceChanged);
    LiveKitCallSession.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  /// TUICallKit: audio 72×72, video 110×196.
  Size get _panelSize {
    if (_service.isVideoCall) {
      return const Size(110, 196);
    }
    return const Size(72, 72);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_service.visible) {
      return widget.child;
    }

    final screen = MediaQuery.sizeOf(context);
    final panelSize = _panelSize;
    _service.ensureDefaultPosition(screen, panelSize);
    final session = LiveKitCallSession.instance;
    final i18n = AppI18n.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: _service.position.dx,
          top: _service.position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              _service.updatePosition(details.delta, screen, panelSize);
            },
            onPanEnd: (_) => _service.snapToEdge(screen, panelSize),
            onTap: () => unawaited(_service.restoreCallPage()),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(10),
              color: _service.isVideoCall ? Colors.black : Colors.white,
              child: Container(
                width: panelSize.width,
                height: panelSize.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _service.isVideoCall ? Colors.black : Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: _service.isVideoCall
                    ? _buildVideoFloat(session, i18n)
                    : _buildAudioFloat(session, i18n),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioFloat(LiveKitCallSession session, AppI18n i18n) {
    final duration = _service.durationLabel();
    final waiting = session.phase == LiveKitCallPhase.ringingOut ||
        session.phase == LiveKitCallPhase.ringingIn ||
        session.phase == LiveKitCallPhase.connecting;
    final label = waiting
        ? i18n.t(
            zhHans: '等待接听',
            zhHant: '等待接聽',
            en: 'Waiting',
            ja: '応答待ち',
            ko: '대기 중',
          )
        : (duration.isNotEmpty ? duration : '00:00');

    return Column(
      children: [
        const SizedBox(height: 12),
        Image.asset(
          'assets/call_ui/icon_float_dialing.png',
          width: 36,
          height: 36,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.call,
            size: 36,
            color: _audioGreen,
          ),
        ),
        const SizedBox(height: 0),
        Expanded(
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _audioGreen,
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoFloat(LiveKitCallSession session, AppI18n i18n) {
    final waiting = session.phase == LiveKitCallPhase.ringingOut ||
        session.phase == LiveKitCallPhase.ringingIn ||
        session.phase == LiveKitCallPhase.connecting;
    final remote = session.remoteVideoTrack;
    final local = session.localVideoTrack;
    final waitingText = i18n.t(
      zhHans: '等待接听',
      zhHant: '等待接聽',
      en: 'Waiting',
      ja: '応答待ち',
      ko: '대기 중',
    );

    if (waiting) {
      // TUICallKit: local preview + waiting label.
      return Stack(
        fit: StackFit.expand,
        children: [
          if (local != null)
            IgnorePointer(
              child: VideoTrackRenderer(
                local,
                fit: VideoViewFit.cover,
                renderMode: VideoRenderMode.texture,
                mirrorMode: VideoViewMirrorMode.mirror,
              ),
            )
          else
            const ColoredBox(color: Colors.black),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Text(
              waitingText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      );
    }

    if (remote != null) {
      // Accepted + remote video available.
      return IgnorePointer(
        child: VideoTrackRenderer(
          remote,
          fit: VideoViewFit.cover,
          renderMode: VideoRenderMode.texture,
          mirrorMode: VideoViewMirrorMode.off,
        ),
      );
    }

    // Accepted but remote video unavailable — gray + avatar.
    return ColoredBox(
      color: _videoUnavailableBg,
      child: Center(
        child: AppUserAvatar(
          faceUrl: _service.peerFaceUrl,
          showName: _service.peerLabel(),
          size: 45,
        ),
      ),
    );
  }
}
