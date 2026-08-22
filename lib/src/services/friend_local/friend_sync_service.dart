import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_friend_message_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_contact_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/utils/friend_display_fields_merge.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

typedef FriendBecameFriendsCompletedHook = void Function(String reason);

/// HTTP Snapshot/Difference + TCP friend_list_changed，统一写入 [FriendLocalStore]。
class FriendSyncService {
  FriendSyncService._();

  static final FriendSyncService instance = FriendSyncService._();

  /// 本机成友收口后回调（供通讯录 burst 补拉，避免漏 TCP 时列表不及时）。
  FriendBecameFriendsCompletedHook? onBecameFriendsCompleted;

  bool _installed = false;
  Future<void>? _syncInFlight;
  int _syncGeneration = 0;
  DateTime? _lastTcpAuthSyncAt;
  static const Duration _tcpAuthSyncCooldown = Duration(minutes: 10);

  /// 成友乐观写入后，全量 sync 暂未带回该 peer 时短时保留，避免通讯录被抹掉。
  static const Duration _optimisticRetainDuration = Duration(minutes: 15);
  final Map<String, int> _optimisticRetainUntilMs = <String, int>{};
  final Map<String, MeFriendRecord> _optimisticRetainRecords =
      <String, MeFriendRecord>{};

  @visibleForTesting
  String? debugOwnerUserId;

  /// 单测用：跳过 UIKit 刷新与后台 syncFull，只验证乐观入库。
  @visibleForTesting
  bool debugSkipBecameFriendsSideEffects = false;

  @visibleForTesting
  void clearOptimisticRetainForTest() {
    _optimisticRetainUntilMs.clear();
    _optimisticRetainRecords.clear();
  }

  @visibleForTesting
  void markOptimisticFriendRetainForTest(
    String peerUserId, {
    MeFriendRecord? record,
  }) {
    _markOptimisticFriendRetain(peerUserId, record: record);
  }

  @visibleForTesting
  Future<void> reapplyOptimisticRetainToStoreForTest() {
    return _reapplyOptimisticRetainToStore(_ownerUserId());
  }

  @visibleForTesting
  List<MeFriendRecord> mergeSyncFullWithOptimisticRetainForTest({
    required List<MeFriendRecord> incoming,
    required List<MeFriendRecord> previous,
  }) {
    return _mergeSyncFullWithOptimisticRetain(
      incoming: incoming,
      previous: previous,
    );
  }

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

    // 重连成功 ≠ 已同步：必须再打 Difference。
    try {
      await FriendContactIncrementalSyncService.instance.sync(
        reason: 'tcp_auth_ok',
      );
    } catch (e) {
      _log('tcp_auth_ok difference failed: $e');
    }

    final last = _lastTcpAuthSyncAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _tcpAuthSyncCooldown) {
      _log('tcp_auth_ok skip syncFull, cooldown');
      await refreshUIKitLists();
      return;
    }

    final local = await FriendLocalStore.instance.readAll(ownerUserId: owner);
    final cursor =
        await FriendContactIncrementalSyncService.instance.readCursor(
      ownerUserId: owner,
    );
    // 本地空或尚无游标时仍 Snapshot 一次；平时靠 Difference。
    if (local.isEmpty || cursor == 0) {
      _lastTcpAuthSyncAt = now;
      await syncFull(reason: 'tcp_auth_ok');
    }
    await refreshUIKitLists();
  }

  String _ownerUserId() {
    final override = debugOwnerUserId?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  /// 从本地好友库灌入通讯录 ViewModel，不触发网络。
  Future<bool> hydrateContactListFromLocal() async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return false;
    }
    try {
      final local = await FriendLocalStore.instance.loadAsV2TimFriends(
        ownerUserId: owner,
      );
      if (local.isEmpty) {
        return false;
      }
      return serviceLocator<TUIFriendShipViewModel>()
          .applyLocalFriendSnapshot(local);
    } catch (e) {
      _log('hydrateContactListFromLocal failed: $e');
      return false;
    }
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

  Future<void> syncFull({String reason = 'manual'}) {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return Future<void>.value();
    }
    final active = _syncInFlight;
    if (active != null) {
      return active;
    }

    final generation = _syncGeneration;
    late final Future<void> task;
    task = _runSyncFull(owner: owner, generation: generation, reason: reason)
        .whenComplete(() {
          if (identical(_syncInFlight, task)) {
            _syncInFlight = null;
          }
        });
    _syncInFlight = task;
    return task;
  }

  Future<void> _runSyncFull({
    required String owner,
    required int generation,
    required String reason,
  }) async {
    try {
      _log('syncFull start reason=$reason');
      final snapshot =
          await MeFriendApi.instance.fetchFriendsSnapshotFromNetwork();
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      final records = snapshot.records;
      var previous = await FriendLocalStore.instance.readAll(
        ownerUserId: owner,
      );
      var merged = _mergeSyncFullWithOptimisticRetain(
        incoming: records,
        previous: previous,
      );
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      // replaceAll 会 await 开库：期间乐观 upsert 可能已经写入。
      // 落库前再读一次，落库后再把 retain 行补回去，避免整表覆盖刚成友的人。
      previous = await FriendLocalStore.instance.readAll(ownerUserId: owner);
      merged = _mergeSyncFullWithOptimisticRetain(
        incoming: records,
        previous: previous,
      );
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      await FriendLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: merged,
      );
      await _reapplyOptimisticRetainToStore(owner);
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      for (final record in merged) {
        if (!_isCurrentSync(owner, generation)) {
          return;
        }
        await UserProfileLocalService.instance.saveFriendRecord(record);
      }
      if (!_isCurrentSync(owner, generation)) {
        return;
      }
      _seedPresenceFromFriendRecords(merged);
      await seedC2cDisplayNamesFromFriendRecords(merged);
      _notifyAvatarChangesAfterSyncFull(
        previous: previous,
        merged: merged,
      );
      await FriendContactIncrementalSyncService.instance
          .resetCursorFromSnapshot(
        snapshot.syncSeq,
        ownerUserId: owner,
      );
      _log('syncFull done count=${merged.length} syncSeq=${snapshot.syncSeq}');
      _lastTcpAuthSyncAt = DateTime.now();
      // 全量落库后必须刷通讯录 UI；否则仅写 SQLite，friendList 快照仍旧。
      if (!debugSkipBecameFriendsSideEffects) {
        await refreshUIKitLists(force: true);
      }
    } catch (e) {
      _log('syncFull failed: $e');
      rethrow;
    }
  }

  void _markOptimisticFriendRetain(
    String peerUserId, {
    MeFriendRecord? record,
  }) {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (id.isEmpty) {
      return;
    }
    _optimisticRetainUntilMs[id] = DateTime.now().millisecondsSinceEpoch +
        _optimisticRetainDuration.inMilliseconds;
    if (record != null) {
      _optimisticRetainRecords[id] = record;
    }
  }

  void _clearOptimisticFriendRetain(String peerUserId) {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (id.isEmpty) {
      return;
    }
    _optimisticRetainUntilMs.remove(id);
    _optimisticRetainRecords.remove(id);
  }

  void _pruneExpiredOptimisticRetain(int nowMs) {
    final expired = <String>[];
    _optimisticRetainUntilMs.forEach((id, until) {
      if (until <= nowMs) {
        expired.add(id);
      }
    });
    for (final id in expired) {
      _optimisticRetainUntilMs.remove(id);
      _optimisticRetainRecords.remove(id);
    }
  }

  Future<void> _reapplyOptimisticRetainToStore(String owner) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _pruneExpiredOptimisticRetain(now);
    if (_optimisticRetainRecords.isEmpty || owner.isEmpty) {
      return;
    }
    for (final entry in _optimisticRetainRecords.entries) {
      final until = _optimisticRetainUntilMs[entry.key];
      if (until == null || until <= now) {
        continue;
      }
      final record = entry.value;
      if (!(record.inMyFriendList || record.isFriend || record.canMessage)) {
        continue;
      }
      await FriendLocalStore.instance.upsert(
        ownerUserId: owner,
        record: record,
      );
    }
  }

  /// 全量合并：保留展示名；对「刚成友、服务端暂未返回」的 peer 短时保留本地行。
  List<MeFriendRecord> _mergeSyncFullWithOptimisticRetain({
    required List<MeFriendRecord> incoming,
    required List<MeFriendRecord> previous,
  }) {
    final merged = FriendDisplayFieldsMerge.mergeListPreservingLocalNames(
      incoming: incoming,
      previous: previous,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    _pruneExpiredOptimisticRetain(now);

    final incomingIds = <String>{};
    final incomingById = <String, MeFriendRecord>{};
    for (final item in incoming) {
      final id = ChatIdFormat.rawUserUid(item.friendUserId);
      if (id.isNotEmpty) {
        incomingIds.add(id);
        incomingById[id] = item;
      }
    }
    // 服务端已带回且确认仍可发 → 清除 retain。
    // retain 窗口内滞后的 canMessage=false 不得覆盖刚加好友的乐观态。
    for (final id in incomingIds) {
      final until = _optimisticRetainUntilMs[id];
      if (until != null && until > now) {
        final row = incomingById[id];
        final confirmed = row != null && row.canMessage;
        if (!confirmed) {
          continue;
        }
      }
      _optimisticRetainUntilMs.remove(id);
      _optimisticRetainRecords.remove(id);
    }

    for (var i = 0; i < merged.length; i++) {
      final id = ChatIdFormat.rawUserUid(merged[i].friendUserId);
      if (id.isEmpty) {
        continue;
      }
      final until = _optimisticRetainUntilMs[id];
      if (until == null || until <= now) {
        continue;
      }
      if (merged[i].canMessage) {
        continue;
      }
      final retained = _optimisticRetainRecords[id] ??
          _previousRecordById(previous, id);
      if (retained == null) {
        continue;
      }
      if (!(retained.canMessage ||
          retained.inMyFriendList ||
          retained.isFriend)) {
        continue;
      }
      merged[i] = merged[i].copyWith(
        canMessage: retained.canMessage,
        inMyFriendList: retained.inMyFriendList,
        isFriend: retained.isFriend,
        peerDeletedMe: retained.peerDeletedMe,
      );
    }

    if (_optimisticRetainUntilMs.isEmpty && _optimisticRetainRecords.isEmpty) {
      return merged;
    }

    final out = List<MeFriendRecord>.from(merged);
    final outIds = <String>{
      for (final item in out) ChatIdFormat.rawUserUid(item.friendUserId),
    }..removeWhere((id) => id.isEmpty);

    void tryRetain(MeFriendRecord candidate) {
      final id = ChatIdFormat.rawUserUid(candidate.friendUserId);
      if (id.isEmpty || outIds.contains(id) || incomingIds.contains(id)) {
        return;
      }
      final until = _optimisticRetainUntilMs[id];
      if (until == null || until <= now) {
        return;
      }
      if (!(candidate.inMyFriendList ||
          candidate.isFriend ||
          candidate.canMessage)) {
        return;
      }
      out.add(candidate);
      outIds.add(id);
    }

    for (final prev in previous) {
      tryRetain(prev);
    }
    // previous 在乐观写入之前拍的快照时，仍用内存里的 retain 行补回。
    for (final record in _optimisticRetainRecords.values) {
      tryRetain(record);
    }
    return out;
  }

  MeFriendRecord? _previousRecordById(
    List<MeFriendRecord> previous,
    String id,
  ) {
    for (final item in previous) {
      if (ChatIdFormat.rawUserUid(item.friendUserId) == id) {
        return item;
      }
    }
    return null;
  }

  /// 好友头像变更：补 C2C 会话列表 + 已缓存群成员 faceUrl（灌源后再由 bus 通知 UI）。
  void _publishPeerAvatarLocally(String userId, String faceUrl) {
    final id = ChatIdFormat.rawUserUid(userId);
    final nextAvatar = UserAvatarHelper.usableAvatarOrEmpty(faceUrl);
    if (id.isEmpty || nextAvatar.isEmpty) {
      return;
    }
    ConversationListNotifier.instance.applyFaceUrlLocally(
      conversationID: 'c2c_$id',
      faceUrl: nextAvatar,
    );
    GroupMemberStore.instance.putFaceUrlForUser(id, nextAvatar, notify: true);
  }

  /// syncFull 写入头像后通知已打开的资料/设置页，并补会话列表 faceUrl。
  void _notifyAvatarChangesAfterSyncFull({
    required List<MeFriendRecord> previous,
    required List<MeFriendRecord> merged,
  }) {
    final prevAvatarById = <String, String>{};
    for (final item in previous) {
      final id = ChatIdFormat.rawUserUid(item.friendUserId);
      if (id.isEmpty) {
        continue;
      }
      prevAvatarById[id] =
          UserAvatarHelper.usableAvatarOrEmpty(item.friendAvatarUrl);
    }
    final changedIds = <String>[];
    for (final record in merged) {
      final id = ChatIdFormat.rawUserUid(record.friendUserId);
      if (id.isEmpty) {
        continue;
      }
      final nextAvatar =
          UserAvatarHelper.usableAvatarOrEmpty(record.friendAvatarUrl);
      if (nextAvatar.isEmpty) {
        continue;
      }
      final prevAvatar = prevAvatarById[id] ?? '';
      if (prevAvatar == nextAvatar) {
        continue;
      }
      changedIds.add(id);
      _publishPeerAvatarLocally(id, nextAvatar);
    }
    if (changedIds.isEmpty) {
      return;
    }
    PeerProfileRefreshBus.instance.notifyMany(changedIds);
  }

  /// 用自建好友记录灌 [DisplayNameStore] + 会话列表展示名（备注优先）。
  ///
  /// 批量 `setC2C(notify:false)` + 一次列表刷新，避免 N 次 refresh 风暴。
  Future<void> seedC2cDisplayNamesFromFriendRecords(
    List<MeFriendRecord> records,
  ) async {
    if (records.isEmpty) {
      return;
    }
    final batch = <String, String>{};
    for (final record in records) {
      final id = ChatIdFormat.rawUserUid(record.friendUserId);
      if (id.isEmpty) {
        continue;
      }
      final showName = record.displayName.trim();
      if (showName.isEmpty ||
          DisplayNameStore.isRawUserIdDisplayName(id, showName)) {
        continue;
      }
      DisplayNameStore.instance.setC2C(id, showName, notify: false);
      batch['c2c_$id'] = showName;
      try {
        serviceLocator<TUIConversationViewModel>().updateC2CShowName(
          id,
          showName,
        );
      } catch (_) {}
    }
    if (batch.isEmpty) {
      return;
    }
    ConversationListNotifier.instance.applyC2cShowNamesBatch(batch);
    DisplayNameStore.instance.notifyBatch();
  }

  /// 从本地好友库重灌展示名（纠正 IM `loadContactListData` 空备注写成的昵称）。
  Future<void> reseedC2cDisplayNamesFromLocalFriends() async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    try {
      final records = await FriendLocalStore.instance.readAll(
        ownerUserId: owner,
      );
      await seedC2cDisplayNamesFromFriendRecords(records);
    } catch (e) {
      _log('reseedC2cDisplayNamesFromLocalFriends failed: $e');
    }
  }

  bool _isCurrentSync(String owner, int generation) {
    return generation == _syncGeneration && _ownerUserId() == owner;
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
    final existingList =
        await FriendLocalStore.instance.readAll(ownerUserId: owner);
    MeFriendRecord? existing;
    for (final item in existingList) {
      if (ChatIdFormat.rawUserUid(item.friendUserId) == id) {
        existing = item;
        break;
      }
    }
    final profile = await UserProfileLocalService.instance.read(id);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final shell = existing ??
        MeFriendRecord(
          friendUserId: id,
          remark: '',
          friendNickname: '',
          friendAvatarUrl: '',
          addedAt: now,
          peerDeletedMe: false,
          canMessage: true,
        );
    final incoming = shell.copyWith(
      friendNickname: friendNickname?.trim() ?? '',
      friendAvatarUrl: friendAvatarUrl?.trim() ?? '',
      remark: remark.trim(),
      canMessage: true,
      inMyFriendList: true,
      isFriend: true,
      addedAt: (existing?.addedAt ?? 0) == 0 ? now : existing?.addedAt,
    );
    final record = FriendDisplayFieldsMerge.merge(
      incoming: incoming,
      previous: existing,
      profile: profile,
    );
    await FriendLocalStore.instance.upsert(ownerUserId: owner, record: record);
    await UserProfileLocalService.instance.saveFriendRecord(record);
    await publishFriendRemarkDisplayName(
      friendUserId: id,
      remark: record.remark,
    );
    // 先 trust 再 notify：打开中的 Chat invalidate 后仍能靠 trust 解锁输入栏。
    C2cFriendMessageGuard.trustCanSendHint(
      id,
      source: C2cFriendMessageGuard.becameFriendsTrustSource,
    );
    PeerProfileRefreshBus.instance.notify(id);
    _markOptimisticFriendRetain(id, record: record);
    // 作废进行中的 Snapshot：否则旧 merged 会 replaceAll 把刚写入的人删掉。
    _syncGeneration++;
    _syncInFlight = null;
    _log('applyOptimisticAdd peer=$id');
  }

  /// 已成为好友统一收口：乐观入库 → 刷通讯录 → 通知 → 后台全量对账。
  Future<void> onBecameFriends({
    required String peerUserId,
    String? nickname,
    String? avatarUrl,
    String remark = '',
    String reason = 'became_friends',
  }) async {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (id.isEmpty) {
      return;
    }
    await applyOptimisticAdd(
      friendUserId: id,
      friendNickname: nickname,
      friendAvatarUrl: avatarUrl,
      remark: remark,
    );
    if (debugSkipBecameFriendsSideEffects) {
      return;
    }
    try {
      await upsertFriendLocallyFromStore(id);
    } catch (e) {
      _log('upsertFriendLocally failed: $e');
    }
    try {
      await ConversationSyncService.instance.ensureC2cConversationVisible(
        userId: id,
        nickname: nickname,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      _log('ensureC2cConversationVisible failed: $e');
    }
    await refreshUIKitLists(force: true);
    onBecameFriendsCompleted?.call(reason);
    PeerProfileRefreshBus.instance.notify(id);
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'friend_list_changed',
      conversationId: 'c2c_$id',
      debounce: Duration.zero,
    );
    unawaited(() async {
      try {
        await FriendContactIncrementalSyncService.instance.sync(
          reason: reason,
          restart: true,
        );
      } catch (e) {
        _log('onBecameFriends difference failed: $e');
        try {
          await syncFull(reason: '${reason}_fallback');
        } catch (err) {
          _log('onBecameFriends syncFull failed: $err');
        }
      }
    }());
  }

  Future<bool> applyListChanged(
    FriendRealtimeEvent event, {
    bool fromDifference = false,
  }) async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return false;
    }
    final action = event.action?.trim().toLowerCase() ?? '';
    final peerUserId = _resolvePeerUserId(event);
    if (action.isEmpty || peerUserId.isEmpty) {
      return false;
    }

    final seq = event.seq;
    if (!fromDifference && seq != null && seq > 0 && action != 'added') {
      final shouldApply = await FriendContactIncrementalSyncService.instance
          .shouldApplyRealtimeSeq(seq);
      if (!shouldApply) {
        // 游标已覆盖该 seq：本地应已由 Difference 写入；多端漏推时补拉一次。
        unawaited(
          FriendContactIncrementalSyncService.instance.sync(
            reason: 'friend_list_changed_stale_seq',
          ),
        );
        return true;
      }
    }

    _log('applyListChanged action=$action peer=$peerUserId seq=$seq');

    var changed = false;
    switch (action) {
      case 'added':
        var addedRecord = MeFriendRecord.fromListChangedEvent(event);
        if (addedRecord.friendUserId.trim().isEmpty) {
          addedRecord = addedRecord.copyWith(friendUserId: peerUserId);
        }
        final existingAdded = await MeFriendApi.instance.cachedByUserId(
          peerUserId,
        );
        final profileAdded =
            await UserProfileLocalService.instance.read(peerUserId);
        addedRecord = FriendDisplayFieldsMerge.merge(
          incoming: addedRecord,
          previous: existingAdded,
          profile: profileAdded,
        );
        await FriendLocalStore.instance.upsert(
          ownerUserId: owner,
          record: addedRecord,
        );
        await UserProfileLocalService.instance.saveFriendRecord(addedRecord);
        _seedPresenceFromFriendRecords([addedRecord]);
        await publishFriendRemarkDisplayName(
          friendUserId: peerUserId,
          remark: addedRecord.remark,
        );
        _publishPeerAvatarLocally(peerUserId, addedRecord.friendAvatarUrl);
        PeerProfileRefreshBus.instance.notify(peerUserId);
        _clearOptimisticFriendRetain(peerUserId);
        await upsertFriendLocallyFromStore(peerUserId);
        changed = true;
        break;
      case 'removed':
        await FriendLocalStore.instance.delete(
          ownerUserId: owner,
          friendUserId: peerUserId,
        );
        _clearOptimisticFriendRetain(peerUserId);
        changed = true;
        break;
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
        final cached = await FriendLocalStore.instance.readAll(
          ownerUserId: owner,
        );
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
        changed = true;
        break;
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
        final cached = await FriendLocalStore.instance.readAll(
          ownerUserId: owner,
        );
        MeFriendRecord? updatedProfile;
        for (final item in cached) {
          if (item.friendUserId == peerUserId) {
            updatedProfile = item;
            await UserProfileLocalService.instance.saveFriendRecord(item);
            break;
          }
        }
        if (updatedProfile != null) {
          await publishFriendRemarkDisplayName(
            friendUserId: peerUserId,
            remark: updatedProfile.remark,
          );
          // 先灌会话/群成员活头像，再 bus，避免聊天页监听时仍读到旧快照。
          _publishPeerAvatarLocally(
            peerUserId,
            updatedProfile.friendAvatarUrl,
          );
        }
        PeerProfileRefreshBus.instance.notify(peerUserId);
        changed = true;
        break;
      case 'remark_updated':
        final nextRemark = event.remark?.trim() ?? '';
        await FriendLocalStore.instance.patch(
          ownerUserId: owner,
          friendUserId: peerUserId,
          transform: (current) => current.copyWith(remark: nextRemark),
        );
        final remarkCached = await FriendLocalStore.instance.readAll(
          ownerUserId: owner,
        );
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
        changed = true;
        break;
      default:
        return false;
    }

    if (changed && !fromDifference && seq != null && seq > 0) {
      await FriendContactIncrementalSyncService.instance.noteRealtimeSeq(seq);
    }
    return changed;
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
    await publishFriendRemarkDisplayName(friendUserId: id, remark: nextRemark);
  }

  /// 备注/展示名变更后同步会话列表（含 hydrate 行指纹依赖的 showName）。
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
      serviceLocator<TUIConversationViewModel>().updateC2CShowName(
        id,
        showName,
      );
    } catch (_) {}

    final conversationId = 'c2c_$id';
    ConversationListNotifier.instance.applyShowNameLocally(
      conversationID: conversationId,
      showName: showName,
    );
    await _persistC2cShowName(
      conversationId: conversationId,
      userId: id,
      showName: showName,
    );
    PeerProfileRefreshBus.instance.notify(id);
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'friend_remark_updated',
      conversationId: conversationId,
    );
  }

  Future<void> _persistC2cShowName({
    required String conversationId,
    required String userId,
    required String showName,
  }) async {
    final name = showName.trim();
    if (conversationId.isEmpty || name.isEmpty) {
      return;
    }
    V2TimConversation? match;
    for (final item in ConversationListNotifier.instance.conversations) {
      final cid = item.conversationID.trim();
      if (cid == conversationId ||
          ChatIdFormat.rawUserUid(item.userID) == userId) {
        match = item;
        break;
      }
    }
    if (match == null) {
      return;
    }
    match.showName = name;
    try {
      await ConversationLocalStore.instance.upsertBatch(
        conversations: <V2TimConversation>[match],
      );
    } catch (_) {}
  }

  Future<void> applyOptimisticDelete(String friendUserId) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.rawUserUid(friendUserId);
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    // 删好友行前把备注/昵称保留进资料库，供再加时自动恢复。
    final existing = await MeFriendApi.instance.cachedByUserId(id);
    if (existing != null) {
      await UserProfileLocalService.instance.saveFriendRecord(existing);
    }
    await FriendLocalStore.instance.delete(
      ownerUserId: owner,
      friendUserId: id,
    );
    C2cFriendMessageGuard.invalidate(id, clearTrusted: true);
    await refreshUIKitLists(force: true);
    try {
      serviceLocator<TUISearchViewModel>().invalidateGlobalSearchContext();
    } catch (_) {}
  }

  /// 本地库已写入后，立即把单条好友灌进通讯录 ViewModel（避免 reload 竞态空窗）。
  Future<void> upsertFriendLocallyFromStore(String peerUserId) async {
    final owner = _ownerUserId();
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (owner.isEmpty || id.isEmpty) {
      return;
    }
    try {
      final optimisticFriends =
          await FriendLocalStore.instance.loadAsV2TimFriendsByIds(
        friendUserIds: <String>[id],
        ownerUserId: owner,
      );
      if (optimisticFriends.isNotEmpty) {
        serviceLocator<TUIFriendShipViewModel>()
            .upsertFriendLocally(optimisticFriends.first);
      }
    } catch (e) {
      _log('upsertFriendLocallyFromStore failed: $e');
    }
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
      // IM 空备注会写成昵称；用自建库备注盖回 Store/列表。
      await reseedC2cDisplayNamesFromLocalFriends();
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
    _syncGeneration++;
    _syncInFlight = null;
    _lastTcpAuthSyncAt = null;
    _optimisticRetainUntilMs.clear();
    _optimisticRetainRecords.clear();
    await FriendLocalStore.instance.clearSession();
    await UserProfileLocalService.instance.clearSession();
    await FriendContactIncrementalSyncService.instance.clearSession();
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
