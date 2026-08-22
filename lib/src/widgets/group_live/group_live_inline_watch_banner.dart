import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_live_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_video_player.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// In-chat 16:9 live preview (watch while chatting), matching the product mock.
class GroupLiveInlineWatchBanner extends StatefulWidget {
  const GroupLiveInlineWatchBanner({
    super.key,
    required this.session,
    required this.onClose,
    this.anchorFaceUrl = '',
  });

  final GroupLiveSession session;
  final VoidCallback onClose;
  final String anchorFaceUrl;

  @override
  State<GroupLiveInlineWatchBanner> createState() =>
      _GroupLiveInlineWatchBannerState();
}

class _GroupLiveInlineWatchBannerState
    extends State<GroupLiveInlineWatchBanner> {
  GroupLivePlayInfo? _playInfo;
  bool _loading = true;
  bool _waitingForPush = false;
  String? _error;
  String _title = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _title = widget.session.roomName.trim();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant GroupLiveInlineWatchBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.session.liveSessionId != widget.session.liveSessionId;
    final becameLive = !oldWidget.session.isLive && widget.session.isLive;
    if (sessionChanged || becameLive) {
      _title = widget.session.roomName.trim();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPollingIfNeeded() {
    _pollTimer?.cancel();
    if (!_waitingForPush) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_waitingForPush) return;
      unawaited(_load(silent: true));
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (LiveKitCallSession.instance.isInCall) {
      if (!mounted) return;
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '通话中无法进入直播间',
        zhHant: '通話中無法進入直播間',
        en: 'Cannot enter live room during a call.',
        ja: '通話中は視聴できません。',
        ko: '통화 중에는 라이브룸에 입장할 수 없습니다.',
      ));
      widget.onClose();
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _waitingForPush = false;
      });
    }

    var liveNow = widget.session.isLive;
    if (!liveNow) {
      try {
        final latest = await GroupLiveApi.instance.sessionDetail(
          liveSessionId: widget.session.liveSessionId,
        );
        liveNow = latest.isLive;
        final roomName = latest.roomName.trim();
        if (roomName.isNotEmpty) {
          _title = roomName;
        }
      } catch (_) {
        // Keep waiting UI when detail refresh fails.
      }
    }

    if (!liveNow) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _waitingForPush = true;
        _error = null;
      });
      _startPollingIfNeeded();
      return;
    }

    try {
      final playInfo = await GroupLiveApi.instance.playInfo(
        liveSessionId: widget.session.liveSessionId,
      );
      if (!mounted) return;
      final roomName = playInfo.roomName.trim();
      if (roomName.isNotEmpty) {
        _title = roomName;
      }
      await _initPlayer(playInfo);
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _loading = false;
        _waitingForPush = false;
        _error = null;
      });
    } on GroupLiveApiException catch (e) {
      if (!mounted) return;
      final code = e.code.trim().toUpperCase();
      final waiting = code == 'LIVE_NOT_LIVE' ||
          code == 'LIVE_NOT_AUTHORIZED_YET' ||
          code.contains('NOT_LIVE');
      setState(() {
        _loading = false;
        _waitingForPush = waiting;
        _error = waiting ? null : GroupLiveErrorMessage.from(e);
      });
      if (waiting) {
        _startPollingIfNeeded();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _waitingForPush = false;
        _error = GroupLiveErrorMessage.from(e);
      });
    }
  }

  Future<void> _initPlayer(GroupLivePlayInfo info) async {
    if (!mounted) return;
    setState(() => _playInfo = info);
  }

  String _waitingText(AppI18n i18n) {
    if (widget.session.status == GroupLiveStatus.scheduled) {
      return i18n.t(
        zhHans: '直播尚未开始，请稍候',
        zhHant: '直播尚未開始，請稍候',
        en: 'Live has not started yet.',
        ja: '配信はまだ始まっていません。',
        ko: '라이브가 아직 시작되지 않았습니다.',
      );
    }
    return i18n.t(
      zhHans: '直播准备中，请稍候…',
      zhHant: '直播準備中，請稍候…',
      en: 'Live is getting ready. Please wait…',
      ja: '配信の準備中です。しばらくお待ちください…',
      ko: '라이브 준비 중입니다. 잠시만 기다려 주세요…',
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final title = _title.isNotEmpty
        ? _title
        : i18n.t(
            zhHans: '群直播',
            zhHant: '群直播',
            en: 'Group Live',
            ja: 'グループ配信',
            ko: '그룹 라이브',
          );

    return ColoredBox(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_playInfo != null)
              GroupLiveVideoPlayer(
                key: ValueKey('live_player_${_playInfo!.liveSessionId}'),
                playInfo: _playInfo!,
                compact: true,
                fit: BoxFit.cover,
              )
            else
              const ColoredBox(color: Color(0xFF111111)),
            if (_loading)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            if (_waitingForPush && !_loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sensors,
                        color: Colors.white70,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _waitingText(i18n),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null && !_loading && !_waitingForPush)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => unawaited(_load()),
                        child: Text(
                          i18n.t(
                            zhHans: '重试',
                            zhHant: '重試',
                            en: 'Retry',
                            ja: '再試行',
                            ko: '재시도',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 48,
              bottom: 10,
              child: Row(
                children: [
                  AppUserAvatar(
                    faceUrl: widget.anchorFaceUrl,
                    showName: widget.session.anchorUserId,
                    size: 28,
                    type: 1,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
