import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';

class RedPacketMember {
  final String userId;

  /// Current user's private display name for the picker (remark first).
  final String name;

  /// Public nickname used in wallet payloads and group-visible cards.
  final String publicName;
  final String avatar;
  final String qq;

  const RedPacketMember({
    required this.userId,
    required this.name,
    this.publicName = '',
    this.avatar = '',
    this.qq = '',
  });

  factory RedPacketMember.fromGroupMember(V2TimGroupMemberFullInfo item) {
    final userId = item.userID.trim();
    final nickname = item.nickName?.trim() ?? '';
    return RedPacketMember(
      userId: userId,
      name: UserDisplayProfile.nameOfMember(item),
      publicName: nickname.isNotEmpty ? nickname : userId,
      avatar: item.faceUrl?.trim() ?? '',
    );
  }

  factory RedPacketMember.fromFriend(V2TimFriendInfo item) {
    final userId = item.userID.trim();
    final nickname = item.userProfile?.nickName?.trim() ?? '';
    return RedPacketMember(
      userId: userId,
      name: UserDisplayProfile.nameOfFriend(item),
      publicName: nickname.isNotEmpty ? nickname : userId,
      avatar: item.userProfile?.faceUrl?.trim() ?? '',
    );
  }

  String get publicNameOrFallback {
    final value = publicName.trim();
    if (value.isNotEmpty) return value;
    final legacyName = name.trim();
    return legacyName.isNotEmpty ? legacyName : userId.trim();
  }
}
