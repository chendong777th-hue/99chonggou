import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/src/pages/join_group_application_page.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_at_mention.dart';
import 'package:tencent_cloud_chat_demo/utils/group_join_lookup.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';

/// 点击消息中的 `@用户ID` / `@群ID` 时，先校验存在再打开资料页。
class ChatIdMentionNavigator {
  ChatIdMentionNavigator._();

  static Future<void> open(
    BuildContext context,
    String mention, {
    String? groupMemberUserId,
    String? groupMemberNickname,
    String? groupMemberAvatarUrl,
    String? groupId,
    void Function(V2TimConversation conversation)? directToChat,
  }) async {
    final trimmed = mention.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final gid = groupId?.trim() ?? '';
    final memberUserId = groupMemberUserId?.trim() ?? '';
    if (gid.isNotEmpty) {
      await _openGroupChatMention(
        context,
        mention: trimmed,
        groupId: gid,
        groupMemberUserId: memberUserId,
        groupMemberNickname: groupMemberNickname,
        groupMemberAvatarUrl: groupMemberAvatarUrl,
      );
      return;
    }

    if (memberUserId.isNotEmpty) {
      if (ProfilePageNav.isSelfUser(memberUserId)) {
        await ProfilePageNav.openMyProfileDetail(context);
        return;
      }
      if (!context.mounted) {
        return;
      }
      await ProfilePageNav.openUserProfileOrAddFriend(
        context,
        userID: memberUserId,
        nickname: groupMemberNickname,
        avatarUrl: groupMemberAvatarUrl,
        addSource: FriendAddSource.chat,
      );
      return;
    }

    final normalized = ChatIdFormat.normalizeSearchKeyword(trimmed);
    if (ChatIdFormat.isIMGroupOrCommunityId(trimmed) ||
        normalized.toUpperCase().contains('TGS#')) {
      final groupKey = normalized.isNotEmpty
          ? ChatIdFormat.canonicalGroupStorageId(normalized)
          : ChatIdFormat.canonicalGroupStorageId(trimmed);
      await _openJoinGroupPage(
        context,
        groupKey.isNotEmpty ? groupKey : trimmed,
        directToChat: directToChat,
      );
      return;
    }

    final id = ChatIdFormat.rawUserUid(
      trimmed.startsWith('@') ? trimmed : '@$trimmed',
    );
    if (id.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '用户或群聊不存在',
        zhHant: '用戶或群聊不存在',
        en: 'User or group chat not found',
        ja: 'ユーザーまたはグループチャットが見つかりません',
        ko: '사용자 또는 그룹 채팅을 찾을 수 없습니다',
      ));
      return;
    }

    if (ProfilePageNav.isSelfUser(id)) {
      await ProfilePageNav.openMyProfileDetail(context);
      return;
    }

    final userResolve = await _resolveExistingUserId(id);
    if (userResolve.userId != null) {
      if (!context.mounted) {
        return;
      }
      await ProfilePageNav.openUserProfileOrAddFriend(
        context,
        userID: userResolve.userId!,
        nickname: userResolve.nickname,
        avatarUrl: userResolve.avatarUrl,
        lastActiveAt: userResolve.lastActiveAt,
        lastActiveVisibility: userResolve.lastActiveVisibility,
        addSource: groupId != null && groupId.trim().isNotEmpty
            ? FriendAddSource.card
            : FriendAddSource.chat,
        groupId: groupId,
      );
      return;
    }
    if (!userResolve.tryGroup) {
      return;
    }

    await _openJoinGroupPage(context, id, directToChat: directToChat);
  }

  /// 群聊点 @：走群隐私保护 + 资料/加好友，绝不走搜好友。
  static Future<void> _openGroupChatMention(
    BuildContext context, {
    required String mention,
    required String groupId,
    required String groupMemberUserId,
    String? groupMemberNickname,
    String? groupMemberAvatarUrl,
  }) async {
    if (GroupAtMention.isAtAllToken(mention) ||
        GroupAtMention.isAtAllToken(groupMemberUserId)) {
      return;
    }

    if (ChatIdFormat.isIMGroupOrCommunityId(mention) ||
        mention.toUpperCase().contains('TGS#')) {
      await _openJoinGroupPage(context, mention);
      return;
    }

    final resolved = GroupAtMention.resolveInGroup(
      groupId: groupId,
      chatMembers: const [],
      mentionToken: mention,
    );
    var userId = groupMemberUserId.isNotEmpty
        ? groupMemberUserId
        : (resolved?.userID ?? '');
    if (userId.isEmpty) {
      final asUid = ChatIdFormat.rawUserUid(mention);
      if (ChatIdFormat.isUserUidToken(asUid)) {
        userId = asUid;
      }
    }
    final nickname = (groupMemberNickname?.trim().isNotEmpty ?? false)
        ? groupMemberNickname
        : resolved?.displayName;
    final avatarUrl = (groupMemberAvatarUrl?.trim().isNotEmpty ?? false)
        ? groupMemberAvatarUrl
        : resolved?.faceUrl;

    if (userId.isNotEmpty && ProfilePageNav.isSelfUser(userId)) {
      await ProfilePageNav.openMyProfileDetail(context);
      return;
    }

    if (userId.isEmpty) {
      final blocked = await GroupPrivacyGuard.blockedGroupProfileHint(
        groupId: groupId,
      );
      if (!context.mounted) {
        return;
      }
      ToastUtils.toast(
        blocked ??
            AppI18n.of(context).t(
              zhHans: '无法查看该用户信息',
              zhHant: '無法查看該用戶資訊',
              en: 'Unable to view this user',
              ja: 'このユーザー情報を表示できません',
              ko: '이 사용자 정보를 볼 수 없습니다',
            ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    await ProfilePageNav.openUserProfileOrAddFriend(
      context,
      userID: userId,
      nickname: nickname,
      avatarUrl: avatarUrl,
      addSource: FriendAddSource.card,
      groupId: groupId,
    );
  }

  static Future<void> _openJoinGroupPage(
    BuildContext context,
    String groupKey, {
    void Function(V2TimConversation conversation)? directToChat,
  }) async {
    V2TimGroupInfo? groupInfo;
    try {
      groupInfo = await GroupJoinLookup.resolve(
        groupKey: groupKey,
        joinSource: GroupJoinSource.groupAlias,
      );
    } on GroupJoinLookupDisabledException catch (error) {
      ToastUtils.toast(GroupJoinLookup.disabledMessage(
        AppI18n.of(context),
        error,
      ));
      return;
    }
    if (groupInfo == null) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '群聊不存在',
        zhHant: '群聊不存在',
        en: 'Group chat not found',
        ja: 'グループチャットが見つかりません',
        ko: '그룹 채팅을 찾을 수 없습니다',
      ));
      return;
    }
    if (!context.mounted) {
      return;
    }
    final resolvedGroup = groupInfo;
    await Navigator.push(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => JoinGroupApplicationPage(
          groupInfo: resolvedGroup,
          directToChat: directToChat,
          joinSource: GroupJoinSource.groupAlias,
        ),
      ),
    );
  }

  /// 通过后端搜索确认用户存在。
  static Future<
      ({
        String? userId,
        String? nickname,
        String? avatarUrl,
        int? lastActiveAt,
        String? lastActiveVisibility,
        bool tryGroup,
      })> _resolveExistingUserId(String id) async {
    try {
      final hit = await UserApi.instance.searchUser(keyword: id);
      final userId = hit.userId.trim();
      if (userId.isEmpty) {
        return (
          userId: null,
          nickname: null,
          avatarUrl: null,
          lastActiveAt: null,
          lastActiveVisibility: null,
          tryGroup: true,
        );
      }
      return (
        userId: userId,
        nickname: hit.nickname,
        avatarUrl: hit.avatarUrl,
        lastActiveAt: hit.lastActiveAt,
        lastActiveVisibility: hit.lastActiveVisibility,
        tryGroup: false,
      );
    } on DioError catch (e) {
      if (_isUserNotFound(e)) {
        return (
          userId: null,
          nickname: null,
          avatarUrl: null,
          lastActiveAt: null,
          lastActiveVisibility: null,
          tryGroup: true,
        );
      }
      ToastUtils.toast(UserApiErrorMessage.fromSearch(e));
      return (
        userId: null,
        nickname: null,
        avatarUrl: null,
        lastActiveAt: null,
        lastActiveVisibility: null,
        tryGroup: false,
      );
    } catch (_) {
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '搜索失败',
        zhHant: '搜尋失敗',
        en: 'Search failed',
        ja: '検索に失敗しました',
        ko: '검색 실패',
      ));
      return (
        userId: null,
        nickname: null,
        avatarUrl: null,
        lastActiveAt: null,
        lastActiveVisibility: null,
        tryGroup: false,
      );
    }
  }

  static bool _isUserNotFound(DioError e) {
    if (e.response?.statusCode == 404) {
      return true;
    }
    final data = e.response?.data;
    if (data is Map) {
      return data['code']?.toString() == 'USER_NOT_FOUND';
    }
    return false;
  }
}
