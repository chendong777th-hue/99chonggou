import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_dispatch_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_im_payload.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_replay_guard.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_send_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order_events.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_friend_message_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 支付 REST 成功后的钱包卡片直发：不依赖 Chat 页是否还在监听。
class WalletCardImSender {
  WalletCardImSender._();

  static final WalletCardImSender instance = WalletCardImSender._();

  final WalletCardSendService _sendSvc = WalletCardSendService();

  Future<bool> sendAfterRest(
    Map<String, dynamic> payload, {
    WalletCardSendSource source = WalletCardSendSource.payment,
  }) async {
    WalletCardDispatchService.instance.enqueue(payload);
    final sent = await send(payload, source: source);
    WalletOrderEvents.notifyChatCard(payload);
    return sent;
  }

  Future<bool> send(
    Map<String, dynamic> payload, {
    WalletCardSendSource source = WalletCardSendSource.payment,
  }) async {
    final orderId = payload['orderId']?.toString() ?? '';
    final clientOrderId = payload['clientOrderId']?.toString() ?? '';
    final target = WalletCardImPayload.resolveTarget(payload);
    if (!target.isValid) {
      debugPrint(
        'wallet-card skip empty-target clientOrderId=$clientOrderId '
        'conv=${payload['conversationId']}',
      );
      return false;
    }

    final allowed = await WalletCardReplayGuard.instance.allowSend(
      orderId: orderId,
      clientOrderId: clientOrderId,
      source: source,
    );
    if (!allowed) {
      debugPrint(
        'wallet-card skip replay-guard clientOrderId=$clientOrderId '
        'source=${source.name}',
      );
      if (await WalletCardReplayGuard.instance.alreadySent(
        orderId: orderId,
        clientOrderId: clientOrderId,
      )) {
        WalletCardDispatchService.instance.removeMatching(payload);
        await _sendSvc.markSent(payload);
        return true;
      }
      return false;
    }

    if (!WalletCardReplayGuard.instance.tryBeginSend(
      orderId: orderId,
      clientOrderId: clientOrderId,
    )) {
      debugPrint('wallet-card skip inflight clientOrderId=$clientOrderId');
      return false;
    }

    try {
      if (target.receiverUserId.isNotEmpty) {
        C2cFriendMessageGuard.trustCanSendHint(
          target.receiverUserId,
          source: 'wallet_card_outbound',
        );
      }

      await _sendSvc.markSending(
        payload,
        requireCanRetry: source != WalletCardSendSource.payment,
      );

      final convId = target.isGroup ? target.groupId : target.receiverUserId;
      final data = WalletCardImPayload.buildCustomData(
        payload,
        conversationId: convId,
      );
      final sdk = TIMUIKitCore.getSDKInstance();
      final created = await sdk.getMessageManager().createCustomMessage(
            data: jsonEncode(data),
          );
      final msg = created.data?.messageInfo;
      if (created.code != 0 || msg == null) {
        debugPrint(
          'wallet-card createCustomMessage failed code=${created.code} '
          'desc=${created.desc} clientOrderId=$clientOrderId',
        );
        await _markFailed(payload, source);
        return false;
      }

      final sendResult =
          await ChatExternalMessageSender.sendCreatedMessageDetailed(
        messageInfo: msg,
        receiverUserId: target.receiverUserId,
        groupId: target.groupId,
        reason: 'wallet_card_sent',
      );
      if (sendResult.state == ExternalMessageSendState.outcomeUnknown) {
        debugPrint(
          'wallet-card outcome unknown; keep pending for adoption '
          'clientOrderId=$clientOrderId',
        );
        return true;
      }
      if (!sendResult.succeeded) {
        debugPrint(
          'wallet-card sendMessage failed clientOrderId=$clientOrderId '
          'group=${target.groupId} peer=${target.receiverUserId}',
        );
        await _markFailed(payload, source);
        return false;
      }

      WalletCardDispatchService.instance.removeMatching(payload);
      await WalletCardReplayGuard.instance.rememberImSent(
        orderId: orderId,
        clientOrderId: clientOrderId,
      );
      await _sendSvc.markSent(payload);
      return true;
    } catch (e) {
      debugPrint('wallet-card send error clientOrderId=$clientOrderId err=$e');
      await _markFailed(payload, source);
      return false;
    } finally {
      WalletCardReplayGuard.instance.endSend(
        orderId: orderId,
        clientOrderId: clientOrderId,
      );
    }
  }

  Future<void> _markFailed(
    Map<String, dynamic> payload,
    WalletCardSendSource source,
  ) async {
    final failed = await _sendSvc.markFailed(payload);
    WalletOrderEvents.notifyChatCardSendFailed(
      failed.toPayload(),
      source: source.name,
    );
  }
}
