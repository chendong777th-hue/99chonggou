import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/my_profile_detail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/add_friend_page.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class ProfilePageNav {
  ProfilePageNav._();

  static String? _selfUserId() =>
      serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim();

  static bool isSelfUser(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    final self = _selfUserId() ?? '';
    return id.isNotEmpty && self.isNotEmpty && id == self;
  }

  static bool isFriendInContactList(String userID) {
    final id = ChatIdFormat.rawUserUid(userID);
    if (id.isEmpty) {
      return false;
    }
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    for (final item in friendship.friendList ?? const <V2TimFriendInfo>[]) {
      if (ChatIdFormat.rawUserUid(item.userID) != id) {
        continue;
      }
      // 出现在自托管/IM 好友列表中即视为好友（customInfo 可能尚未同步）。
      return true;
    }
    return false;
  }

  static Future<bool> isFriendUser(String userID) async {
    final id = ChatIdFormat.rawUserUid(userID);
    if (id.isEmpty || isSelfUser(id)) {
      return false;
    }
    if (isFriendInContactList(id)) {
      return true;
    }
    return MeFriendApi.instance.isFriend(id);
  }

  static Future<void> openMyProfileDetail(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    final selfInfo = serviceLocator<TUISelfInfoViewModel>().loginInfo;
    await Navigator.push(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => MyProfileDetail(
          userProfile: selfInfo,
          controller: TIMUIKitProfileController(),
        ),
      ),
    );
  }

  static Future<bool> openUserProfile(
    BuildContext context, {
    required String userID,
    String? addSource,
    String? groupId,
    void Function(String remark)? onRemarkUpdate,
  }) async {
    final id = ChatIdFormat.rawUserUid(userID);
    if (id.isEmpty) {
      return false;
    }
    if (isSelfUser(id)) {
      await openMyProfileDetail(context);
      return false;
    }
    if (!context.mounted) {
      return false;
    }

    // 桌面 / Web：不要全屏盖住左侧导航与会话列表。
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (isDesktop) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      DesktopProfileHost.open(id, groupId: groupId);
      return false;
    }

    final result = await Navigator.push(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => UserProfile(
          userID: id,
          addSource: addSource,
          groupId: groupId,
          onRemarkUpdate: onRemarkUpdate,
        ),
      ),
    );
    return result == UserProfileRouteResult.friendDeleted;
  }

  static Future<bool> openUserProfileOrAddFriend(
    BuildContext context, {
    required String userID,
    String? nickname,
    String? avatarUrl,
    int? lastActiveAt,
    String? lastActiveVisibility,
    String? addSource,
    String? groupId,
    void Function(String remark)? onRemarkUpdate,
  }) async {
    final id = ChatIdFormat.rawUserUid(userID);
    if (id.isEmpty) {
      return false;
    }
    if (isSelfUser(id)) {
      await openMyProfileDetail(context);
      return false;
    }

    final effectiveAddSource =
        addSource?.trim().isNotEmpty == true ? addSource!.trim() : FriendAddSource.chat;

    // 群上下文看资料：按 groupId 做隐私保护；与「加好友渠道」解耦。
    final gid = groupId?.trim() ?? '';
    if (gid.isNotEmpty) {
      final blockedHint = await GroupPrivacyGuard.blockedGroupProfileHint(
        groupId: gid,
        targetUserId: id,
      );
      if (blockedHint != null) {
        if (context.mounted) {
          ToastUtils.toast(blockedHint);
        }
        return false;
      }
    }

    if (!context.mounted) {
      return false;
    }

    final isFriend = await isFriendUser(id);
    if (isFriend) {
      return openUserProfile(
        context,
        userID: id,
        addSource: effectiveAddSource,
        groupId: groupId,
        onRemarkUpdate: onRemarkUpdate,
      );
    }

    final displayName =
        nickname?.trim().isNotEmpty == true ? nickname!.trim() : id;
    V2TimUserFullInfo? sdkUserInfo;
    final sdkRes =
        await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [id]);
    if (sdkRes.code == 0 && sdkRes.data != null && sdkRes.data!.isNotEmpty) {
      sdkUserInfo = sdkRes.data!.first;
    }
    final initialInfo = sdkUserInfo ??
        V2TimUserFullInfo(
          userID: id,
          nickName: displayName,
          faceUrl: avatarUrl?.trim() ?? '',
        );

    if (!context.mounted) {
      return false;
    }

    await AddFriendPage.open(
      context,
      userID: id,
      nickname: TencentUtils.checkString(initialInfo.nickName) ?? displayName,
      initialUserInfo: initialInfo,
      addSource: effectiveAddSource,
      lastActiveAt: lastActiveAt,
      lastActiveVisibility: lastActiveVisibility,
      groupId: groupId,
    );
    return false;
  }
}
