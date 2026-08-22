import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_privacy_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';

class GroupPrivacyCache {
  GroupPrivacyCache._();

  static final Map<String, bool> _enabledByGroupId = {};

  static void set(String groupId, bool enabled) {
    final id = groupId.trim();
    if (id.isEmpty) return;
    _enabledByGroupId[id] = enabled;
  }

  static void invalidate(String groupId) {
    _enabledByGroupId.remove(groupId.trim());
  }

  static Future<bool> privacyProtectionEnabled(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) return false;
    final cached = _enabledByGroupId[id];
    if (cached != null) return cached;
    try {
      final settings = await GroupPrivacyApi.instance.fetch(id);
      _enabledByGroupId[id] = settings.privacyProtectionEnabled;
      return settings.privacyProtectionEnabled;
    } catch (_) {
      return false;
    }
  }
}

class GroupAddFriendUiPolicy {
  const GroupAddFriendUiPolicy({
    required this.showAddButton,
    this.hiddenHint,
  });

  final bool showAddButton;
  final String? hiddenHint;

  static const GroupAddFriendUiPolicy showButton =
      GroupAddFriendUiPolicy(showAddButton: true);

  factory GroupAddFriendUiPolicy.hideButton(String hint) =>
      GroupAddFriendUiPolicy(showAddButton: false, hiddenHint: hint);
}

class GroupPrivacyGuard {
  GroupPrivacyGuard._();

  static final GroupServices _groupServices = serviceLocator<GroupServices>();
  static AppI18n get _i => AppI18n.current;

  static bool _isManagerRole(int? role) {
    return GroupRolePolicy.isManagerRole(role);
  }

  static Future<bool> isCurrentUserGroupManager(String? groupId) async {
    final gid = groupId?.trim() ?? '';
    if (gid.isEmpty) return false;
    try {
      final res = await _groupServices.getGroupsInfo(groupIDList: [gid]);
      if (res == null || res.isEmpty) return false;
      for (final item in res) {
        if (item.resultCode == 0 && item.groupInfo != null) {
          return _isManagerRole(item.groupInfo!.role);
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static Future<bool> isTargetGroupManager({
    required String groupId,
    required String targetUserId,
  }) async {
    final gid = groupId.trim();
    final target = ChatIdFormat.rawUserUid(targetUserId);
    if (gid.isEmpty || target.isEmpty) {
      return false;
    }

    final cached = GroupMemberStore.instance.memberOf(gid, target);
    if (cached != null) {
      return _isManagerRole(cached.role);
    }

    try {
      final res = await _groupServices.getGroupMembersInfo(
        groupID: gid,
        memberList: [target],
      );
      final member = res.data?.isNotEmpty == true ? res.data!.first : null;
      if (member != null) {
        GroupMemberStore.instance.putMember(gid, member, notify: false);
        return _isManagerRole(member.role);
      }
    } catch (_) {}

    return false;
  }

  static bool isGroupAddEntry({
    String? groupId,
    String? addSource,
  }) {
    // 仅当显式声明来源为群聊时才走「通过群聊添加」。
    // 群内点开用户资料/名片会带 groupId，但添加渠道应是名片，不能因 groupId 误判。
    final source = addSource?.trim() ?? '';
    if (source.isNotEmpty) {
      return source == FriendAddSource.group;
    }
    return groupId?.trim().isNotEmpty ?? false;
  }

  static Future<GroupAddFriendUiPolicy> resolveAddFriendUi({
    required String? groupId,
    required String targetUserId,
    String? addSource,
  }) async {
    final gid = groupId?.trim() ?? '';
    final target = targetUserId.trim();
    if (target.isEmpty) return GroupAddFriendUiPolicy.showButton;

    if (!isGroupAddEntry(groupId: gid, addSource: addSource)) {
      return GroupAddFriendUiPolicy.showButton;
    }

    final blockedHint = await blockedGroupProfileHint(
      groupId: gid,
      targetUserId: target,
    );
    if (blockedHint != null) {
      return GroupAddFriendUiPolicy.hideButton(blockedHint);
    }

    return checkTargetAllowsGroupAdd(target);
  }

  static Future<String?> blockedGroupProfileHint({
    required String? groupId,
    String? targetUserId,
  }) async {
    final gid = groupId?.trim() ?? '';
    if (gid.isEmpty) return null;
    try {
      if (!await GroupPrivacyCache.privacyProtectionEnabled(gid)) {
        return null;
      }
      if (await isCurrentUserGroupManager(gid)) {
        return null;
      }
      final target = ChatIdFormat.rawUserUid(targetUserId ?? '');
      if (target.isNotEmpty &&
          await isTargetGroupManager(groupId: gid, targetUserId: target)) {
        return null;
      }
    } catch (_) {
      return null;
    }
    return _i.t(
      zhHans: '当前群聊开启群隐私保护无法查看该用户信息',
      zhHant: '目前群聊開啟群隱私保護，無法查看該用戶資訊',
      en: 'Group privacy protection is on. You cannot view this user.',
      ja: 'グループのプライバシー保護が有効なため、このユーザーを表示できません',
      ko: '그룹 개인정보 보호가 켜져 있어 이 사용자를 볼 수 없습니다',
    );
  }

  static Future<GroupAddFriendUiPolicy> checkTargetAllowsGroupAdd(
    String targetUserId,
  ) async {
    final target = targetUserId.trim();
    if (target.isEmpty) return GroupAddFriendUiPolicy.showButton;

    try {
      final check = await UserApi.instance.checkAddFriend(
        targetUserId: target,
        channel: AddFriendCheckChannel.group,
      );
      if (!check.allowed) {
        return GroupAddFriendUiPolicy.hideButton(
          UserApiErrorMessage.fromAddFriendReasonCode(
            check.reason,
            fallback: _groupAddNotAllowed(),
          ),
        );
      }
      return GroupAddFriendUiPolicy.showButton;
    } catch (_) {
      // Fall back to the user privacy endpoint.
    }

    try {
      final remote = await UserApi.instance.fetchUserPrivacy(target);
      if (remote == null) {
        return GroupAddFriendUiPolicy.hideButton(_cannotVerifyAddPermission());
      }
      if (!remote.allowViaGroup) {
        return GroupAddFriendUiPolicy.hideButton(_groupAddNotAllowed());
      }
      return GroupAddFriendUiPolicy.showButton;
    } catch (_) {
      return GroupAddFriendUiPolicy.hideButton(_cannotVerifyAddPermission());
    }
  }

  @visibleForTesting
  static bool isManagerRoleForTest(int? role) => _isManagerRole(role);

  static String _groupAddNotAllowed() => _i.t(
        zhHans: '对方未开放通过群聊添加',
        zhHant: '對方未開放透過群聊添加',
        en: 'This user does not allow adds from group chats',
        ja: 'This user does not allow adds from group chats',
        ko: 'This user does not allow adds from group chats',
      );

  static String _cannotVerifyAddPermission() => _i.t(
        zhHans: '无法校验添加权限',
        zhHant: '無法校驗添加權限',
        en: 'Unable to verify add permission',
        ja: 'Unable to verify add permission',
        ko: 'Unable to verify add permission',
      );
}
