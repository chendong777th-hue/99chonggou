import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

/// 群 @ 解析结果，用于点击后跳转资料/添加页。
class GroupAtMentionTarget {
  final String userID;
  final String displayName;
  final String? faceUrl;

  const GroupAtMentionTarget({
    required this.userID,
    required this.displayName,
    this.faceUrl,
  });
}

/// 群聊 @成员：展示名解析与点击跳转。
class GroupAtMention {
  GroupAtMention._();

  static String showName(V2TimGroupMemberFullInfo member) {
    return resolveGroupSenderShowName(
      friendRemark: member.friendRemark,
      nameCard: member.nameCard,
      nickName: member.nickName,
      storeName: DisplayNameStore.instance.c2c(member.userID),
      userID: member.userID,
    );
  }

  static bool isAtAllToken(String? token) {
    final key = _normalizeMentionKey(token);
    return key == '所有人' ||
        key == '__kImSDK_MesssageAtALL__' ||
        key.toLowerCase() == 'all';
  }

  static String _normalizeMentionKey(String? token) {
    var key = token?.trim() ?? '';
    if (key.startsWith('@')) {
      key = key.substring(1).trim();
    }
    return key;
  }

  static bool _matchesAlias(
    V2TimGroupMemberFullInfo member,
    String key,
  ) {
    final userID = member.userID.trim();
    if (userID.isEmpty || key.isEmpty) {
      return false;
    }
    if (userID == key) {
      return true;
    }
    final aliases = <String>{
      showName(member),
      member.nameCard?.trim() ?? '',
      member.nickName?.trim() ?? '',
      member.friendRemark?.trim() ?? '',
      DisplayNameStore.instance.c2c(userID)?.trim() ?? '',
    };
    return aliases.any((a) => a.isNotEmpty && a == key);
  }

  /// 将消息中的 @展示名 / @UID 解析为群成员；无匹配返回 null。
  static GroupAtMentionTarget? resolveMember(
    List<V2TimGroupMemberFullInfo> members,
    String mentionToken,
  ) {
    final key = _normalizeMentionKey(mentionToken);
    if (key.isEmpty || isAtAllToken(key)) {
      return null;
    }
    for (final member in members) {
      if (!_matchesAlias(member, key)) {
        continue;
      }
      return GroupAtMentionTarget(
        userID: member.userID.trim(),
        displayName: showName(member),
        faceUrl: member.faceUrl?.trim(),
      );
    }
    return null;
  }

  static String? resolveUserId(
    List<V2TimGroupMemberFullInfo> members,
    String mentionToken,
  ) {
    return resolveMember(members, mentionToken)?.userID;
  }

  /// 会话成员列表 + 群成员缓存一起解析，避免大群分页导致点 @ 找不到人。
  static GroupAtMentionTarget? resolveInGroup({
    required String groupId,
    required List<V2TimGroupMemberFullInfo> chatMembers,
    required String mentionToken,
  }) {
    final fromChat = resolveMember(chatMembers, mentionToken);
    if (fromChat != null) {
      return fromChat;
    }
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return null;
    }
    return resolveMember(
      GroupMemberStore.instance.membersForGroup(gid),
      mentionToken,
    );
  }
}
