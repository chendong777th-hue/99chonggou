import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order_events.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_sender_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// TCP `red_packet_changed`：仅发包人收到，用于刷新红包卡片状态。
/// 领取灰字由领取端 App `sendMessage`（`red_packet_claim_notice`）发出，TCP 不画 tip。
class RedPacketRealtimeSyncService {
  RedPacketRealtimeSyncService._();

  static final RedPacketRealtimeSyncService instance =
      RedPacketRealtimeSyncService._();

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose realtime tracing disabled.
  }

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'red_packet_changed') {
      return;
    }

    final action = event.action?.trim().toLowerCase() ?? '';
    if (action == 'claimed' || action == 'completed') {
      _log('ignore deprecated red_packet_changed action=$action');
      return;
    }
    if (action != 'card_refresh' && action != 'expired') {
      _log('skip red_packet_changed with unknown action=$action');
      return;
    }

    final packetId = event.packetId;
    if (packetId == null || packetId <= 0) {
      _log('skip red_packet_changed with invalid packetId=$packetId');
      return;
    }

    final senderUserId = event.senderUserId?.trim() ?? '';
    if (senderUserId.isEmpty) {
      _log('skip red_packet_changed with empty senderUserId');
      return;
    }

    final selfId = _selfUserId();
    if (selfId.isEmpty || !_isSameUser(senderUserId, selfId)) {
      _log(
        'skip red_packet_changed sender=$senderUserId self=$selfId '
        'packetId=$packetId',
      );
      return;
    }

    final refreshEvent = RedPacketSenderRefreshEvent.fromRealtime(event);
    _log(
      'red_packet_changed action=$action packetId=$packetId '
      'groupId=${refreshEvent.groupId ?? ''} '
      'remaining=${refreshEvent.remainingCount ?? -1}',
    );

    if (action == 'expired') {
      _showExpiredToast();
    }
    RedPacketSenderRefreshBus.instance.notify(refreshEvent);
    WalletOrderEvents.notifyRecord();
    if (action == 'expired') {
      WalletOrderEvents.notifyBalance();
    }
  }

  void _showExpiredToast() {
    ToastUtils.toast(
      AppI18n.current.t(
        zhHans: '红包未领完部分已退回您的钱包',
        zhHant: '紅包未領完部分已退回您的錢包',
        en: 'Unclaimed amount has been refunded to your wallet',
        ja: '未受取分はウォレットに返金されました',
        ko: '미수령 금액이 지갑으로 환불되었습니다',
      ),
    );
  }

  String _selfUserId() {
    try {
      final fromCore = ChatIdFormat.rawUserUid(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
      if (fromCore.isNotEmpty) {
        return fromCore;
      }
    } catch (_) {}
    return ChatIdFormat.rawUserUid(
      serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID,
    );
  }

  bool _isSameUser(String? a, String? b) {
    final left = ChatIdFormat.rawUserUid(a);
    final right = ChatIdFormat.rawUserUid(b);
    return left.isNotEmpty && right.isNotEmpty && left == right;
  }
}
