import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/pages/add_friend_page.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/add_friend_navigator.dart';

/// 将 UIKit 聊天内「重新添加好友」等入口收口到自研 [AddFriendPage]。
class UikitAddFriendBridge {
  UikitAddFriendBridge._();

  static void install() {
    AddFriendNavigator.openAddFriendPage = _openAddFriendPage;
  }

  static Future<void> _openAddFriendPage(
    BuildContext context, {
    required String userID,
    required V2TimUserFullInfo friendInfo,
    String? addSource,
    String? groupId,
  }) async {
    if (!context.mounted) {
      return;
    }
    final id = userID.trim();
    if (id.isEmpty) {
      return;
    }
    final displayName = TencentUtils.checkString(friendInfo.nickName) ?? id;
    await AddFriendPage.open(
      context,
      userID: id,
      nickname: displayName,
      initialUserInfo: friendInfo,
      addSource: addSource?.trim().isNotEmpty == true
          ? addSource!.trim()
          : FriendAddSource.chat,
      groupId: groupId,
    );
  }
}
