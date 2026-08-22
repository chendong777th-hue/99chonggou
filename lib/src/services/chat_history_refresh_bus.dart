import 'dart:async';

import 'package:flutter/foundation.dart';

/// 聊天历史激活总线：合并短时间内的重复 refresh，避免外发消息后多路叠拉。
class ChatHistoryRefreshBus {
  ChatHistoryRefreshBus._();

  static final ChatHistoryRefreshBus instance = ChatHistoryRefreshBus._();

  static const Duration defaultDebounce = Duration(milliseconds: 280);
  static const Duration outboundDebounce = Duration(milliseconds: 480);

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  Timer? _timer;
  String? _pendingConversationId;
  String? _lastConversationId;
  String? _lastReason;

  String? get lastConversationId => _lastConversationId;
  String? get lastReason => _lastReason;

  /// 已通过 [sendMessageFromController] 乐观入列的外发：无需再全量拉历史。
  static bool skipsHistoryReload(String? reason) {
    final normalized = reason?.trim() ?? '';
    return normalized == 'wallet_card_sent' ||
        normalized == 'wallet_message_sent';
  }

  /// 外发类 reason：可合并 debounce；打开中的会话有消息时可跳过 legacy 四连拉。
  static bool isOptimisticOutboundReason(String? reason) {
    final normalized = reason?.trim() ?? '';
    return normalized == 'wallet_card_sent' ||
        normalized == 'wallet_message_sent' ||
        normalized == 'external_message_sent';
  }

  static Duration debounceForReason(String? reason, {Duration? override}) {
    if (override != null) {
      return override;
    }
    return isOptimisticOutboundReason(reason)
        ? outboundDebounce
        : defaultDebounce;
  }

  void requestRefresh({
    required String conversationId,
    String? reason,
    Duration? delay,
  }) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    _lastConversationId = id;
    _lastReason = reason;

    if (skipsHistoryReload(reason)) {
      return;
    }

    final wait = debounceForReason(reason, override: delay);
    if (_timer != null &&
        _timer!.isActive &&
        _pendingConversationId != null &&
        _pendingConversationId == id) {
      return;
    }

    _timer?.cancel();
    _pendingConversationId = id;
    _timer = Timer(wait, () {
      _pendingConversationId = null;
      revision.value++;
    });
  }

  void dispose() {
    _timer?.cancel();
    revision.dispose();
  }
}
