import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';

class ConversationFaceUrl {
  ConversationFaceUrl._();

  static const String defaultGroupFaceAsset = 'assets/default_group_avatar.svg';

  static String resolve({
    required String? userId,
    required String? conversationFaceUrl,
    bool isGroup = false,
    Iterable<V2TimFriendInfo>? friendList,
    Iterable<V2TimGroupInfo>? groupList,
    String? groupId,
  }) {
    if (isGroup) {
      final gid = groupId?.trim() ?? '';
      // 展示信群资料库：本地群头像优先于 groupList / 会话行。
      String localUrl = '';
      try {
        localUrl =
            GroupLocalStore.instance.readCached(groupId: gid)?.avatarUrl.trim() ??
                '';
      } catch (_) {
        localUrl = '';
      }
      if (_isUsable(localUrl)) {
        return localUrl;
      }
      final fromRest = GroupDisplayResolver.findGroup(groupList, gid);
      final restUrl = fromRest?.faceUrl?.trim() ?? '';
      if (restUrl.isNotEmpty &&
          !UserAvatarHelper.isDefaultPlaceholder(restUrl)) {
        return restUrl;
      }
    }
    final resolved = PlatformOfficialAccountService.resolveFaceUrl(
      userId: userId,
      conversationFaceUrl: conversationFaceUrl,
    );
    if (isGroup && !_isUsable(resolved)) {
      return defaultGroupFaceAsset;
    }
    final id = userId?.trim() ?? '';
    if (!isGroup && id.isNotEmpty) {
      final local = UserAvatarHelper.usableAvatarOrEmpty(
        UserProfileLocalService.instance.readCached(id)?.avatarUrl,
      );
      if (local.isNotEmpty) return local;
    }
    if (id.isEmpty ||
        PlatformOfficialAccountService.isPlatformOfficialAccount(id) ||
        _isUsable(resolved)) {
      return resolved;
    }
    for (final friend in friendList ?? const <V2TimFriendInfo>[]) {
      if (friend.userID != id) continue;
      final face = friend.userProfile?.faceUrl?.trim() ?? '';
      if (_isUsable(face)) {
        return face;
      }
      break;
    }
    return resolved;
  }

  static bool _isUsable(String url) {
    final trimmed = url.trim();
    return trimmed.isNotEmpty &&
        !UserAvatarHelper.isDefaultPlaceholder(trimmed);
  }
}
