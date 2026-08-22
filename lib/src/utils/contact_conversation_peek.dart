import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/starred_friend_provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peek_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_display_helper.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_actions.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';

/// 通讯录联系人长按：会话预览 + 联系人专属操作菜单。
class ContactConversationPeek {
  ContactConversationPeek._();

  static String _friendShowName(V2TimFriendInfo friend) {
    return FriendDisplayName.resolveLocalFirst(
      localProfile:
          UserProfileLocalService.instance.readCached(friend.userID),
      userId: friend.userID,
      conversationShowName: FriendDisplayName.fromFriend(friend),
    );
  }

  static Future<V2TimConversation> resolveConversation(
    V2TimFriendInfo friend,
  ) async {
    final userId = friend.userID.trim();
    final conversationID = 'c2c_$userId';

    final fromNotifier = ConversationListNotifier.instance.conversations
        .where((item) => item.conversationID == conversationID)
        .firstOrNull;
    if (fromNotifier != null) {
      return fromNotifier;
    }

    for (final item in serviceLocator<TUIConversationViewModel>().conversationList) {
      if (item?.conversationID == conversationID && item != null) {
        return item;
      }
    }

    final res = await TIMUIKitCore.getSDKInstance()
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    return res.data ??
        V2TimConversation(
          conversationID: conversationID,
          userID: userId,
          type: 1,
          showName: _friendShowName(friend),
          faceUrl: UserAvatarHelper.pickBestPreferBackend(
            imFaceUrl: friend.userProfile?.faceUrl,
            backendAvatarUrl: UserProfileLocalService.instance
                .readCached(friend.userID)
                ?.avatarUrl,
          ),
        );
  }

  static String? _onlineStatusText(
    BuildContext context,
    V2TimConversation conversation,
  ) {
    final localSetting = Provider.of<LocalSetting>(context, listen: false);
    if (!localSetting.isShowOnlineStatus) {
      return null;
    }
    final userId = conversation.userID?.trim() ?? '';
    if (userId.isEmpty ||
        PlatformOfficialAccountService.showsVerifiedBadge(userId)) {
      return null;
    }
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    final onlineStatus = friendship.userStatusList.firstWhere(
      (item) => item.userID == userId,
      orElse: () => V2TimUserStatus(statusType: 0),
    );
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    presence.ensure([userId]);
    presence.refresh([userId], urgent: true);
    final label = presence.listLabelFor(
      userId: userId,
      imOnline: onlineStatus.statusType == 1,
      isMutualFriend: friendCanMessage(friendship, userId),
    );
    return label.isEmpty ? null : label;
  }

  static Future<void> _toggleStar(
    BuildContext context,
    String userId,
  ) async {
    final starred = StarredFriendProvider.shared;
    final isStarred = starred.isStarred(userId);
    try {
      if (isStarred) {
        await starred.unstar(userId);
      } else {
        await starred.star(userId);
      }
    } on DioError catch (e) {
      ToastUtils.toast(UserApiErrorMessage.fromStarredFriend(e));
    } catch (_) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '操作失败',
        zhHant: '操作失敗',
        en: 'Operation failed',
        ja: '操作に失敗',
        ko: '작업 실패',
      ));
    }
  }

  static Future<void> _deleteFriend(
    BuildContext context,
    String userId,
  ) async {
    final i18n = AppI18n.of(context);
    try {
      await MeFriendApi.instance.deleteFriend(userId);
      try {
        await serviceLocator<ConversationService>().deleteConversation(
          conversationID: 'c2c_$userId',
        );
      } catch (_) {}
      try {
        final friendship = serviceLocator<TUIFriendShipViewModel>();
        await friendship.loadContactListData();
        await friendship.loadContactApplicationData();
      } catch (_) {}
      ConversationRefreshBus.instance.requestRefresh(reason: 'friend_deleted');
      ToastUtils.toast(i18n.t(
        zhHans: '好友删除成功',
        zhHant: '好友刪除成功',
        en: 'Friend removed',
        ja: '友達を削除しました',
        ko: '친구 삭제 완료',
      ));
    } on DioError catch (e) {
      ToastUtils.toast(UserApiErrorMessage.fromFriendRequest(e));
    } catch (_) {
      ToastUtils.toast(i18n.t(
        zhHans: '好友删除失败',
        zhHant: '好友刪除失敗',
        en: 'Failed to remove friend',
        ja: '友達の削除に失敗',
        ko: '친구 삭제 실패',
      ));
    }
  }

  static ConversationPeekActions _buildActions(
    BuildContext context,
    V2TimConversation conversation,
    V2TimFriendInfo friend,
  ) {
    final userId = friend.userID.trim();
    final isOfficial = PlatformOfficialAccountService.isPlatformOfficialAccount(
      conversation.userID,
    );
    final isStarred = StarredFriendProvider.shared.isStarred(userId);
    return ConversationPeekActions(
      variant: ConversationPeekMenuVariant.contact,
      onOpenChat: () => openChatWithAnchor(context, conversation),
      isOfficialAccount: isOfficial,
      isStarred: isStarred,
      onlineStatusText: _onlineStatusText(context, conversation),
      onViewProfile: () async {
        await ProfilePageNav.openUserProfile(
          context,
          userID: userId,
          addSource: 'contacts',
        );
      },
      onToggleStar: isOfficial
          ? null
          : () async {
              await _toggleStar(context, userId);
            },
      onDeleteFriend: isOfficial
          ? null
          : () async {
              await _deleteFriend(context, userId);
            },
    );
  }

  static Future<void> show(
    BuildContext context, {
    required V2TimFriendInfo friend,
  }) async {
    if (kIsWeb) {
      return;
    }
    final conversation = await resolveConversation(friend);
    if (!context.mounted || !ConversationPeekService.canPeek(conversation)) {
      return;
    }
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    showConversationPeekForItem(
      context: context,
      conversation: conversation,
      displayName: ConversationDisplayHelper.showName(
        conversation: conversation,
        friendList: friendship.friendList,
      ),
      actions: _buildActions(context, conversation, friend),
    );
  }
}
