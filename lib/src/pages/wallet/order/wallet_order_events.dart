import 'package:flutter/foundation.dart';

import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';

class WalletOrderEvents {
  WalletOrderEvents._();

  static const Duration _chatCardFailNoticeWindow = Duration(seconds: 8);

  static final ValueNotifier<int> balanceChanged = ValueNotifier<int>(0);
  static final ValueNotifier<int> recordChanged = ValueNotifier<int>(0);
  static final ValueNotifier<Map<String, dynamic>?> chatCardPayload =
      ValueNotifier<Map<String, dynamic>?>(null);
  static final ValueNotifier<Map<String, dynamic>?> chatCardSendFailedPayload =
      ValueNotifier<Map<String, dynamic>?>(null);
  static final Map<String, DateTime> _chatCardFailNoticeClaims =
      <String, DateTime>{};

  static void notifyBalance() => balanceChanged.value++;

  static void notifyRecord() => recordChanged.value++;

  static void notifyChatCard([Map<String, dynamic>? data]) {
    chatCardPayload.value = data;
    ConversationRefreshBus.instance.requestRefresh(reason: 'wallet_chat_card');
  }

  static void notifyChatCardSendFailed(
    Map<String, dynamic> data, {
    String source = 'autoRetry',
  }) {
    chatCardSendFailedPayload.value = {
      ...data,
      'source': source,
    };
    ConversationRefreshBus.instance
        .requestRefresh(reason: 'wallet_chat_card_failed');
  }

  static bool claimChatCardFailNotice(Map<String, dynamic> data) {
    final key = _chatCardFailNoticeKey(data);
    if (key.isEmpty) {
      return true;
    }
    final now = DateTime.now();
    _chatCardFailNoticeClaims.removeWhere(
      (_, claimedAt) => now.difference(claimedAt) > _chatCardFailNoticeWindow,
    );
    final last = _chatCardFailNoticeClaims[key];
    if (last != null && now.difference(last) <= _chatCardFailNoticeWindow) {
      return false;
    }
    _chatCardFailNoticeClaims[key] = now;
    return true;
  }

  static String _chatCardFailNoticeKey(Map<String, dynamic> data) {
    final clientOrderId = data['clientOrderId']?.toString().trim() ?? '';
    if (clientOrderId.isNotEmpty) {
      return clientOrderId;
    }
    return data['orderId']?.toString().trim() ?? '';
  }
}
