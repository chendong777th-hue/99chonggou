import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_store.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';

/// In-memory snapshot of `/live/current` for one open group chat.
class GroupLiveChatState extends ChangeNotifier {
  GroupLiveCurrentSnapshot? snapshot;
  bool loading = false;

  GroupLiveSession? get activeSession =>
      snapshot?.active == true ? snapshot?.session : null;

  bool get hasActiveSlot {
    final session = activeSession;
    return session != null && session.status.isActiveSlot;
  }

  /// 用会话列表已缓存的 live-index 立刻填横幅，避免进群后再闪一下。
  void seedFromIndex(String groupId, {bool notify = false}) {
    final id = groupId.trim();
    if (id.isEmpty) {
      if (snapshot != null) {
        snapshot = null;
        loading = false;
        if (notify) notifyListeners();
      }
      return;
    }
    final item = GroupLiveIndexStore.instance.itemForGroup(id);
    if (item != null && item.status.isActiveSlot) {
      snapshot = GroupLiveCurrentSnapshot.active(item.toSession());
    } else {
      snapshot = null;
    }
    loading = false;
    if (notify) notifyListeners();
  }

  Future<void> refresh(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) return;
    loading = true;
    try {
      final next = await GroupLiveApi.instance.current(groupId: id);
      final session = next.session;
      if (next.active &&
          session != null &&
          session.groupId.trim().isEmpty) {
        snapshot = GroupLiveCurrentSnapshot.active(
          GroupLiveSession(
            liveSessionId: session.liveSessionId,
            groupId: id,
            roomName: session.roomName,
            anchorUserId: session.anchorUserId,
            status: session.status,
            scheduledStartAt: session.scheduledStartAt,
            expireAt: session.expireAt,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            endReason: session.endReason,
          ),
        );
      } else {
        snapshot = next;
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupLive] current failed groupId=$id error=$e');
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void applyImPayload(GroupLiveImPayload payload) {
    final session = activeSession;
    if (session == null && !payload.isCard) {
      return;
    }
    if (payload.businessId == GroupLiveMessageIds.ended) {
      snapshot = const GroupLiveCurrentSnapshot.inactive();
      notifyListeners();
      return;
    }
    if (payload.liveSessionId.isEmpty) {
      return;
    }
    final merged = GroupLiveSession(
      liveSessionId: payload.liveSessionId,
      groupId: payload.groupId.isNotEmpty
          ? payload.groupId
          : (session?.groupId ?? ''),
      roomName: payload.roomName.isNotEmpty
          ? payload.roomName
          : (session?.roomName ?? ''),
      anchorUserId: payload.anchorUserId.isNotEmpty
          ? payload.anchorUserId
          : (session?.anchorUserId ?? ''),
      status: payload.status != GroupLiveStatus.unknown
          ? payload.status
          : (session?.status ?? GroupLiveStatus.unknown),
      scheduledStartAt: payload.scheduledStartAt ?? session?.scheduledStartAt,
      expireAt: session?.expireAt,
      startedAt: session?.startedAt,
      endReason: payload.endReason,
    );
    if (!merged.status.isActiveSlot &&
        payload.businessId != GroupLiveMessageIds.started) {
      snapshot = const GroupLiveCurrentSnapshot.inactive();
    } else {
      snapshot = GroupLiveCurrentSnapshot.active(merged);
    }
    notifyListeners();
  }

  void applyTcpDetail(
    Map<String, dynamic> detail, {
    required String groupId,
  }) {
    final status = GroupLiveStatus.parse(detail['status']?.toString());
    if (!status.isActiveSlot) {
      snapshot = const GroupLiveCurrentSnapshot.inactive();
      notifyListeners();
      return;
    }
    final item = GroupLiveIndexItem.fromTcpDetail(
      detail,
      groupId: groupId,
    );
    if (item.liveSessionId.trim().isEmpty) {
      // 详情缺 id 时仍按 status 展示槽位；由聊天页随后 REST current 补全。
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[GroupLive] applyTcpDetail missing liveSessionId '
          'groupId=$groupId status=$status',
        );
      }
    }
    snapshot = GroupLiveCurrentSnapshot.active(item.toSession());
    notifyListeners();
  }

  void clear() {
    snapshot = null;
    loading = false;
    notifyListeners();
  }
}
