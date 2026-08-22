import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/call_record_api.dart';

class CallRecentRefreshEvent {
  const CallRecentRefreshEvent({
    required this.action,
    this.item,
    this.pushTs,
  });

  final String action;
  final CallRecordItem? item;
  final int? pushTs;
}

/// TCP `call_recent_changed` 后通知最近通话页增量刷新。
class CallRecentRefreshBus {
  CallRecentRefreshBus._();

  static final CallRecentRefreshBus instance = CallRecentRefreshBus._();

  final ValueNotifier<CallRecentRefreshEvent?> lastRefresh =
      ValueNotifier<CallRecentRefreshEvent?>(null);
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyAdded(CallRecordItem item, {int? pushTs}) {
    if (item.callId.trim().isEmpty) {
      return;
    }
    revision.value++;
    lastRefresh.value = CallRecentRefreshEvent(
      action: 'added',
      item: item,
      pushTs: pushTs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  void notifyRefresh({int? pushTs}) {
    revision.value++;
    lastRefresh.value = CallRecentRefreshEvent(
      action: 'refresh',
      pushTs: pushTs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
