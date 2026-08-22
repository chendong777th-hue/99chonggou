import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// HTTP 全量 + TCP friend_list_changed 增量，统一写入 [FriendLocalStore]。
class FriendSyncService {
  FriendSyncService._();

  static final FriendSyncService instance = FriendSyncService._();

  bool _installed = false;
  bool _syncInFlight = false;
  String? _pendingSyncReason;
  DateTime? _lastTcpAuthSyncAt;
  static const Duration _tcpAuthSyncCooldown = Duration(minutes: 10);

  @visibleForTesting
  String? debugOwnerUserId;

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose sync tracing disabled.
  }

  void install() {
    if (_installed) {
      return;
    }
    _installed = true;
    FriendRealtimeService.instance.onAuthOk = () {
      unawaited(_onTcpAuthOk());
    };
  }

  Future<void> _onTcpAuthOk() async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }

    final last = _lastTcpAuthSyncAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _tcpAuthSyncCooldown) {
      _log('tcp_auth_ok skip syncFull, cooldown');
      await refreshUIKitLists();
      return;
    }

    _lastTcpAuthSyncAt = now;
    await syncFull(reason: 'tcp_auth_ok');
    await refreshUIKitLists();
  }

  String _ownerUserId() {
    final override = debugOwnerUserId?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  Future<List<V2TimFriendInfo>> loadFriendsForUIKit() async {
    final owner = _ownerUserId();
    final local = await FriendLocalStore.instance.loadAsV2TimFriends(
      ownerUserId: owner,
    );
    if (local.isNotEmpty) {
      return local;
    }
    await syncFull(reason: 'ui_empty_local');
    return FriendLocalStore.instance.loadAsV2TimFriends(ownerUserId: owner);
  }

  Future<void> syncFull({String reason = 'manual'}) async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    if (_syncInFlight) {
      _pendingSyncReason = reason;
      return;
    }
    _syncInFlight = true;
    try {
      _log('syncFull start reason=$reason');
      final records = await MeFriendApi.instance.fetchFriendsFromNetwork();
      await FriendLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: records,
      );
      for (final record in records) {
        await UserProfileLocalService.instance.saveFriendRecord(record);
      }
      _seedPresenceFromFriendRecords(records);
      _log('syncFull done count=${records.length}');
      _lastTcpAuthSyncAt = DateTime.now();
    } catch (e) {
      _log('syncFull failed: $e');
      rethrow;
    } finally {
      _syncInFlight = false;
      final pending = _pendingSyncReason;
      _pendingSyncReason = null;
      if (pending != null) {
        unawaited(syncFull(reason: pending));
      }
    }
  }

  String _resolvePeerUserId(FriendRealtimeEvent event) {
    final peer = ChatIdFormat.rawUserUid(event.peerUserId);
    if (peer.isNotEmpty) {
      return peer;
    }
    final self = _ownerUserId();
    final from = ChatIdFormat.rawUserUid(event.fromUserId);
    final to = ChatIdFormat.rawUserUid(event.toUserId);
    if (self.isNotEmpty) {
      if (from.isNotEmpty && from != self) {
        return from;
      }
      if (to.isNotEmpty && to != self) {
        return to;
      }
    }
    return from.isNotEmpty ? from : to;
  }

  Future<void> applyOptimisticAdd({
    required String friendUserId,
    String? friendNickname,
    String? friendAvatarUrl,
    String remark = '',
  }) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.rawUserUid(friendUserId);
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final existing = await MeFriendApi.instance.cachedByUserId(id);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final record = (existing ??
            MeFriendRecord(
              friendUserId: id,
              remark: remark,
              friendNickname: '',
              friendAvatarUrl: '',
              addedAt: now,
              peerDeletedMe: false,
              canMessage: true,
            ))
        .copyWith(
      friendNickname: _firstNonEmpty(
        friendNickname,
        existing?.friendNickname ?? '',
      ),
      friendAvatarUrl: _firstNonEmpty(
        friendAvatarUrl,
        existing?.friendAvatarUrl ?? '',
      ),
      remark: remark.trim().isNotEmpty
          ? remark.trim()
          : (existing?.remark ?? ''),
      canMessage: true,
      inMyFriendList: true,
      isFriend: true,
      addedAt: existing?.addedAt == 0 ? now : existing?.addedAt,
    );
    await FriendLocalStore.instance.upsert(
      ownerUserId: owner,
      record: record,
    );
    await UserProfileLocalService.instance.saveFriendRecord(record);
    PeerProfileRefreshBus.instance.notify(id);
    _log('applyOptimisticAdd peer=$id');
  }

  Future<bool> applyListChanged(FriendRealtimeEvent event) async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return false;
    }
    final action = event.action?.trim().toLowerCase() ?? '';
    final peerUserId = _resolvePeerUserId(event);
    if (action.isEmpty || peerUserId.isEmpty) {
      return false;
    }

    _log('applyListChanged action=$action peer=$peerUserId');

    switch (action) {
      case 'added':
        var addedRecord = MeFriendRecord.fromListChangedEvent(event);
        if (addedRecord.friendUserId.trim().isEmpty) {
          addedRecord = addedRecord.copyWith(friendUserId: peerUserId);
        }
        await FriendLocalStore.instance.upsert(
          ownerUserId: owner,
          record: addedRecord,
        );
        await UserProfileLocalService.instance.saveFriendRecord(addedRecord);
        _seedPresenceFromFriendRecords([addedRecord]);
        PeerProfileRefreshBus.instance.notify(peerUserId);
        return true;
      case 'removed':
        await FriendLocalStore.instance.delete(
          ownerUserId: owner,
          friendUserId: peerUserId,
        );
        return true;
      case 'updated':
        await FriendLocalStore.instance.patch(
          ownerUserId: owner,
          friendUserId: peerUserId,
          transform: (current) => current.copyWith(
            peerDeletedMe: event.peerDeletedMe ?? current.peerDeletedMe,
            canMessage: event.canMessage ?? current.canMessage,
            isFriend: event.isFriend ?? current.isFriend,
            inMyFriendList: event.inMyFriendList ?? current.inMyFriendList,
            lastActiveAt: event.lastActiveAt ?? current.lastActiveAt,
            lastActiveVisibility:
                event.lastActiveVisibility ?? current.lastActiveVisibility,
          ),
        );
        final cached = await FriendLocalStore.instance.readAll(ownerUserId: owner);
        for (final item in cached) {
          if (item.friendUserId == peerUserId) {
            await UserProfileLocalService.instance.saveFriendRecord(item);
            _seedPresenceFromFriendRecords([item]);
            break;
          }
        }
        PeerProfileRefreshBus.instance.notify(peerUserId);
        ConversationRefreshBus.instance.requestRefresh(
          reason: 'friend_list_changed',
          conversationId: 'c2c_$peerUserId',
        );
        return true;
      case 'profile_updated':
        await FriendLocalStore.instance.patch(
          ownerUserId: owner,
          friendUserId: peerUserId,
          transform: (current) => current.copyWith(
            friendNickname: _firstNonEmpty(
              event.peerNickname,
              current.friendNickname,
            ),
            friendAvatarUrl: _firstNonEmpty(
              event.peerAvatarUrl,
              current.friendAvatarUrl,
            ),
            remark: event.remark ?? current.remark,
          ),
        );
        final cached = await FriendLocalStore.instance.readAll(ownerUserId: owner);
        for (final item in cached) {
          if (item.friendUserId == peerUserId) {
            await UserProfileLocalService.instance.saveFriendRecord(item);
            break;
          }
        }
        PeerProfileRefreshBus.instance.notify(peerUserId);
        return true;
      case 'remark_updated':
        final nextRemark = event.remark?.trim() ?? '';
        await FriendLocalStore.instance.patch(
          ownerUserId: owner,
          friendUserId: peerUserId,
          transform: (current) => current.copyWith(remark: nextRemark),
        );
        final remarkCached =
            await FriendLocalStore.instance.readAll(ownerUserId: owner);
        for (final item in remarkCached) {
          if (item.friendUserId == peerUserId) {
            await UserProfileLocalService.instance.saveFriendRecord(item);
            break;
          }
        }
        await publishFriendRemarkDisplayName(
          friendUserId: peerUserId,
          remark: nextRemark,
        );
        return true;
      default:
        return false;
    }
  }

  Future<void> applyOptimisticRemark({
    required String friendUserId,
    required String remark,
  }) async {
    final owner = _ownerUserId();
    final id = friendUserId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    final nextRemark = remark.trim();
    await FriendLocalStore.instance.patch(
      ownerUserId: owner,
      friendUserId: id,
      transform: (current) => current.copyWith(remark: nextRemark),
    );
    final cached = await FriendLocalStore.instance.readAll(ownerUserId: owner);
    for (final item in cached) {
      if (item.friendUserId == id) {
        await UserProfileLocalService.instance.saveFriendRecord(item);
        break;
      }
    }
    await publishFriendRemarkDisplayName(
      friendUserId: id,
      remark: nextRemark,
    );
  }

  /// 备注变更后同步会话列表展示名（含行指纹依赖的 showName）。
  Future<void> publishFriendRemarkDisplayName({
    required String friendUserId,
    required String remark,
  }) async {
    final id = ChatIdFormat.rawUserUid(friendUserId);
    if (id.isEmpty) {
      return;
    }
    final text = remark.trim();
    TUIFriendShipViewModel? friendship;
    try {
      friendship = serviceLocator<TUIFriendShipViewModel>();
      friendship.updateFriendRemarkLocal(id, text);
    } catch (_) {
      friendship = null;
    }

    var showName = text;
    if (showName.isEmpty) {
      final friend = FriendDisplayName.findFriend(friendship?.friendList, id);
      final nickFromFriend = friend?.userProfile?.nickName?.trim() ?? '';
      if (nickFromFriend.isNotEmpty) {
        showName = nickFromFriend;
      } else {
        // 好友列表未加载时，从本地资料/好友缓存取昵称，避免短暂回退成 userID。
        final local = await UserProfileLocalService.instance.read(id);
        final localNick = local?.nickname.trim() ?? '';
        if (localNick.isNotEmpty) {
          showName = localNick;
        } else {
          final cachedFriend = await MeFriendApi.instance.cachedByUserId(id);
          final cachedNick = cachedFriend?.friendNickname.trim() ?? '';
          showName = cachedNick.isNotEmpty ? cachedNick : id;
        }
      }
    }

    DisplayNameStore.instance.setC2C(id, showName);
    try {
      serviceLocator<TUIConversationViewModel>().updateC2CShowName(id, showName);
    } catch (_) {}

    final conversationId = 'c2c_$id';
    ConversationListNotifier.instance.applyShowNameLocally(
      conversationID: conversationId,
      showName: showName,
    );
    PeerProfileRefreshBus.instance.notify(id);
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'friend_remark_updated',
      conversationId: conversationId,
    );
  }

  Future<void> applyOptimisticDelete(String friendUserId) async {
    final owner = _ownerUserId();
    final id = friendUserId.trim();
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    await FriendLocalStore.instance.delete(
      ownerUserId: owner,
      friendUserId: id,
    );
    await refreshUIKitLists(force: true);
    try {
      serviceLocator<TUISearchViewModel>().invalidateGlobalSearchContext();
    } catch (_) {}
  }

  Future<void> refreshUIKitLists({bool force = false}) async {
    try {
      final friendship = serviceLocator<TUIFriendShipViewModel>();
      if (force) {
        await friendship.reloadContactListData();
      } else {
        await friendship.loadContactListData();
      }
      if ((friendship.friendList?.isNotEmpty ?? false)) {
        await friendship.loadUserStatus();
      }
    } catch (e) {
      _log('refreshUIKitLists failed: $e');
    }
  }

  Future<void> handlePushFriendList(Map<String, dynamic> data) async {
    final event = FriendRealtimeEvent.fromJson(<String, dynamic>{
      ...data,
      'event': data['event'] ?? 'friend_list_changed',
      'type': 'event',
    });
    if (event.event != 'friend_list_changed') {
      return;
    }
    final changed = await applyListChanged(event);
    if (changed) {
      await refreshUIKitLists(force: true);
    } else {
      await syncFull(reason: 'push_friend_list_fallback');
      await refreshUIKitLists(force: true);
    }
  }

  Future<void> clearSession() async {
    await FriendLocalStore.instance.clearSession();
    await UserProfileLocalService.instance.clearSession();
  }

  String _firstNonEmpty(String? primary, String fallback) {
    final value = primary?.trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  void _seedPresenceFromFriendRecords(List<MeFriendRecord> records) {
    final lastSeen = <String, int>{};
    final visibility = <String, String>{};
    for (final record in records) {
      final id = ChatIdFormat.rawUserUid(record.friendUserId);
      if (id.isEmpty) {
        continue;
      }
      final ts = record.lastActiveAt;
      if (ts != null) {
        lastSeen[id] = ts;
      }
      final vis = record.lastActiveVisibility?.trim() ?? '';
      if (vis.isNotEmpty) {
        visibility[id] = vis;
      }
    }
    PresenceProvider.activeInstance?.applyPresenceBatch(
      lastSeen: lastSeen.isEmpty ? null : lastSeen,
      lastActiveVisibility: visibility.isEmpty ? null : visibility,
    );
  }
}
