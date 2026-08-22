import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_tip_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_live_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_video_player.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class GroupLiveRoomPage extends StatefulWidget {
  const GroupLiveRoomPage({
    super.key,
    required this.liveSessionId,
    this.initialSession,
  });

  final String liveSessionId;
  final GroupLiveSession? initialSession;

  static Future<void> open(
    BuildContext context, {
    required String liveSessionId,
    GroupLiveSession? initialSession,
  }) {
    if (LiveKitCallSession.instance.isInCall) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '通话中无法进入直播间',
        zhHant: '通話中無法進入直播間',
        en: 'Cannot enter live room during a call.',
        ja: '通話中は視聴できません。',
        ko: '통화 중에는 라이브룸에 입장할 수 없습니다.',
      ));
      return Future.value();
    }
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        builder: (_) => GroupLiveRoomPage(
          liveSessionId: liveSessionId,
          initialSession: initialSession,
        ),
      ),
    );
  }

  @override
  State<GroupLiveRoomPage> createState() => _GroupLiveRoomPageState();
}

class _GroupLiveRoomPageState extends State<GroupLiveRoomPage> {
  GroupLivePlayInfo? _playInfo;
  GroupLiveSession? _session;
  bool _loading = true;
  String? _error;
  final List<_TipBanner> _tipBanners = <_TipBanner>[];

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    unawaited(_load());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final playInfo = await GroupLiveApi.instance
          .playInfo(liveSessionId: widget.liveSessionId);
      final session = await GroupLiveApi.instance
          .sessionDetail(liveSessionId: widget.liveSessionId);
      if (!mounted) return;
      setState(() {
        _playInfo = playInfo;
        _session = session;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = GroupLiveErrorMessage.from(e);
      });
    }
  }

  void showTipBanner(GroupLiveImPayload payload) {
    if (!mounted || !payload.isTip) return;
    final banner = _TipBanner(payload: payload);
    setState(() => _tipBanners.add(banner));
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _tipBanners.remove(banner));
    });
  }

  Future<void> _openTip() async {
    final anchorId = _playInfo?.anchorUserId ?? _session?.anchorUserId ?? '';
    final currentUserId = TIMUIKitCore.getInstance().loginInfo.userID.trim();
    if (anchorId.isNotEmpty && anchorId == currentUserId) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '不能给自己打赏',
        zhHant: '不能給自己打賞',
        en: 'You cannot tip yourself.',
        ja: '自分自身に投げ銭できません。',
        ko: '본인에게 후원할 수 없습니다.',
      ));
      return;
    }
    await GroupLiveTipSheet.show(
      context,
      liveSessionId: widget.liveSessionId,
      anchorUserId: anchorId,
    );
  }

  Future<void> _stopLive() async {
    final groupId = _session?.groupId ?? '';
    if (groupId.isEmpty) return;
    try {
      await GroupLiveApi.instance.stop(groupId: groupId);
      if (!mounted) return;
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '已结束直播，请在 OBS 中停止推流',
        zhHant: '已結束直播，請在 OBS 中停止推流',
        en: 'Live stopped. Also stop pushing in OBS.',
        ja: '配信を終了しました。OBS も停止してください。',
        ko: '라이브를 종료했습니다. OBS 推流도 중지하세요.',
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(GroupLiveErrorMessage.from(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final title = _playInfo?.roomName.trim().isNotEmpty == true
        ? _playInfo!.roomName
        : (_session?.roomName ??
            i18n.t(
              zhHans: '直播间',
              zhHant: '直播間',
              en: 'Live Room',
              ja: '配信ルーム',
              ko: '라이브룸',
            ));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          if (_session?.isLive == true)
            IconButton(
              tooltip: i18n.t(
                zhHans: '打赏',
                zhHant: '打賞',
                en: 'Tip',
                ja: '投げ銭',
                ko: '후원',
              ),
              onPressed: () => unawaited(_openTip()),
              icon: const Icon(Icons.card_giftcard_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: () => unawaited(_load()))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_playInfo != null)
                      GroupLiveVideoPlayer(
                        key: ValueKey('room_player_${_playInfo!.liveSessionId}'),
                        playInfo: _playInfo!,
                      )
                    else
                      const SizedBox.shrink(),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final banner in _tipBanners)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _LiveTipBanner(banner: banner),
                            ),
                          if (_canStopLive())
                            FilledButton(
                              onPressed: () => unawaited(_stopLive()),
                              child: Text(i18n.t(
                                zhHans: '结束直播',
                                zhHant: '結束直播',
                                en: 'Stop live',
                                ja: '配信終了',
                                ko: '라이브 종료',
                              )),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  bool _canStopLive() {
    return _session?.isLive == true;
  }
}

class _TipBanner {
  _TipBanner({required this.payload});

  final GroupLiveImPayload payload;
}

class _LiveTipBanner extends StatelessWidget {
  const _LiveTipBanner({required this.banner});

  final _TipBanner banner;

  @override
  Widget build(BuildContext context) {
    final amountText = _formatAmount(
      banner.payload.currency,
      banner.payload.amount,
    );
    final memo = banner.payload.memo.trim();
    final text = memo.isNotEmpty ? '$amountText · $memo' : amountText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  String _formatAmount(String currency, int amount) {
    final cur = currency.trim().toUpperCase();
    if (cur == 'USDT') {
      return '${formatUsdtMicro(amount)} USDT';
    }
    if (cur == '99' || cur == 'CNY' || cur == 'PLATFORM') {
      return '${formatPlatformFen(amount)} ${walletDisplayCoin(cur == 'PLATFORM' ? '99' : cur)}';
    }
    return '$amount $cur';
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry,
                child: Text(AppI18n.of(context).t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '재시도',
                ))),
          ],
        ),
      ),
    );
  }
}
