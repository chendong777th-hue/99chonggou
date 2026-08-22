import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 群 tip Custom 全员可见展示名：群名片 → 公开昵称 → raw uid（禁止好友备注）。
class GroupTipPublicDisplayName {
  GroupTipPublicDisplayName._();

  /// 从已有字段挑选公开名；皆空或占位则返回 null（由上层继续回退）。
  static String? pickPublicName({
    String? nameCard,
    String? nickName,
  }) {
    for (final value in [nameCard, nickName]) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      if (GroupTipsMessageHelper.isRolePlaceholderNick(text)) {
        continue;
      }
      return text;
    }
    return null;
  }

  /// 解析 tip 用公开展示名；拿不到公开名时返回 [userId] 的 raw uid。
  static Future<String> resolve({
    required String groupId,
    required String userId,
  }) async {
    final uid = ChatIdFormat.rawUserUid(userId);
    if (uid.isEmpty) {
      return '';
    }
    final gid = groupId.trim();

    try {
      final stored = await GroupMemberLocalStore.instance.readByUserIds(
        groupId: gid,
        userIds: <String>[uid],
      );
      if (stored.isNotEmpty) {
        final m = stored.first;
        final fromStore = pickPublicName(
          nameCard: m.nameCard,
          nickName: m.nickName,
        );
        if (fromStore != null) {
          return fromStore;
        }
      }
    } catch (_) {}

    try {
      final fromMemory = GroupMemberStore.instance.memberOf(gid, uid);
      if (fromMemory != null) {
        final picked = pickPublicName(
          nameCard: fromMemory.nameCard,
          nickName: fromMemory.nickName,
        );
        if (picked != null) {
          return picked;
        }
      }
    } catch (_) {}

    try {
      final friendList =
          serviceLocator<TUIFriendShipViewModel>().friendList ?? const [];
      final friend = FriendDisplayName.findFriend(friendList, uid);
      final nick = friend?.userProfile?.nickName;
      final picked = pickPublicName(nickName: nick);
      if (picked != null) {
        return picked;
      }
    } catch (_) {}

    try {
      final profile = await UserProfileLocalService.instance.read(uid);
      final picked = pickPublicName(nickName: profile?.nickname);
      if (picked != null) {
        return picked;
      }
    } catch (_) {}

    if (uid ==
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId())) {
      try {
        final self = serviceLocator<CoreServicesImpl>().loginUserInfo;
        final picked = pickPublicName(nickName: self?.nickName);
        if (picked != null) {
          return picked;
        }
      } catch (_) {}
    }

    try {
      final res = await TIMUIKitCore.getSDKInstance().getUsersInfo(
        userIDList: <String>[uid],
      );
      if (res.code == 0 && res.data != null) {
        for (final user in res.data!) {
          if (ChatIdFormat.rawUserUid(user.userID) != uid) {
            continue;
          }
          final picked = pickPublicName(nickName: user.nickName);
          if (picked != null) {
            return picked;
          }
        }
      }
    } catch (_) {}

    return uid;
  }
}
