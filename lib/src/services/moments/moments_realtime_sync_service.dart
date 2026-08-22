import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_refresh_bus.dart';

class MomentsRealtimeSyncService {
  MomentsRealtimeSyncService._();

  static final MomentsRealtimeSyncService instance =
      MomentsRealtimeSyncService._();

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'moment_changed') {
      return;
    }
    final hint = MomentsRefreshHint.fromRealtime(event);
    if (hint.action.isEmpty) {
      return;
    }
    MomentsRefreshBus.instance.notify(hint);
  }
}
