import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'wallet_order.dart';
import 'wallet_pending_store.dart';

class WalletCardSendResult {
  final bool updated;
  final String orderId;
  final String clientOrderId;
  final String conversationId;
  final String type;
  final String status;
  final int retryCount;
  final bool manualRequired;

  const WalletCardSendResult({
    required this.updated,
    this.orderId = '',
    this.clientOrderId = '',
    this.conversationId = '',
    this.type = '',
    this.status = '',
    this.retryCount = 0,
    this.manualRequired = false,
  });

  Map<String, dynamic> toPayload() {
    return {
      'type': type,
      'sendSource': 'manual',
      'orderId': orderId,
      'clientOrderId': clientOrderId,
      'conversationId': conversationId,
      'cardSendStatus': status,
      'retryCount': retryCount,
      'manualRequired': manualRequired,
    };
  }
}

class WalletCardSendService {
  static const int maxRetryCount = 5;
  static const Duration staleSendingAfter = Duration(minutes: 2);

  final WalletPendingStore store;

  WalletCardSendService({WalletPendingStore? pendingStore})
      : store = pendingStore ?? WalletPendingStore();

  Future<List<Map<String, dynamic>>> retryPayloadsForConversation(
    String conversationId, {
    int limit = 5,
  }) async {
    if (conversationId.trim().isEmpty) return const [];

    final items = await store.load();
    final now = DateTime.now();
    return items
        .where((e) => e.conversationId == conversationId)
        .where(_hasOrderKey)
        .where((e) => _canRetry(e, now))
        .take(limit)
        .map(_payloadOf)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> retryPayloads({
    int limit = 20,
  }) async {
    final items = await store.load();
    final now = DateTime.now();
    return items
        .where(_hasOrderKey)
        .where((e) => _canRetry(e, now))
        .take(limit)
        .map(_payloadOf)
        .toList(growable: false);
  }

  bool _hasOrderKey(WalletOrderDraft item) {
    return item.needsChatCard &&
        (item.serverOrderId.trim().isNotEmpty ||
            item.clientOrderId.trim().isNotEmpty);
  }

  Future<bool> markSending(
    Map<String, dynamic> payload, {
    bool requireCanRetry = true,
  }) async {
    final ret = await _update(
      payload,
      status: 'sending',
      requireCanRetry: requireCanRetry,
    );
    if (ret.updated) return true;
    // 支付当场发卡：草稿缺失/状态不满足重试时仍要发 IM，避免扣款成功卡片丢失。
    return !requireCanRetry;
  }

  Future<bool> markSent(Map<String, dynamic> payload) async {
    final ret = await _update(
      payload,
      status: 'sent',
      removeIfDone: true,
    );
    return ret.updated;
  }

  Future<WalletCardSendResult> markFailed(Map<String, dynamic> payload) {
    return _update(
      payload,
      status: 'failed',
      bumpRetry: true,
      markManualWhenMax: true,
    );
  }

  Future<Map<String, dynamic>?> resetForManualSend(Map<String, dynamic> payload) async {
    final ret = await _update(
      payload,
      status: 'idle',
      resetRetry: true,
      allowManual: true,
    );
    if (!ret.updated) return null;
    return ret.toPayload();
  }

  Future<Map<String, dynamic>?> resetForManualSendByClientId(String clientOrderId) async {
    if (clientOrderId.trim().isEmpty) return null;
    final item = await _findByClientOrderId(clientOrderId);
    if (item == null) return null;
    return resetForManualSend(_payloadOf(item));
  }

  Future<bool> ignoreCardFail(String clientOrderId) async {
    if (clientOrderId.trim().isEmpty) return false;
    final item = await _findByClientOrderId(clientOrderId);
    if (item == null) return false;

    if (item.isDoneOrder) {
      await store.remove(item.clientOrderId);
      return true;
    }

    final now = DateTime.now().toIso8601String();
    await store.put(
      item.copyWith(
        cardSendStatus: 'ignored',
        updatedAt: now,
      ),
    );
    return true;
  }

  Future<WalletOrderDraft?> pendingCardForOrder(String orderNo) {
    return pendingCardForOrderKeys([orderNo]);
  }

  Future<WalletOrderDraft?> pendingCardForOrderKeys(List<String> keys) async {
    final normalized = keys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '--')
        .toSet();

    if (normalized.isEmpty) return null;

    final items = await store.load();
    for (final item in items) {
      final ids = <String>{
        item.clientOrderId.trim(),
        item.serverOrderId.trim(),
      }..removeWhere((e) => e.isEmpty || e == '--');

      if (ids.any(normalized.contains)) {
        if (item.needsChatCard && !item.cardSent && !item.cardIgnored) {
          return item;
        }
      }
    }
    return null;
  }

  bool _canRetry(WalletOrderDraft item, DateTime now) {
    if (item.cardSendRetryCount >= maxRetryCount) return false;

    final state = WalletOrderStateX.fromName(item.orderState);
    if (item.isDoneOrder && state != WalletOrderState.success) return false;

    if (item.cardSendStatus == 'idle') return true;
    if (item.cardSendStatus == 'failed') return true;

    if (item.cardSendStatus != 'sending') return false;

    final last = DateTime.tryParse(item.lastCardSendAt);
    if (last == null) return true;
    return now.difference(last) > staleSendingAfter;
  }

  Map<String, dynamic> _payloadOf(WalletOrderDraft item) {
    final type = item.businessType.isNotEmpty
        ? item.businessType
        : item.type == WalletOrderType.redPacket
            ? 'wallet_red_packet'
            : 'wallet_transfer';
    final login = TIMUIKitCore.getInstance().loginInfo;
    final senderId = login.userID.trim();
    final senderName = login.loginUser?.nickName?.trim() ?? '';
    return {
      'type': type,
      'sendSource': 'manual',
      'orderId': item.serverOrderId,
      'clientOrderId': item.clientOrderId,
      'conversationId': item.conversationId,
      'currency': _normalizeCurrency(item.coin),
      'amount': item.amountMinor,
      'status': type == 'wallet_group_transfer'
          ? 'success'
          : _cardStatus(item.orderState),
      'greeting': item.memo,
      if (item.memo.trim().isNotEmpty) 'memo': item.memo.trim(),
      if (type == 'wallet_group_transfer') 'packetType': 'GROUP_TRANSFER',
      if (senderId.isNotEmpty) 'senderId': senderId,
      if (senderId.isNotEmpty) 'senderUserId': senderId,
      if (senderId.isNotEmpty) 'fromUserId': senderId,
      if (senderName.isNotEmpty) 'senderName': senderName,
      if (senderName.isNotEmpty) 'fromUserName': senderName,
      'receiverId': item.receiverId,
      'receiverName': item.receiverName,
      'toUserId': item.receiverId,
      'toUserName': item.receiverName,
      'isGroup': type == 'wallet_group_transfer' ||
          ChatIdFormat.looksLikeCommunityGroupId(item.conversationId) ||
          ChatIdFormat.isIMGroupOrCommunityId(item.conversationId),
    };
  }

  String _normalizeCurrency(String raw) {
    final text = raw.trim().toUpperCase();
    if (text == '99' || text == '99币' || text == '元') {
      return '99';
    }
    return text;
  }

  String _cardStatus(String raw) {
    final state = WalletOrderStateX.fromName(raw);
    switch (state) {
      case WalletOrderState.success:
        return 'success';
      case WalletOrderState.failed:
      case WalletOrderState.expired:
      case WalletOrderState.cancelled:
      case WalletOrderState.refunded:
        return 'failed';
      case WalletOrderState.idle:
      case WalletOrderState.created:
      case WalletOrderState.confirming:
      case WalletOrderState.password:
      case WalletOrderState.submitting:
      case WalletOrderState.accepted:
      case WalletOrderState.pending:
      case WalletOrderState.unknown:
        return 'pending';
    }
  }

  WalletCardSendResult _resultOf(
    WalletOrderDraft item, {
    required bool updated,
    required String status,
    required int retryCount,
  }) {
    final payload = _payloadOf(item);
    return WalletCardSendResult(
      updated: updated,
      orderId: payload['orderId']?.toString() ?? '',
      clientOrderId: payload['clientOrderId']?.toString() ?? '',
      conversationId: payload['conversationId']?.toString() ?? '',
      type: payload['type']?.toString() ?? '',
      status: status,
      retryCount: retryCount,
      manualRequired: status == 'manual',
    );
  }

  Future<WalletOrderDraft?> _findByClientOrderId(String clientOrderId) async {
    final items = await store.load();
    for (final item in items) {
      if (item.clientOrderId == clientOrderId) return item;
    }
    return null;
  }

  Future<WalletCardSendResult> _update(
    Map<String, dynamic> payload, {
    required String status,
    bool bumpRetry = false,
    bool removeIfDone = false,
    bool requireCanRetry = false,
    bool markManualWhenMax = false,
    bool resetRetry = false,
    bool allowManual = false,
  }) async {
    final clientOrderId = payload['clientOrderId']?.toString() ?? '';
    if (clientOrderId.trim().isEmpty) {
      return const WalletCardSendResult(updated: false);
    }

    final target = await _findByClientOrderId(clientOrderId);
    if (target == null) {
      return WalletCardSendResult(
        updated: false,
        clientOrderId: clientOrderId,
        orderId: payload['orderId']?.toString() ?? '',
        conversationId: payload['conversationId']?.toString() ?? '',
        type: payload['type']?.toString() ?? '',
      );
    }

    final nowTime = DateTime.now();
    if (requireCanRetry && !_canRetry(target, nowTime)) {
      return _resultOf(
        target,
        updated: false,
        status: target.cardSendStatus,
        retryCount: target.cardSendRetryCount,
      );
    }

    if (!allowManual && target.cardSendStatus == 'manual') {
      return _resultOf(
        target,
        updated: false,
        status: target.cardSendStatus,
        retryCount: target.cardSendRetryCount,
      );
    }

    final now = nowTime.toIso8601String();
    final nextRetry = resetRetry
        ? 0
        : bumpRetry
            ? target.cardSendRetryCount + 1
            : target.cardSendRetryCount;
    final nextStatus = markManualWhenMax && nextRetry >= maxRetryCount
        ? 'manual'
        : status;

    final updated = target.copyWith(
      cardSendStatus: nextStatus,
      cardSendRetryCount: nextRetry,
      lastCardSendAt: now,
      updatedAt: now,
    );

    if (removeIfDone && updated.isDoneOrder) {
      await store.remove(updated.clientOrderId);
      return _resultOf(
        updated,
        updated: true,
        status: nextStatus,
        retryCount: nextRetry,
      );
    }

    await store.put(updated);
    return _resultOf(
      updated,
      updated: true,
      status: nextStatus,
      retryCount: nextRetry,
    );
  }
}
