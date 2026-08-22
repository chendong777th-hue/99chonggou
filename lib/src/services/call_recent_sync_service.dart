import 'package:tencent_cloud_chat_demo/src/api/call_record_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_recent_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_enrichment_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';

/// TCP `call_recent_changed` 统一处理。
class CallRecentSyncService {
  CallRecentSyncService._();

  static final CallRecentSyncService instance = CallRecentSyncService._();

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose sync tracing disabled.
  }

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'call_recent_changed') {
      return;
    }
    final action = event.action?.trim().toLowerCase() ?? '';
    final callId = event.callId?.trim() ?? '';
    if (action.isEmpty || callId.isEmpty) {
      _log('skip invalid call_recent_changed callId=$callId action=$action');
      return;
    }

    final item = CallRecordItem.fromRealtimeEvent(event);
    if (item.callId.isEmpty) {
      _log('skip call_recent_changed with empty parsed callId');
      return;
    }

    _log(
      'call_recent_changed action=$action callId=$callId '
      'peer=${item.peerUserId} result=${item.result} '
      'caller=${item.callerUserId} operator=${item.operatorUserId}',
    );

    // Server result is authoritative for chat bubbles (result / direction /
    // operatorUserId). Also refresh the recent-calls list.
    if (item.result.trim().isNotEmpty) {
      CallResultEnrichmentService.instance.ingestServerItem(item);
    }

    switch (action) {
      case 'added':
        CallRecentRefreshBus.instance.notifyAdded(
          item,
          pushTs: event.ts,
        );
        return;
      default:
        CallRecentRefreshBus.instance.notifyRefresh(pushTs: event.ts);
    }
  }
}
