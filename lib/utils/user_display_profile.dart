import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

/// 通讯录 / 群成员 / 聊天发送人 / 朋友圈共用的头像昵称真源。
///
/// 写入走 [UserProfileLocalService]；展示一律从这里读，并监听
/// [PeerProfileRefreshBus] 刷新。
class UserDisplayProfile {
  UserDisplayProfile._();

  static UserProfileCachedSnapshot? cachedSnapshot(String? userId) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    final record = UserProfileLocalService.instance.readCached(id) ??
        UserProfileLocalService.instance
            .readCached(ChatIdFormat.rawUserUid(id));
    if (record == null) {
      return null;
    }
    return UserProfileCachedSnapshot(
      remark: record.friendRemark,
      nickname: record.nickname,
      avatarUrl: record.avatarUrl,
    );
  }

  static String name({
    required String userId,
    String? nameCard,
    String? imRemark,
    String? imNickName,
    String? fallbackName,
    String? conversationShowName,
  }) {
    if (PlatformOfficialAccountService.prefersImProfileDisplayName(userId)) {
      return PlatformOfficialAccountService.resolveShowName(
        userId: userId,
        conversationShowName: conversationShowName ?? fallbackName,
      );
    }
    // A group name card is specific to this membership and wins. For the
    // public profile, the local profile store wins over stale message snapshots.
    final local = UserProfileLocalService.instance.readCached(userId);
    final resolved = memberDisplayName(
      friendRemark: nameCard?.trim().isNotEmpty == true
          ? imRemark
          : (local?.friendRemark ?? imRemark),
      nameCard: nameCard,
      nickName:
          local?.nickname.isNotEmpty == true ? local!.nickname : imNickName,
      storeName: DisplayNameStore.instance.c2c(userId),
      userID: userId,
    );
    if (resolved.isNotEmpty &&
        !DisplayNameStore.isRawUserIdDisplayName(userId, resolved)) {
      return resolved;
    }
    final fallback = (conversationShowName ?? fallbackName)?.trim() ?? '';
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return FriendDisplayName.resolveLocalFirst(
      localProfile: UserProfileLocalService.instance.readCached(userId),
      userId: userId,
      conversationShowName: conversationShowName ?? fallbackName,
    );
  }

  static String nameOfFriend(V2TimFriendInfo item) {
    return name(
      userId: item.userID,
      imRemark: item.friendRemark,
      imNickName: item.userProfile?.nickName,
      fallbackName: FriendDisplayName.fromFriend(item),
    );
  }

  static String nameOfMember(V2TimGroupMemberFullInfo member) {
    return name(
      userId: member.userID,
      nameCard: member.nameCard,
      imRemark: member.friendRemark,
      imNickName: member.nickName,
    );
  }

  static String nameOfSnapshot(MomentUserSnapshot user) {
    return name(
      userId: user.id,
      fallbackName: user.name,
    );
  }

  static String avatar({
    required String userId,
    String? fallbackIm,
    bool isSelf = false,
  }) {
    if (PlatformOfficialAccountService.prefersImProfileDisplayName(userId)) {
      return PlatformOfficialAccountService.resolveFaceUrl(
        userId: userId,
        conversationFaceUrl: fallbackIm,
      );
    }
    if (isSelf) {
      final selfFace = UserAvatarHelper.currentSelfFaceUrl();
      return UserAvatarHelper.pickBestPreferBackend(
        backendAvatarUrl:
            UserProfileLocalService.instance.readCached(userId)?.avatarUrl,
        imFaceUrl: selfFace.isNotEmpty ? selfFace : fallbackIm,
      );
    }
    return UserAvatarHelper.pickBestPreferBackend(
      backendAvatarUrl:
          UserProfileLocalService.instance.readCached(userId)?.avatarUrl,
      imFaceUrl: fallbackIm,
    );
  }

  static String avatarOfFriend(V2TimFriendInfo item) {
    return avatar(
      userId: item.userID,
      fallbackIm: item.userProfile?.faceUrl,
    );
  }

  static String avatarOfMember(V2TimGroupMemberFullInfo member) {
    return avatar(
      userId: member.userID,
      fallbackIm: member.faceUrl,
    );
  }

  static String avatarOfSnapshot(MomentUserSnapshot user) {
    return avatar(
      userId: user.id,
      fallbackIm: user.avatarUrl,
    );
  }
}
