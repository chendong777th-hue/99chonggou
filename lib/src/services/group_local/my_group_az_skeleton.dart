import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

/// 「我的群聊」AZ 轻量行：避免进页全量 [MeGroupRecord]→[V2TimGroupInfo]+现场拼音。
class MyGroupAzSkeleton {
  const MyGroupAzSkeleton({
    required this.groupId,
    required this.groupType,
    required this.groupName,
    required this.avatarUrl,
    required this.memberCount,
    required this.myRole,
    required this.indexTag,
  });

  final String groupId;
  final String groupType;
  final String groupName;
  final String avatarUrl;
  final int memberCount;
  final int myRole;
  final String indexTag;

  String get showName {
    final name = groupName.trim();
    return name.isNotEmpty ? name : groupId;
  }

  /// 与 TIMUIKitGroup / 通讯录同一套字母标签算法。
  static String computeIndexTagForShowName(String showName) {
    return memberSuspensionIndexTag(showName);
  }

  static String showNameOf({
    required String groupName,
    required String groupId,
  }) {
    final name = groupName.trim();
    return name.isNotEmpty ? name : groupId.trim();
  }

  static String computeIndexTag({
    required String groupName,
    required String groupId,
  }) {
    return computeIndexTagForShowName(
      showNameOf(groupName: groupName, groupId: groupId),
    );
  }

  V2TimGroupInfo toV2TimGroupInfo() {
    final imGroupId = ChatIdFormat.isIMGroupOrCommunityId(groupId)
        ? ChatIdFormat.normalizeGroupId(groupId)
        : groupId;
    return V2TimGroupInfo(
      groupID: imGroupId.isNotEmpty ? imGroupId : groupId,
      groupType: groupType,
      groupName: groupName,
      faceUrl: avatarUrl,
      memberCount: memberCount,
      role: myRole,
    );
  }
}
