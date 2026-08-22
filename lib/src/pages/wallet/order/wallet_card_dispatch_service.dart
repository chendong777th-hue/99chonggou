import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';

import 'wallet_order_events.dart';

/// 跨会话钱包卡片补发队列：recovery 入队，打开目标会话时 flush。
class WalletCardDispatchService {
  WalletCardDispatchService._();

  static final WalletCardDispatchService instance = WalletCardDispatchService._();

  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];

  int get pendingCount => _queue.length;

  void enqueue(Map<String, dynamic> payload) {
    if (payload.isEmpty) return;
    final key = _key(payload);
    if (key.isEmpty) return;
    if (_queue.any((item) => _key(item) == key)) return;
    _queue.add(Map<String, dynamic>.from(payload));
  }

  void removeMatching(Map<String, dynamic> payload) {
    final key = _key(payload);
    if (key.isEmpty) return;
    _queue.removeWhere((item) => _key(item) == key);
  }

  List<Map<String, dynamic>> takeForConversation(
    String conversationId, {
    int limit = 20,
  }) {
    final convId = conversationId.trim();
    if (convId.isEmpty || limit <= 0) return const [];

    final taken = <Map<String, dynamic>>[];
    _queue.removeWhere((payload) {
      if (taken.length >= limit) return false;
      final payloadConvId = payload['conversationId']?.toString() ?? '';
      if (!MessageConversationId.sameConversation(payloadConvId, convId)) {
        return false;
      }
      taken.add(payload);
      return true;
    });
    return taken;
  }

  void dispatch(Map<String, dynamic> payload) {
    enqueue(payload);
    WalletOrderEvents.notifyChatCard(payload);
  }

  String _key(Map<String, dynamic> payload) {
    final clientOrderId = payload['clientOrderId']?.toString().trim() ?? '';
    if (clientOrderId.isNotEmpty) return clientOrderId;
    return payload['orderId']?.toString().trim() ?? '';
  }

  @visibleForTesting
  void debugClear() => _queue.clear();
}
