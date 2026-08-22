import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';

class RedPacketSenderRefreshEvent {
  const RedPacketSenderRefreshEvent({
    required this.action,
    required this.packetId,
    this.groupId,
    this.senderUserId,
    this.packetType,
    this.currency,
    this.packetStatus,
    this.remainingCount,
    this.remainingAmount,
    this.claimerUserId,
    this.claimerNickName,
    this.claimAmount,
    this.pushTs,
  });

  final String action;
  final String packetId;
  final String? groupId;
  final String? senderUserId;
  final String? packetType;
  final String? currency;
  final String? packetStatus;
  final int? remainingCount;
  final int? remainingAmount;
  final String? claimerUserId;
  final String? claimerNickName;
  final int? claimAmount;
  final int? pushTs;

  factory RedPacketSenderRefreshEvent.fromRealtime(FriendRealtimeEvent event) {
    final packetId = event.packetId?.toString().trim() ?? '';
    return RedPacketSenderRefreshEvent(
      action: event.action?.trim().toLowerCase() ?? '',
      packetId: packetId,
      groupId: event.groupId?.trim(),
      senderUserId: event.senderUserId?.trim(),
      packetType: event.packetType?.trim(),
      currency: event.currency?.trim(),
      packetStatus: event.packetStatus?.trim(),
      remainingCount: event.remainingCount,
      remainingAmount: event.remainingAmount,
      claimerUserId: event.claimerUserId?.trim(),
      claimerNickName: event.claimerNickName?.trim(),
      claimAmount: event.claimAmount,
      pushTs: event.ts,
    );
  }
}

/// TCP `red_packet_changed` 后通知发包人侧 UI 增量刷新。
class RedPacketSenderRefreshBus {
  RedPacketSenderRefreshBus._();

  static final RedPacketSenderRefreshBus instance =
      RedPacketSenderRefreshBus._();

  final ValueNotifier<RedPacketSenderRefreshEvent?> lastRefresh =
      ValueNotifier<RedPacketSenderRefreshEvent?>(null);
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notify(RedPacketSenderRefreshEvent event) {
    if (event.packetId.trim().isEmpty || event.action.trim().isEmpty) {
      return;
    }
    revision.value++;
    lastRefresh.value = event;
  }
}
