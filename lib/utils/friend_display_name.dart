import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

/// 与通讯录一致的 C2C 展示名：DisplayNameStore > 备注 > 昵称 > 会话名 > userID。
class FriendDisplayName {
  FriendDisplayName._();

  static final Expando<_FriendIndexSnapshot> _friendIndexCache =
      Expando<_FriendIndexSnapshot>();

  static String _friendLookupKey(String? input) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    // Normal C2C IDs are already canonical. Avoid the community-ID regex
    // chain for every visible row.
    if (!trimmed.startsWith('@') && !trimmed.contains('TGS#')) {
      return trimmed;
    }
    return ChatIdFormat.rawUserUid(trimmed);
  }

  static String fromFriend(V2TimFriendInfo item) {
    final remark = item.friendRemark?.trim() ?? '';
    if (remark.isNotEmpty) {
      return remark;
    }
    final nick = item.userProfile?.nickName?.trim() ?? '';
    if (nick.isNotEmpty) {
      return nick;
    }
    return item.userID;
  }

  static V2TimFriendInfo? findFriend(
    List<V2TimFriendInfo>? friendList,
    String? userId,
  ) {
    final id = _friendLookupKey(userId);
    if (id.isEmpty || friendList == null) {
      return null;
    }
    var snapshot = _friendIndexCache[friendList];
    if (snapshot == null || !snapshot.matches(friendList)) {
      final byId = <String, V2TimFriendInfo>{};
      for (final item in friendList) {
        final key = _friendLookupKey(item.userID);
        if (key.isNotEmpty) {
          byId[key] = item;
        }
      }
      snapshot = _FriendIndexSnapshot(
        length: friendList.length,
        first: friendList.isEmpty ? null : friendList.first,
        last: friendList.isEmpty ? null : friendList.last,
        byId: byId,
      );
      _friendIndexCache[friendList] = snapshot;
    }
    return snapshot.byId[id];
  }

  static String resolveC2C({
    String? userId,
    String? conversationShowName,
    List<V2TimFriendInfo>? friendList,
  }) {
    if (PlatformOfficialAccountService.prefersImProfileDisplayName(userId)) {
      return PlatformOfficialAccountService.resolveShowName(
        userId: userId,
        conversationShowName: conversationShowName,
      );
    }
    // 单聊资料以本地资料库的内存镜像为真源；Store / IM 只作冷启动补缺。
    final lookupId = _friendLookupKey(userId);
    final local = UserProfileLocalService.instance.readCached(lookupId);
    final localRemark = local?.friendRemark.trim() ?? '';
    if (localRemark.isNotEmpty) return localRemark;
    final localNickname = local?.nickname.trim() ?? '';
    if (localNickname.isNotEmpty) return localNickname;

    // 与 publishFriendRemarkDisplayName / 聊天顶栏写入的 Store 对齐，避免列表仍信旧 friendList。
    final storeName = DisplayNameStore.instance.c2c(lookupId)?.trim() ?? '';
    final friend = findFriend(friendList, lookupId);
    if (storeName.isNotEmpty) {
      // C：Store 恰为 IM 昵称、但好友有备注时，不跟错误的昵称帧。
      final remark = friend?.friendRemark?.trim() ?? '';
      final nick = friend?.userProfile?.nickName?.trim() ?? '';
      if (remark.isNotEmpty &&
          nick.isNotEmpty &&
          storeName == nick &&
          storeName != remark) {
        return remark;
      }
      return storeName;
    }
    if (friend != null) {
      return fromFriend(friend);
    }
    final fromConversation = conversationShowName?.trim() ?? '';
    if (fromConversation.isNotEmpty) {
      return fromConversation;
    }
    return userId?.trim() ?? '';
  }

  /// 本地库优先：备注 > 昵称 > 会话名 > userID（不走 IM 好友备注）。
  static String resolveLocalFirst({
    UserProfileRecord? localProfile,
    String? userId,
    String? conversationShowName,
  }) {
    if (PlatformOfficialAccountService.prefersImProfileDisplayName(userId)) {
      return PlatformOfficialAccountService.resolveShowName(
        userId: userId,
        conversationShowName: conversationShowName,
      );
    }
    final remark = localProfile?.friendRemark.trim() ?? '';
    if (remark.isNotEmpty) {
      return remark;
    }
    final nickname = localProfile?.nickname.trim() ?? '';
    if (nickname.isNotEmpty) {
      return nickname;
    }
    final fromConversation = conversationShowName?.trim() ?? '';
    if (fromConversation.isNotEmpty) {
      return fromConversation;
    }
    return userId?.trim() ?? '';
  }

  static String resolveConversation({
    required V2TimConversation conversation,
    List<V2TimFriendInfo>? friendList,
    Iterable<V2TimGroupInfo>? groupList,
    String? localGroupName,
  }) {
    final groupId = conversation.groupID?.trim() ?? '';
    if (conversation.type == 2 || groupId.isNotEmpty) {
      return GroupDisplayResolver.resolveShowName(
        conversation: conversation,
        groupList: groupList,
        localGroupName: localGroupName,
      );
    }
    return resolveC2C(
      userId: conversation.userID,
      conversationShowName: conversation.showName,
      friendList: friendList,
    );
  }
}

class _FriendIndexSnapshot {
  const _FriendIndexSnapshot({
    required this.length,
    required this.first,
    required this.last,
    required this.byId,
  });

  final int length;
  final V2TimFriendInfo? first;
  final V2TimFriendInfo? last;
  final Map<String, V2TimFriendInfo> byId;

  bool matches(List<V2TimFriendInfo> list) {
    return list.length == length &&
        (list.isEmpty || identical(list.first, first)) &&
        (list.isEmpty || identical(list.last, last));
  }
}
