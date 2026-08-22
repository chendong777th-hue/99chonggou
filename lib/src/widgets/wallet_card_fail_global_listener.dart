import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_pending_list_screen.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order_events.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

/// 非当前 Chat 会话时，钱包卡片发送失败（需人工）的全局 SnackBar。
class WalletCardFailGlobalListener extends StatefulWidget {
  const WalletCardFailGlobalListener({super.key, required this.child});

  final Widget child;

  @override
  State<WalletCardFailGlobalListener> createState() =>
      _WalletCardFailGlobalListenerState();
}

class _WalletCardFailGlobalListenerState
    extends State<WalletCardFailGlobalListener> {
  @override
  void initState() {
    super.initState();
    WalletOrderEvents.chatCardSendFailedPayload
        .addListener(_onWalletCardSendFailed);
  }

  @override
  void dispose() {
    WalletOrderEvents.chatCardSendFailedPayload
        .removeListener(_onWalletCardSendFailed);
    super.dispose();
  }

  void _onWalletCardSendFailed() {
    final data = WalletOrderEvents.chatCardSendFailedPayload.value;
    if (data == null || data.isEmpty) return;
    if (data['manualRequired'] != true) return;

    final payloadConvId = data['conversationId']?.toString() ?? '';
    final foreground = ActiveChatRegistry.instance.activeConversationId ?? '';
    if (payloadConvId.isNotEmpty &&
        foreground.isNotEmpty &&
        MessageConversationId.sameConversation(payloadConvId, foreground)) {
      return;
    }

    if (!WalletOrderEvents.claimChatCardFailNotice(data)) return;

    final navContext = AppNavigator.key.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final i18n = AppI18n.of(navContext);
    final retryCount = data['retryCount']?.toString() ?? '';
    final tip = retryCount.isEmpty
        ? i18n.t(
            zhHans: '钱包消息发送失败，可在待处理订单中重试',
            zhHant: '錢包訊息傳送失敗，可在待處理訂單中重試',
            en: 'Wallet message failed to send. Retry from pending orders.',
            ja: 'ウォレットメッセージの送信に失敗しました。保留中の注文から再試行できます。',
            ko: '지갑 메시지 전송 실패. 대기 중인 주문에서 다시 시도하세요.',
          )
        : i18n.format(
            zhHans: '钱包消息发送失败（已重试{option1}次），可在待处理订单中处理',
            zhHant: '錢包訊息傳送失敗（已重試{option1}次），可在待處理訂單中處理',
            en: 'Wallet message failed after {option1} retries. Open pending orders.',
            ja: 'ウォレットメッセージの送信に失敗（{option1}回）。保留注文から処理してください。',
            ko: '지갑 메시지 전송 실패 ({option1}회). 대기 주문에서 처리하세요.',
            vars: {'option1': retryCount},
          );

    AppDialog.showNotice(
      title: i18n.t(
        zhHans: '钱包消息',
        zhHant: '錢包訊息',
        en: 'Wallet message',
        ja: 'ウォレットメッセージ',
        ko: '지갑 메시지',
      ),
      message: tip,
      actionText: i18n.t(
        zhHans: '查看',
        zhHant: '查看',
        en: 'View',
        ja: '表示',
        ko: '보기',
      ),
      duration: const Duration(seconds: 6),
      onTap: () {
        AppNavigator.key.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => const WalletPendingListScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
