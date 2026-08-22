import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

class UserProfileLocalService {
  UserProfileLocalService._();

  static final UserProfileLocalService instance = UserProfileLocalService._();

  final UserProfileLocalStore _store = UserProfileLocalStore.instance;

  final Map<String, UserProfileRecord> _memory = <String, UserProfileRecord>{};

  /// 页面同步渲染时的单聊资料真源。首次 [read] 后由所有写入统一维护。
  UserProfileRecord? readCached(String userId) => _memory[userId.trim()];

  Future<UserProfileRecord?> read(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    final cached = _memory[id];
    if (cached != null) return cached;
    final record = await _store.read(userId: id);
    if (record != null) _memory[id] = record;
    return record;
  }

  Future<void> _saveAndPublish(UserProfileRecord next) async {
    final id = next.userId.trim();
    if (id.isEmpty) return;
    final previous = _memory[id];
    await _store.upsert(record: next);
    _memory[id] = next;
    final displayName = next.friendRemark.trim().isNotEmpty
        ? next.friendRemark.trim()
        : (next.nickname.trim().isNotEmpty ? next.nickname.trim() : id);
    // 包括“清空备注”：必须覆盖 Store 的旧备注，不能保留旧值。
    DisplayNameStore.instance.setC2C(id, displayName, notify: false);
    GroupMemberStore.instance.putProfileForUser(
      userID: id,
      nickName: next.nickname,
      faceUrl: next.avatarUrl,
    );
    GroupMemberStore.instance.putFriendRemarkForUser(
      id,
      next.friendRemark,
    );
    if (previous == null ||
        previous.nickname != next.nickname ||
        previous.avatarUrl != next.avatarUrl ||
        previous.friendRemark != next.friendRemark) {
      PeerProfileRefreshBus.instance.notify(id);
    }
  }

  Future<V2TimFriendInfo?> loadFriendInfo(String userId) async {
    final record = await read(userId);
    return mergeHostedFriendRemark(userId, record?.toV2TimFriendInfo());
  }

  /// 当资料缓存里没有备注时，从 [FriendLocalStore]（通讯录同源）补齐；
  /// 已清空的备注也必须覆盖 IM 残留值。
  Future<V2TimFriendInfo?> mergeHostedFriendRemark(
    String userId,
    V2TimFriendInfo? info,
  ) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return info;
    }

    var target = info ?? V2TimFriendInfo(userID: id);
    target.userProfile ??= V2TimUserFullInfo(userID: id);

    final friendRecord = await MeFriendApi.instance.cachedByUserId(id);
    if (friendRecord == null) {
      return info == null ? null : target;
    }

    // 自托管好友库是备注真源：空字符串表示已清空，不能被 IM 旧备注顶回去。
    target.friendRemark = friendRecord.remark.trim();

    final nickname = friendRecord.friendNickname.trim();
    if (nickname.isNotEmpty &&
        (target.userProfile?.nickName?.trim().isEmpty ?? true)) {
      target.userProfile!.nickName = nickname;
    }

    final avatar = friendRecord.friendAvatarUrl.trim();
    if (avatar.isNotEmpty &&
        (target.userProfile?.faceUrl?.trim().isEmpty ?? true)) {
      target.userProfile!.faceUrl = avatar;
    }

    return target;
  }

  Future<V2TimUserFullInfo?> loadUserFullInfo(String userId) async {
    final record = await read(userId);
    return record?.toV2TimUserFullInfo();
  }

  Future<void> saveFriendInfo(V2TimFriendInfo? info) async {
    if (info == null) {
      return;
    }
    final id = info.userID.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = await read(id);
    final next = (existing ?? UserProfileRecord(userId: id))
        .mergeSdkRemotePreferLocal(info);
    await _saveAndPublish(next);
  }

  Future<void> saveUserFullInfo(V2TimUserFullInfo? info) async {
    if (info == null) {
      return;
    }
    final id = info.userID?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    final existing = await read(id);
    final next = (existing ?? UserProfileRecord(userId: id))
        .mergeSdkRemoteUserInfoPreferLocal(info);
    await _saveAndPublish(next);
  }

  Future<void> saveMeResult(MeResult me) async {
    final id = me.userId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = await read(id);
    final next = (existing ?? UserProfileRecord(userId: id)).copyWith(
      nickname: me.nickname.trim().isNotEmpty
          ? me.nickname.trim()
          : (existing?.nickname ?? ''),
      avatarUrl: me.avatarUrl?.trim().isNotEmpty == true
          ? me.avatarUrl!.trim()
          : (existing?.avatarUrl ?? ''),
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await _saveAndPublish(next);
  }

  /// 自建 API 公开资料写入本地（强制覆盖昵称/头像）。
  Future<void> saveBackendProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = await read(id);
    final next = (existing ?? UserProfileRecord(userId: id)).copyWith(
      nickname: nickname?.trim().isNotEmpty == true
          ? nickname!.trim()
          : (existing?.nickname ?? ''),
      avatarUrl: avatarUrl?.trim().isNotEmpty == true
          ? avatarUrl!.trim()
          : (existing?.avatarUrl ?? ''),
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await _saveAndPublish(next);
  }

  Future<void> saveFriendRecord(MeFriendRecord record) async {
    final id = record.friendUserId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = await read(id);
    final next = (existing ?? UserProfileRecord(userId: id)).copyWith(
      nickname: record.friendNickname.trim().isNotEmpty
          ? record.friendNickname.trim()
          : (existing?.nickname ?? ''),
      avatarUrl: record.friendAvatarUrl.trim().isNotEmpty
          ? record.friendAvatarUrl.trim()
          : (existing?.avatarUrl ?? ''),
      friendRemark: record.remark.trim(),
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await _saveAndPublish(next);
  }

  /// 显式写入备注，空字符串表示清空（不会回退到旧备注）。
  Future<void> saveFriendRemark({
    required String userId,
    required String remark,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = await read(id);
    final next = (existing ?? UserProfileRecord(userId: id)).copyWith(
      friendRemark: remark.trim(),
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await _saveAndPublish(next);
  }

  Future<V2TimFriendInfo?> mergePreferLocal(
    String userId,
    V2TimFriendInfo? remote,
  ) async {
    final localRecord = await read(userId);
    if (localRecord == null) {
      if (remote != null) {
        await saveFriendInfo(remote);
      }
      return remote;
    }
    final local = localRecord.toV2TimFriendInfo();
    if (remote == null) {
      return local;
    }
    final merged = localRecord.mergeSdkRemotePreferLocal(remote);
    await _saveAndPublish(merged);
    return merged.toV2TimFriendInfo();
  }

  Future<void> hydrateFromFriendLocalStore() async {
    final friends = await FriendLocalStore.instance.readAll();
    for (final friend in friends) {
      await saveFriendRecord(friend);
    }
  }

  Future<void> clearSession() {
    _memory.clear();
    return _store.clearSession();
  }
}
