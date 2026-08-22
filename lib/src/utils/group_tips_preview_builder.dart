import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 根据 TCP / change-events 的真实操作者生成群成员变动灰字文案。
class GroupTipsPreviewBuilder {
  GroupTipsPreviewBuilder._();

  static Future<String> build({
    required String groupId,
    required String action,
    required String operatorUserId,
    required List<String> memberUserIds,
  }) async {
    final normalizedAction = action.trim().toLowerCase();
    final operator = await _resolveDisplayName(
      groupId: groupId,
      userId: operatorUserId,
      normalizeAdmin: true,
    );
    switch (normalizedAction) {
      case 'member_added':
        final names = await _resolveMemberNames(groupId, memberUserIds);
        return '$operator邀请$names加入群组';
      case 'member_removed':
        final names = await _resolveMemberNames(groupId, memberUserIds);
        return '$operator将$names踢出群组';
      case 'member_left':
        final leaver = memberUserIds.isNotEmpty
            ? memberUserIds.first
            : operatorUserId;
        final name = await _resolveDisplayName(
          groupId: groupId,
          userId: leaver,
        );
        return '$name退出群聊';
      case 'member_muted':
        final names = await _resolveMemberNames(groupId, memberUserIds);
        return '$operator将$names禁言';
      case 'member_unmuted':
        final names = await _resolveMemberNames(groupId, memberUserIds);
        return '$operator解除了$names的禁言';
      case 'group_mute_all_on':
        return '$operator开启了全员禁言';
      case 'group_mute_all_off':
        return '$operator关闭了全员禁言';
      case 'member_set_admin':
        final names = await _resolveMemberNames(groupId, memberUserIds);
        return '$operator将$names设置为管理员';
      case 'member_cancel_admin':
        final names = await _resolveMemberNames(groupId, memberUserIds);
        return '$operator将$names取消管理员';
      default:
        return '群提示';
    }
  }

  static Future<String> _resolveMemberNames(
    String groupId,
    List<String> memberUserIds,
  ) async {
    final names = <String>[];
    for (final userId in memberUserIds) {
      final name = await _resolveDisplayName(groupId: groupId, userId: userId);
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    return names.join('、');
  }

  static Future<String> _resolveDisplayName({
    required String groupId,
    required String userId,
    bool normalizeAdmin = false,
  }) async {
    final normalized = ChatIdFormat.rawUserUid(userId);
    if (normalized.isEmpty) {
      return '';
    }

    final fromStore = await GroupMemberLocalStore.instance.readByUserIds(
      groupId: groupId,
      userIds: <String>[normalized],
    );
    if (fromStore.isNotEmpty) {
      return _displayNameFromMember(fromStore.first, normalizeAdmin: normalizeAdmin);
    }

    final fromMemory = GroupMemberStore.instance.memberOf(groupId, normalized);
    if (fromMemory != null) {
      return _displayNameFromInfo(
        userId: normalized,
        nickName: fromMemory.nickName,
        nameCard: fromMemory.nameCard,
        friendRemark: fromMemory.friendRemark,
        normalizeAdmin: normalizeAdmin,
      );
    }

    try {
      final friendList =
          serviceLocator<TUIFriendShipViewModel>().friendList ?? const [];
      final friend = FriendDisplayName.findFriend(friendList, normalized);
      if (friend != null) {
        return _displayNameFromInfo(
          userId: normalized,
          nickName: friend.userProfile?.nickName,
          friendRemark: friend.friendRemark,
          normalizeAdmin: normalizeAdmin,
        );
      }
    } catch (_) {}

    try {
      final profile = await UserProfileLocalService.instance.read(normalized);
      if (profile != null) {
        final remark = profile.friendRemark.trim();
        final nickname = profile.nickname.trim();
        if (remark.isNotEmpty) {
          return _normalizeAdminLabel(remark, normalizeAdmin: normalizeAdmin);
        }
        if (nickname.isNotEmpty) {
          return _normalizeAdminLabel(nickname, normalizeAdmin: normalizeAdmin);
        }
      }
    } catch (_) {}

    try {
      final res = await TIMUIKitCore.getSDKInstance().getUsersInfo(
        userIDList: <String>[normalized],
      );
      if (res.code == 0 && res.data != null) {
        for (final user in res.data!) {
          final uid = ChatIdFormat.rawUserUid(user.userID);
          final nick = user.nickName?.trim() ?? '';
          if (uid == normalized && nick.isNotEmpty) {
            return _normalizeAdminLabel(nick, normalizeAdmin: normalizeAdmin);
          }
        }
      }
    } catch (_) {}

    return _normalizeAdminLabel(normalized, normalizeAdmin: normalizeAdmin);
  }

  static String _displayNameFromMember(
    dynamic member, {
    required bool normalizeAdmin,
  }) {
    return _displayNameFromInfo(
      userId: member.userID?.toString() ?? '',
      nickName: member.nickName?.toString(),
      nameCard: member.nameCard?.toString(),
      friendRemark: member.friendRemark?.toString(),
      normalizeAdmin: normalizeAdmin,
    );
  }

  static String _displayNameFromInfo({
    required String userId,
    String? nickName,
    String? nameCard,
    String? friendRemark,
    required bool normalizeAdmin,
  }) {
    for (final value in [friendRemark, nameCard, nickName, userId]) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      if (GroupTipsMessageHelper.isRolePlaceholderNick(text)) {
        if (normalizeAdmin) {
          return GroupTipsMessageHelper.normalizeGroupOperatorDisplayName(text);
        }
        continue;
      }
      return _normalizeAdminLabel(text, normalizeAdmin: normalizeAdmin);
    }
    return _normalizeAdminLabel(userId, normalizeAdmin: normalizeAdmin);
  }

  static String _normalizeAdminLabel(
    String name, {
    required bool normalizeAdmin,
  }) {
    if (!normalizeAdmin) {
      return name;
    }
    return GroupTipsMessageHelper.normalizeGroupOperatorDisplayName(name);
  }
}
