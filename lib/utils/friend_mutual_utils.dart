import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';

/// 是否双向好友（可发消息），用于上线时间隐私判断。
bool friendCanMessage(TUIFriendShipViewModel friendship, String userId) {
  if (userId.isEmpty) {
    return false;
  }
  return friendInfoFor(friendship, userId)?.friendCustomInfo?['canMessage'] ==
      '1';
}

V2TimFriendInfo? friendInfoFor(
    TUIFriendShipViewModel friendship, String userId) {
  if (userId.isEmpty) {
    return null;
  }
  return FriendDisplayName.findFriend(friendship.friendList, userId);
}

bool friendPeerDeletedMe(TUIFriendShipViewModel friendship, String userId) {
  final info = friendInfoFor(friendship, userId);
  return info?.friendCustomInfo?['peerDeletedMe'] == '1';
}

/// 同步判断：在好友列表中且不可发消息。
bool friendCannotMessageSync(TUIFriendShipViewModel friendship, String userId) {
  if (userId.isEmpty) {
    return false;
  }
  return friendInfoFor(friendship, userId) != null &&
      !friendCanMessage(friendship, userId);
}

bool friendRelationBlockedFromInfo(V2TimFriendInfo? info) {
  final custom = info?.friendCustomInfo;
  if (custom == null) {
    return false;
  }
  if (custom['canMessage'] == '0') {
    return true;
  }
  if (custom['peerDeletedMe'] == '1') {
    return true;
  }
  return false;
}
