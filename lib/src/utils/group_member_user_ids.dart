import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

List<String> normalizeMemberUserIds(List<V2TimFriendInfo> members) {
  return members
      .map((friend) => ChatIdFormat.rawUserUid(friend.userID))
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}
